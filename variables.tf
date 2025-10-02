variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  description = "Environment name (e.g. dev1, dev2, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "instance_type" {
  type = string
}

variable "ec2_name" {
  type    = string
  default = "tf-ec2"
}

variable "disk_size_gb" {
  type = number
}

variable "hosted_zone_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type = string
}

variable "db_identifier_name" {
  type = string
}

variable "s3_bucket_name" {
  description = "Name for S3 bucket name, environment will be appended"
  type        = string
}

variable "iam_role_name" {
  description = "IAM role name to attach to instance"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "Name for IAM instance profile name, environment will be appended"
  type        = string
}

variable "record_name" {
  type    = string
  default = "tfe"
}
