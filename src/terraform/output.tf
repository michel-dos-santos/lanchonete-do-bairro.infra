output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public Subnets IDs in the VPC"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private Subnets IDs in the VPC"
  value       = module.vpc.private_subnets
}
