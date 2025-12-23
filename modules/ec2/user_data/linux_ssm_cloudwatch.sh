# #!/bin/bash
# set -ex

# # Enable and start SSM Agent (Amazon Linux typically has it by default)
# systemctl enable amazon-ssm-agent || true
# systemctl start amazon-ssm-agent || true

# # Install/Start CloudWatch Agent
# yum install -y amazon-cloudwatch-agent || true
# systemctl enable amazon-cloudwatch-agent || true
# systemctl start amazon-cloudwatch-agent || true

# # Basic updates and timezone
# yum update -y || true
# # Asia/Kolkata aligns with India Standard Time
# if command -v timedatectl >/dev/null 2>&1; then
#   timedatectl set-timezone Asia/Kolkata || true
