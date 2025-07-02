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