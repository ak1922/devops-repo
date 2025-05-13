#--------- Security Key -----------
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key" {
  key_name   = "keybridge-key"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "local_file" "keyfile" {
  content  = tls_private_key.private_key.private_key_pem
  filename = "keybridge-keyfile"
}

#---------- Auto scaling -----------
# Launch template
resource "aws_launch_template" "app_template" {
  name                   = "${local.project_tags.app}-lt"
  key_name               = aws_key_pair.key.key_name
  instance_type          = var.instance_type
  user_data              = filebase64("userdata.sh")
  image_id               = data.aws_ami.server_image.id
  vpc_security_group_ids = [aws_security_group.asg_group.id]

  monitoring {
    enabled = true
  }
}

# Load Balancer
resource "aws_lb" "app_lb" {
  name                             = "${local.project_tags.app}-lt"
  subnets                          = [for i in aws_subnet.app_vpc_public : i.id]
  enable_deletion_protection       = false
  load_balancer_type               = "application"
  enable_cross_zone_load_balancing = true

  depends_on = [
    aws_security_group.asg_group,
    aws_security_group.lb_group
  ]
}

# Target group
resource "aws_lb_target_group" "app_lb_group" {
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.app_vpc.id
  name        = "${local.project_tags.app}-lb-tg"

  health_check {
    protocol            = "HTTP"
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 7
    timeout             = 5
  }

  depends_on = [aws_lb.app_lb]

  tags = merge({ Name = "${local.project_tags.app}-lb-tg" }, local.project_tags)
}

# Listener
resource "aws_lb_listener" "lb_listener" {
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_lb_group.arn
  }

  port              = 80
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.app_lb.arn

  depends_on = [aws_lb_target_group.app_lb_group]
}

# Scaling group
resource "aws_autoscaling_group" "asg" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  name                = "${local.project_tags.app}-asg"
  vpc_zone_identifier = [for x in aws_subnet.app_vpc_private[*] : x.id]
  target_group_arns   = [aws_lb_target_group.app_lb_group.arn]

  launch_template {
    version = aws_launch_template.app_template.latest_version
    id      = aws_launch_template.app_template.id
  }
}

# Scale down policy
resource "aws_autoscaling_schedule" "scale_down" {
  min_size               = 1
  max_size               = 1
  start_time             = local.downscale
  recurrence             = "00 20 * * *"
  desired_capacity       = 1
  autoscaling_group_name = aws_autoscaling_group.asg.name
  scheduled_action_name  = "${local.project_tags.app}-asg-scaledown"
}

# Scaling attachment
resource "aws_autoscaling_attachment" "asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.asg.name
  lb_target_group_arn    = aws_lb_target_group.app_lb_group.arn
}

# Scale up
resource "aws_autoscaling_schedule" "scale_up" {
  min_size               = 1
  max_size               = 2
  desired_capacity       = 1
  recurrence             = "00 08 * * *"
  start_time             = local.upscale
  autoscaling_group_name = aws_autoscaling_group.asg.name
  scheduled_action_name  = "${local.project_tags.app}-asg-scaleup"
}
