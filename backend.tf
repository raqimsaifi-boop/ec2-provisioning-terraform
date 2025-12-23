terraform {
  backend "s3" {
    bucket               = "tek-bv-terraform-state"
    region               = "ap-south-1"
    dynamodb_table       = "terraform-locks"
    encrypt              = true
    workspace_key_prefix = "ec2-provisioning"
  }
}
