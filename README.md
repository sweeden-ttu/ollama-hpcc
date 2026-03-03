<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Provide a nicely formatted Q\&A style document that is entirely in markdown .  Continue the line of questions, and provide answers that will vaguely serve as specs for other built-in aliases and actions that communicate with the High Performance Computing Center (HPCC).  Answer things like, how do I reserve resources for a slurm job that requires GPU.  How do I run multiple agents in parallel using OpenMPI?  What other built-in aliases can be called on from this local client to connect to HPCC?  (hint: hpcc-info -> node, ollama_host, ollama_base_url,model,port_number)   Should I ever use the default OLLAM port?   (No, use the built-in hpcc-tunnel and hpcc-tunnel-jump alias to expose ollama on the same port made available on the server).

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

