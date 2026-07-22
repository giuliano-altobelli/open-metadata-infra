locals {
  name_prefix = substr(var.project_name, 0, 24)

  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    Project     = var.project_name
    Environment = "poc"
    ManagedBy   = "Terraform"
  }

  openmetadata_url = "http://${aws_lb.openmetadata.dns_name}"

  compose_yaml = templatefile("${path.module}/templates/docker-compose.yml.tftpl", {
    openmetadata_version = var.openmetadata_version
    external_url         = local.openmetadata_url
  })

  user_data = templatefile("${path.module}/templates/user-data.sh.tftpl", {
    compose_yaml   = local.compose_yaml
    data_volume_id = aws_ebs_volume.openmetadata.id
  })
}

