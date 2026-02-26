#!/bin/bash
# interactive_ollama.sh - Start an interactive ollama session on HPCC
# Usage: interactive_ollama.sh [granite|deepseek|codellama|qwen]

set -e

MODEL=${1:-granite}
PARTITION=${PARTITION:-matador}
TIME=${TIME:-02:30:00}

case $MODEL in
    granite)
        MODEL_NAME="granite4"
        MODEL_VER="3b"
        CPUS=4
        BASE_PORT=55077
        ;;
    deepseek)
        MODEL_NAME="deepseek-r1"
        MODEL_VER="8b"
        CPUS=8
        BASE_PORT=55088
        ;;
    codellama)
        MODEL_NAME="codellama"
        MODEL_VER="7b"
        CPUS=6
        BASE_PORT=66033
        ;;
    qwen)
        MODEL_NAME="qwen2.5-coder"
        MODEL_VER="7b"
        CPUS=6
        BASE_PORT=66044
        ;;
    *)
        echo "Unknown model: $MODEL"
        echo "Usage: $0 [granite|deepseek|codellama|qwen]"
        exit 1
        ;;
esac

echo "=============================================="
echo "Starting interactive $MODEL_NAME:$MODEL_VER session"
echo "Resources: 1 GPU, $CPUS CPUs"
echo "=============================================="

# Function to check if a port is available
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

# Find available port - try base, then increment
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

export OLPORT=$AVAILABLE_PORT
export OLLAMA_HOST=127.0.0.1:$OLPORT
export OLLAMA_BASE_URL="http://localhost:$OLPORT"

echo "=============================================="
echo "Port $OLPORT selected"
echo "=============================================="

interactive -c $CPUS -g 1 -p $PARTITION -t $TIME << INNEREOF
cd ~/ollama-hpcc
source scripts/model_versions.env

export OLLAMA_HOST=127.0.0.1:$OLPORT
export OLLAMA_BASE_URL="http://localhost:$OLPORT"

module load gcc
module load cuda/12.9.0

~/ollama-latest/bin/ollama serve > ~/ollama-hpcc/running_${MODEL}_${OLPORT}.log 2> ~/ollama-hpcc/running_${MODEL}_${OLPORT}.err &

sleep 5

echo ""
echo "=============================================="
echo "OLLAMA SERVER STARTED"
echo "=============================================="
echo "Port: $OLPORT"
echo "Model: $MODEL_NAME:$MODEL_VER"
echo ""
echo "To connect from your Mac (with VPN active):"
echo "  ssh -L ${OLPORT}:127.0.0.1:${OLPORT} -i ~/.ssh/id_rsa \$USER@login.hpcc.ttu.edu"
echo ""
echo "Then run:"
echo "  ~/ollama-latest/bin/ollama run $MODEL_NAME:$MODEL_VER"
echo ""
echo "Press Ctrl+C to exit when done."
echo "=============================================="

wait
INNEREOF
