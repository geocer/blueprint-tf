module "ec2_instances" {
  source = "terraform-aws-modules/ec2-instance/aws"
  for_each = local.ec2_instances_to_create

  name = each.value.name

  subnet_id = each.value.subnet_id
  
  vpc_security_group_ids = each.value.security_group_ids

  create_iam_instance_profile = each.value.create_iam_instance_profile
  iam_role_description        = each.value.iam_role_description
  iam_role_policies           = each.value.iam_role_policies

  ami = each.value.ami 
  instance_type = each.value.instance_type

  tags = merge(local.common_tags, each.value.tags)
}
