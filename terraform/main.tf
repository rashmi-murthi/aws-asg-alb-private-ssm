terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
########################
# DATA
########################
data "aws_availability_zones" "available" {
  state = "available"
}
########################
# VPC & SUBNETS
########################

resource "aws_vpc" "demo_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "demo_vpc"
  }
}
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = var.public_subnet1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet1"
  }
}
resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = var.public_subnet2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet2"
  }
}
resource "aws_subnet" "private_subnet1" {
  cidr_block        = var.private_subnet1_cidr
  vpc_id            = aws_vpc.demo_vpc.id
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "private-subnet1"
  }
}
resource "aws_subnet" "private_subnet2" {
  cidr_block        = var.private_subnet2_cidr
  vpc_id            = aws_vpc.demo_vpc.id
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "private-subnet2"
  }
}
resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id
  tags = {
    Name = "demo-igw"
  }
}
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "nat-eip"
  }
}
resource "aws_nat_gateway" "demo_ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet1.id
  tags = {
    Name = "demo-ngw"
  }
  depends_on = [aws_internet_gateway.demo_igw]
}
# Public Route table 
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.demo_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }
  tags = {
    Name = "Public-rt"
  }
}
resource "aws_route_table_association" "public-1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public-2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_rt.id
}
# Private route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.demo_ngw.id
  }
  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_rt.id
}
########################
# SECURITY GROUPS
########################

# ALB SG – open to internet on 80
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "alb-sg"
  }
}
# EC2/ASG SG – accepts HTTP only from ALB SG
resource "aws_security_group" "asg_sg" {
  name        = "asg-sg"
  description = "ASG instances security group"
  vpc_id      = aws_vpc.demo_vpc.id
  tags = {
    Name = "asg-sg"
  }
}

resource "aws_security_group_rule" "asg_ingress_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.asg_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "asg_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.asg_sg.id
}


########################
# IAM FOR SSM
########################

resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  role = aws_iam_role.ec2_ssm_role.name
  name = "ec2-ssm-profile"
}

########################
# LAUNCH TEMPLATE
########################

locals {
  user_data = <<EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1

apt-get update -y
apt-get install -y nginx stress

systemctl enable nginx
systemctl start nginx

cat <<'HTML' > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head><title>ASG + NGINX</title></head>
<body style="font-family:Arial; text-align:center;">
<h2 style="color:green;">Auto Scaling Group with NGINX</h2>
<p>Served from instance: <strong>$(hostname -f)</strong></p>
</body>
</html>
HTML
EOF
}

resource "aws_launch_template" "lt_asg" {
  name_prefix   = "lt-asg"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm_profile.name
  }

  vpc_security_group_ids = [aws_security_group.asg_sg.id]

  user_data = base64encode(local.user_data)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "web-ec2"
    }
  }
}
########################
# TARGET GROUP + ALB
########################

resource "aws_lb_target_group" "tg_alb" {
  name     = "tg-alb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo_vpc.id

  health_check {
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "tg-alb"
  }
}

resource "aws_lb" "alb_public" {
  name               = "alb-public"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]

  tags = {
    Name = "alb-public"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb_public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_alb.arn
  }
}
########################
# AUTO SCALING GROUP
########################

resource "aws_autoscaling_group" "asg_private" {
  name                      = "asg-private"
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  target_group_arns = [aws_lb_target_group.tg_alb.arn]

  launch_template {
    id      = aws_launch_template.lt_asg.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "web-ec2"
    propagate_at_launch = true
  }
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 90
      instance_warmup        = 120
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb_listener.http]

}

########################
# TARGET TRACKING SCALING
########################

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "cpu-target"
  autoscaling_group_name = aws_autoscaling_group.asg_private.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}