
output "instances" {
  value = {
    for k, v in aws_instance.this :
    k => {
      id         = v.id
      private_ip = v.private_ip
      public_ip  = v.public_ip
      az         = v.availability_zone
      state      = v.instance_state
      tags       = v.tags
    }
  }
}

output "resolved_network_profile" {
  value = local.net
}