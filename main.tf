module "ec2" {
  source               = "./modules/ec2"
  region               = var.region
  environment          = var.environment
  network_profile_name = var.network_profile_name
  instances            = var.instances
}