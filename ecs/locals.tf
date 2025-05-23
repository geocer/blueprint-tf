locals {
  # Transforma a entrada de fargate_capacity_providers para o formato esperado pelo módulo ECS
  fargate_capacity_providers = { for k, v in var.fargate_capacity_providers_input : k => v }

  # Transforma a entrada de ecs_services para o formato esperado pelo módulo ECS
  # e permite flexibilidade na definição de múltiplos serviços
  ecs_services = { for k, v in var.ecs_services_input : k => {
    cpu                         = v.cpu
    memory                      = v.memory
    container_definitions       = v.container_definitions
    service_connect_configuration = v.service_connect_configuration
    load_balancer               = v.load_balancer
    subnet_ids                  = v.subnet_ids
    security_group_rules        = v.security_group_rules
  } }
}
