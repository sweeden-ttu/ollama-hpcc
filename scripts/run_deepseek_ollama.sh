#!/bin/bash
# =============================================================================
# run_deepseek_ollama.sh
# SLURM batch script: launch an OLLAMA server running DeepSeek-R1 on RedRaider
# Partition: matador (GPU)
#
# Submit with:  sbatch run_deepseek_ollama.sh
# Or via MPI:   bash mpi_run.sh run_deepseek_ollama.sh
# =============================================================================

#SBATCH --job-name=ollama-deepseek
#SBATCH --partition=matador
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=6144MB
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

MODEL="${DEEPSEEK_MODEL}"
MODEL_VERSION="${DEEPSEEK_VERSION}"
FULL_MODEL="${MODEL}:${MODEL_VERSION}"

mkdir -p "${OLLAMA_LOG_DIR}"

# ---------------------------------------------------------------------------
# Pick a free ephemeral port
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

# Write connection info so other scripts can discover this server
INFO_FILE="${OLLAMA_LOG_DIR}/${MODEL}_${SLURM_JOB_ID}.info"
cat > "${INFO_FILE}" <<EOF
JOB_ID=${SLURM_JOB_ID}
MODEL=${FULL_MODEL}
NODE=$(hostname)
PORT=${OLPORT}
OLLAMA_BASE_URL=${OLLAMA_BASE_URL}
STARTED=$(date --iso-8601=seconds)
EOF

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
"${OLLAMA_BIN}" serve > "${LOG_BASE}.log" 2> "${LOG_BASE}.err" &
OLLAMA_PID=$!
echo "OLLAMA server PID: ${OLLAMA_PID}"

echo "Waiting ${OLLAMA_STARTUP_WAIT}s for OLLAMA to initialise..."
sleep "${OLLAMA_STARTUP_WAIT}"

if ! "${OLLAMA_BIN}" list &>/dev/null; then
    echo "ERROR: OLLAMA server did not start. Check ${LOG_BASE}.err"
    exit 1
fi

# ---------------------------------------------------------------------------
# Pull model if not already cached
# ---------------------------------------------------------------------------
echo "Pulling model ${FULL_MODEL} (skipped if already cached)..."
"${OLLAMA_BIN}" pull "${FULL_MODEL}"

# ---------------------------------------------------------------------------
# Run the model
# ---------------------------------------------------------------------------
echo "Launching ${FULL_MODEL} in serve mode. Connect at ${OLLAMA_BASE_URL}"
"${OLLAMA_BIN}" run "${FULL_MODEL}" --verbose

echo "Job finished: $(date)"
