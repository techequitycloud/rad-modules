/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${var.cluster_name_prefix}-vpc"
  })
}

locals {
  public_subnets = {
    for i, az in var.subnet_availability_zones : az => {
      cidr = var.public_subnet_cidr_blocks[i]
      az   = az
    } if var.enable_public_subnets
  }
  private_subnets = {
    for i, az in var.subnet_availability_zones : az => {
      cidr = var.private_subnet_cidr_blocks[i]
      az   = az
    } if !var.enable_public_subnets
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name                                          = "${var.cluster_name_prefix}-subnet-public-${each.value.az}",
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false
  tags = merge(local.tags, {
    Name                                          = "${var.cluster_name_prefix}-subnet-private-${each.value.az}",
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })
}

resource "aws_internet_gateway" "this" {
  count = var.enable_public_subnets ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, {
    Name = "${var.cluster_name_prefix}-vpc"
  })
}

resource "aws_route_table" "public" {
  count = var.enable_public_subnets ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, {
    Name = "${var.cluster_name_prefix}-vpc-public"
  })
}

resource "aws_route" "public_internet_gateway" {
  count = var.enable_public_subnets ? 1 : 0

  route_table_id = aws_route_table.public[0].id
  gateway_id     = aws_internet_gateway.this[0].id

  destination_cidr_block = "0.0.0.0/0"

  timeouts {
    create = "5m"
  }
}

resource "aws_route_table_association" "public" {
  for_each = var.enable_public_subnets ? aws_subnet.public : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  count = !var.enable_public_subnets ? 1 : 0

  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count = !var.enable_public_subnets ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = one(values(aws_subnet.public)).id

  tags = merge(local.tags, {
    Name = "${var.cluster_name_prefix}-nat-gateway"
  })
}

resource "aws_route_table" "private" {
  count = !var.enable_public_subnets ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, {
    Name = "${var.cluster_name_prefix}-vpc-private"
  })
}

resource "aws_route" "private_nat_gateway" {
  count = !var.enable_public_subnets ? 1 : 0

  route_table_id = aws_route_table.private[0].id
  gateway_id     = aws_nat_gateway.nat[0].id

  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private" {
  for_each = !var.enable_public_subnets ? aws_subnet.private : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[0].id
}
