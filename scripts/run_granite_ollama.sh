#!/bin/bash
# =============================================================================
# run_granite_ollama.sh
# SLURM batch script — IBM Granite 4 on RedRaider HPCC (matador GPU partition)
#
# Submission (from login node):
#   cd ~/ollama-hpcc
#   sbatch scripts/run_granite_ollama.sh
#
# Or use the mpi_run launcher to submit N parallel instances:
#   bash scripts/mpi_run.sh run_granite_ollama.sh        # 1 node
#   bash scripts/mpi_run.sh run_granite_ollama.sh 4      # 4 nodes
#
# Following the TTU HPCC Job Submission Guide:
#   - sbatch submits this script to the SLURM scheduler
#   - modules are loaded (gcc + cuda) before execution, matching the guide
# =============================================================================

#SBATCH --job-name=ollama-granite
#SBATCH --partition=matador
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=4096MB
#SBATCH --gpus-per-node=1
#SBATCH --time=02:30:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=sweeden@ttu.edu

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
# Clean up previous output/error files for this job name
find ~/ollama-hpcc -maxdepth 1 -name "${SLURM_JOB_NAME}-*.out" ! -name "${SLURM_JOB_NAME}-${SLURM_JOB_ID}.out" -delete 2>/dev/null || true
find ~/ollama-hpcc -maxdepth 1 -name "${SLURM_JOB_NAME}-*.err" ! -name "${SLURM_JOB_NAME}-${SLURM_JOB_ID}.err" -delete 2>/dev/null || true

SCRIPT_DIR="/home/sweeden/ollama-hpcc/scripts"
source "${SCRIPT_DIR}/model_versions.env"

MODEL="${GRANITE_MODEL}"
MODEL_VERSION="${GRANITE_VERSION}"
FULL_MODEL="${MODEL}:${MODEL_VERSION}"

mkdir -p "${OLLAMA_LOG_DIR}"

# ---------------------------------------------------------------------------
# Pick a free ephemeral port (dynamic) — use same port locally via SSH tunnel
# ---------------------------------------------------------------------------
OLPORT=$(python3 -c "
import socket
s = socket.socket()
s.bind(('', 0))
print(s.getsockname()[1])
s.close()
")

export OLLAMA_HOST="127.0.0.1:${OLPORT}"
export OLLAMA_BASE_URL="http://localhost:${OLPORT}"

echo "============================================================"
echo "Job:        ${SLURM_JOB_NAME} (ID: ${SLURM_JOB_ID})"
echo "Node:       $(hostname)"
echo "Model:      ${FULL_MODEL}"
echo "Port:       ${OLPORT}"
echo "GPU(s):     ${CUDA_VISIBLE_DEVICES}"
echo "Started:    $(date)"
echo "============================================================"

# Write connection info for ollama_port_map.sh and ollama_health_check.sh
INFO_FILE="${OLLAMA_LOG_DIR}/${MODEL}_${SLURM_JOB_ID}.info"
cat > "${INFO_FILE}" <<EOF
JOB_ID=${SLURM_JOB_ID}
MODEL=${FULL_MODEL}
NODE=$(hostname)
PORT=${OLPORT}
OLLAMA_BASE_URL=${OLLAMA_BASE_URL}
STARTED=$(date --iso-8601=seconds)
EOF
echo "Server info written to: ${INFO_FILE}"

# ---------------------------------------------------------------------------
# Load modules (try common HPCC module init paths; SLURM batch has no profile)
# ---------------------------------------------------------------------------

module load gcc
module load cuda/12.9.0
module load python/3.12.5

# ---------------------------------------------------------------------------
# CUDA and GPU summary
# ---------------------------------------------------------------------------
echo "============================================================"
echo "CUDA / GPU summary"
echo "============================================================"
if command -v nvidia-smi &>/dev/null; then
  nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free,utilization.gpu --format=csv,noheader 2>/dev/null || nvidia-smi
else
  echo "nvidia-smi not found; CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
fi
echo "============================================================"

# ---------------------------------------------------------------------------
# Start OLLAMA server
# ---------------------------------------------------------------------------
LOG_BASE="${OLLAMA_LOG_DIR}/${MODEL}_${OLPORT}"

echo "Starting OLLAMA server (${SLURM_CPUS_PER_TASK} CPUs)..."
"${OLLAMA_BIN}" serve > "${LOG_BASE}.log" 2> "${LOG_BASE}.err" &
OLLAMA_PID=$!
echo "OLLAMA PID: ${OLLAMA_PID}"

# Wait for server to be ready
echo "Waiting ${OLLAMA_STARTUP_WAIT}s for OLLAMA to initialise..."
sleep "${OLLAMA_STARTUP_WAIT}"

# Verify server is up
if ! "${OLLAMA_BIN}" list &>/dev/null; then
    echo "ERROR: OLLAMA server did not start. Check ${LOG_BASE}.err"
    exit 1
fi
echo "OLLAMA server ready at ${OLLAMA_BASE_URL}"
echo "SSH tunnel command (from your Mac; Ollama runs on compute node $(hostname)):"
echo "  ssh -L ${OLPORT}:$(hostname):${OLPORT} -i ~/.ssh/id_rsa ${USER}@login.hpcc.ttu.edu -N"
echo "============================================================"

# ---------------------------------------------------------------------------
# Pull model if not already in Lustre cache
# ---------------------------------------------------------------------------
echo "Pulling model ${FULL_MODEL} (no-op if already cached)..."
"${OLLAMA_BIN}" pull "${FULL_MODEL}"

# ---------------------------------------------------------------------------
# Run the model immediately (first inference to load and verify)
# ---------------------------------------------------------------------------
echo "Running model ${FULL_MODEL} (first inference)..."
if curl -s -S --max-time 120 -X POST "http://127.0.0.1:${OLPORT}/api/generate" \
  -H "Content-Type: application/json" \
  -d '{"model":"'"${FULL_MODEL}"'","prompt":"Say OK in one word.","stream":false}' \
  -o /dev/null -w "HTTP %{http_code}\n"; then
  echo "Model ${FULL_MODEL} loaded and ready."
else
  echo "WARNING: First inference failed or timed out; server may still be usable."
fi

# ---------------------------------------------------------------------------
# Keep the job alive — run ollama in background until walltime
# ---------------------------------------------------------------------------
echo "Serving ${FULL_MODEL} — job will run until walltime (${HPCC_TIME})"
echo "To connect from your Mac:"
echo "  ssh -L ${OLPORT}:$(hostname):${OLPORT} -i ~/.ssh/id_rsa ${USER}@login.hpcc.ttu.edu -N"
~/ollama-latest/bin/ollama run ${FULL_MODEL} --verbose >~/ollama-hpcc/running_${MODEL}_${OLPORT}.log 2>~/ollama-hpcc/running_${MODEL}_${OLPORT}.err &
sleep 2h30m
wait ${OLLAMA_PID}
