terraform {
  backend "s3" {
    bucket               = "tek-bv-terraform-state"
    region               = "ap-south-1"
    key                  = "ec2-provisioning/default/terraform.tfstate"  # default now lives under prefix
    workspace_key_prefix = "ec2-provisioning"
    encrypt              = true
    use_lockfile         = true  # native S3 locking (Terraform 1.10+)
  }
}
