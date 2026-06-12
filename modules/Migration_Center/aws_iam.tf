#*
# * Copyright 2024 Google LLC
# *
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *      http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
#

# ─── AWS IAM: Scoped EC2 discovery user ──────────────────────────────────────
# When AWS credentials are supplied the module automatically provisions a
# dedicated IAM user with the minimum permissions required for EC2 discovery
# (DescribeInstances, DescribeInstanceTypes, DescribeVolumes).  The generated
# access key is fed directly into the mc_aws_import provisioner so that the
# bootstrap credentials are never used for EC2 queries.  All resources are
# removed on terraform destroy.

locals {
  aws_iam_user_name   = "mc-ec2-discovery-${local.random_id}"
  aws_iam_policy_name = "MCDiscoveryEC2ReadOnly-${local.random_id}"
}

resource "aws_iam_policy" "mc_discovery" {
  count = var.aws_access_key_id != "" ? 1 : 0

  name        = local.aws_iam_policy_name
  description = "Minimum EC2 read permissions for Migration Center discovery"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MCDiscoveryEC2Read"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeVolumes",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user" "mc_discovery" {
  count = var.aws_access_key_id != "" ? 1 : 0
  name  = local.aws_iam_user_name

  tags = {
    Purpose      = "Migration Center EC2 discovery"
    ManagedBy    = "Terraform"
    DeploymentId = local.random_id
  }
}

resource "aws_iam_user_policy_attachment" "mc_discovery" {
  count      = var.aws_access_key_id != "" ? 1 : 0
  user       = aws_iam_user.mc_discovery[0].name
  policy_arn = aws_iam_policy.mc_discovery[0].arn
}

resource "aws_iam_access_key" "mc_discovery_key" {
  count = var.aws_access_key_id != "" ? 1 : 0
  user  = aws_iam_user.mc_discovery[0].name

  depends_on = [aws_iam_user_policy_attachment.mc_discovery]
}
