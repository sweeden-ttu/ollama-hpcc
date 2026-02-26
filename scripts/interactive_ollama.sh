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
        BASE_PORT=55077
        ;;
    deepseek)
        MODEL_NAME="deepseek-r1"
        MODEL_VER="8b"
        BASE_PORT=55088
        ;;
    codellama)
        MODEL_NAME="codellama"
        MODEL_VER="7b"
        BASE_PORT=66033
        ;;
    qwen)
        MODEL_NAME="qwen2.5-coder"
        MODEL_VER="7b"
        BASE_PORT=66044
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

check_port() {
    local port=$1
    python3 -c "
import socket
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(('127.0.0.1', $port))
    s.close()
    print('available')
except:
    print('inuse')
" 2>/dev/null
}

AVAILABLE_PORT=""
for port in $BASE_PORT $(($BASE_PORT + 100)) $(($BASE_PORT + 200)); do
    if [ "$(check_port $port)" = "available" ]; then
        AVAILABLE_PORT=$port
        echo "Using port: $port"
        break
    fi
    echo "Port $port in use, trying next..."
done

if [ -z "$AVAILABLE_PORT" ]; then
    echo "ERROR: No available ports found starting from $BASE_PORT"
    exit 1
fi

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
echo "Model: $MODEL_NAME:$MODEL_VER"
echo ""
echo "To connect from your Mac (with VPN active):"
echo "  ssh -q -L ${AVAILABLE_PORT}:127.0.0.1:${AVAILABLE_PORT} -i ~/.ssh/id_rsa sweeden@login.hpcc.ttu.edu"
echo ""
echo "Then run:"
echo "  /home/sweeden/ollama-latest/bin/ollama run $MODEL_NAME:$MODEL_VER"
echo ""
echo "Press Ctrl+C to exit when done."
echo "=============================================="

wait
