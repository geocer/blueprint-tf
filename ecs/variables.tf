variable "ecs_cluster_name" {
  description = "Nome do cluster ECS."
  type        = string
}

variable "ecs_log_group_name" {
  description = "Nome do grupo de logs do CloudWatch para o ECS."
  type        = string
}

variable "fargate_capacity_providers_input" {
  description = "Configuração dos provedores de capacidade Fargate."
  type = map(object({
    default_capacity_provider_strategy = object({
      weight = number
    })
  }))
}

variable "ecs_services_input" {
  description = "Definição dos serviços ECS."
  type = map(object({
    cpu    = number
    memory = number
    container_definitions = map(object({
      cpu                      = number
      memory                   = number
      essential                = bool
      image                    = string
      firelens_configuration   = optional(map(string))
      memory_reservation       = optional(number)
      port_mappings            = optional(list(object({
        name          = string
        containerPort = number
        protocol      = string
      })))
      readonly_root_filesystem = optional(bool)
      dependencies             = optional(list(object({
        containerName = string
        condition     = string
      })))
      enable_cloudwatch_logging = optional(bool)
      log_configuration = optional(object({
        logDriver = string
        options   = map(string)
      }))
    }))
    service_connect_configuration = optional(object({
      namespace = string
      service = object({
        client_alias = object({
          port     = number
          dns_name = string
        })
        port_name      = string
        discovery_name = string
      })
    }))
    load_balancer = optional(object({
      service = object({
        target_group_arn = string
        container_name   = string
        container_port   = number
      })
    }))
    subnet_ids = list(string)
    security_group_rules = map(object({
      type                     = string
      from_port                = number
      to_port                  = number
      protocol                 = string
      description              = string
      source_security_group_id = optional(string)
      cidr_blocks              = optional(list(string))
    }))
  }))
}

variable "common_tags" {
  description = "Tags comuns para todos os recursos."
  type        = map(string)
}

variable "resource_name" {
  description = "O nome do recurso. Deve terminar com um sufixo fixo (ex: '-prod' para produção)."
  type        = string

  validation {
    # Define o padrão que o nome do recurso deve seguir.
    # Exemplo: O nome deve terminar com '-prod'.
    condition     = can(regex(".*-prod$", var.resource_name))
    error_message = "O nome do recurso deve terminar com '-prod' (ex: 'my-app-prod')."
  }
}

# Exemplo de uso da variável em um local para demonstrar a validação
locals {
  # Este local apenas ilustra que a variável validada seria usada.
  # Em um cenário real, 'var.resource_name' seria usado no bloco de recurso.
  final_resource_name = var.resource_name
}

