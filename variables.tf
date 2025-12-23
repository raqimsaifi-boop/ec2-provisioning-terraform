
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Workload environment (Production, Dev, Test, UAT, Staging, Training)"
  type        = string
  default     = "Production"
}

variable "network_profile_name" {
  description = "SSM profile name to read (usually 'ec2')"
  type        = string
  default     = "ec2"
}

variable "instances" {
  description = "List of instance definitions"
  type        = list(any)
}