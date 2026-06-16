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

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks" {
  name               = "${var.cluster_name_prefix}-eks-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy" "amazon_eks_cluster_policy" {
  arn = "arn:aws:iam::aws:policy/amazon_eks_cluster_policy"
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_policy" {
  policy_arn = data.aws_iam_policy.amazon_eks_cluster_policy.arn
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role" "node" {
  name = "${var.cluster_name_prefix}-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

data "aws_iam_policy" "amazon_eks_worker_node_policy" {
  arn = "arn:aws:iam::aws:policy/amazon_eks_worker_node_policy"
}

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = data.aws_iam_policy.amazon_eks_worker_node_policy.arn
  role       = aws_iam_role.node.name
}

data "aws_iam_policy" "amazon_eks_cni_policy" {
  arn = "arn:aws:iam::aws:policy/amazon_eks_cni_policy"
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = data.aws_iam_policy.amazon_eks_cni_policy.arn
  role       = aws_iam_role.node.name
}

data "aws_iam_policy" "amazon_ec2_container_registry_read_only" {
  arn = "arn:aws:iam::aws:policy/amazon_ec2_container_registry_read_only"
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = data.aws_iam_policy.amazon_ec2_container_registry_read_only.arn
  role       = aws_iam_role.node.name
}
