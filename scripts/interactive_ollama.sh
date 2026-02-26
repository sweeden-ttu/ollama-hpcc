#!/bin/bash
# interactive_ollama.sh - Start an interactive ollama session on HPCC
# This script runs on the GPU node after salloc/srun allocates it
# Usage: interactive_ollama.sh [granite|deepseek|codellama|qwen]

set -e

MODEL=${1:-granite}

case $MODEL in
    granite)
        MODEL_NAME="granite4"
        MODEL_VER="3b"
        ;;
    deepseek)
        MODEL_NAME="deepseek-r1"
        MODEL_VER="8b"
        ;;
    codellama)
        MODEL_NAME="codellama"
        MODEL_VER="7b"
        ;;
    qwen)
        MODEL_NAME="qwen2.5-coder"
        MODEL_VER="7b"
        ;;
    *)
        echo "Unknown model: $MODEL"
        echo "Usage: $0 [granite|deepseek|codellama|qwen]"
        exit 1
        ;;
esac

echo "=============================================="
echo "Starting $MODEL_NAME:$MODEL_VER on $(hostname)"
echo "=============================================="

# Get a dynamic port
AVAILABLE_PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")
echo "Selected dynamic port: $AVAILABLE_PORT"

export OLLAMA_HOST=127.0.0.1:$AVAILABLE_PORT
export OLLAMA_BASE_URL="http://localhost:$AVAILABLE_PORT"

echo "=============================================="
echo "Port $AVAILABLE_PORT selected"
echo "=============================================="

cd /home/sweeden/ollama-hpcc
source /home/sweeden/ollama-hpcc/scripts/model_versions.env

export OLLAMA_HOST=127.0.0.1:$AVAILABLE_PORT
export OLLAMA_BASE_URL="http://localhost:$AVAILABLE_PORT"

module load gcc
module load cuda/12.9.0

echo "Starting Ollama server..."
/home/sweeden/ollama-latest/bin/ollama serve > /home/sweeden/ollama-hpcc/running_${MODEL}_${AVAILABLE_PORT}.log 2> /home/sweeden/ollama-hpcc/running_${MODEL}_${AVAILABLE_PORT}.err &

sleep 5

echo ""
echo "=============================================="
echo "OLLAMA SERVER STARTED"
echo "=============================================="
echo "Port: $AVAILABLE_PORT"
echo "Node: $(hostname)"
echo "Model: $MODEL_NAME:$MODEL_VER"
echo ""
echo "To create a tunnel from your Mac use this format:"
echo "  1. Login to interactive nocona on HPCC: /etc/slurm/scripts/interactive -p nocona"
echo "  2. Note the node name and port from this session (node=$(hostname), port=$AVAILABLE_PORT)"
echo "  3. From your Mac: ssh sweeden@login.hpcc.ttu.edu -L pppp:NODE:pppp"
echo "     Substitute NODE and pppp with the node name and port from step 2."
echo ""
echo "  Example for this session: ssh sweeden@login.hpcc.ttu.edu -L ${AVAILABLE_PORT}:$(hostname):${AVAILABLE_PORT}"
echo ""
echo "Then use Ollama locally:"
echo "  OLLAMA_HOST=127.0.0.1:${AVAILABLE_PORT} ollama list"
echo "  OLLAMA_BASE_URL=http://127.0.0.1:${AVAILABLE_PORT} ollama run $MODEL_NAME:$MODEL_VER"
echo ""
echo "Press Ctrl+C in this terminal to exit when done."
echo "=============================================="

wait
