provider "aws" {
  assume_role {
    role_arn = var.AWS_ASSUME_ROLE_ARN
    external_id = var.AWS_EXTERNAL_ID
  }  
  region = local.aws_region
}

module "ecs_main" {
  source = "terraform-aws-modules/ecs/aws"
  version = "5.12.1"

  cluster_name          = local.ecs_cluster_config.cluster_name
  cluster_configuration = local.ecs_cluster_config.cluster_configuration
  fargate_capacity_providers = local.ecs_cluster_config.fargate_capacity_providers

  services = { for service_name, service_attrs in local.ecs_service_configs : service_name => {
      name                       = service_name
      desired_count              = service_attrs.desired_count
      launch_type                = service_attrs.launch_type
      fargate_platform_version   = service_attrs.fargate_platform_version
      cpu                        = service_attrs.cpu
      memory                     = service_attrs.memory
      container_definitions      = service_attrs.container_definitions
      load_balancer              = service_attrs.load_balancer
      subnet_ids                 = service_attrs.subnet_ids
      security_group_rules       = service_attrs.security_group_rules

      deployment_controller      = service_attrs.deployment_controller
      deployment_minimum_healthy_percent = service_attrs.deployment_minimum_healthy_percent
      deployment_maximum_percent = service_attrs.deployment_maximum_percent

      tags                       = service_attrs.tags
      
      tasks_iam_role_name               = service_attrs.tasks_iam_role_name
      tasks_iam_role_description        = service_attrs.tasks_iam_role_description
      tasks_iam_role_policies           = service_attrs.tasks_iam_role_policies
      tasks_iam_role_statements         = service_attrs.tasks_iam_role_statements
      service_connect_configuration     = service_attrs.service_connect_configuration
    } 
  }

  depends_on = [
    aws_lb_listener.dynamic_listener, # Depende do novo recurso de listener dinâmico
    aws_service_discovery_http_namespace.this
  ]

  tags = local.ecs_cluster_config.tags
}

resource "aws_service_discovery_http_namespace" "this" {
  name        = "${local.project_name}-app-namespace"
  description = "HTTP namespace for application services"
}

# Para cada serviço, cria apenas o ALB (sem listeners)
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.16.0"

  for_each = local.alb_core_configs

  name                           = each.value.name
  vpc_id                         = each.value.vpc_id
  subnets                        = each.value.subnets
  security_group_ingress_rules   = each.value.security_group_ingress_rules
  security_group_egress_rules    = each.value.security_group_egress_rules
  access_logs                    = each.value.access_logs

  
  enable_deletion_protection     = false
  internal                       = true # Mude para true se você quiser um ALB interno
  

  tags                           = each.value.tags
}

# Criação manual dos Target Groups
resource "aws_lb_target_group" "this" {
  for_each = local.target_group_configs 

  name_prefix          = each.value.name_prefix
  protocol             = each.value.protocol
  port                 = each.value.port
  target_type          = each.value.target_type
  vpc_id               = each.value.vpc_id
  deregistration_delay = 300 # Valor padrão recomendado para ECS

  health_check {
    enabled             = each.value.health_check.enabled
    path                = each.value.health_check.path
    port                = each.value.health_check.port
    protocol            = each.value.health_check.protocol
    matcher             = each.value.health_check.matcher
    interval            = each.value.health_check.interval
    timeout             = each.value.health_check.timeout
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
  }

  tags = each.value.tags
}

# ====================================================================
# RECURSO DE LISTENER DINÂMICO
# Corrigido o acesso a 'each.value.listener_config' e 'each.value.load_balancer_arn'
# ====================================================================
resource "aws_lb_listener" "dynamic_listener" {
  for_each = local.flat_alb_listeners # Itera sobre o mapa achatado

  load_balancer_arn = each.value.load_balancer_arn # Agora acessa diretamente
  port              = each.value.listener_config.port
  protocol          = each.value.listener_config.protocol
  certificate_arn   = each.value.listener_config.certificate_arn
  ssl_policy        = each.value.listener_config.ssl_policy

  default_action {
    type = each.value.listener_config.default_action_type

    # Bloco 'fixed_response' é incluído SOMENTE se o tipo for 'fixed-response'
    dynamic "fixed_response" {
      for_each = each.value.listener_config.default_action_type == "fixed-response" ? [each.value.listener_config.fixed_response] : []
      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }

    # Bloco 'forward' é incluído SOMENTE se o tipo for 'forward'
    dynamic "forward" {
      for_each = each.value.listener_config.default_action_type == "forward" ? [each.value.listener_config.forward] : []
      content {
        target_group {
          arn = forward.value.target_group_arn
        }
      }
    }

    # Bloco 'redirect' (se você quiser um futuro)
    dynamic "redirect" {
      for_each = each.value.listener_config.default_action_type == "redirect" ? [each.value.listener_config.redirect] : []
      content {
        port        = redirect.value.port
        protocol    = redirect.value.protocol
        status_code = redirect.value.status_code
      }
    }
  }

  tags = each.value.listener_config.tags
}

module "secrets_manager_docker_credentials" {
 source      = "terraform-aws-modules/secrets-manager/aws"

  name        = "docker/fmh.nexus"
  description = "Credenciais para o Docker Registry fmh.nexus.onefiserv.net"

  secret_string = jsonencode({
    username = "svc",
    password = var.docker_nexus_password
  })

  create_policy       = false
  block_public_policy = true

  recovery_window_in_days = 7
  create_random_password  = false

  tags = {
    Environment = "Development"
    Project     = "DockerIntegration"
  }
}