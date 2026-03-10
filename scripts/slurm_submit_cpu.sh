#!/bin/bash
#SBATCH --job-name=graniteCPU-only
#SBATCH --output=%j_%x.out
#SBATCH --error=%j_%x.err
#SBATCH --partition=nocona
#SBATCH --cpus-per-task=2
#SBATCH --mem=4096
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=04:30:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=sweeden@ttu.edu

# Load module environment (batch jobs don't run as login shell; see slurm_tunnel.sh)
source /etc/slurm/scripts/slurm_fix_modules.sh 2>/dev/null || source /etc/profile.d/lmod.sh

cd $SLURM_SUBMIT_DIR
MODEL=${1:-granite}

case $MODEL in
    granite)
        MODEL_NAME="granite4"
        MODEL_VER="3b"
        ;;
    granite3.2-vision|vision)
        MODEL_NAME="granite3-vision"
        MODEL_VER="8b"
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
        echo "Usage: $0 [granite|granite3.2-vision|deepseek|codellama|qwen]"
        exit 1
        ;;
esac

echo "=============================================="
echo "Starting $MODEL_NAME:$MODEL_VER on $(hostname)"
echo "=============================================="

# Get a dynamic port
export OLLAMA_AVAILABLE_PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")
echo "Selected dynamic port: $OLLAMA_AVAILABLE_PORT"

export OLLAMA_HOST=127.0.0.1:$OLLAMA_AVAILABLE_PORT
export OLLAMA_BASE_URL="http://localhost:$OLLAMA_AVAILABLE_PORT"

echo "=============================================="
echo "Port $OLLAMA_AVAILABLE_PORT selected"
echo "=============================================="
echo ""
echo "TUNNEL_FROM_MAC: ssh -L ${OLLAMA_AVAILABLE_PORT}:$(hostname):${OLLAMA_AVAILABLE_PORT} \$USER@login.hpcc.ttu.edu"
echo "NODE=$(hostname)"
echo "PORT=$OLLAMA_AVAILABLE_PORT"
echo ""

cd /home/sweeden/ollama-hpcc
source /home/sweeden/ollama-hpcc/scripts/model_versions_cpu.env

module purge
module load gcc

export OLLAMA_HOST="127.0.0.1:$OLLAMA_AVAILABLE_PORT"
export OLLAMA_BASE_URL="http://localhost:$OLLAMA_AVAILABLE_PORT"

# Start Ollama server in background
$HOME/ollama-latest/bin/ollama serve > $HOME/ollama-logs/$MODEL_NAME-CPU-$OLLAMA_AVAILABLE_PORT.log 2> $HOME/ollama-logs/$MODEL_NAME-CPU-$OLLAMA_AVAILABLE_PORT.err &
OLLAMA_PID=$!

wait $OLLAMA_PID
