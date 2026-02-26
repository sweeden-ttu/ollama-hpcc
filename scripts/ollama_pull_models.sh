#!/bin/bash
# =============================================================================
# ollama_pull_models.sh
# Pre-pull all OLLAMA models to the local cache from an interactive session
# on a matador GPU node. Run this ONCE before submitting batch jobs to
# avoid repeated downloads eating into walltime.
#
# Usage (from login node):
#   interactive -p matador --gpus-per-node=1 -c 8 --mem-per-cpu=4096MB
#   bash ollama_pull_models.sh
#
# Or as a short batch job:
#   sbatch ollama_pull_models.sh
# =============================================================================

#SBATCH --job-name=ollama-pull
#SBATCH --partition=matador
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4096MB
#SBATCH --gpus-per-node=1
#SBATCH --time=02:00:00
#SBATCH --output=ollama-pull-%j.out
#SBATCH --error=ollama-pull-%j.err

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/model_versions.env"

mkdir -p "${OLLAMA_LOG_DIR}"

module purge
module load gcc
module load cuda/12.9.0

# Start a temporary OLLAMA server just for pulling
OLPORT=$(python3 -c "
import socket
s = socket.socket()
s.bind(('', 0))
print(s.getsockname()[1])
s.close()
")
export OLLAMA_HOST="127.0.0.1:${OLPORT}"

"${OLLAMA_BIN}" serve > "${OLLAMA_LOG_DIR}/pull_${OLPORT}.log" \
                      2> "${OLLAMA_LOG_DIR}/pull_${OLPORT}.err" &
OLLAMA_PID=$!
sleep "${OLLAMA_STARTUP_WAIT}"

MODELS=(
    "${GRANITE_MODEL}:${GRANITE_VERSION}"
    "${DEEPSEEK_MODEL}:${DEEPSEEK_VERSION}"
    "${QWENCODER_MODEL}:${QWENCODER_VERSION}"
    "${CODELLAMA_MODEL}:${CODELLAMA_VERSION}"
)

echo "Pulling ${#MODELS[@]} models..."
for m in "${MODELS[@]}"; do
    echo ""
    echo "=== Pulling ${m} ==="
    "${OLLAMA_BIN}" pull "${m}"
    echo "=== Done: ${m} ==="
done

echo ""
echo "All models pulled. Cached models:"
"${OLLAMA_BIN}" list

kill "${OLLAMA_PID}" 2>/dev/null
echo "Pull job complete: $(date)"
