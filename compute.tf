resource "aws_iam_role" "instance" {
  name_prefix = "${local.name_prefix}-ec2-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "openmetadata" {
  name_prefix = "${local.name_prefix}-"
  role        = aws_iam_role.instance.name
}

resource "aws_ebs_volume" "openmetadata" {
  availability_zone = local.availability_zones[0]
  encrypted         = true
  type              = "gp3"
  size              = var.data_volume_size_gib
  iops              = 3000
  throughput        = 125

  tags = {
    Name = "${local.name_prefix}-data"
  }
}

resource "aws_instance" "openmetadata" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.openmetadata.name

  user_data                   = local.user_data
  user_data_replace_on_change = true

  monitoring              = false
  disable_api_termination = false
  ebs_optimized           = true

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gib
    delete_on_termination = true
  }

  tags = {
    Name = "${local.name_prefix}-server"
  }

  depends_on = [aws_iam_role_policy_attachment.ssm]
}

resource "aws_volume_attachment" "openmetadata" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.openmetadata.id
  instance_id = aws_instance.openmetadata.id
}
