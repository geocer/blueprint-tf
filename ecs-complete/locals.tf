locals {
  # Extrai os dados do tfvars.auto.json
  project_name            = var.project_name
  aws_region              = var.aws_region
  vpc_id                  = var.vpc_id
  private_subnet_ids      = var.private_subnet_ids
  public_subnet_ids       = var.public_subnet_ids
  alb_certificate_arn     = var.alb_certificate_arn
  alb_access_logs_bucket  = var.alb_access_logs_bucket
  ecs_cluster_name        = var.ecs_cluster_name
  ecs_log_group_name      = var.ecs_log_group_name
  service_discovery_namespace_arn = aws_service_discovery_http_namespace.this.arn 

  ecs_services_input = {
    for k, v in var.ecs_services : k => v
  }

  # <<<<<<<<<< NOVO LOCAL ADICIONADO AQUI
  ecs_services_with_alb = {
    for service_name, service_attrs in local.ecs_services_input : service_name => service_attrs
    if lookup(service_attrs, "create_alb", false) # Filtra serviços que devem ter ALB
  }

  alb_core_configs = { 
    for service_name, service_attrs in local.ecs_services_with_alb : service_name => { # <<<< USANDO NOVO LOCAL
    name = "${local.project_name}-${service_name}-alb"
    vpc_id = local.vpc_id
    subnets = local.public_subnet_ids # ALBs geralmente ficam em subnets públicas

    # Regras de Security Group para o ALB
    security_group_ingress_rules = {
      http_from_any = {
        from_port   = 80
        to_port     = 80
        ip_protocol = "tcp"
        description = "Allow HTTP access from anywhere"
        cidr_ipv4   = "0.0.0.0/0"
      }
      https_from_any = {
        from_port   = 443
        to_port     = 443
        ip_protocol = "tcp"
        description = "Allow HTTPS access from anywhere"
        cidr_ipv4   = "0.0.0.0/0"
      }
    }
    security_group_egress_rules = {
      all = {
        ip_protocol = "-1"
        cidr_ipv4   = "0.0.0.0/0"
      }
    }

    # Logs de acesso do ALB
    access_logs = {
      bucket = local.alb_access_logs_bucket
      enabled = true # Alterado para true para habilitar logs
    }

    tags = {
      Environment = "Development"
      Project     = local.project_name
      Service     = service_name
    }
  }}

  # Mapeamento para criar Target Groups de forma independente
  target_group_configs = { 
    for service_name, service_attrs in local.ecs_services_with_alb : service_name => { # <<<< USANDO NOVO LOCAL
    name                 = "${local.project_name}-${service_name}-tg"
    name_prefix          = substr(service_name, 0, 6)
    protocol             = "HTTP"
    port                 = service_attrs.container_definitions[keys(service_attrs.container_definitions)[0]].container_port
    target_type          = "ip" # Para Fargate
    vpc_id               = local.vpc_id
    deregistration_delay = 300 # Valor padrão recomendado para ECS
    health_check = {
      enabled             = true
      path                = service_attrs.health_check_path
      port                = service_attrs.health_check_port
      protocol            = "HTTP"
      matcher             = "200"
      interval            = 30
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 2
    }
    tags = {
      Environment = "Development"
      Project     = local.project_name
      Service     = service_name
    }
  }}

  # ====================================================================
  # MAPEAMENTO PARA LISTENERS: AGORA COM fixed-response E forward
  # ====================================================================
  alb_dynamic_listener_configs = {
    for service_name, service_attrs in local.ecs_services_with_alb : service_name => { # <<<< USANDO NOVO LOCAL
      # Listener HTTP (porta 80) com fixed-response
      "http-fixed-response" = { # Chave simplificada para este listener
        port              = 80
        protocol          = "HTTP"
        certificate_arn   = null # Não precisa de certificado para HTTP
        ssl_policy        = null
        default_action_type = "fixed-response"
        fixed_response = {
          content_type = "text/plain"
          message_body = "No HTTP route defined for ${service_name} on port 80"
          status_code  = "200"
        }
        forward = null
        redirect = null
        tags = {
          Environment = "Development"
          Project     = local.project_name
          Service     = service_name
          Listener    = "HTTP_Fixed_Response"
        }
      },
      # Listener principal (HTTPS ou HTTP) com forward para o Target Group
      "main-app-forward" = { # Chave simplificada para este listener
        # Adicionar verificação para `alb_listener_port` e `alb_protocol`
        port              = lookup(service_attrs, "alb_listener_port", 443) # Usar lookup com default
        protocol          = upper(lookup(service_attrs, "alb_protocol", "HTTPS")) # Usar lookup com default
        certificate_arn   = lookup(service_attrs, "alb_protocol", "HTTPS") == "HTTPS" ? local.alb_certificate_arn : null
        ssl_policy        = lookup(service_attrs, "alb_protocol", "HTTPS") == "HTTPS" ? "ELBSecurityPolicy-TLS13-1-2-Res-2021-06" : null
        default_action_type = "forward"
        fixed_response = null
        redirect = null
        forward = {
          target_group_arn = aws_lb_target_group.this[service_name].arn
        }
        tags = {
          Environment = "Development"
          Project     = local.project_name
          Service     = service_name
          Listener    = "Main_App_Forward"
        }
      }
    }
  }

  flat_alb_listeners = merge([
    for service_name, listeners_map in local.alb_dynamic_listener_configs : {
      for listener_key, listener_config in listeners_map :
      "${service_name}:${listener_key}" => {
        load_balancer_arn = module.alb[service_name].arn
        listener_config   = listener_config
      }
    }
  ]...) # O '...' desempacota a lista de mapas em argumentos para 'merge'


  # Mapeamento para criar serviços ECS Fargate
  ecs_service_configs = { for service_name, service_attrs in local.ecs_services_input : service_name => {
    name = "${local.project_name}-${service_name}-ecs-service"
    desired_count = service_attrs.desired_count
    launch_type = "FARGATE"

    # Condicionar 'load_balancer_sg_id'
    load_balancer_sg_id = lookup(service_attrs, "create_alb", false) ? module.alb[service_name].security_group_id : null

    # Configurações do Fargate
    fargate_platform_version = "LATEST"
    cpu = service_attrs.cpu
    memory = service_attrs.memory

    # Mapeia as definições dos containers
    container_definitions = {
      for container_name, container_def in service_attrs.container_definitions : container_name => {
        name        = container_name
        image       = container_def.image
        essential   = lookup(container_def, "essential", true)
        cpu         = lookup(container_def, "cpu", null)
        memory      = lookup(container_def, "memory", null)
        environment = [for k, v in lookup(container_def, "environment", {}) : {
          name  = k
          value = v
        }]
        firelens_configuration = merge({}, lookup(container_def, "firelens_configuration", {}))
        log_configuration = lookup(container_def, "log_configuration", null)
        port_mappings = lookup(container_def, "container_port", null) != null ? [
          {
            containerPort = container_def.container_port
            protocol      = "tcp"
          }
        ] : []

        repository_credentials = try(
          {
            credentials_parameter = container_def.repository_credentials.credentials_parameter
          },
          {} 
        )

        # Removed 'service_connect_client_alias' from here, it's now part of service_connect_configuration.service.client_alias
      }
    }

    # Configuração do Load Balancer para o serviço ECS (condicional)
    load_balancer = lookup(service_attrs, "create_alb", false) ? {
      service = {
        # Agora referencia o Target Group que será criado manualmente
        target_group_arn = aws_lb_target_group.this[service_name].arn
        container_name   = keys(service_attrs.container_definitions)[0] # Pega o nome do primeiro container
        container_port   = service_attrs.container_definitions[keys(service_attrs.container_definitions)[0]].container_port
      }
    } : null

    # Subnets privadas para o serviço ECS
    subnet_ids = local.private_subnet_ids

    # Security Group para o serviço ECS (ajustar regra de ingresso para ser condicional)
    security_group_rules = merge(
      lookup(service_attrs, "create_alb", false) ? {
        ingress_from_alb = {
          type                     = "ingress"
          from_port                = service_attrs.container_definitions[keys(service_attrs.container_definitions)[0]].container_port
          to_port                  = service_attrs.container_definitions[keys(service_attrs.container_definitions)[0]].container_port
          protocol                 = "tcp"
          description              = "Allow traffic from ALB"
          source_security_group_id = module.alb[service_name].security_group_id # Referencia o SG do ALB
        }
      } : {},
      {
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    )

    # Configurações de deployment (agora dentro da definição de cada serviço)
    deployment_controller = {
      type = "ECS"
    }
    deployment_minimum_healthy_percent = service_attrs.min_healthy_percent
    deployment_maximum_percent = service_attrs.max_percent

    tags = {
      Environment = "Development"
      Project     = local.project_name
    }

    tasks_iam_role_policies = merge(
      {
        "logs_access" = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
      },
      { for i, arn in lookup(service_attrs, "additional_task_role_policy_arns", []) : "custom_policy_${i}" => arn }
    )

    tasks_iam_role_statements = [
      # Exemplo de statement inline, se necessário
      # {
      #   actions = ["s3:GetObject"]
      #   resources = ["arn:aws:s3:::my-bucket/*"]
      # }
    ]

    tasks_iam_role_name        = "${local.project_name}-${service_name}-task-role"
    tasks_iam_role_description = "IAM Task Role for ${local.project_name}-${service_name} ECS service"
    
    service_connect_configuration = service_attrs.enable_service_connect ? (
      {
        namespace = local.service_discovery_namespace_arn
        service   = {
          port_name      = tostring(values(service_attrs.container_definitions)[0].container_port)
          discovery_name = keys(service_attrs.container_definitions)[0]
          client_alias = {
            port     = values(service_attrs.container_definitions)[0].container_port
            dns_name = keys(service_attrs.container_definitions)[0]
          }
        }
      }
    ) : null  

  }}

  # Configuração do cluster ECS
  ecs_cluster_config = {
    cluster_name = local.ecs_cluster_name
    cluster_configuration = {
      execute_command_configuration = {
        logging = "OVERRIDE"
        log_configuration = {
          cloud_watch_log_group_name = local.ecs_log_group_name
        }
      }
    }
    fargate_capacity_providers = {
      FARGATE = {
        default_capacity_provider_strategy = {
          weight = 100
        }
      }
    }
    tags = {
      Environment = "Development"
      Project     = local.project_name
    }
  }
}