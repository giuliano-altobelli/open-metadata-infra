mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b", "us-west-2c"]
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }
}

run "lightweight_secure_defaults" {
  command = plan

  variables {
    allowed_cidrs = ["198.51.100.10/32"]
  }

  assert {
    condition     = aws_instance.openmetadata.instance_type == "t3a.xlarge"
    error_message = "The default instance must retain the agreed 4-vCPU/16-GiB proof-of-concept size."
  }

  assert {
    condition     = aws_instance.openmetadata.credit_specification[0].cpu_credits == "standard"
    error_message = "Burst credits must use standard mode to prevent unbounded T3 surplus-credit charges."
  }

  assert {
    condition     = aws_ebs_volume.openmetadata.size == 100 && aws_ebs_volume.openmetadata.encrypted
    error_message = "The separate data volume must be an encrypted 100-GiB baseline."
  }

  assert {
    condition     = aws_instance.openmetadata.metadata_options[0].http_tokens == "required"
    error_message = "The EC2 instance must require IMDSv2 tokens."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.instance_from_alb.from_port == 8585 &&
      aws_vpc_security_group_ingress_rule.instance_from_alb.to_port == 8585 &&
      aws_vpc_security_group_ingress_rule.instance_from_alb.cidr_ipv4 == null
    )
    error_message = "Port 8585 must not use CIDR-based ingress."
  }

  assert {
    condition     = aws_lb_listener.http.protocol == "HTTP" && aws_lb_listener.http.port == 80
    error_message = "The explicitly accepted short-lived test endpoint must use the HTTP ALB listener."
  }

  assert {
    condition     = aws_lb_target_group.openmetadata.health_check[0].path == "/api/v1/system/version"
    error_message = "The ALB must use a valid unauthenticated OpenMetadata readiness endpoint."
  }

}

run "rejects_world_open_http" {
  command = plan

  variables {
    allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.allowed_cidrs]
}

run "rejects_undersized_data_volume" {
  command = plan

  variables {
    allowed_cidrs        = ["198.51.100.10/32"]
    data_volume_size_gib = 99
  }

  expect_failures = [var.data_volume_size_gib]
}
