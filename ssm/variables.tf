variable "parameters" {
  description = "A map of SSM parameters to create."
  type = map(object({
    name            = optional(string)
    value           = optional(string)
    values          = optional(list(string))
    type            = optional(string)
    secure_type     = optional(bool)
    description     = optional(string)
    tier            = optional(string)
    key_id          = optional(string)
    allowed_pattern = optional(string)
    data_type       = optional(string)
  }))
  default = {}
}