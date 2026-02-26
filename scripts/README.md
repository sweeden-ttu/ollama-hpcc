# OLLAMA on TTU RedRaider HPCC — Script Reference

Scripts for running multiple OLLAMA LLM servers on the **matador** GPU partition
of Texas Tech's RedRaider HPCC cluster.

---

## Model Versions (as of 2026-02-26)

| Variable | Model | Tag | Params | VRAM est. | Notes |
|---|---|---|---|---|---|
| `GRANITE_MODEL` | `granite4` | `3b` | 3B | ~2.1 GB | IBM Granite 4 "micro"; also `:1b` (3.3GB) and `-h` hybrid Mamba-2 variants |
| `DEEPSEEK_MODEL` | `deepseek-r1` | `8b` | 8B | ~5.2 GB | R1-0528-Qwen3 distill |
| `QWENCODER_MODEL` | `qwen2.5-coder` | `7b` | 7B | ~4.7 GB | |
| `CODELLAMA_MODEL` | `codellama` | `7b` | 7B | ~3.8 GB | |

All versions and tags are set in `model_versions.env`. Edit there to upgrade.

---

## Quick Start

### 1. Pre-pull model weights (do this once)
```bash
sbatch scripts/ollama_pull_models.sh
```
Pulls all four models to your Lustre cache so batch jobs start instantly.

### 2. Launch a single model
```bash
sbatch scripts/run_granite_ollama.sh
sbatch scripts/run_deepseek_ollama.sh
sbatch "scripts/run_qwen-coder_ollama.sh"
sbatch scripts/run_codellama_ollama.sh
```

### 3. Launch a model with multiple nodes (load-balanced pool)
```bash
bash scripts/mpi_run.sh run_granite_ollama.sh 4   # 4 independent granite servers
```

### 4. Launch all models at once
```bash
bash scripts/mpi_run_all.sh          # 1 node per model
bash scripts/mpi_run_all.sh 2        # 2 nodes per model
```

---

## Monitoring

```bash
# Show all running OLLAMA SLURM jobs + discovered server info
bash scripts/ollama_list_jobs.sh

# Health-check every running server (HTTP ping + SLURM state)
bash scripts/ollama_health_check.sh

# Machine-readable JSON output
bash scripts/ollama_health_check.sh --json
```

---

## Connecting from Your Laptop

Each job writes a `~/ollama-logs/<model>_<jobid>.info` file containing the
compute node hostname and dynamic port. Use `ollama_connect.sh` to set up
a two-hop SSH tunnel:

```bash
# Connect to the first granite server, expose locally on port 11434
bash scripts/ollama_connect.sh granite

# Connect to deepseek-r1 on local port 11435
bash scripts/ollama_connect.sh deepseek-r1 11435

# Then from your laptop:
curl http://localhost:11434/api/tags
OLLAMA_HOST=http://localhost:11434 ollama run granite3.3:8b
```

---

## Static ↔ Dynamic Port Mapping

Each OLLAMA job binds a random dynamic port. `ollama_port_map.sh` reads the
running `.info` files and maps those dynamic ports to your pre-agreed static
ports for each environment, then generates SSH tunnel commands.

### Static port table

| Environment        | granite | deepseek | qwen-coder | codellama |
|--------------------|---------|----------|------------|-----------|
| Debug (VPN)        | 55077   | 55088    | 66044      | 66033     |
| Testing +1 (macOS) | 55177   | 55188    | 66144      | 66133     |
| Testing +2 (Rocky) | 55277   | 55288    | 66244      | 66233     |
| Release +3         | 55377   | 55388    | 66344      | 66333     |

### Usage

```bash
# Human-readable table + ready-to-paste SSH commands for all environments
bash scripts/ollama_port_map.sh

# Write ~/ollama-logs/port_map.json (also prints to stdout)
bash scripts/ollama_port_map.sh --json

# Filter to one environment
bash scripts/ollama_port_map.sh --env debug
bash scripts/ollama_port_map.sh --env testing1
bash scripts/ollama_port_map.sh --env testing2
bash scripts/ollama_port_map.sh --env release

# JSON for a single environment
bash scripts/ollama_port_map.sh --json --env debug
```

### Example SSH tunnel (granite, Debug/VPN)

```bash
ssh -L 55077:127.0.0.1:{$GRANITE_DYNAMIC_PORT} -i ~/.ssh/id_rsa sweeden@login.hpcc.ttu.edu
```

The script generates this command automatically for every model/environment
combination based on the currently running `.info` files. Once the tunnel is
up, reach the model at `http://localhost:55077` from your local machine.

---

## Teardown

```bash
# Cancel all OLLAMA jobs
bash scripts/ollama_teardown.sh --all

# Cancel only deepseek jobs
bash scripts/ollama_teardown.sh --model deepseek

# Cancel a specific job
bash scripts/ollama_teardown.sh --job 123456

# Remove stale .info files for completed jobs
bash scripts/ollama_teardown.sh --clean
```

---

## File Reference

| File | Purpose |
|---|---|
| `model_versions.env` | Central config: model tags, SLURM defaults |
| `run_granite_ollama.sh` | SLURM job: IBM Granite 4 3B |
| `run_deepseek_ollama.sh` | SLURM job: DeepSeek-R1 8B |
| `run_qwen-coder_ollama.sh` | SLURM job: Qwen2.5-Coder 7B |
| `run_codellama_ollama.sh` | SLURM job: CodeLlama 7B |
| `mpi_run.sh` | Submit N parallel instances of any run script |
| `mpi_run_all.sh` | Submit all four models at once |
| `ollama_pull_models.sh` | Pre-warm model cache (run once) |
| `ollama_list_jobs.sh` | Show running jobs + server info |
| `ollama_health_check.sh` | HTTP + SLURM health table |
| `ollama_connect.sh` | SSH tunnel from laptop to compute node (ad-hoc) |
| `ollama_port_map.sh` | Map dynamic→static ports; generate SSH tunnel cmds; output JSON |
| `ollama_teardown.sh` | Cancel jobs / clean up stale .info files |

---

## SLURM Defaults (matador partition)

```
Partition:    matador
GPUs/node:    1
CPUs/task:    8
Mem/CPU:      4096 MB
Walltime:     8 hours
```

Adjust in `model_versions.env` or override per-script with `#SBATCH` lines.

---

## Notes

- OLLAMA binaries are expected at `~/ollama-latest/bin/ollama`
- Server logs go to `~/ollama-logs/<model>_<port>.log`
- Each job auto-discovers a free TCP port via Python socket binding
- The `OLLAMA_HOST` env var scopes each server to `127.0.0.1` only (no
  inter-node exposure); use `ollama_connect.sh` for external access
- Example scripts in `/lustre/work/examples/matador/` on the cluster
  can serve as additional reference for matador-specific SLURM options
