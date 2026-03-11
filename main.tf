locals {
  env       = var.environment
  zone_name = endswith(var.hosted_zone_name, ".") ? var.hosted_zone_name : "${var.hosted_zone_name}."

  vpc_name              = "tf-vpc-${local.env}"
  igw_name              = "tf-igw-${local.env}"
  rt_name               = "tf-public-rt-${local.env}"
  web_sg_name           = "tf-web-sg-${local.env}"
  db_sg_name            = "tf-db-sg-${local.env}"
  eip_name              = "tf-web-eip-${local.env}"
  ec2_name              = "${var.ec2_name}-${local.env}"
  db_identifier         = "${var.db_identifier_name}-${local.env}"
  db_subnet_group_name  = "tfe-db-subnet-group-${local.env}"
  s3_bucket_name        = "${var.s3_bucket_name}-${local.env}"
  iam_instance_profile  = "${var.iam_instance_profile_name}-${local.env}"
  record_name           = "${var.record_name}-${local.env}"
}

# Fetch available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = local.vpc_name })
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = local.igw_name })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, { Name = "tfe-public-subnet-${local.env}-${count.index + 1}" })
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.tags, { Name = local.rt_name })
}

resource "aws_route_table_association" "public_assoc" {
  count = length(aws_subnet.public[*].id)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for Web
resource "aws_security_group" "web_sg" {
  name        = local.web_sg_name
  description = "Allow SSH/HTTP/HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TFE Console"
    from_port   = 8800
    to_port     = 8800
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = local.web_sg_name })
}

# DB Security Group
resource "aws_security_group" "db_sg" {
  name        = local.db_sg_name
  description = "Allow Postgres from web instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from web_sg"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = local.db_sg_name })
}

# IAM
data "aws_iam_role" "existing_s3_role" {
  name = var.iam_role_name
}

resource "aws_iam_instance_profile" "web_profile" {
  name = local.iam_instance_profile
  role = data.aws_iam_role.existing_s3_role.name
}

# Web EC2 instance
resource "aws_instance" "web" {
  ami                         = "ami-062fdacc7ff0c9959"
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.web_profile.name

  root_block_device {
    volume_size = var.disk_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
              #!/bin/bash
              mkdir -p /home/ubuntu/.ssh
              echo "${file("${path.root}/jenkins_gcp_key.pub")}" > /home/ubuntu/.ssh/authorized_keys
              chown -R ubuntu:ubuntu /home/ubuntu/.ssh
              chmod 700 /home/ubuntu/.ssh
              chmod 600 /home/ubuntu/.ssh/authorized_keys
              EOF

  tags = merge(var.tags, { Name = local.ec2_name })
}

# Elastic IP
resource "aws_eip" "web_eip" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = local.eip_name })
}

resource "aws_eip_association" "web_eip_assoc" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web_eip.id
}

# RDS
resource "aws_db_subnet_group" "db_subnets" {
  name       = local.db_subnet_group_name
  subnet_ids = aws_subnet.public[*].id

  tags = merge(var.tags, { Name = local.db_subnet_group_name })
}

resource "aws_db_instance" "postgres" {
  identifier             = local.db_identifier
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  allocated_storage      = var.db_allocated_storage
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  skip_final_snapshot = true
  publicly_accessible = false
  multi_az            = false
  storage_encrypted   = true
  apply_immediately   = true

  tags = merge(var.tags, { Name = local.db_identifier })
}

# S3
resource "aws_s3_bucket" "ci_bucket" {
  bucket        = local.s3_bucket_name
  force_destroy = true

  tags = merge(var.tags, { Name = local.s3_bucket_name })
}

# Route53
data "aws_route53_zone" "target" {
  name         = local.zone_name
  private_zone = false
}

resource "aws_route53_record" "a_record" {
  zone_id = data.aws_route53_zone.target.zone_id
  name    = "${local.record_name}.${chomp(data.aws_route53_zone.target.name)}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.web_eip.public_ip]
}
