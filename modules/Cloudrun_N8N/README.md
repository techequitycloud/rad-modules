# Cloudrun N8N

## Overview

This module deploys n8n workflow automation on Google Cloud Run, providing a serverless, secure, and automated environment with PostgreSQL database for persistence.

## Duration

- Create: ~15 mins
- Destroy: ~10 mins

## Description

n8n is a powerful workflow automation tool that allows you to connect various apps and services to automate workflows. This module deploys n8n on Google Cloud Run with the following features:

- **Serverless Deployment**: Runs on Google Cloud Run for automatic scaling and cost optimization
- **PostgreSQL Database**: Uses Cloud SQL for PostgreSQL to persist workflows, credentials, and execution history
- **Secure by Default**: Credentials are encrypted using N8N_ENCRYPTION_KEY stored in Secret Manager
- **Multi-Environment Support**: Supports dev, QA, and production environments
- **Automated Backups**: Optional scheduled backups of the database
- **CI/CD Integration**: Optional GitHub integration for continuous deployment
- **Security Features**: Optional Cloud Armor integration for web application firewall

## Architecture

The module creates:

1. **Cloud Run Service**: Serverless container running n8n on port 5678
2. **Cloud SQL (PostgreSQL)**: Database for storing n8n data
3. **Secret Manager**: Secure storage for database password and encryption key
4. **Artifact Registry**: Container image repository
5. **Cloud Storage**: Backup storage (optional)
6. **VPC Network**: Private networking for database access
7. **IAM Roles**: Service accounts with least-privilege permissions

## Requirements

- n8n does **NOT** require NFS (file storage)
- n8n requires a PostgreSQL database for production use
- An encryption key is required for securing credentials (auto-generated if not provided)

## Environment Variables

The module configures the following n8n environment variables:

- `DB_TYPE`: Set to "postgresdb"
- `DB_POSTGRESDB_DATABASE`: Database name
- `DB_POSTGRESDB_USER`: Database user
- `DB_POSTGRESDB_PASSWORD`: Database password (from Secret Manager)
- `DB_POSTGRESDB_HOST`: Cloud SQL internal IP
- `DB_POSTGRESDB_PORT`: PostgreSQL port (5432)
- `N8N_ENCRYPTION_KEY`: Encryption key for credentials (from Secret Manager)
- `N8N_HOST`: Set to "0.0.0.0"
- `N8N_PORT`: Set to "5678"
- `N8N_PROTOCOL`: Set to "https"
- `WEBHOOK_URL`: Cloud Run service URL for webhooks

## Configuration Options

### Basic Settings

- `application_name`: Default is "n8n"
- `application_version`: n8n Docker image version (default: "latest")
- `n8n_encryption_key`: Custom encryption key (optional, auto-generated if not provided)

### Environment Selection

- `configure_development_environment`: Enable dev environment
- `configure_nonproduction_environment`: Enable QA environment
- `configure_production_environment`: Enable production environment

### Optional Features

- `configure_backups`: Enable scheduled database backups
- `configure_monitoring`: Enable uptime checks and monitoring
- `configure_application_security`: Enable Cloud Armor WAF
- `configure_continuous_integration`: Enable GitHub CI/CD
- `configure_continuous_deployment`: Enable Cloud Deploy pipeline

## Access

After deployment, access your n8n instance at:

- Dev: `https://appn8n[tenant_id][deployment_id]dev-[region]-[project_number].a.run.app/`
- QA: `https://appn8n[tenant_id][deployment_id]qa-[region]-[project_number].a.run.app/`
- Prod: `https://appn8n[tenant_id][deployment_id]prod-[region]-[project_number].a.run.app/`

## Security Notes

1. The n8n encryption key is critical - if lost, you cannot decrypt stored credentials
2. Database passwords are automatically generated and stored in Secret Manager
3. Cloud Run services are configured with IAM authentication by default
4. Consider enabling Cloud Armor for production deployments

## Comparison with Other Modules

Unlike Cloudrun_Moodle and Cloudrun_Odoo, this module:
- Does NOT require NFS storage
- Uses the official n8nio/n8n Docker image
- Requires an encryption key for credential security
- Uses port 5678 instead of 8080

Similar to Cloudrun_Cyclos, this module:
- Requires PostgreSQL database
- Does not need NFS storage
- Supports multi-environment deployments

## References

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Cloud Run Tutorial](https://codelabs.developers.google.com/n8n-cloud-run)
- [n8n Database Configuration](https://docs.n8n.io/hosting/configuration/environment-variables/database/)
- [n8n Deployment Guide](https://docs.n8n.io/hosting/installation/docker/)
