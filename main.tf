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

resource "aws_vpc" "my_first_VPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "MyFirstVPC"
  }
}

resource "aws_subnet" "my_public_subnet1" {
  vpc_id     = aws_vpc.my_first_VPC.id
  cidr_block = "10.0.1.0/24"
  tags       = {
   Name = "MyPublicSubnet1"
   }
}

resource "aws_instance" "my_public_instance1" {
  ami           = "ami-040361ed8686a66a2"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.my_public_subnet1.id
  key_name = "vockey"
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  tags = {
    Name = "MyPublicInstance1"
  }
}

resource "aws_eip" "bastion_eip" {
  domain = "vpc"
  tags = {
    Name = "BastionEIP"
  }
}
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.my_public_instance1.id
  allocation_id = aws_eip.bastion_eip.id
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

resource "aws_subnet" "my_private_subnet1" {
  vpc_id     = aws_vpc.my_first_VPC.id
  cidr_block = "10.0.2.0/24"
  tags       = {
   Name = "MyPrivateSubnet1"
   }
}

resource "aws_instance" "my_private_instance1" {
  ami           = "ami-040361ed8686a66a2"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.my_private_subnet1.id
  key_name = "vockey"
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  tags = {
    Name = "MyPrivateInstance1"
  }
}


resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Allow SSH from my IP, HTTP/HTTPS from anywhere"
  vpc_id      = aws_vpc.my_first_VPC.id
  # SSH (nur von deiner IP)
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["89.46.11.152/32"] # my IP
  }
  # HTTP (für WordPress)
  ingress {
    description = "HTTP from anywhere"
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
    Name = "bastion_sg"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "db_sg"
  description = "Allow MySQL access from Bastion Host"
  vpc_id      = aws_vpc.my_first_VPC.id
  ingress {
    description = "Allow MySQL from Bastion Host"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Bastion Host IP
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "db_sg"
  }
}