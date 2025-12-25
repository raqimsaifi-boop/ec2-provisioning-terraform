terraform {
  backend "s3" {
    bucket               = "tek-bv-terraform-state"
    region               = "ap-south-1"
    key                  = "terraform.tfstate"        # REQUIRED: path in the bucket
    encrypt              = true
    workspace_key_prefix = "ec2-provisioning"         # optional, used with workspaces
    use_lockfile         = true                       # S3-native locking (recommended)
  }
}
