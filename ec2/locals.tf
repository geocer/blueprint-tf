locals {
  # Transforma o mapa de entrada de instâncias EC2 diretamente para uso com for_each
  ec2_instances_to_create = { for k, v in var.ec2_instances_input : k => v }

  # Tags comuns, movidas para locals para consistência
  common_tags = var.common_tags
}
