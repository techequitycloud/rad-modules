# N8N AI Starter Kit Module

Deploys n8n workflow automation with AI components: **Qdrant** (vector database) and **Ollama** (local LLM inference).

## Architecture
- **Base Image**: Custom build from `n8nio/n8n` with additional dependencies.
- **Database**: PostgreSQL (Cloud SQL).
- **AI Services**: Qdrant and Ollama deployed as separate Cloud Run services with internal-only ingress.

## Key Features
- **Workflow Automation**: Full n8n platform for building AI-powered workflows.
- **Qdrant Vector Database**: Deployed as an internal Cloud Run service for vector similarity search and RAG pipelines.
- **Ollama LLM**: Deployed as an internal Cloud Run service for local LLM inference (default model: `llama3.2`).
- **Persistence**: Workflow data persisted to Cloud SQL; vector and model data persisted via GCS FUSE.
- **Configurable**: AI components can be individually enabled/disabled via `enable_ai_components`, `enable_qdrant`, and `enable_ollama` variables.

## AI-Specific Variables
| Variable | Default | Description |
|---|---|---|
| `enable_ai_components` | `true` | Master toggle for all AI services |
| `enable_qdrant` | `true` | Enable Qdrant vector database |
| `qdrant_version` | `latest` | Qdrant Docker image tag |
| `enable_ollama` | `true` | Enable Ollama LLM service |
| `ollama_version` | `latest` | Ollama Docker image tag |
| `ollama_model` | `llama3.2` | Default Ollama model |

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "N8N_AI" {
  source = "./modules/N8N_AI"

  # ... configuration variables
  enable_ai_components = true
  enable_qdrant        = true
  enable_ollama        = true
  ollama_model         = "llama3.2"
}
```
