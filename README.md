# ollama-hpcc

Ollama LLM server and client for HPCC RedRaider GPU clusters.

## Description

This project provides a complete solution for running Ollama LLM servers on HPCC (High Performance Computing Center) RedRaider GPU clusters. It includes container deployment, Slurm job integration, and Python client libraries.

## Features

- **GPU inference on HPCC**: Deploy Ollama models on NVIDIA GPU nodes
- **Slurm job integration**: Submit and manage Ollama servers as Slurm jobs
- **Podman containers**: Run Ollama in isolated containers using Podman
- **Python client**: Easy Python API for interacting with Ollama servers


## Related Projects

- [toolchain-module](https://github.com/sdw3098/toolchain-module)
- [module-toolchains](https://github.com/sdw3098/module-toolchains)
- [ollama-rocky](https://github.com/sdw3098/ollama-rocky)
- [ollama-mac](https://github.com/sdw3098/ollama-mac)
- [ollama-podman](https://github.com/sdw3098/ollama-podman)

## Installation

```bash
pip install -e src/python/
```

## Shell Aliases (macOS / zsh)

Source the aliases script in your `~/.zshrc`:

```bash
source /Users/owner/projects/ollama-hpcc/scripts/hpcc-aliases.zsh
```

### SSH & Connection
| Alias | Description |
|-------|-------------|
| `hpcc-login` | SSH into HPCC login node |
| `hpcc "cmd"` | Run any command remotely |

### Submit Batch Jobs
| Alias | Description |
|-------|-------------|
| `granite` | Submit granite batch job |
| `deepseek` | Submit deepseek batch job |
| `codellama` | Submit codellama batch job |
| `qwen` | Submit qwen batch job |

### Interactive Sessions
| Alias | Description |
|-------|-------------|
| `granite-interactive` | Start interactive GPU session with granite |
| `deepseek-interactive` | Start interactive GPU session with deepseek |
| `codellama-interactive` | Start interactive GPU session with codellama |
| `qwen-interactive` | Start interactive GPU session with qwen |

Interactive sessions:
- Request a GPU node via SLURM
- Start Ollama server on a dynamic port
- Display SSH tunnel command for local connection

### Job Management
| Alias | Description |
|-------|-------------|
| `hpcc-jobs` | View queued/running jobs |

### Git Operations
| Alias | Description |
|-------|-------------|
| `hpcc-git-pull` | Pull latest changes on HPCC |
| `hpcc-git-status` | Check git status on HPCC |
| `hpcc-git-add` | Add *.err and *.out files |
| `hpcc-git-commit "msg"` | Commit changes |
| `hpcc-git-push` | Push to remote |

### Examples

```bash
# Check jobs
hpcc-jobs

# Submit batch job
granite

# Start interactive session
granite-interactive
# The job output will show the SSH tunnel command
# Example tunnel command:
ssh -L <PORT>:127.0.0.1:<PORT> -i ~/.ssh/id_rsa sweeden@login.hpcc.ttu.edu -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -N

# Use Ollama through the tunnel
OLLAMA_HOST=127.0.0.1:<PORT> ollama list
OLLAMA_HOST=127.0.0.1:<PORT> ollama run granite4:3b --verbose
```

### Tunnel debugging

If the tunnel connects but you get **connection reset by peer** or **connection refused**:

1. **Check the tunnel locally** (on your Mac):
   ```bash
   lsof -i :<PORT>   # should show ssh listening
   curl -v http://127.0.0.1:<PORT>/api/tags   # verbose test
   ```

2. **SSH channel error**  
   If the SSH session shows `channel 2: open failed: connect failed: Connection refused`, the remote side of the forward has nothing listening. That usually means:
   - **Batch jobs**: Ollama runs on a **compute node**, not the login node. The tunnel must forward to the compute node by hostname, not to `127.0.0.1` on the login node.
   - Use the tunnel command printed in the **job output** (it includes the node name), e.g.:
     ```bash
     ssh -L <PORT>:<COMPUTE_NODE>:<PORT> -i ~/.ssh/id_rsa sweeden@login.hpcc.ttu.edu -N
     ```
   - Replace `<COMPUTE_NODE>` with the node name from the job (e.g. the hostname shown in the job log).

3. **Interactive sessions**  
   If you started Ollama in an interactive session on the **login node**, then `-L <PORT>:127.0.0.1:<PORT>` is correct. If the session runs on a compute node, use that node's hostname in the tunnel.

## License

MIT
