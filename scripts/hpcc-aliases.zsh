#!/bin/zsh

# Remove any existing hpcc alias to avoid conflicts
unalias hpcc 2>/dev/null

# Run commands on remote HPCC
hpcc() {
    ssh -q sweeden@login.hpcc.ttu.edu "$@"
}

# SSH into HPCC login node
hpcc-login() {
    ssh -q sweeden@login.hpcc.ttu.edu
}

# Model-specific aliases (Debug ports: granite=55077, deepseek=55088, qwen=66044, codellama=66033)
granite() {
    ssh -q sweeden@login.hpcc.ttu.edu "./ollama-hpcc/scripts/run_granite_ollama.sh ${1:-DEBUG} ${2:-55077}"
}

codellama() {
    ssh -q sweeden@login.hpcc.ttu.edu "./ollama-hpcc/scripts/run_codellama_ollama.sh ${1:-DEBUG} ${2:-66033}"
}

deepseek() {
    ssh -q sweeden@login.hpcc.ttu.edu "./ollama-hpcc/scripts/run_deepseek_ollama.sh ${1:-DEBUG} ${2:-55088}"
}

qwen() {
    ssh -q sweeden@login.hpcc.ttu.edu "./ollama-hpcc/scripts/run_qwen_ollama.sh ${1:-DEBUG} ${2:-66044}"
}

# Interactive model sessions - request GPU node and start ollama server
# These use the HPCC interactive command to get a GPU node
# Then start ollama serve and show SSH tunnel command

granite-interactive() {
    # granite4:3b - 3B params, ~2.1GB VRAM - minimal resources
    echo "=============================================="
    echo "Starting interactive granite session..."
    echo "Model: granite4:3b (~2.1GB VRAM)"
    echo "Resources: 1 GPU, 4 CPUs, 4GB memory"
    echo "=============================================="
    ssh -t sweeden@login.hpcc.ttu.edu 'interactive -c 4 -g 1 -p matador -t 02:30:00'
}

