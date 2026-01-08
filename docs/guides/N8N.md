# N8N Module Guide

## Overview
The **N8N** module deploys n8n, a fair-code workflow automation tool, onto Google Cloud. This tool allows your business to connect disparate apps, APIs, and data sources to automate processes without writing complex code.

## Key Benefits
- **Own Your Automation**: Unlike SaaS automation tools, you host this yourself, giving you full control over your data and no per-execution fees.
- **Enterprise Grade**: Runs on Google Cloud's secure infrastructure with a dedicated database, making it suitable for mission-critical workflows.
- **Cost Efficient**: Serverless deployment means you pay for the compute only when your workflows are actually running (or keep it minimum for listeners).
- **Secure Connectivity**: Deploy within your private VPC to securely connect to internal databases and services that aren't exposed to the public internet.

## Functionality
- Deploys the n8n editor and execution engine on Cloud Run.
- Provisions a dedicated PostgreSQL database for storing workflow definitions and execution history.
- Configures webhook endpoints to trigger automations from external events.

---
