# GCP Services Module Technical Features

## Architecture
This module operates as the infrastructure layer. It outputs critical resource IDs (Network ID, Database Instance Connection Names, NFS IP) which are consumed by application modules (like Moodle, Odoo, etc.) via `terraform_remote_state` or direct variable passing in a pipeline.

## Cloud Capabilities

### Networking
- **Resource**: `google_compute_network`, `google_compute_subnetwork`
- **Capabilities**: Creates a custom VPC with distinct subnets for Compute Engine and GKE. Configures firewall rules for internal traffic and specific external access.

### Cloud SQL (Managed Database)
- **Resource**: `google_sql_database_instance`
- **Capabilities**:
  - Configurable for **PostgreSQL 16** or **MySQL 8.0**.
  - Supports **Zonal** (Dev) or **Regional** (HA/Prod) availability types.
  - Custom machine types (e.g., `db-custom-1-3840`) allow right-sizing resources.

### Network File System (NFS)
- **Resource**: `google_compute_instance`
- **Capabilities**: Deploys a GCE VM configured as an NFS kernel server. This provides a `ReadWriteMany` storage backend compatible with Cloud Run and GKE, essential for legacy apps requiring shared file systems (e.g., Moodle `moodledata`).

### Google Kubernetes Engine (GKE) [Optional]
- **Resource**: `google_container_cluster`
- **Capabilities**:
  - VPC-native cluster (Alias IPs).
  - Integrates with **Anthos** features: Config Management, Policy Controller, and Cloud Service Mesh.
  - Configurable CIDR ranges for Pods and Services.

## Configuration & Enhancement
- **Database Tuning**: Technical users can adjust `postgres_tier` or `mysql_tier` variables to scale database performance vertically.
- **Network Segmentation**: Subnet CIDR ranges (`gce_subnet_cidr_range`, `gke_subnet_cidr_range`) are fully parameterized, allowing integration into existing corporate IP schemas.
- **Feature Flags**: The module uses boolean flags (e.g., `create_google_kubernetes_engine`, `create_postgres`) to toggle major components, making it adaptable for lightweight (Cloud Run only) or heavy (GKE) environments.
