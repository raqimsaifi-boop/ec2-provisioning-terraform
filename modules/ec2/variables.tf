
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "environment" {
  description = "Environment (Production, Dev, Test, UAT, Staging, Training)"
  type        = string
}

variable "region" {
  description = "AWS region (e.g., ap-south-1)"
  type        = string
}

variable "network_profile_name" {
  description = "SSM profile name (usually 'ec2')"
  type        = string
  default     = "ec2"
}

variable "instances" {
  description = "List of EC2 instances to create with specific configs and mandatory tags"
  type = list(object({
    name        = string
    amiid       = optional(string)
    amissmparam = optional(string)

    instancetype = optional(string)
    size         = optional(string) # small | large | extra_large

    subnetid           = optional(string)
    securitygroupids   = optional(list(string))
    keyname            = optional(string)
    iaminstanceprofile = optional(string)
    enablepublicip     = optional(bool, false)

    ebsrootsizegb = number
    ebsroottype   = string
    ebsrootiops   = number

    additionalvolumes = optional(list(object({
      devicename = string
      sizegb     = number
      type       = string
      iops       = optional(number)
      encrypted  = bool
    })), [])

    userdata_base64 = optional(string)
    tags            = map(string)
  }))

  # ✅ Mandatory tag keys and allowed values
  validation {
    condition = alltrue([
      for i in var.instances : (
        # Required tag keys present
        alltrue([
          for k in [
            "Application", "Technical Owner", "Business Owner",
            "Environment", "Criticality", "Data Sensitivity",
            "DeleteOn", "Schedule", "CreationDate"
          ] : can(i.tags[k])
        ])
        &&
        # Allowed values
        contains(["Training", "Production", "Dev", "Test", "UAT", "Staging"], i.tags["Environment"])
        &&
        contains(["Critical", "Major", "Moderate", "Minor"], i.tags["Criticality"])
        &&
        contains(["High", "Medium", "Low"], i.tags["Data Sensitivity"])
        &&
        # Date format YYYY-MM-DD
        length(regexall("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", i.tags["DeleteOn"])) > 0
        &&
        length(regexall("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", i.tags["CreationDate"])) > 0
      )
    ])
    error_message = "Mandatory tags missing/invalid. Dates must be YYYY-MM-DD; Environment must be one of [Training, Production, Dev, Test, UAT, Staging]."
  }
}
# ✅ AMI resolution: instance can omit both; we will use SSM profile fallback
#   validation {
#     condition     = true
#     error_message = "AMI will be resolved by amiid, amissmparam, or profile.ami_ssm_param."
#   }
# }