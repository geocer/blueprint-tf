variable "project_name" {
  description = "Name of the project used for naming conventions and tagging."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources in."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where resources will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALBs."
  type        = list(string)
}

variable "alb_certificate_arn" {
  description = "ARN of the ACM certificate for ALB HTTPS listeners."
  type        = string
}

variable "alb_access_logs_bucket" {
  description = "Name of the S3 bucket for ALB access logs."
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  type        = string
}

variable "ecs_log_group_name" {
  description = "CloudWatch Log Group name for ECS cluster logs."
  type        = string
}

variable "ecs_services" {
  description = "Map of ECS Fargate service definitions."
  type = map(object({
    cpu                 = number
    memory              = number
    container_definitions = map(object({
      image               = string
      container_port      = optional(number)
      essential           = optional(bool, true)
      cpu                 = optional(number)
      memory              = optional(number)
      environment         = optional(map(string), {})
      firelens_configuration = optional(object({
        type = string
      }))
      log_configuration   = optional(object({
        logDriver = string
        options   = map(string)
      }))
    }))
    health_check_path   = string
    health_check_port   = string
    desired_count       = number
    min_healthy_percent = number
    max_percent         = number
    alb_listener_port   = number
    alb_protocol        = string
    alb_host_header     = optional(string)
    additional_task_role_policy_arns = optional(list(string), [])
  }))
}