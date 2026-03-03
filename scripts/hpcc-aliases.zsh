# =============================================================================
# hpcc-aliases.zsh — HPCC / RedRaider client aliases and functions
# Source from ~/.zshrc:  [ -f ~/ollama-hpcc/scripts/hpcc-aliases.zsh ] && source ~/ollama-hpcc/scripts/hpcc-aliases.zsh
# Specs: README.md, PIPELINE.md, OpenMPI.md, OLLAMA.md
# =============================================================================

# -----------------------------------------------------------------------------
# Connection
# -----------------------------------------------------------------------------
alias hpcc='ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu'
alias hpcc-login='ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu'

# -----------------------------------------------------------------------------
# Environment introspection (node, ollama_host, ollama_base_url, model, port)
# -----------------------------------------------------------------------------
hpcc-info() {
  ssh -q sweeden@login.hpcc.ttu.edu "squeue -u \$USER"
  echo ""
  echo "=== Latest Ollama job info (if any) ==="
  ssh -q sweeden@login.hpcc.ttu.edu 'ls -la ~/ollama-logs/*.info 2>/dev/null || echo "No job info files found"' 
}

hpcc-latest-log() {
  local job_status
  job_status=$(ssh -q sweeden@login.hpcc.ttu.edu "squeue -u \$USER -o '%T' -h | head -1")
  if [[ "$job_status" != "RUNNING" ]]; then
    echo "Job status: $job_status (not RUNNING)"
    echo "Run 'hpcc-info' to check queue status"
    return 1
  fi
  ssh -q sweeden@login.hpcc.ttu.edu 'latest=$(ls -t ~/ollama-logs/*.info | head -1) && tail -20 "$latest"'
}

hpcc-update-env() {
  local job_info node port model
  job_info=$(ssh -q sweeden@login.hpcc.ttu.edu 'latest=$(ls -t ~/ollama-logs/*.info | head -1) && cat "$latest"')
  
  node=$(echo "$job_info" | grep '^NODE=' | cut -d= -f2)
  port=$(echo "$job_info" | grep '^PORT=' | cut -d= -f2)
  model=$(echo "$job_info" | grep '^MODEL=' | cut -d= -f2)
  
  if [[ -z "$node" || -z "$port" ]]; then
    echo "Failed to get job info"
    return 1
  fi
  
  local env_file="${HOME}/projects/CS5374_Software_VV/project/src/agent/.env"
  
  cat > "$env_file" <<EOF
OLLAMA_HOST="127.0.0.1:${port}"
OLLAMA_BASE_URL="http://127.0.0.1:${port}"
OLLAMA_MODEL="${model}"
OLLAMA_JOB_ID="$(echo "$job_info" | grep '^JOB_ID=' | cut -d= -f2)"
EOF
  
  echo "Updated $env_file:"
  echo "  OLLAMA_HOST=127.0.0.1:${port}"
  echo "  OLLAMA_BASE_URL=http://127.0.0.1:${port}"
  echo "  OLLAMA_MODEL=${model}"
}

# -----------------------------------------------------------------------------
# Job queue and control
# -----------------------------------------------------------------------------
hpcc-status() {
  ssh -q sweeden@login.hpcc.ttu.edu "squeue -u \$USER"
}
alias hpcc-jobs='hpcc-status'

hpcc-kill() {
  if [[ -z "$1" ]]; then
    echo "Usage: hpcc-kill JOBID"
    return 1
  fi
  ssh -q sweeden@login.hpcc.ttu.edu "scancel $1"
}

# -----------------------------------------------------------------------------
# Tunnels — auto-detect running Ollama job and create tunnel
# Usage: hpcc-tunnel [MODEL]   e.g. hpcc-tunnel granite4:3b
#        If no model passed, defaults to granite4
# -----------------------------------------------------------------------------
hpcc-tunnel() {
  local model=${1:-granite4}
  local info_file job_info node port
  
  # Check job status first
  local job_status
  job_status=$(ssh -q sweeden@login.hpcc.ttu.edu "squeue -u \$USER -o '%T' -h" 2>/dev/null | head -1)
  
  if [[ "$job_status" != "RUNNING" ]]; then
    echo "Job status: $job_status (not RUNNING)"
    echo "Run 'hpcc-info' to check queue status"
    echo "Usage: hpcc-tunnel [MODEL]"
    echo "Example: hpcc-tunnel granite4:3b"
    return 1
  fi
  
  # Find latest info file matching the model
  info_file=$(ssh -q sweeden@login.hpcc.ttu.edu "ls -t ~/ollama-logs/${model}*.info 2>/dev/null | head -1")
  
  if [[ -z "$info_file" ]]; then
    echo "No info file found for model: $model"
    echo "Available models: granite4, deepseek-coder, codellama, qwen"
    echo "Usage: hpcc-tunnel [MODEL]"
    return 1
  fi
  
  # Get job info
  job_info=$(ssh -q sweeden@login.hpcc.ttu.edu "cat $info_file" 2>/dev/null)
  
  node=$(echo "$job_info" | grep '^NODE=' | cut -d= -f2)
  port=$(echo "$job_info" | grep '^PORT=' | cut -d= -f2)
  
  if [[ -z "$node" || -z "$port" ]]; then
    echo "Failed to parse NODE/PORT from $info_file"
    echo "Raw output: $job_info"
    return 1
  fi
  
  echo "=== Creating tunnel ==="
  echo "Model: $model"
  echo "Node: $node"
  echo "Port: $port"
  echo "Command: ssh -L ${port}:${node}:${port} hpcc-login -N -f"
  echo "========================"
  
  ssh -L "${port}:${node}:${port}" hpcc-login -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -N -f
  
  echo "Tunnel started!"
  echo "Test: curl http://localhost:${port}/api/tags"
}

# -----------------------------------------------------------------------------
# Repo update on HPCC
# -----------------------------------------------------------------------------
hpcc-git-pull() {
  ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && git pull'
}

# -----------------------------------------------------------------------------
# Batch job submission (model-specific)
# -----------------------------------------------------------------------------
granite() {
  ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && sbatch scripts/run_granite_ollama.sh'
}
deepseek() {
  ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && sbatch scripts/run_deepseek_ollama.sh'
}
codellama() {
  ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && sbatch scripts/run_codellama_ollama.sh'
}
qwen() {
  ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && sbatch scripts/run_qwen-coder_ollama.sh'
}

# -----------------------------------------------------------------------------
# Interactive GPU session (Matador: 8 CPUs, 1 GPU). Once on the node run:
#   ~/ollama-hpcc/scripts/interactive_ollama.sh granite
# (or deepseek, codellama, qwen)
# -----------------------------------------------------------------------------
alias granite-interactive="ssh -q -t sweeden@login.hpcc.ttu.edu '/etc/slurm/scripts/interactive -c 8 -g 1 -p matador'"
alias deepseek-interactive="ssh -q -t sweeden@login.hpcc.ttu.edu '/etc/slurm/scripts/interactive -c 8 -g 1 -p matador'"
alias codellama-interactive="ssh -q -t sweeden@login.hpcc.ttu.edu '/etc/slurm/scripts/interactive -c 8 -g 1 -p matador'"
alias qwen-interactive="ssh -q -t sweeden@login.hpcc.ttu.edu '/etc/slurm/scripts/interactive -c 8 -g 1 -p matador'"
