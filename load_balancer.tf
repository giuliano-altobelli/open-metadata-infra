resource "aws_lb" "openmetadata" {
  name               = substr("${local.name_prefix}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  drop_invalid_header_fields = true
  idle_timeout               = 120

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "openmetadata" {
  name        = substr("${local.name_prefix}-tg", 0, 32)
  port        = 8585
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.openmetadata.id

  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 10
    path                = "/api/v1/system/version"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}

resource "aws_lb_target_group_attachment" "openmetadata" {
  target_group_arn = aws_lb_target_group.openmetadata.arn
  target_id        = aws_instance.openmetadata.id
  port             = 8585
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.openmetadata.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openmetadata.arn
  }
}
