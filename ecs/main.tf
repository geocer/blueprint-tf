module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = var.ecs_cluster_name

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = var.ecs_log_group_name
      }
    }
  }

  fargate_capacity_providers = local.fargate_capacity_providers

  # Iterando sobre os serviços definidos em locals
  services = local.ecs_services

  tags = var.common_tags
}
