# Ollama on HPCC: Slurm Job + Port Forward to Mac

This guide covers running Ollama as a Slurm batch job on the HPCC cluster and using it from your Mac via SSH port forwarding.

---

## Where things run

| Where | What runs |
|-------|-----------|
| **HPCC cluster** | Slurm job (`slurm_submit.sh`) allocates a node (e.g. `matador1`), starts `ollama serve` there, and picks a dynamic port. |
| **Your Mac** | Port forward (SSH `-L`) and the Ollama client (`ollama run`, `ollama list`, etc.). |

The Ollama server runs only on the compute node. Your Mac runs only the client and talks to the server through the tunnel.

---

## Run the model: from the job or from the client?

**Run `ollama run <model>` from your Mac after you set up the port forward.** Do not add it after the server start in the Slurm script.

- **`ollama run` is interactive** — In the script it would start a chat REPL and block the job. You’d be tied to the job’s stdin/stdout instead of your local terminal.
- **Port is chosen at runtime** — The script picks a dynamic port and prints it in the job’s `.out` file. You need that port to create the tunnel, then you use the client with that tunnel.
- **Model loads on first request** — Once the server is up and you’ve tunneled to it, the first `ollama run` (or API call) from your Mac will make the server load/pull the model. No need to “run” the model inside the job.

---

## How you know the node name and port

When you use the batch job (`sbatch job/slurm_submit.sh`):

1. After the job starts, the **.out file** (e.g. `12345_graniteGPU.out`) is written in the directory where you ran `sbatch`.
2. It contains lines like:
   - `NODE=gpu-nn-nn` (or whatever node the job got)
   - `PORT=41234` (the dynamic port)
   - `TUNNEL_FROM_MAC: ssh -L 41234:gpu-nn-nn:41234 sweeden@login.hpcc.ttu.edu`

**On HPCC, after the job is running:**

```bash
grep -E 'NODE=|PORT=|TUNNEL_FROM_MAC' <jobid>_*GPU.out
# Or just:
cat <jobid>_graniteGPU.out
```

You can also get the node from Slurm (from the same machine you submitted from):

```bash
squeue -u $USER -o "%.18i %.9P %.30j %.8u %.2t %.10M %.6D %R"
# Nodelist is the last column (%R)
```

---

## Port forward setup

Port forwarding is done **on your Mac**, not in the Slurm script. The script only prints the exact command you should run on your Mac.

**On your Mac:**

1. Get **NODE** and **PORT** from the job’s `.out` file (or from the `TUNNEL_FROM_MAC` line).
2. Start the tunnel (one SSH session; leave it open):

   ```bash
   ssh -L PORT:NODE:PORT $USER@login.hpcc.ttu.edu
   ```

   Example (port `41234`, node `matador1`):

   ```bash
   ssh -L 41234:matador1:41234 sweeden@login.hpcc.ttu.edu
   ```

3. In **another** terminal on your Mac, use Ollama:

   ```bash
   OLLAMA_HOST=127.0.0.1:41234 ollama list
   OLLAMA_HOST=127.0.0.1:41234 ollama run granite4:3b
   ```

So: the port forward is set up on the Mac with that `ssh -L` command; the tunnel script on HPCC (`slurm_tunnel.sh`) only prints instructions and does not create the forward itself.

---

## Quick reference

| Step | Where | Command / action |
|------|--------|-------------------|
| 1. Start server | HPCC | `granite` or `deepseek` or `codellama` or `qwen` |
| 2. Get node & port | **Mac** | `hpcc-env` (reads ~/ollama-logs/*.info, prints NODE/PORT/MODEL) |
| 3. Create tunnel | **Mac** | `hpcc-tunnel [MODEL]` e.g. `hpcc-tunnel granite4` |
| 4. Use Ollama | **Mac** | `hpcc-update-env` (sets .env and runs `ollama run <model>`) |

All aliases are defined in `scripts/hpcc-aliases.zsh`.

### Test plan (job already running, start at step 2)
---

## Batch job vs interactive tunnel script

- **`slurm_submit.sh`** — Batch job: starts `ollama serve` on the allocated node and keeps the job alive. Get NODE and PORT from the job’s `.out` file, then run the `ssh -L` and `OLLAMA_HOST=... ollama` commands on your Mac.
- **`slurm_tunnel.sh`** — Interactive Slurm allocation (e.g. `salloc`). Use it when you want a shell on a node and will start Ollama yourself in that session. After you get the shell, the script prints generic tunnel instructions; substitute the node you’re on and the port Ollama reports.

For the typical “run Ollama in the background on a GPU node and use it from my Mac” workflow, use the batch job and the Mac steps above.
