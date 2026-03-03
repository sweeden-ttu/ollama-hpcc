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
    ssh -q sweeden@login.hpcc.ttu.edu "sbatch ~/job/slurm_submit.sh granite"
}

codellama() {
    ssh -q sweeden@login.hpcc.ttu.edu "sbatch ~/job/slurm_submit.sh codellama"
}

deepseek() {
    ssh -q sweeden@login.hpcc.ttu.edu "sbatch ~/job/slurm_submit.sh deepseek"
}

qwen() {
    ssh -q sweeden@login.hpcc.ttu.edu "sbatch ~/job/slurm_submit.sh qwen"
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
# Batch job submission (model-specific) — uses job/slurm_submit.sh
# -----------------------------------------------------------------------------
granite() {
  ssh -q sweeden@login.hpcc.ttu.edu 'sbatch ~/job/slurm_submit.sh granite'
}
deepseek() {
  ssh -q sweeden@login.hpcc.ttu.edu 'sbatch ~/job/slurm_submit.sh deepseek'
}
codellama() {
  ssh -q sweeden@login.hpcc.ttu.edu 'sbatch ~/job/slurm_submit.sh codellama'
}
qwen() {
  ssh -q sweeden@login.hpcc.ttu.edu 'sbatch ~/job/slurm_submit.sh qwen'
}

# -----------------------------------------------------------------------------
# Wait for job to start and show connection info
# Usage: hpcc-wait-for-job [job-id]
#   OR: hpcc-wait-for-job [model-name] (submits job first; use granite|deepseek|codellama|qwen)
# -----------------------------------------------------------------------------
hpcc-wait-for-job() {
  local HPCC_SSH="ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu"
  local job_id model_name
  
  # Use array so zsh invokes ssh correctly (zsh doesn't word-split unquoted vars like bash)
  local -a HPCC_SSH=(ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu)
  local job_id model_name script_name

  # Map friendly model name to script filename (qwen -> qwen-coder)
  case "$1" in
    granite|deepseek|codellama) script_name="$1" ;;
    qwen) script_name="qwen-coder" ;;
    *) script_name="$1" ;;
  esac

  if [[ -z "$1" ]]; then
    echo "Usage: hpcc-wait-for-job <job-id> OR <model-name>"
    echo "  model-name: granite, deepseek, codellama, qwen"
    return 1
  fi

  if [[ "$1" =~ ^[0-9]+$ ]]; then
    job_id="$1"
    model_name="${2:-granite}"
  else
    model_name="$1"
    echo "Submitting $model_name job..."
    job_id=$($HPCC_SSH "sbatch ~/job/slurm_submit.sh $model_name" | grep -oP '\d+')
    # Portable job ID extraction (macOS grep has no -P; sbatch prints "Submitted batch job 12345")
    job_id=$("${HPCC_SSH[@]}" "cd ~/ollama-hpcc && sbatch scripts/run_${script_name}_ollama.sh" | awk '{print $NF}')
    if [[ -z "$job_id" || ! "$job_id" =~ ^[0-9]+$ ]]; then
      echo "Failed to get job ID from sbatch output"
      return 1
    fi
    echo "Submitted job: $job_id"
  fi

  echo "Waiting for job $job_id to start..."

  while true; do
    local job_state
    job_state=$("${HPCC_SSH[@]}" "squeue -j $job_id -o %t -h" 2>/dev/null || echo "UNKNOWN")

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

  # Give the job script time to write the .info file (OLLAMA_LOG_DIR on compute node)
  sleep 5

  echo ""
  echo "=== Connection Info ==="
  local conn_info=$($HPCC_SSH "grep -E 'NODE=|PORT=|TUNNEL_FROM_MAC=' ~/*${job_id}*.out ~/ollama-hpcc/*${job_id}*.out 2>/dev/null" || echo "")
  
  # Info files live in ~/ollama-logs as MODEL_JOBID.info (e.g. granite4_12345.info)
  local conn_info=$("${HPCC_SSH[@]}" "grep -E '^NODE=|^PORT=' ~/ollama-logs/*${job_id}*.info 2>/dev/null" || echo "")

  if [[ -z "$conn_info" ]]; then
    conn_info=$("${HPCC_SSH[@]}" "grep -E '^NODE=|^PORT=' ~/ollama-logs/*_${job_id}.info 2>/dev/null" || echo "")
  fi

  if [[ -n "$conn_info" ]]; then
    echo "$conn_info"
  else
    echo "(No .info file found for job $job_id in ~/ollama-logs yet; try again in a few seconds)"
  fi

  local node=$(echo "$conn_info" | grep '^NODE=' | cut -d= -f2)
  local port=$(echo "$conn_info" | grep '^PORT=' | cut -d= -f2)

  if [[ -n "$node" && -n "$port" ]]; then
    echo ""
    echo "=== SSH Tunnel Command ==="
    echo "ssh -L ${port}:${node}:${port} sweeden@login.hpcc.ttu.edu -N"
    echo ""
    echo "=== Connect Locally ==="
    echo "OLLAMA_HOST=127.0.0.1:${port} ollama list"
    echo "OLLAMA_HOST=127.0.0.1:${port} ollama run <model>"
  fi
}
