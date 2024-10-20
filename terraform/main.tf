provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "terraform_extra_2" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "igw_terraform" {
  vpc_id = aws_vpc.terraform_extra_2.id
}

locals {
  azs = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

resource "aws_subnet" "terraform_subnet" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.terraform_extra_2.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = local.azs[count.index]

  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.terraform_extra_2.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_terraform.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.terraform_subnet[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "terraform_sg" {
  vpc_id = aws_vpc.terraform_extra_2.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}

resource "aws_instance" "terraform_hw" {
  ami           = "ami-0084a47cc718c111a"
  instance_type = "t3.micro"
  # key_name      = "terraform-instance-test"
  subnet_id     = element(aws_subnet.terraform_subnet[*].id, 0)
  security_groups = [aws_security_group.terraform_sg.id]

  tags = {
    Name = "TerraformHW"
  }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.terraform_extra_2.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.terraform_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_parameter_group" "pg_terraform" {
  name   = "pgterraform"
  family = "postgres16"
  description = "for terraform hw"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_db_subnet_group" "subgroup" {
  name       = "db-group"
  subnet_ids = aws_subnet.terraform_subnet[*].id

  tags = {
    Name = "db to single vpc"
  }
}

resource "aws_db_instance" "postgres" {
  identifier         = "terraformdb"
  engine             = "postgres"
  instance_class     = "db.t4g.micro"
  engine_version     = "16"
  allocated_storage   = 20
  db_name            = "tfhw"
  username           = "dummy"
  password           = "dummy1337"
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.subgroup.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  parameter_group_name = aws_db_parameter_group.pg_terraform.name
}
