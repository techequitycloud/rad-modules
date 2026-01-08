# GCP Services Module Guide

## Overview
The **GCP Services** module acts as the foundation builder for your applications. Once your project is created, this module lays down the necessary infrastructure "plumbing"—networks, databases, and shared storage—that your applications need to run. It ensures that all services are connected securely and efficiently.

## Key Benefits
- **Plug-and-Play Infrastructure**: Deploys a production-ready network and database layer that other application modules can simply "plug into."
- **Hybrid Storage Options**: Provides both structured data storage (Databases) and file storage (NFS) to support a wide range of legacy and modern applications.
- **Flexible Database Choices**: Choose between PostgreSQL or MySQL based on your application's requirements.
- **Advanced Compute Options**: Optionally enables Google Kubernetes Engine (GKE) for complex, container-orchestrated workloads.

## Functionality
- Provisions a Virtual Private Cloud (VPC) network.
- Deploys managed Cloud SQL instances (Postgres or MySQL).
- Sets up a Network File System (NFS) server for shared file access across applications.
- Optionally creates a GKE cluster with enterprise features like Policy Controller and Service Mesh.

---
