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
- Create a tunnel using: (1) Login to interactive nocona via `/etc/slurm/scripts/interactive -p nocona`, (2) note node and port, (3) from Mac: `ssh sweeden@login.hpcc.ttu.edu -L pppp:NODE:pppp`

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

### Creating a tunnel to Ollama on HPCC

Use this procedure to create an SSH tunnel from your Mac to the Ollama server.

**Step 1 — Login to interactive nocona (on HPCC):**

```bash
/etc/slurm/scripts/interactive -p nocona
```

**Step 2 — From that session:** Note the **hostname** (e.g. `cpu-NN-nn`) and the **Ollama dynamic port** (pppp) from the job or script output.

**Step 3 — From your Mac**, run (substitute the node name and port from the previous step for `cpu-NN-nn` and `pppp` respectively):

```bash
ssh sweeden@login.hpcc.ttu.edu -L pppp:cpu-NN-nn:pppp
```

Example: if the node is `cpu-01-42` and the port is `34935`:

```bash
ssh sweeden@login.hpcc.ttu.edu -L 34935:cpu-01-42:34935
```

Then use Ollama locally:

```bash
OLLAMA_HOST=127.0.0.1:<pppp> ollama list
OLLAMA_HOST=127.0.0.1:<pppp> ollama run granite4:3b --verbose
```

### Examples

```bash
# Check jobs
hpcc-jobs

# Submit batch job
granite

# Start interactive session
granite-interactive
# Follow the 3-step tunnel procedure above using the port and node from the output
```

### Tunnel debugging

If the tunnel connects but you get **connection reset by peer** or **connection refused**:

1. **Check the tunnel locally** (on your Mac):
   ```bash
   lsof -i :<pppp>   # should show ssh listening
   curl -v http://127.0.0.1:<pppp>/api/tags   # verbose test
   ```

2. Ensure you used the correct format: `ssh sweeden@login.hpcc.ttu.edu -L pppp:NODE:pppp` where **NODE** is the hostname from `/etc/slurm/scripts/interactive -p nocona` (e.g. `cpu-NN-nn`) and **pppp** is the Ollama dynamic port.

## License

MIT
