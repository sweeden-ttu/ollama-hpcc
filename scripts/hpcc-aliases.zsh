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
    ssh -q sweeden@login.hpcc.ttu.edu "sbatch ~/job/slurm_submit_gpu.sh granite"
}

codellama() {
    ssh -q sweeden@login.hpcc.ttu.edu "sbatch ~/job/slurm_submit_gpu.sh codellama"
}

deepseek() {
    ssh -q sweeden@login.hpcc.ttu.edu "sbatch ~/job/slurm_submit_gpu.sh deepseek"
}

qwen() {
    ssh -q sweeden@login.hpcc.ttu.edu "sbatch ~/job/slurm_submit_gpu.sh qwen"
}

# SSH tunnel to Ollama on HPCC
# Usage: hpcc-tunnel PORT [NODE]
#   PORT - remote (and local) port, e.g. from job output
#   NODE - compute node hostname (omit for interactive on login node, use 127.0.0.1)
# Example: hpcc-tunnel 56905 matador07
hpcc-tunnel() {
    local port="${1:?Usage: hpcc-tunnel PORT [NODE]}"
    local node="${2:-127.0.0.1}"
    ssh -q -i ~/.ssh/id_rsa -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -N sweeden@login.hpcc.ttu.edu -L "${port}:${node}:${port}" 
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
  local job_info node port model job_id
  job_info=$(ssh -q sweeden@login.hpcc.ttu.edu 'latest=$(ls -t ~/ollama-logs/*.info 2>/dev/null | head -1); [ -n "$latest" ] && cat "$latest"')

  if [[ -z "$job_info" ]]; then
    # Fallback: running GPU job from ~/job (same as hpcc-tunnel)
    local running_job_id
    running_job_id=$(ssh -q sweeden@login.hpcc.ttu.edu "squeue -u \$USER -h -o '%i %t' 2>/dev/null | awk '\$2==\"R\" {print \$1; exit}'" | tr -d '\r')
    if [[ -n "$running_job_id" ]]; then
      job_info=$(ssh -q sweeden@login.hpcc.ttu.edu "for f in ~/job/*${running_job_id}*.info ~/job/*_${running_job_id}.info; do [ -f \"\$f\" ] && cat \"\$f\" 2>/dev/null && break; done" 2>/dev/null)
      if [[ -z "$job_info" ]]; then
        job_info=$(ssh -q sweeden@login.hpcc.ttu.edu "for f in ~/job/*${running_job_id}*.out ~/job/*${running_job_id}*.err; do [ -f \"\$f\" ] && grep -E '^NODE=|^PORT=|^MODEL=|^JOB_ID=' \"\$f\" 2>/dev/null && break; done" 2>/dev/null)
      fi
    fi
  fi

  node=$(echo "$job_info" | grep '^NODE=' | cut -d= -f2)
  port=$(echo "$job_info" | grep '^PORT=' | cut -d= -f2)
  model=$(echo "$job_info" | grep '^MODEL=' | cut -d= -f2)
  job_id=$(echo "$job_info" | grep '^JOB_ID=' | cut -d= -f2)

  if [[ -z "$node" || -z "$port" ]]; then
    echo "Failed to get job info (checked ~/ollama-logs and ~/job)"
    return 1
  fi

  local env_file="${HOME}/projects/CS5374_Software_VV/project/src/agent/.env"
  mkdir -p "$(dirname "$env_file")"

  cat > "$env_file" <<EOF
OLLAMA_HOST="127.0.0.1:${port}"
OLLAMA_BASE_URL="http://127.0.0.1:${port}"
OLLAMA_MODEL="${model}"
OLLAMA_JOB_ID="${job_id}"
EOF

  echo "Updated $env_file:"
  echo "  OLLAMA_HOST=127.0.0.1:${port}"
  echo "  OLLAMA_BASE_URL=http://127.0.0.1:${port}"
  echo "  OLLAMA_MODEL=${model}"
  echo "  OLLAMA_JOB_ID=${job_id}"
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
# Usage: hpcc-tunnel [MODEL]   e.g. hpcc-tunnel granite4
#        Or: hpcc-tunnel PORT NODE   e.g. hpcc-tunnel 56905 gpu-21-10
# -----------------------------------------------------------------------------
hpcc-tunnel() {
  local model=${1:-granite4}
  local info_file job_info node port

  # If first arg is a number, treat as PORT [NODE]
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    port="$1"
    node="${2:-127.0.0.1}"
    if [[ -z "$port" ]]; then
      echo "Usage: hpcc-tunnel PORT [NODE]  or  hpcc-tunnel [MODEL]"
      return 1
    fi
    echo "=== Creating tunnel (PORT NODE mode) ==="
    echo "Port: $port  Node: $node"
    ssh -L "${port}:${node}:${port}" hpcc-login -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -N -f
    echo "Tunnel started! Test: curl http://localhost:${port}/api/tags"
    return 0
  fi

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
  
  # Find latest info file: ~/ollama-logs (model name) or ~/job (running GPU job by id)
  info_file=$(ssh -q sweeden@login.hpcc.ttu.edu "ls -t ~/ollama-logs/${model}*.info 2>/dev/null | head -1")
  job_info=""

  if [[ -n "$info_file" ]]; then
    job_info=$(ssh -q sweeden@login.hpcc.ttu.edu "cat $info_file" 2>/dev/null)
  else
    # Fallback: get running job id and look in ~/job
    local running_job_id
    running_job_id=$(ssh -q sweeden@login.hpcc.ttu.edu "squeue -u \$USER -h -o '%i %t' 2>/dev/null | awk '\$2==\"R\" {print \$1; exit}'" | tr -d '\r')
    if [[ -n "$running_job_id" ]]; then
      job_info=$(ssh -q sweeden@login.hpcc.ttu.edu "for f in ~/job/*${running_job_id}*.info ~/job/*_${running_job_id}.info; do [ -f \"\$f\" ] && cat \"\$f\" 2>/dev/null && break; done" 2>/dev/null)
      if [[ -z "$job_info" ]]; then
        job_info=$(ssh -q sweeden@login.hpcc.ttu.edu "for f in ~/job/*${running_job_id}*.out ~/job/*${running_job_id}*.err; do [ -f \"\$f\" ] && grep -E '^NODE=|^PORT=' \"\$f\" 2>/dev/null && break; done" 2>/dev/null)
      fi
    fi
  fi

  node=$(echo "$job_info" | grep '^NODE=' | cut -d= -f2)
  port=$(echo "$job_info" | grep '^PORT=' | cut -d= -f2)

  if [[ -z "$node" || -z "$port" ]]; then
    echo "No NODE/PORT found for model: $model (checked ~/ollama-logs and ~/job for running job)"
    echo "Usage: hpcc-tunnel [MODEL]  or  hpcc-tunnel PORT NODE"
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
  echo "Test: curl http://127.0.0.1:${port}/api/tags"
  echo ""
  echo "If you get 'Connection reset by peer': on the compute node Ollama must listen on 0.0.0.0 (not 127.0.0.1)."
  echo "In your ~/job script set: OLLAMA_HOST=0.0.0.0:${port}  before starting ollama serve"
}

# -----------------------------------------------------------------------------
# Repo update on HPCC
# -----------------------------------------------------------------------------
hpcc-git-pull() {
  ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && git pull'
}

# -----------------------------------------------------------------------------
# Batch job submission (model-specific) — uses job/slurm_submit_gpu.sh
# -----------------------------------------------------------------------------
granite() {
  ssh -q sweeden@login.hpcc.ttu.edu 'sbatch ~/job/slurm_submit_gpu.sh granite'
}
deepseek() {
  ssh -q sweeden@login.hpcc.ttu.edu 'sbatch ~/job/slurm_submit_gpu.sh deepseek'
}
codellama() {
  ssh -q sweeden@login.hpcc.ttu.edu 'sbatch ~/job/slurm_submit_gpu.sh codellama'
}
qwen() {
  ssh -q sweeden@login.hpcc.ttu.edu 'sbatch ~/job/slurm_submit_gpu.sh qwen'
}

# -----------------------------------------------------------------------------
# Wait for job to start and show connection info
# Usage: hpcc-wait-for-job [job-id]
#   OR: hpcc-wait-for-job [model-name] (submits job first; use granite|deepseek|codellama|qwen)
# -----------------------------------------------------------------------------
hpcc-wait-for-job() {
  # Use array so zsh invokes ssh correctly (zsh doesn't word-split unquoted vars like bash)
  local -a HPCC_SSH=(ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu)
  local job_id model_name

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
    # Check if a GPU job is already running before submitting (use ~/job/slurm_submit_gpu.sh)
    local running_job
    running_job=$("${HPCC_SSH[@]}" "squeue -u \$USER -h -o '%i %t' 2>/dev/null | awk '\$2==\"R\" {print \$1; exit}'" | tr -d '\r')
    if [[ -n "$running_job" && "$running_job" =~ ^[0-9]+$ ]]; then
      echo "Job $running_job is already RUNNING; using it (no sbatch)."
      job_id="$running_job"
    else
      echo "Submitting $model_name job via ~/job/slurm_submit_gpu.sh..."
      job_id=$("${HPCC_SSH[@]}" "sbatch ~/job/slurm_submit_gpu.sh $model_name" | awk '{print $NF}')
      if [[ -z "$job_id" || ! "$job_id" =~ ^[0-9]+$ ]]; then
        echo "Failed to get job ID from sbatch output"
        return 1
      fi
      echo "Submitted job: $job_id"
    fi
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
  # Info files: ~/ollama-logs (MODEL_JOBID.info) or ~/job for GPU jobs
  local conn_info=$("${HPCC_SSH[@]}" "grep -E '^NODE=|^PORT=' ~/ollama-logs/*${job_id}*.info 2>/dev/null" || echo "")

  if [[ -z "$conn_info" ]]; then
    conn_info=$("${HPCC_SSH[@]}" "grep -E '^NODE=|^PORT=' ~/ollama-logs/*_${job_id}.info 2>/dev/null" || echo "")
  fi
  if [[ -z "$conn_info" ]]; then
    conn_info=$("${HPCC_SSH[@]}" "for f in ~/job/*${job_id}*.info ~/job/*_${job_id}.info; do [ -f \"\$f\" ] && grep -E '^NODE=|^PORT=' \"\$f\" 2>/dev/null && break; done" || echo "")
  fi
  if [[ -z "$conn_info" ]]; then
    conn_info=$("${HPCC_SSH[@]}" "for f in ~/job/*${job_id}*.out ~/job/*${job_id}*.err; do [ -f \"\$f\" ] && grep -E '^NODE=|^PORT=' \"\$f\" 2>/dev/null && break; done" || echo "")
  fi

  if [[ -n "$conn_info" ]]; then
    echo "$conn_info"
  else
    echo "(No NODE/PORT found for job $job_id in ~/ollama-logs or ~/job; check hpcc-jobs and job output)"
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