deepseek-interactive() {
    # deepseek-r1:8b - 8B params, ~5.2GB VRAM - needs more resources
    echo "=============================================="
    echo "Starting interactive deepseek session..."
    echo "Model: deepseek-r1:8b (~5.2GB VRAM)"
    echo "Resources: 1 GPU, 8 CPUs, 8GB memory"
    echo "=============================================="
    ssh -t sweeden@login.hpcc.ttu.edu "
        interactive -c 8 -g 1 -p matador -t 02:30:00 '
            cd ~/ollama-hpcc
            source scripts/model_versions.env
            export OLPORT=\$(python3 -c \"import socket; s = socket.socket(); s.bind((\\"\\\"\\, 0)); print(s.getsockname()[1]); s.close()\")
            export OLLAMA_HOST=127.0.0.1:\$OLPORT
            export OLLAMA_BASE_URL=http://localhost:\$OLPORT
            module load gcc
            module load cuda/12.9.0
            ~/ollama-latest/bin/ollama serve > ~/ollama-hpcc/running_deepseek_\$OLPORT.log 2> ~/ollama-hpcc/running_deepseek_\$OLPORT.err &
            sleep 5
            echo \"\"
            echo \"==============================================\"
            echo \"OLLAMA SERVER STARTED\"
            echo \"==============================================\"
            echo \"Dynamic Port: \$OLPORT\"
            echo \"Model: \$DEEPSEEK_MODEL:\$DEEPSEEK_VERSION\"
            echo \"\"
            echo \"To connect from your Mac (with VPN active):\"
            echo "  ssh -L 55088:127.0.0.1:\$OLPORT -i ~/.ssh/id_rsa sweeden@login.hpcc.ttu.edu"
            echo \"\"
            echo \"Then run:\"
            echo \"  ~/ollama-latest/bin/ollama run \$DEEPSEEK_MODEL:\$DEEPSEEK_VERSION\"
            echo \"\"
            echo \"Press Ctrl+C to exit when done.\"
            echo \"==============================================\"
            wait
        '
    "
}

codellama-interactive() {
    # codellama:7b - 7B params, ~3.8GB VRAM - moderate resources
    echo "=============================================="
    echo "Starting interactive codellama session..."
    echo "Model: codellama:7b (~3.8GB VRAM)"
    echo "Resources: 1 GPU, 6 CPUs, 6GB memory"
    echo "=============================================="
    ssh -t sweeden@login.hpcc.ttu.edu "
        interactive -c 6 -g 1 -p matador -t 02:30:00 '
            cd ~/ollama-hpcc
            source scripts/model_versions.env
            export OLPORT=\$(python3 -c \"import socket; s = socket.socket(); s.bind((\\"\\\"\\, 0)); print(s.getsockname()[1]); s.close()\")
            export OLLAMA_HOST=127.0.0.1:\$OLPORT
            export OLLAMA_BASE_URL=http://localhost:\$OLPORT
            module load gcc
            module load cuda/12.9.0
            ~/ollama-latest/bin/ollama serve > ~/ollama-hpcc/running_codellama_\$OLPORT.log 2> ~/ollama-hpcc/running_codellama_\$OLPORT.err &
            sleep 5
            echo \"\"
            echo \"==============================================\"
            echo \"OLLAMA SERVER STARTED\"
            echo \"==============================================\"
            echo \"Dynamic Port: \$OLPORT\"
            echo \"Model: \$CODELLAMA_MODEL:\$CODELLAMA_VERSION\"
            echo \"\"
            echo \"To connect from your Mac (with VPN active):\"
            echo \"  ssh -L 66033:127.0.0.1:\$OLPORT -i ~/.ssh/id_rsa sweeden@login.hpcc.ttu.edu\"
            echo \"\"
            echo \"Then run:\"
            echo \"  ~/ollama-latest/bin/ollama run \$CODELLAMA_MODEL:\$CODELLAMA_VERSION\"
            echo \"\"
            echo \"Press Ctrl+C to exit when done.\"
            echo \"==============================================\"
            wait
        '
    "
}

qwen-interactive() {
    # qwen2.5-coder:7b - 7B params, ~4.7GB VRAM - moderate resources
    echo "=============================================="
    echo "Starting interactive qwen session..."
    echo "Model: qwen2.5-coder:7b (~4.7GB VRAM)"
    echo "Resources: 1 GPU, 6 CPUs, 6GB memory"
    echo "=============================================="
    ssh -t sweeden@login.hpcc.ttu.edu "
        interactive -c 6 -g 1 -p matador -t 02:30:00 '
            cd ~/ollama-hpcc
            source scripts/model_versions.env
            export OLPORT=\$(python3 -c \"import socket; s = socket.socket(); s.bind((\\"\\\"\\, 0)); print(s.getsockname()[1]); s.close()\")
            export OLLAMA_HOST=127.0.0.1:\$OLPORT
            export OLLAMA_BASE_URL=http://localhost:\$OLPORT
            module load gcc
            module load cuda/12.9.0
            ~/ollama-latest/bin/ollama serve > ~/ollama-hpcc/running_qwen_\$OLPORT.log 2> ~/ollama-hpcc/running_qwen_\$OLPORT.err &
            sleep 5
            echo \"\"
            echo \"==============================================\"
            echo \"OLLAMA SERVER STARTED\"
            echo \"==============================================\"
            echo \"Dynamic Port: \$OLPORT\"
            echo \"Model: \$QWENCODER_MODEL:\$QWENCODER_VERSION\"
            echo \"\"
            echo \"To connect from your Mac (with VPN active):\"
            echo \"  ssh -L 66044:127.0.0.1:\$OLPORT -i ~/.ssh/id_rsa sweeden@login.hpcc.ttu.edu\"
            echo \"\"
            echo \"Then run:\"
            echo \"  ~/ollama-latest/bin/ollama run \$QWENCODER_MODEL:\$QWENCODER_VERSION\"
            echo \"\"
            echo \"Press Ctrl+C to exit when done.\"
            echo \"==============================================\"
            wait
        '
    "
}

# Git aliases for HPCC
hpcc-jobs() {
    ssh -q sweeden@login.hpcc.ttu.edu "squeue -u sweeden"
}

hpcc-git-pull() {
    ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && git pull"
}

hpcc-git-add() {
    ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && git add *.err *.out"
}

hpcc-git-commit() {
    ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && git commit -m \"$1\""
}

hpcc-git-push() {
    ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && git push"
}

hpcc-git-status() {
    ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && git status"
}
