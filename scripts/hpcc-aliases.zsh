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
