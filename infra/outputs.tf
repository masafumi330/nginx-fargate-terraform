output "vpc_id" {
  description = "Primary VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = values(aws_subnet.public)[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = values(aws_subnet.private)[*].id
}

output "alb_security_group_id" {
  description = "Security group used by ALB"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "Security group used by ECS services"
  value       = aws_security_group.ecs.id
}

output "ecr_repository_url" {
  description = "URL of the application ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the application ECR repository"
  value       = aws_ecr_repository.app.arn
}
