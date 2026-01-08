# N8N AI Module Technical Features

## Architecture
This module extends the standard N8N architecture by adding two additional services: **Qdrant** and **Ollama**. These can be deployed as separate Cloud Run services or sidecars, depending on the specific implementation version, but typically they are distinct services communicating over the private VPC network.

## Cloud Capabilities

### Vector Database (Qdrant)
- **Service**: Deploys the Qdrant container.
- **Storage**: Uses persistence (volume or database backend) to store high-dimensional vectors.
- **Integration**: Automatically configured as a credential/node in n8n.

### LLM Serving (Ollama)
- **Service**: Deploys Ollama on Cloud Run (often with GPU acceleration if configured/available, or CPU for smaller models).
- **Model Management**: The `ollama_model` variable allows you to specify which model (e.g., `llama3.2`) should be pulled and loaded upon startup.
- **Hardware**: Technical users should pay attention to resource limits (`memory`, `cpu`) as LLMs are resource-intensive.

### Orchestration
- **Networking**: Uses internal VPC DNS or Service Connect to allow n8n to talk to Qdrant and Ollama with low latency and without public internet exposure.

## Configuration & Enhancement
- **Model Swapping**: Change the `ollama_model` variable to switch between different open-source models (e.g., Mistral, Gemma) without redeploying infrastructure.
- **Feature Toggles**: Variables like `enable_qdrant` and `enable_ollama` allow you to turn off specific AI components if you only need a partial stack (e.g., using OpenAI API instead of local Ollama).
