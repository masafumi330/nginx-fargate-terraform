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

output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.app.dns_name
}

output "alb_target_group_arn" {
  description = "Target group ARN for ECS service"
  value       = aws_lb_target_group.app.arn
}
