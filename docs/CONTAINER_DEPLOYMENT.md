# Container Deployment Guide

## Overview

This document describes the container deployment setup for Ollama on HPCC GPU clusters using Podman.

## Base Image

```
docker.io/autosubmit/slurm-openssh-container:latest
```

## Prerequisites

- Podman installed on the system
- Access to HPCC GPU nodes
- SSH key configured for authentication

## Port Configuration

| Model | Port |
|-------|------|
| granite | 55077 |
| deepseek | 55088 |
| qwen-coder | 66044 |
| codellama | 66033 |

Full mapping (all environments): **docs/AGENTS.md**.

## Container Setup

### Pull Base Image

```bash
podman pull docker.io/autosubmit/slurm-openssh-container:latest
```

### Run Ollama Container

```bash
podman run -d \
  --name ollama-granite4 \
  -p 55077:11434 \
  --gpus all \
  ollama serve
```

```bash
podman run -d \
  --name ollama-qwen-coder \
  -p 66044:11434 \
  --gpus all \
  ollama serve
```

## Network Configuration

The containers expose Ollama on the following ports:
- **55077**: granite4 model
- **66044**: qwen-coder model

Ensure firewall rules allow traffic on these ports.

## Volume Mounts

Mount local directories for model storage:

```bash
podman run -d \
  --name ollama-granite4 \
  -p 55077:11434 \
  -v /path/to/models:/root/.ollama \
  --gpus all \
  ollama serve
```

## GPU Configuration

Use `--gpus all` to allocate all available GPUs, or specify specific GPUs:

```bash
--gpus '"device=0,1"'
```

## Testing

Verify the container is running:

```bash
podman ps
```

Test Ollama API:

```bash
curl http://localhost:55077/api/tags
curl http://localhost:66044/api/tags
```

## Troubleshooting

### GPU Not Available

Check NVIDIA device plugin:
```bash
podman exec -it ollama-granite4 nvidia-smi
```

### Port Binding Issues

Check if ports are already in use:
```bash
netstat -tuln | grep -E '55077|66044'
```
