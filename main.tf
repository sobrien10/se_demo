#Configure the AWS provider
provider "aws" {
  version = "~> 2.0"  
  region  = "eu-west-2"
}

#Configure the VPC and Public Subnets
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> v2.0"

  name = "${var.prefix}-f5-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway = true

  tags = {
    Environment = "ob1-vpc-teraform"
  }
}

#Configure the security Group
resource "aws_security_group" "f5" {
  name   = "${var.prefix}-f5"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["90.208.9.18/32"]
  }

    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["90.208.9.18/32"]
  }

    ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["90.208.9.18/32"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["90.208.9.18/32"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["90.208.9.18/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ob1-SecurityGroup1"
  }
}

#Configure the mgmt interface and assign public IP
resource "aws_network_interface" "mgmt" {
  subnet_id   = module.vpc.public_subnets[0]
  private_ips = ["10.0.1.10"]
  security_groups = [ aws_security_group.f5.id ]

  tags = {
    Name = "mgmt_interface"
  }
}

resource "aws_eip" "mgmt" {
  vpc                       = true
  network_interface         = aws_network_interface.mgmt.id
  associate_with_private_ip = "10.0.1.10"
}

#Configure the public interface and assign public IP
resource "aws_network_interface" "public" {
  subnet_id   = module.vpc.public_subnets[1]
  private_ips = ["10.0.2.10", "10.0.2.11"]
  security_groups = [ aws_security_group.f5.id ]

  tags = {
    Name = "public_interface"
  }
}

resource "aws_eip" "public1" {
  vpc                       = true
  network_interface         = aws_network_interface.public.id
  associate_with_private_ip = "10.0.2.10"
}

resource "aws_eip" "public2" {
  vpc                       = true
  network_interface         = aws_network_interface.public.id
  associate_with_private_ip = "10.0.2.11"
}

#Find the ami variable
data "aws_ami" "f5_ami" {
  most_recent = true
  owners      = ["679593333241"]
  filter {    
  name   = "name"
  values = [var.f5_ami_search_name]
    }
  }

#Create a random Password
  resource "random_string" "password" {
    length  = 10
    special = false
  }

#Data for the user-data.tmpl file
  data "template_file" "f5_init" {
      template = file("user-data.tmpl")
      vars = {
      password              = random_string.password.result
      doVersion             = "latest"
      #example version:    
      #as3Version           = "3.16.0"
      as3Version            = "latest"
      tsVersion             = "latest"
      cfVersion             = "latest"
      fastVersion           = "latest"
      libs_dir              = var.libs_dir
      onboard_log           = var.onboard_log
      projectPrefix         = var.prefix
    }
  }

#Create the BIG-IP
resource "aws_instance" "big-ip" {
  ami           = data.aws_ami.f5_ami.id
  instance_type = "m5.xlarge"
  key_name      = var.ssh_key_name
  user_data     = data.template_file.f5_init.rendered

    network_interface {
    network_interface_id = aws_network_interface.mgmt.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.public.id
    device_index         = 1
  }

   provisioner "local-exec" {
    command = "while [[ \"$(curl -skiu ${var.username}:${random_string.password.result} https://${self.public_ip}/mgmt/shared/appsvcs/declare | grep -Eoh \"^HTTP/1.1 204\")\" != \"HTTP/1.1 204\" ]]; do sleep 5; done"
  }

  tags = {
    Name = "ob1-mybigip"
  }
}

output "f5_password" {
  value = random_string.password.result
}

output "f5_tmui" {
  value = "https://${aws_eip.mgmt.public_ip}"
}

output "f5_user" {
  value = var.username
}

output "f5_pub_ip" {
  value = aws_eip.public1.private_ip
}

data "aws_subnet" "f5_pub_data" {
  id = module.vpc.public_subnets[1]
}

output "f5_pub_cidr" {
  value = data.aws_subnet.f5_pub_data.cidr_block
}