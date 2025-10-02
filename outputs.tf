output "public_ip" {
  description = "Elastic IP attached to the EC2 instance"
  value       = aws_eip.web_eip.public_ip
}

output "private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.web.private_ip
}

output "fqdn" {
  description = "Fully qualified domain name mapped to the EC2 public IP"
  value       = aws_route53_record.a_record.fqdn
}

output "s3_bucket_name" {
  description = "S3 bucket created for CI"
  value       = aws_s3_bucket.ci_bucket.bucket
}

output "rds_endpoint" {
  description = "RDS Postgres endpoint"
  value       = aws_db_instance.postgres.address
}
