terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

module myip {
  source  = "4ops/myip/http"
  version = "1.0.0"
}

resource "aws_vpc" "my_first_VPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "MyFirstVPC"
  }
}

############################################################################################################
# Public Subnet 1 
############################################################################################################

resource "aws_subnet" "my_public_subnet1" {
  vpc_id     = aws_vpc.my_first_VPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  tags       = {
  Name = "MyPublicSubnet1"
   }
}

############################################################################################################
# Application Load Balancer
############################################################################################################

resource "aws_lb" "web_alb" {
  name               = "web-alb"
  load_balancer_type = "application"
  subnets            = [
    aws_subnet.my_public_subnet1.id,
    aws_subnet.my_public_subnet2.id
  ]
  security_groups    = [aws_security_group.web_sg.id]

  enable_deletion_protection = false

  tags = {
    Name = "web-alb"
  }
}

resource "aws_lb_target_group" "web_lbtg" {
  name     = "web-lbtg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_first_VPC.id
  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "http_l" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_lbtg.arn
  }
}

# target group attachments missing
# für ALB test 2 instances in target group
# testalb user data on instances (no wordpress)

resource "aws_lb_target_group_attachment" "web1" {
  target_group_arn = aws_lb_target_group.web_lbtg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web2" {
  target_group_arn = aws_lb_target_group.web_lbtg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}

resource "aws_instance" "web1" {
  ami                    = "ami-040361ed8686a66a2" # dein AMI
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.my_public_subnet1.id
  key_name               = "vockey"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true      
  user_data              = file("${path.module}/userdata/test_ALB.sh")

  tags = {
    Name = "web1"
  }
}

resource "aws_instance" "web2" {
  ami                         = "ami-040361ed8686a66a2"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.my_public_subnet2.id
  key_name                    = "vockey"
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true                    
  user_data                   = file("${path.module}/userdata/test_ALB.sh")
  tags = {
    Name = "web2"
  }
}


############################################################################################################
# Autoscaling Web Servers 
############################################################################################################

resource "aws_launch_template" "web_lt" {
  name_prefix = "web-server-"
  image_id = "ami-040361ed8686a66a2"
  instance_type = "t3.micro"
  key_name = "vockey"
  network_interfaces {
    associate_public_ip_address = true
    device_index                = 0
    subnet_id                   = aws_subnet.my_public_subnet1.id
    security_groups             = [aws_security_group.web_sg.id]
  }
  user_data = base64encode(file("userdata/wordpress.tpl.sh"))
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-server"
      }
  }
}

resource "aws_autoscaling_group" "web_asg" {
name                      = "web-asg"
  max_size                  = 4
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = [
    aws_subnet.my_public_subnet1.id,
    aws_subnet.my_public_subnet2.id
  ]
  health_check_type         = "EC2"
  health_check_grace_period = 300
  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "WebServer"
    propagate_at_launch = true
  }
    enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
}

resource "aws_autoscaling_policy" "cpu_policy" {
  name                   = "scale_on_cpu"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value       = 60.0  # ➤ Ziel: 60 % durchschnittliche CPU-Auslastung
  }
}


############################################################################################################
# Bastion Host 
############################################################################################################

resource "aws_instance" "Bastion_Host" {
  ami           = "ami-040361ed8686a66a2"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.my_public_subnet1.id
  key_name = "vockey"
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  tags = {
    Name = "BastionHost"
  }
}

resource "aws_eip" "bastion_eip" {
  domain = "vpc"
  tags = {
    Name = "BastionEIP"
  }
}
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.Bastion_Host.id
  allocation_id = aws_eip.bastion_eip.id
}

############################################################################################################
# Public Subnet 2 
############################################################################################################

resource "aws_subnet" "my_public_subnet2" {
  vpc_id     = aws_vpc.my_first_VPC.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"
  tags       = {
   Name = "MyPublicSubnet2"
   }
}

resource "aws_internet_gateway" "my_first_IGW" {
  vpc_id = aws_vpc.my_first_VPC.id

  tags = {
    Name = "MyFirstIGW"
  }
}

resource "aws_route_table" "my_first_routetable" {
  vpc_id = aws_vpc.my_first_VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_first_IGW.id
  }
  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.my_public_subnet1.id
  route_table_id = aws_route_table.my_first_routetable.id
  }

  resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.my_public_subnet2.id
  route_table_id = aws_route_table.my_first_routetable.id
  }

