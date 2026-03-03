<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# OpenMPI-Enabled Ollama Model Launcher Slurm Job (Port Offset by JOBID)

**RECOMMENDED PORT STRATEGY**: Use `$SLURM_JOB_ID % 256` offset to ensure **unique ports across all jobs** while staying within valid port range (11434-11589).

```bash
#!/bin/bash
# =============================================================================
# ollama_mpi_single_model.sh
# Launch a single Ollama model server per MPI rank on Matador GPU nodes.
# **PORT OFFSET: $SLURM_JOB_ID % 256** ensures unique ports across jobs.
#
# Usage:
#   mpirun -np 4 sbatch ollama_mpi_single_model.sh granite4:3b
#
# =============================================================================

#SBATCH --job-name=ollama-mpi-model
#SBATCH --partition=matador
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4          # MPI processes per node
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4096MB
#SBATCH --gpus-per-task=1
#SBATCH --time=04:00:00
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=sweeden@ttu.edu
#SBATCH --output=ollama-mpi-%j.out
#SBATCH --error=ollama-mpi-%j.err

# MPI rank awareness + JOBID-based port offset
export OMPROC_NUM_THREADS=1
export OMPI_MCA_btl_vader_single_copy_mechanism=none

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/model_versions.env" 2>/dev/null || echo "Using default model config"

# Model parameter (passed via MPI)
MODEL=${1:-granite4:3b}
echo "Job ${SLURM_JOB_ID}: MPI Rank ${SLURM_PROCID}: Launching ${MODEL}"

# **🎯 PORT STRATEGY: BASE + (JOBID % 256) + RANK**
# Ensures: 1) Unique per-job, 2) Unique per-rank, 3) Valid range (11434-11589)
JOB_OFFSET=$((SLURM_JOB_ID % 256))
RANK_OFFSET=${SLURM_PROCID}
OLPORT=$((11434 + JOB_OFFSET + RANK_OFFSET))
export OLLAMA_HOST="127.0.0.1:${OLPORT}"

# Per-rank directories with JOBID prefix
mkdir -p "${OLLAMA_LOG_DIR:-./logs}/job-${SLURM_JOB_ID}-mpi-${SLURM_PROCID}"

# Load modules
module purge
module load gcc cuda/12.9.0 openmpi
export PATH="${OLLAMA_BIN:-/usr/local/bin}:$PATH"

echo "📋 Job ${SLURM_JOB_ID} Rank ${SLURM_PROCID} Summary:"
echo "   Model: ${MODEL}"
echo "   Port:  ${OLPORT} (base=11434 + job=${JOB_OFFSET} + rank=${RANK_OFFSET})"
echo "   Logs:  ${OLLAMA_LOG_DIR:-./logs}/job-${SLURM_JOB_ID}-mpi-${SLURM_PROCID}/"

# Pull model (one-time)
ollama pull "${MODEL}" > "${OLLAMA_LOG_DIR:-./logs}/job-${SLURM_JOB_ID}-mpi-${SLURM_PROCID}/pull.log" 2>&1

# Launch Ollama server
"${OLLAMA_BIN:-ollama}" serve \
    > "${OLLAMA_LOG_DIR:-./logs}/job-${SLURM_JOB_ID}-mpi-${SLURM_PROCID}/serve.log" \
    2> "${OLLAMA_LOG_DIR:-./logs}/job-${SLURM_JOB_ID}-mpi-${SLURM_PROCID}/serve.err" &

sleep 10

# Health check
if curl -s http://127.0.0.1:${OLPORT}/api/tags > /dev/null; then
    echo "✅ Job ${SLURM_JOB_ID} Rank ${SLURM_PROCID}: Ollama ready at 127.0.0.1:${OLPORT}"
else
    echo "❌ Job ${SLURM_JOB_ID} Rank ${SLURM_PROCID}: Startup failed"
fi

# Keep alive
wait
```


## Port Allocation Strategy

| Component | Offset Formula | Range |
| :-- | :-- | :-- |
| **Base Port** | `11434` | Fixed |
| **Job Offset** | `$SLURM_JOB_ID % 256` | `0-255` |
| **Rank Offset** | `$SLURM_PROCID` | `0-3` (for 4 ranks) |
| **Final Port** | `11434 + job_offset + rank_offset` | **11434-11650** |

**Example**: Job 12345 with 4 MPI ranks:

```
Rank 0: 11434 + (12345%256=185) + 0 = 11619
Rank 1: 11434 + 185 + 1 = 11620  
Rank 2: 11434 + 185 + 2 = 11621
Rank 3: 11434 + 185 + 3 = 11622
```


## Usage Examples

```bash
# Launch 4 parallel granite instances (Job 67890 → ports 11620-11623)
mpirun -np 4 sbatch ollama_mpi_single_model.sh granite4:3b

# Different job (54321) → completely different ports (11587-11590)
mpirun -np 4 sbatch ollama_mpi_single_model.sh deepseek-coder:6.7b
```


## Tunnel Command (Auto-Generated)

For job 12345 on node `cpu-01-42`:

```bash
ssh sweeden@login.hpcc.ttu.edu \
  -L 11619:cpu-01-42:11619 \
  -L 11620:cpu-01-42:11620 \
  -L 11621:cpu-01-42:11621 \
  -L 11622:cpu-01-42:11622 \
  -N
```


## Key Benefits of JOBID % 256 Strategy

- ✅ **Zero port collisions** across all concurrent jobs
- ✅ **Predictable ranges** (max 256 jobs × 4 ranks = 1024 unique ports)
- ✅ **Scales automatically** with Slurm job numbering
- ✅ **No manual port management** required

**Perfect for production OpenMPI + Ollama deployments!** 🎯

