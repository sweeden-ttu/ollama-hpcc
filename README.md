<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Provide a nicely formatted Q\&A style document that is entirely in markdown .  Continue the line of questions, and provide answers that will vaguely serve as specs for other built-in aliases and actions that communicate with the High Performance Computing Center (HPCC).  Answer things like, how do I reserve resources for a slurm job that requires GPU.  How do I run multiple agents in parallel using OpenMPI?  What other built-in aliases can be called on from this local client to connect to HPCC?  (hint: hpcc-info -> node, ollama_host, ollama_base_url,model,port_number)   Should I ever use the default OLLAM port?   (No, use the built-in hpcc-tunnel and hpcc-tunnel-jump alias to expose ollama on the same port made available on the server).

<<<<<<< HEAD
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
=======
1. How do I connect to RedRaider using SSH?
Answer:  Since your eraider user-id is *sweeden* , you want to suppress the welcome message upon each connection and connect using public key authentication.  This is accomplished with the following command:
```zsh
ssh -q -i `/Users/owner/.ssh/id_rsa' [sweeden@login.hpcc.ttu.edu](mailto:sweeden@login.hpcc.ttu.edu)  # .. see hpcc alias in ~/.zshrc for further information
```

For further information see [https://www.depts.ttu.edu/hpcc/userguides/general_guides/login_general.php](https://www.depts.ttu.edu/hpcc/userguides/general_guides/login_general.php)

2. How will I know when I am connected to the High Performance Computing Center?
```bash
sweeden@login-40-2 >   `/etc/slurm/scripts/interactive -c 4 -g 1 -p matador'  
```

For running and installing python code and dependencies see: [https://www.depts.ttu.edu/hpcc/userguides/application_guides/Miniforge.php](https://www.depts.ttu.edu/hpcc/userguides/application_guides/Miniforge.php)

3. Should I ever use the default ollama port for an ollama model? *No*
```bash
sweeden@login-40-2 >  `~/ollama-hpcc/scripts/run-$MODEL.sh' should be used and the default model should be granite4:3b.  Run multiple models in parallel using OpenMPI. 
```

Here’s a well-structured **Q\&A style document** in Markdown that continues your established format, providing guidance and specifications for built-in aliases, job scheduling, GPU reservations, and remote model hosting with HPCC.

***

# HPCC Client Q\&A Reference

## 1. How do I connect to RedRaider using SSH?

Since your eraider user ID is **sweeden**, you’ll want to suppress the welcome message and connect using public key authentication. Use the command:

```zsh
ssh -q -i '/Users/owner/.ssh/id_rsa' sweeden@login.hpcc.ttu.edu
# .. see hpcc alias in ~/.zshrc for further information
```

For more details, visit [HPCC Login Guide](https://www.depts.ttu.edu/hpcc/userguides/general_guides/login_general.php).

***

## 2. How will I know when I am connected to the High Performance Computing Center?

When logged in, your shell prompt will indicate a remote session such as:

```bash
sweeden@login-40-2 >
```

To request interactive Slurm resources with GPU access:

```bash
/etc/slurm/scripts/interactive -c 4 -g 1 -p matador
```

This requests 4 CPU cores and 1 GPU on the `matador` partition.
For managing Python environments, follow [Miniforge Setup Instructions](https://www.depts.ttu.edu/hpcc/userguides/application_guides/Miniforge.php).

***

## 3. Should I ever use the default Ollama port for a model?

**No.** Do **not** use the default Ollama port. Instead, use the provided tunneling aliases to expose your model on the correct bound port.

Example:

```bash
hpcc-tunnel
hpcc-tunnel-jump
```

These aliases ensure that your local Ollama endpoint matches the one securely exposed from the remote host.

***

## 4. How do I reserve resources for a Slurm job that requires GPU?

To schedule a batch or interactive job requiring GPU acceleration, use the `--gres` flag or the shorthand `-g` if the interactive wrapper supports it. For example:

```bash
sbatch --partition=matador --gres=gpu:1 --cpus-per-task=4 --mem=16G my_gpu_script.sh
```

Or interactively:

```bash
/etc/slurm/scripts/interactive -c 4 -g 1 -p matador
```

Example `my_gpu_script.sh` template:

```bash
#!/bin/bash
#SBATCH --job-name=gpu-test
#SBATCH --output=out.%j
#SBATCH --error=err.%j
#SBATCH --partition=matador
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

module load cuda/12.0
python train_model.py --epochs 10
```


***

## 5. How do I run multiple agents in parallel using OpenMPI?

When scaling workloads across nodes, use `mpirun` or `srun` with the OpenMPI module loaded:

```bash
module load openmpi
mpirun -np 8 python agent.py
```

Alternatively, in a Slurm-managed environment:

```bash
srun --mpi=pmix_v3 -n 8 python agent.py
```

Each process will execute in parallel across available nodes as defined by Slurm’s resource allocation.

***

## 6. What built-in aliases are available to connect or query HPCC information?

Your local client contains several helpful aliases for quick environment introspection and connection:

```bash
hpcc-info      # Displays node, ollama_host, ollama_base_url, model, and port_number
hpcc-tunnel    # Opens a secure tunnel to expose Ollama server port locally
hpcc-tunnel-jump  # Multi-hop tunneling from local → login → compute node
hpcc            # Shortcut to connect to login.hpcc.ttu.edu
hpcc-status     # Lists active Slurm jobs and queued states
hpcc-kill       # Terminates HPCC jobs by job ID
```

Use `alias` or `type` commands in Zsh to inspect these definitions directly.

***

## 7. How can I launch Ollama models correctly on HPCC?

Use the model launch scripts provided under `~/ollama-hpcc/scripts/`:

```bash
~/ollama-hpcc/scripts/run-$MODEL.sh
```

By default, the baseline model to run is **granite4:3b**.
You can launch multiple models in parallel using OpenMPI:

```bash
mpirun -np 4 ./ollama-hpcc/scripts/run-granite4:3b.sh
```

This will orchestrate multiple model instances efficiently across compute resources.

***

## 8. Quick Summary of Resource Alias Behavior

| Alias | Purpose | Notes |
| :-- | :-- | :-- |
| `hpcc` | SSH connection to HPCC login node | Uses key authentication |
| `hpcc-info` | Displays environment connection info | Includes Ollama and Slurm metadata |
| `hpcc-tunnel` | Creates local port tunnel to HPCC environment | Avoid default Ollama port |
| `hpcc-tunnel-jump` | Multi-hop tunnel for compute nodes | Useful for node isolation |
| `hpcc-status` | Lists job queue and running states | Wraps `squeue` command |
| `hpcc-kill` | Cancels a job using job ID | Alias for `scancel JOBID` |


***

Would you like me to include an example of how to chain these aliases together for an automated job submission pipeline (e.g., tunneling + model spin-up + MPI launch)?
>>>>>>> 768bef3f2b3a61570d0a1839270e88bf35e26554

