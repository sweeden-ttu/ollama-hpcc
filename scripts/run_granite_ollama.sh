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
# Pick a free ephemeral port (dynamic) — mapped to static port 55077 via
# SSH tunnel for the Debug/VPN environment
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
echo "SSH tunnel command (Debug/VPN port 55077):"
echo "  ssh -L 55077:127.0.0.1:${OLPORT} -i ~/.ssh/id_rsa ${USER}@login.hpcc.ttu.edu"
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
# Load modules
# ---------------------------------------------------------------------------
source /etc/profile.d/modules.sh
module purge
module load gcc/13.2.0
module load cuda/11.8.0

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

# ---------------------------------------------------------------------------
# Pull model if not already in Lustre cache
# ---------------------------------------------------------------------------
echo "Pulling model ${FULL_MODEL} (no-op if already cached)..."
"${OLLAMA_BIN}" pull "${FULL_MODEL}"

# ---------------------------------------------------------------------------
# Keep the job alive — OLLAMA serve runs until walltime or scancel
# The job output file (%x-%j.out) shows the dynamic port for tunnelling
# ---------------------------------------------------------------------------
echo "Serving ${FULL_MODEL} — job will run until walltime (${HPCC_TIME})"
echo "To connect from your Mac (VPN active):"
echo "  ssh -L 55077:127.0.0.1:${OLPORT} -i ~/.ssh/id_rsa ${USER}@login.hpcc.ttu.edu"
wait ${OLLAMA_PID}

echo "Job finished: $(date)"
