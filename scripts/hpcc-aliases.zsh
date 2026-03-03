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

# Add SLURM job output/error files (guide format: %x.o%j / %x.e%j → jobname.oJOBID, jobname.eJOBID)
hpcc-git-add() {
    ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && git add ollama-*.o* ollama-*.e* 2>/dev/null; true"
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


# Wait for job to start and show connection info
# Usage: hpcc-wait-for-job [job-id]
#   OR: hpcc-wait-for-job [model-name] (submits job first)
hpcc-wait-for-job() {
  local HPCC_SSH="ssh -q sweeden@login.hpcc.ttu.edu"
  local job_id model_name
  
  if [[ -z "$1" ]]; then
    echo "Usage: hpcc-wait-for-job <job-id> OR <model-name>"
    return 1
  fi
  
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    job_id="$1"
    model_name="${2:-granite}"
  else
    model_name="$1"
    echo "Submitting $model_name job..."
    job_id=$($HPCC_SSH "cd ~/ollama-hpcc && sbatch scripts/run_${model_name}_ollama.sh" | grep -oP '\d+')
    echo "Submitted job: $job_id"
  fi
  
  echo "Waiting for job $job_id to start..."
  
  while true; do
    local job_state
    job_state=$($HPCC_SSH "squeue -j $job_id -o %t -h" 2>/dev/null || echo "UNKNOWN")
    
    if [[ "$job_state" == "R" ]]; then
      echo "Job is RUNNING!"
      break
    elif [[ "$job_state" == "PD" ]]; then
      echo "Job is PENDING..."
    else
      echo "Job status: $job_state"
    fi
    
    sleep 60
  done
  
  sleep 5
  
  echo ""
  echo "=== Connection Info ==="
  local conn_info=$($HPCC_SSH "grep -E 'NODE=|PORT=|TUNNEL_FROM_MAC=' ~/ollama-hpcc/*${job_id}*.out 2>/dev/null" || echo "")
  
  if [[ -n "$conn_info" ]]; then
    echo "$conn_info"
  else
    conn_info=$($HPCC_SSH "grep -E 'NODE=|PORT=' ~/ollama-hpcc/logs/*${job_id}*.info 2>/dev/null" || echo "")
    echo "$conn_info"
  fi
  
  local node=$(echo "$conn_info" | grep '^NODE=' | cut -d= -f2)
  local port=$(echo "$conn_info" | grep '^PORT=' | cut -d= -f2)
  
  if [[ -n "$node" && -n "$port" ]]; then
    echo ""
    echo "=== SSH Tunnel Command ==="
    echo "ssh -L ${port}:${node}:${port} sweeden@login.hpcc.ttu.edu"
    echo ""
    echo "=== Connect Locally ==="
    echo "OLLAMA_HOST=127.0.0.1:${port} ollama list"
    echo "OLLAMA_HOST=127.0.0.1:${port} ollama run ${model_name}"
  fi
}
