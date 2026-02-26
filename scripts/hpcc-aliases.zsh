#!/bin/zsh

# Remove any existing hpcc alias to avoid conflicts
unalias hpcc 2>/dev/null

# Run commands on remote HPCC
hpcc() {
    ssh sweeden@login.hpcc.ttu.edu "$@"
}

# SSH into HPCC login node
hpcc-login() {
    ssh sweeden@login.hpcc.ttu.edu
}

# Model-specific aliases (Debug ports: granite=55077, deepseek=55088, qwen=66044, codellama=66033)
granite() {
    ssh sweeden@login.hpcc.ttu.edu "./ollama-hpcc/scripts/run_granite_ollama.sh ${1:-DEBUG} ${2:-55077}"
}

codellama() {
    ssh sweeden@login.hpcc.ttu.edu "./ollama-hpcc/scripts/run_codellama_ollama.sh ${1:-DEBUG} ${2:-66033}"
}

deepseek() {
    ssh sweeden@login.hpcc.ttu.edu "./ollama-hpcc/scripts/run_deepseek_ollama.sh ${1:-DEBUG} ${2:-55088}"
}

qwen() {
    ssh sweeden@login.hpcc.ttu.edu "./ollama-hpcc/scripts/run_qwen_ollama.sh ${1:-DEBUG} ${2:-66044}"
}
