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

# Submit batch jobs - uses dynamic ports (sbatch on HPCC)
granite() {
    ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && sbatch scripts/run_granite_ollama.sh"
}

codellama() {
    ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && sbatch scripts/run_codellama_ollama.sh"
}

deepseek() {
    ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && sbatch scripts/run_deepseek_ollama.sh"
}

qwen() {
    ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && sbatch scripts/run_qwen-coder_ollama.sh"
}

# SSH tunnel to Ollama on HPCC
# Usage: hpcc-tunnel PORT [NODE]
#   PORT - remote (and local) port, e.g. from job output
#   NODE - compute node hostname (omit for interactive on login node, use 127.0.0.1)
# Example: hpcc-tunnel 56905 matador07
hpcc-tunnel() {
    local port="${1:?Usage: hpcc-tunnel PORT [NODE]}"
    local node="${2:-127.0.0.1}"
    ssh -i ~/.ssh/id_rsa -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -N sweeden@login.hpcc.ttu.edu -L "${port}:${node}:${port}" 
}

# Interactive model sessions - use salloc + srun to allocate GPU node and run ollama
granite-interactive() {
    ssh -t -q sweeden@login.hpcc.ttu.edu "salloc --nodes=1 --ntasks=1 --cpus-per-task=4 --gpus=1 --partition=matador --time=02:30:00 srun --preserve-env --pty bash -lc '~/ollama-hpcc/scripts/interactive_ollama.sh granite'"
}

deepseek-interactive() {
    ssh -t -q sweeden@login.hpcc.ttu.edu "salloc --nodes=1 --ntasks=1 --cpus-per-task=8 --gpus=1 --partition=matador --time=02:30:00 srun --preserve-env --pty bash -lc '~/ollama-hpcc/scripts/interactive_ollama.sh deepseek'"
}

codellama-interactive() {
    ssh -t -q sweeden@login.hpcc.ttu.edu "salloc --nodes=1 --ntasks=1 --cpus-per-task=6 --gpus=1 --partition=matador --time=02:30:00 srun --preserve-env --pty bash -lc '~/ollama-hpcc/scripts/interactive_ollama.sh codellama'"
}

qwen-interactive() {
    ssh -t -q sweeden@login.hpcc.ttu.edu "salloc --nodes=1 --ntasks=1 --cpus-per-task=6 --gpus=1 --partition=matador --time=02:30:00 srun --preserve-env --pty bash -lc '~/ollama-hpcc/scripts/interactive_ollama.sh qwen'"
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
