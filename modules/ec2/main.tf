locals {
  instances_by_name = { for i in var.instances : i.name => i }
}

data "aws_ssm_parameter" "net_profile" {
  name = "/provisioning/${var.region}/${var.environment}/${var.network_profile_name}"
}

locals {
  # Safely trim any whitespace/newlines from SSM value
  net_profile_str = trimspace(data.aws_ssm_parameter.net_profile.value)

  # Parse JSON
  net_raw = jsondecode(local.net_profile_str)

  # Normalize + safe defaults
  net = {
    vpc_id               = try(local.net_raw.vpc_id, null)
    subnet_ids           = try(local.net_raw.subnet_ids, [])
    security_group_ids   = try(local.net_raw.security_group_ids, [])
    key_name             = try(local.net_raw.key_name, null)
    iam_instance_profile = try(local.net_raw.iam_instance_profile, null)
    ami_ssm_param        = try(local.net_raw.ami_ssm_param, null)
    size_to_type = try(local.net_raw.size_to_type, {
      small       = "t3.small"
      large       = "t3.large"
      extra_large = "t3.xlarge"
    })
    ebs_kms_key_id = try(local.net_raw.ebs_kms_key_id, null) # <-- important for SCP
  }
}


# AMI resolution (instance -> SSM param -> profile)
data "aws_ssm_parameter" "ami_profile" {
  for_each = {
    for n, i in local.instances_by_name : n => i
    if try(i.amiid, null) == null && try(i.amissmparam, null) == null
  }
  name = local.net.ami_ssm_param
}

data "aws_ssm_parameter" "ami_by_instance" {
  for_each = {
    for n, i in local.instances_by_name : n => i
    if try(i.amissmparam, null) != null
  }
  name = each.value.amissmparam
}

locals {
  effective_ami = {
    for n, i in local.instances_by_name : n => (
      try(i.amiid, null) != null
      ? i.amiid
      : (
        try(i.amissmparam, null) != null
        ? data.aws_ssm_parameter.ami_by_instance[n].value
        : data.aws_ssm_parameter.ami_profile[n].value
      )
    )
  }

  size_map = local.net.size_to_type

  instance_type = {
    for n, i in local.instances_by_name : n => (
      try(i.instancetype, null) != null
      ? i.instancetype
      : lookup(local.size_map, lower(try(i.size, "large")), "t3.large")
    )
  }

  # Safe fallbacks: only use profile if present
  resolved_subnet_id = {
    for n, i in local.instances_by_name : n =>
    (try(i.subnetid, null) != null ? i.subnetid : (length(local.net.subnet_ids) > 0 ? local.net.subnet_ids[0] : null))
  }

  resolved_security_group_ids = {
    for n, i in local.instances_by_name : n =>
    (try(i.securitygroupids, null) != null && length(i.securitygroupids) > 0
      ? i.securitygroupids
    : local.net.security_group_ids)
  }

  resolved_key_name = {
    for n, i in local.instances_by_name : n =>
    (try(i.keyname, null) != null ? i.keyname : local.net.key_name)
  }

  resolved_instance_profile = {
    for n, i in local.instances_by_name : n =>
    (try(i.iaminstanceprofile, null) != null ? i.iaminstanceprofile : local.net.iam_instance_profile)
  }
}


resource "aws_instance" "this" {
  for_each = local.instances_by_name

  ami                         = local.effective_ami[each.key]
  instance_type               = local.instance_type[each.key]
  subnet_id                   = local.resolved_subnet_id[each.key]
  vpc_security_group_ids      = local.resolved_security_group_ids[each.key]
  key_name                    = local.resolved_key_name[each.key]
  iam_instance_profile        = local.resolved_instance_profile[each.key]
  associate_public_ip_address = try(each.value.enablepublicip, false)


  lifecycle {
    # You already ignore subnet_id to prevent accidental moves
    ignore_changes = [
      subnet_id,

      # Add these lines to avoid recreating existing instances
      root_block_device[0].kms_key_id,
      root_block_device[0].encrypted,
    ]
  }


  # Instance tags (applied to resourceType = "instance")
  tags = merge(
    {
      "Name"            = each.value.name,
      "ManagedBy"       = "Terraform",
      "ProvisionSource" = "SSMProfile"
    },
    each.value.tags
  )

  # Volume tags (applied to resourceType = "volume" during RunInstances)
  # This is required to satisfy SCPs that enforce tag-on-create on EBS volumes.
  volume_tags = merge(
    {
      "Name"            = "${each.value.name}-root", # optional naming convention
      "ManagedBy"       = "Terraform",
      "ProvisionSource" = "SSMProfile"
    },
    each.value.tags
  )

  # User data: prefer plain user_data if given; else decode userdata_base64
  user_data = (
    try(each.value.user_data, null) != null
    ? each.value.user_data
    : (
      try(each.value.userdata_base64, null) != null
      ? base64decode(each.value.userdata_base64)
      : null
    )
  )

  # Root EBS volume

  root_block_device {
    volume_size           = each.value.ebsrootsizegb
    volume_type           = each.value.ebsroottype
    iops                  = try(each.value.ebsrootiops, 0) > 0 ? each.value.ebsrootiops : null
    encrypted             = true
    # kms_key_id            = local.net.ebs_kms_key_id # keep if SCP requires CMK usage
    delete_on_termination = true
  }


  # Additional EBS volumes (optional)
  dynamic "ebs_block_device" {
    for_each = try(each.value.additionalvolumes, [])
    content {
      device_name           = ebs_block_device.value.devicename
      volume_size           = ebs_block_device.value.sizegb
      volume_type           = ebs_block_device.value.type
      iops                  = try(ebs_block_device.value.iops, 0) > 0 ? ebs_block_device.value.iops : null
      encrypted             = ebs_block_device.value.encrypted
      # kms_key_id            = local.net.ebs_kms_key_id # keep if SCP requires CMK usage
      delete_on_termination = true
    }
  }
}