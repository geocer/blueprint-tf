module "multiple_ssm_parameters" {
  source  = "terraform-aws-modules/ssm-parameter/aws"
  version = "3.2.0" 

  for_each = local.parameters

  name            = try(each.value.name, each.key)
  value           = try(each.value.value, null)
  values          = try(each.value.values, [])
  type            = try(each.value.type, null)
  secure_type     = try(each.value.secure_type, null)
  description     = try(each.value.description, null)
  tier            = try(each.value.tier, null)
  key_id          = try(each.value.key_id, null)
  allowed_pattern = try(each.value.allowed_pattern, null)
  data_type       = try(each.value.data_type, null)
}