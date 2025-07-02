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

resource "aws_instance" "my_first_instance" {
  ami           = "ami-040361ed8686a66a2"
  instance_type = "t2.micro"
  tags = {
    Name = "MyFirstInstance"
  }
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
   Name = "PublicSubnet1"
   }
}

resource "aws_internet_gateway" "my_first_IGW" {
  vpc_id = aws_vpc.my_first_VPC.id

  tags = {
    Name = "IGW"
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