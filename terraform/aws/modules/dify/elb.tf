
resource "aws_lb" "dify" {
  name               = "${var.project}-dify-alb"
  load_balancer_type = "application"
  subnets            = var.vpc.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
}

# ALB Target Group
resource "aws_lb_target_group" "web" {
  name        = "${var.project}-dify-web"
  vpc_id      = var.vpc.id
  protocol    = "HTTP"
  port        = 3000
  target_type = "ip"

  slow_start           = 0
  deregistration_delay = 65

  health_check {
    path     = "/apps" # "/" だと 307 になる
    interval = 10
    # timeout             = 5
    # healthy_threshold   = 3
    # unhealthy_threshold = 5
  }
}

resource "aws_lb_target_group" "api" {
  name        = "${var.project}-dify-api"
  vpc_id      = var.vpc.id
  protocol    = "HTTP"
  port        = 5001
  target_type = "ip"

  slow_start           = 0
  deregistration_delay = 65

  health_check {
    path     = "/health"
    interval = 10
    # timeout             = 5
    # healthy_threshold   = 3
    # unhealthy_threshold = 5
  }
}

# ALB Listener (HTTP)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.dify.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ALB Listener Rule (API)
# path pattern によって API に振り分ける
locals {
  api_paths = ["/console/api", "/api", "/v1", "/files"]
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    path_pattern {
      values = local.api_paths
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_listener_rule" "api_wildcard" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 11

  condition {
    path_pattern {
      values = [for path in local.api_paths : "${path}/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