############################################################################################################
# Private Subnet 1 
############################################################################################################

# resource "aws_subnet" "my_private_subnet1" {
#   vpc_id     = aws_vpc.my_first_VPC.id
#   availability_zone = "us-west-2a"
#   cidr_block = "10.0.3.0/24"
#   tags       = {
#    Name = "MyPrivateSubnet1"
#    }
# }

# RDS Instance
resource "aws_db_subnet_group" "discogs_db_subnet_group" {
  name       = "discogs-db-subnet-group"
  subnet_ids = [
    aws_subnet.my_public_subnet1.id,
    aws_subnet.my_public_subnet2.id
  ]
  tags = {
    Name = "DiscogsDBSubnetGroup"
  }
}
resource "aws_db_instance" "discogs_db" {
  identifier              = "discogs-db"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  db_name                 = "discogs"
  username                = "admin"
  password                = "SuperSecretPass123"
  skip_final_snapshot     = true
  deletion_protection     = false
  publicly_accessible     = false
  multi_az                = false
  db_subnet_group_name    = aws_db_subnet_group.discogs_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  tags = {
    Name = "DiscogsRDS"
  }
}


# Route Table für das private Subnet
# resource "aws_route_table" "private_rt" {
#   vpc_id = aws_vpc.my_first_VPC.id
#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.nat_gw.id
#   }
#   tags = {
#     Name = "PrivateRouteTable"
#   }
# }
# Route Table Association für das private Subnet
# resource "aws_route_table_association" "private_assoc" {
#   subnet_id      = aws_subnet.my_private_subnet1.id
#   route_table_id = aws_route_table.private_rt.id
# }

############################################################################################################
# NAT Gateway
############################################################################################################

# resource "aws_eip" "nat_eip" {
#  domain = "vpc"
#   tags = {
#     Name = "NAT_EIP"
#   }
# }

# # NAT Gateway im öffentlichen Subnet
# resource "aws_nat_gateway" "nat_gw" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id     = aws_subnet.my_public_subnet1.id
#   tags = {
#     Name = "MyNATGateway"
#   }
#   depends_on = [aws_internet_gateway.my_first_IGW]
# }

############################################################################################################
# Security Groups
############################################################################################################

resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Allow SSH from my IP, HTTP/HTTPS from anywhere"
  vpc_id      = aws_vpc.my_first_VPC.id

  tags = {
    Name = "bastion_sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_ingress" {
  security_group_id = aws_security_group.bastion_sg.id
  description        = "SSH from my IP"
  from_port          = 22
  to_port            = 22
  ip_protocol        = "tcp"
  cidr_ipv4          = "${module.myip.address}/32"
}
resource "aws_vpc_security_group_egress_rule" "bastion_allow_all" {
  security_group_id = aws_security_group.bastion_sg.id
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}


############################################################################################################

resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow HTTP from anywhere"
  vpc_id      = aws_vpc.my_first_VPC.id
  tags = {
    Name = "web_sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "web_http_ingress" {
  security_group_id = aws_security_group.web_sg.id
  description        = "HTTP from anywhere"
  from_port          = 80
  to_port            = 80
  ip_protocol        = "tcp"
  cidr_ipv4          = "0.0.0.0/0"
}
resource "aws_vpc_security_group_egress_rule" "web_allow_all" {
  security_group_id = aws_security_group.web_sg.id
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}

############################################################################################################

resource "aws_security_group" "db_sg" {
  name        = "db_sg"
  description = "Allow MySQL access from Bastion Host"
  vpc_id      = aws_vpc.my_first_VPC.id
  tags = {
    Name = "db_sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "db_mysql_from_webagent" {
  security_group_id            = aws_security_group.db_sg.id
  description                  = "Allow MySQL from Web/Agent EC2"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.web_sg.id
}
resource "aws_vpc_security_group_ingress_rule" "db_ssh_from_bastion" {
  security_group_id            = aws_security_group.db_sg.id
  description                  = "Allow SSH from Bastion Host"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion_sg.id
}
resource "aws_vpc_security_group_egress_rule" "db_allow_all" {
  security_group_id = aws_security_group.db_sg.id
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}

############################################################################################################
