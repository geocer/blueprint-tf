variable "ec2_instances_input" {
  description = "Mapa de definições para múltiplas instâncias EC2."
  type = map(object({
    name                        = string
    ami                         = string # Adicionando AMI
    instance_type               = string # Adicionando tipo de instância
    subnet_id                   = string # Cada instância pode ter sua subnet
    security_group_ids          = list(string)
    create_iam_instance_profile = bool
    iam_role_description        = string
    iam_role_policies           = map(string)
    tags                        = map(string)
  }))
}

variable "common_tags" {
  description = "Tags comuns para todos os recursos."
  type        = map(string)
}

variable "vpc_intra_subnets" {
  description = "IDs das subnets intra VPC."
  type        = list(string)
}

variable "security_group_instance_id" {
  description = "ID do security group da instância."
  type        = string
}
*/
