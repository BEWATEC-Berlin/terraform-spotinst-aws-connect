provider "spotinst" {
    token = var.spotinst_token
}

# Create AWS account on Spot
resource "spotinst_account_aws" "spot_acct" {
    name=var.name
}

data "http" "externalid" {
  url = "https://api.spotinst.io/setup/credentials/aws/externalId?accountId=${spotinst_account_aws.spot_acct.id}"
  method = "POST"
  request_headers = {
    Content-Type = "application/json"
    Authorization = "Bearer ${var.spotinst_token}"
  }
  
}
resource "terraform_data" "externalid" {
  input = local.externalids[0]
  lifecycle {
    ignore_changes = [ input ]
  }
}

locals {
    user_data = jsondecode(data.http.externalid.response_body)
    externalids = [for item in local.user_data.response.items : item.externalId]
}

# Create AWS Role for Spot
resource "aws_iam_role" "spot"{
    name = var.role_name == null ? "SpotRole-${spotinst_account_aws.spot_acct.id}-${random_id.random_string.hex}" : var.role_name
    provisioner "local-exec" {
        # Without this set-cloud-credentials fails
        command = "sleep 10"
    }
    assume_role_policy = <<-EOT
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::922761411349:root"
                },
                "Action": "sts:AssumeRole",
                "Condition": {
                    "StringEquals": {
                    "sts:ExternalId": "${local.externalids[0]}"
                    }
                }
                }
            ]
        }
    EOT
    tags = var.tags
    lifecycle {
        ignore_changes = [tags]
    }
}

# Create IAM Policy
resource "aws_iam_policy" "spot" {
    name        = var.policy_name == null ? "Spot-Policy-${spotinst_account_aws.spot_acct.id}-${random_id.random_string.hex}" : var.policy_name
    path        = "/"
    description = "Spot by NetApp IAM policy to manage resources"
    policy      = var.policy_file == null ? templatefile("${path.module}/spot_policy.json", {}) : var.policy_file
    tags        = var.tags
    lifecycle {
        ignore_changes = [tags]
    }
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "spot" {
    role       = aws_iam_role.spot.name
    policy_arn = aws_iam_policy.spot.arn
}

resource "time_sleep" "wait_05_seconds" {
    depends_on = [aws_iam_role_policy_attachment.spot]
    create_duration = "5s"
}

# Link the Role ARN to the Spot Account
resource "spotinst_credentials_aws" "credential" {
  depends_on = [aws_iam_role_policy_attachment.spot, time_sleep.wait_05_seconds]
  iamrole = aws_iam_role.spot.arn
  account_id = spotinst_account_aws.spot_acct.id
}