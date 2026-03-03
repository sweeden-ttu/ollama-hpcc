#!/bin/bash
# =============================================================================
# run_codellama_ollama.sh
# SLURM batch script: launch an OLLAMA server running CodeLlama on RedRaider
# Partition: matador (GPU)
#
# Submit with:  sbatch run_codellama_ollama.sh
# Or via MPI:   bash mpi_run.sh run_codellama_ollama.sh
# =============================================================================

# SLURM directives per TTU HPCC Job Submission Guide (Submission Script Layout)
#SBATCH -J ollama-codellama
#SBATCH -o %x.o%j
#SBATCH -e %x.e%j
#SBATCH -p matador
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --mem-per-cpu=4096MB
#SBATCH -t 02:30:00
#SBATCH --gpus-per-node=1
# Optional: --cpus-per-task (guide "Other Command Options")
#SBATCH --cpus-per-task=2
# Optional: email notifications (guide "Other Command Options")
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=sweeden@ttu.edu

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
# Clean up previous output/error files for this job name
# Clean old job output/error files (guide format: %x.o%j → <job_name>.o<job_ID>, no .out/.err suffix)
find ~/ollama-hpcc -maxdepth 1 -name "${SLURM_JOB_NAME}.o*" ! -name "${SLURM_JOB_NAME}.o${SLURM_JOB_ID}" -delete 2>/dev/null || true
find ~/ollama-hpcc -maxdepth 1 -name "${SLURM_JOB_NAME}.e*" ! -name "${SLURM_JOB_NAME}.e${SLURM_JOB_ID}" -delete 2>/dev/null || true

SCRIPT_DIR="/home/sweeden/ollama-hpcc/scripts"
source "${SCRIPT_DIR}/model_versions.env"

MODEL="${CODELLAMA_MODEL}"
MODEL_VERSION="${CODELLAMA_VERSION}"
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
module load gcc
module load cuda/12.9.0

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

echo "TUNNEL_FROM_MAC=ssh -L ${OLPORT}:$(hostname):${OLPORT} sweeden@login.hpcc.ttu.edu"

# ---------------------------------------------------------------------------
# Pull model if not already cached
# ---------------------------------------------------------------------------
echo "Pulling model ${FULL_MODEL} (skipped if already cached)..."
"${OLLAMA_BIN}" pull "${FULL_MODEL}"

# ---------------------------------------------------------------------------
# Run the model in background
# ---------------------------------------------------------------------------
echo "Launching ${FULL_MODEL} in serve mode. Connect at ${OLLAMA_BASE_URL}"
~/ollama-latest/bin/ollama run ${FULL_MODEL} --verbose >~/ollama-hpcc/running_${MODEL}_${OLPORT}.log 2>~/ollama-hpcc/running_${MODEL}_${OLPORT}.err &
<<<<<<< HEAD
# Sleep until walltime (02:30:00 = 9000s); standard sleep only accepts seconds
sleep 9000
=======
sleep 2h30m
>>>>>>> 768bef3f2b3a61570d0a1839270e88bf35e26554
wait ${OLLAMA_PID}
