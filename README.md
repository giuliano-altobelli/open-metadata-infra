# OpenMetadata on one EC2 instance

Terraform for a short-lived OpenMetadata 1.12 proof of concept in `us-west-2`.

The stack creates:

- a dedicated VPC with two public subnets in separate Availability Zones;
- an internet-facing Application Load Balancer restricted to operator-supplied IPv4 CIDRs;
- one Ubuntu 24.04 `t3a.xlarge` EC2 instance with no inbound SSH;
- a 20-GiB encrypted root volume and a separate 100-GiB encrypted `gp3` data volume;
- Docker Compose services for OpenMetadata, PostgreSQL 15, and Elasticsearch 9.3;
- OpenMetadata native username/password authentication with self-signup disabled;
- an account-level AWS Budget with a $300 monthly threshold; and
- Systems Manager access for administration.

Airflow ingestion is intentionally omitted. The deployment is single-node, single-AZ, HTTP-only, and not suitable for production.

## Security boundary

OpenMetadata initially creates `admin@open-metadata.org` with password `admin`. The application is therefore not exposed to `0.0.0.0/0`; `allowed_cidrs` must contain your current public IP, normally as a `/32`. Change the admin password immediately after the first successful login under **Settings → Members → Admins**.

HTTP sends credentials without transport encryption. Use this only as the agreed short-lived test, avoid untrusted networks, and destroy the stack promptly. A longer-lived deployment should add a domain, ACM certificate, HTTPS listener, and production-grade external database and search services.

The EC2 security group accepts port 8585 only from the ALB security group. PostgreSQL, Elasticsearch, the OpenMetadata admin port, and SSH are not publicly reachable. PostgreSQL credentials, the Fernet key, and deployment-specific RSA JWT keys are generated on first boot and stored with restricted permissions on the encrypted EBS volume.

## Expected cost

The planning baseline for 730 hours in `us-west-2` is roughly **$150-$175/month** under light traffic:

| Resource | Approximate monthly cost |
| --- | ---: |
| `t3a.xlarge` On-Demand EC2 | $110-$120 |
| Application Load Balancer and light LCU use | $20-$25 |
| 120 GiB total `gp3` storage | about $10 |
| Three public IPv4 addresses (two ALB, one EC2) | about $11 |
| Data transfer and miscellaneous usage | variable |

This is an estimate, not a quote. Run the included Infracost guard before applying. The script exits nonzero if the priced Terraform plan exceeds $300. T3 CPU credits use `standard` mode so sustained CPU can throttle but cannot incur surplus-credit charges. AWS charges `$0.005` per public IPv4 address-hour, ALB pricing includes hourly and LCU charges, and `gp3` includes 3,000 IOPS and 125 MB/s at its storage baseline. See [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/), [Elastic Load Balancing pricing](https://aws.amazon.com/elasticloadbalancing/pricing/), and [EBS pricing](https://aws.amazon.com/ebs/pricing/).

The AWS Budget is account-wide so it cannot miss costs because cost-allocation tags have not yet activated. Set `budget_alert_email` to receive an actual-spend alert at 80% and a forecast alert at 100%. Budget forecasts can lag and do not replace the pre-apply cost check.

## Prerequisites

- Terraform 1.7 or newer
- AWS credentials able to manage VPC, EC2, ELBv2, IAM roles, SSM parameter reads, EBS, and AWS Budgets
- Infracost and `jq` for the pre-apply cost guard
- AWS CLI and the Session Manager plugin for shell access

Check the active AWS identity before planning:

```bash
aws sts get-caller-identity
```

## Configure

Create the untracked variable file:

```bash
cp terraform.tfvars.example terraform.tfvars
curl -4 https://checkip.amazonaws.com
```

Replace the example CIDR in `terraform.tfvars` with the returned address plus `/32`. Optionally add `budget_alert_email` and confirm the subscription email AWS sends.

## Validate and estimate

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform test
./tests/static-contract.sh
./scripts/check-cost.sh terraform.tfvars 300
```

The cost script requires `INFRACOST_API_KEY`. Review its unsupported and usage-based resources even when the threshold passes.

## Deploy

```bash
terraform plan -var-file=terraform.tfvars -out=openmetadata.tfplan
terraform apply openmetadata.tfplan
```

Bootstrap can take 10-20 minutes while packages and container images download, PostgreSQL initializes, and OpenMetadata runs its migrations. Follow it without opening SSH:

```bash
aws ssm start-session \
  --region us-west-2 \
  --target "$(terraform output -raw instance_id)"
```

Inside the SSM session:

```bash
sudo tail -f /var/log/openmetadata-bootstrap.log
sudo systemctl status openmetadata
cd /opt/openmetadata/app && sudo docker compose ps
```

## Validate the acceptance criterion

1. Wait until the target is healthy:

   ```bash
   aws elbv2 describe-target-health \
     --region us-west-2 \
     --target-group-arn "$(terraform output -raw target_group_arn)"
   ```

2. Open the printed URL:

   ```bash
   terraform output -raw openmetadata_url
   ```

3. Log in using `admin@open-metadata.org` and the initial password `admin`.
4. Change the password immediately under **Settings → Members → Admins**.
5. Confirm the catalog UI loads after signing out and signing back in with the new password.

The ALB health check uses OpenMetadata's unauthenticated `/api/v1/system/version` endpoint. If your public IP changes, update `allowed_cidrs` and apply again.

## Operations

Useful commands inside an SSM session:

```bash
cd /opt/openmetadata/app
sudo docker compose ps
sudo docker compose logs --tail=200 openmetadata-server
sudo systemctl restart openmetadata
```

All Docker images, container layers, PostgreSQL data, Elasticsearch data, generated credentials, and JWT keys live under `/opt/openmetadata` on the separate EBS volume.

## Destroy promptly

This is a cost-incurring test environment. When finished:

```bash
terraform plan -destroy -var-file=terraform.tfvars -out=destroy.tfplan
terraform apply destroy.tfplan
```

Destroying the stack permanently deletes the separate EBS data volume and its OpenMetadata data. The account-level AWS Budget is also deleted. Confirm the destroy plan before applying it.
