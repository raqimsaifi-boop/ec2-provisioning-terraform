# terraform {
#   backend "s3" {
#     bucket         = "tek-bv-terraform-state"
#     key            = "ec2/${var.instance_name}.tfstate"
#     region         = "ap-south-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }