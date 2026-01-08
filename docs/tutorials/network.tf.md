# Tutorial: Network (network.tf)

## Overview
The `network.tf` file usually handles the discovery of the **VPC Network** and **Subnets** created by the foundational modules. It rarely creates new networks (unless it's the `GCP_Services` module itself).

## Standard Pattern
It uses `data` sources to look up network details needed for VPC Access configurations.

## Implementation Example

```hcl
data "google_compute_network" "vpc_network" {
  name    = var.network_name
  project = local.project.project_id
}

data "google_compute_subnetwork" "subnet" {
  name    = "gce-vpc-subnet-${local.region}"
  region  = local.region
  project = local.project.project_id
}
```

## Best Practices & Recommendations

### 1. Don't Hardcode Subnets
**Recommendation**: Use variables or logical naming conventions to find subnets.
**Why**: Subnet names might change or differ per region.

### 2. Serverless VPC Access
**Recommendation**: If using the legacy connector (not Gen2 Direct Egress), `network.tf` is where you would define the `google_vpc_access_connector`. However, modern modules should prefer Direct VPC Egress defined in `service.tf`.
