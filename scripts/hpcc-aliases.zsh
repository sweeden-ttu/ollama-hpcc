#!/bin/zsh

# Remove any existing hpcc alias to avoid conflicts
unalias hpcc 2>/dev/null

# =============================================================================
# hpcc-wait-for-job granite → get PORT and NODE
# hpcc-tunnel <PORT> <NODE> (or hpcc-tunnel-jump <PORT> <NODE> then hpcc-tunnel <PORT> 127.0.0.1)
# hpcc-env → sets OLLAMA_HOST etc. in the current shell
#ollama list and ollama run $OLLAMA_MODEL
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
  ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu "squeue -u \$USER"
  echo ""
  echo "=== Latest Ollama job info (if any) ==="
  ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu 'ls -la ~/ollama-logs/*.info 2>/dev/null || echo "No job info files found"' 
}

hpcc-latest-log() {
  local job_status
  job_status=$(ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu "squeue -u \$USER -o '%T' -h | head -1")
  job_status=$(echo "$job_status" | tr -d '\r\n' | xargs)
  if [[ "$job_status" != "RUNNING" ]]; then
    echo "Job status: $job_status (not RUNNING)"
    echo "Run 'hpcc-info' to check queue status"
    return 1
  fi
  local latest_content
  latest_content=$(ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu 'latest=$(ls -t ~/ollama-logs/*.info 2>/dev/null | head -1); [ -n "$latest" ] && cat "$latest"')
  if [[ -n "$latest_content" ]]; then
    echo "$latest_content" | tail -20
  else
    echo "No job info found in ~/ollama-logs/"
    return 1
  fi
}

# Set OLLAMA_* in current shell from latest running job .info (run after tunnel is up: hpcc-tunnel PORT NODE)
# Use: hpcc-env    or  eval $(hpcc-env -p)   to set OLLAMA_HOST, OLLAMA_BASE_URL, OLLAMA_MODEL in current shell
hpcc-env() {
  local job_info node port model job_id
  local do_print=
  [[ "$1" == "-p" ]] && do_print=1
  job_info=$(ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu 'latest=$(ls -t ~/ollama-logs/*.info 2>/dev/null | head -1); [ -n "$latest" ] && cat "$latest"')
  if [[ -z "$job_info" ]]; then
    echo "No job info found in ~/ollama-logs/. Run hpcc-wait-for-job first, then hpcc-tunnel PORT NODE."
    return 1
  fi
  node=$(echo "$job_info" | grep '^NODE=' | cut -d= -f2- | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  port=$(echo "$job_info" | grep '^PORT=' | cut -d= -f2- | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  model=$(echo "$job_info" | grep '^MODEL=' | cut -d= -f2- | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  job_id=$(echo "$job_info" | grep '^JOB_ID=' | cut -d= -f2- | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [[ -z "$model" ]]; then
    model=$(echo "$job_info" | grep -oE 'Starting [a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+' | head -1 | sed 's/^Starting //')
    model=$(echo "$model" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  fi
  if [[ -z "$port" ]]; then
    echo "Could not get PORT from ~/ollama-logs/*.info"
    return 1
  fi
  export OLLAMA_HOST="127.0.0.1:${port}"
  export OLLAMA_BASE_URL="http://127.0.0.1:${port}"
  [[ -n "$model" ]] && export OLLAMA_MODEL="$model"
  [[ -n "$job_id" ]] && export OLLAMA_JOB_ID="$job_id"
  if [[ -n "$do_print" ]]; then
    echo "export OLLAMA_HOST=\"127.0.0.1:${port}\""
    echo "export OLLAMA_BASE_URL=\"http://127.0.0.1:${port}\""
    [[ -n "$model" ]] && echo "export OLLAMA_MODEL=\"${model}\""
    [[ -n "$job_id" ]] && echo "export OLLAMA_JOB_ID=\"${job_id}\""
    return 0
  fi
  echo "OLLAMA_HOST=$OLLAMA_HOST"
  echo "OLLAMA_BASE_URL=$OLLAMA_BASE_URL"
  [[ -n "$OLLAMA_MODEL" ]] && echo "OLLAMA_MODEL=$OLLAMA_MODEL"
  echo "Tunnel must be open: hpcc-tunnel $port $node"
  echo "Then run: ollama list   or   ollama run \$OLLAMA_MODEL"
}

hpcc-update-env() {
  local job_info node port model job_id
  job_info=$(ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu 'latest=$(ls -t ~/ollama-logs/*.info 2>/dev/null | head -1); [ -n "$latest" ] && cat "$latest"')

  if [[ -z "$job_info" ]]; then
    echo "No job info found in ~/ollama-logs/"
    return 1
  fi

  node=$(echo "$job_info" | grep '^NODE=' | cut -d= -f2)
  port=$(echo "$job_info" | grep '^PORT=' | cut -d= -f2)
  model=$(echo "$job_info" | grep '^MODEL=' | cut -d= -f2)
  job_id=$(echo "$job_info" | grep '^JOB_ID=' | cut -d= -f2)
  # Fallback: infer model from "Starting model:tag" line in job log
  if [[ -z "$model" ]]; then
    model=$(echo "$job_info" | grep -oE 'Starting [a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+' | head -1 | sed 's/^Starting //')
  fi

  if [[ -z "$node" || -z "$port" ]]; then
    echo "Failed to get NODE/PORT from ~/ollama-logs/ (check latest .info file)"
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

  # Run ollama with the tunnel (ensure tunnel is open: hpcc-tunnel)
  if [[ -n "$model" ]]; then
    echo ""
    echo "Running: OLLAMA_HOST=127.0.0.1:${port} ollama run ${model}"
    OLLAMA_HOST="127.0.0.1:${port}" ollama run "${model}"
  else
    echo ""
    echo "OLLAMA_MODEL not in job info. Run manually:"
    echo "  OLLAMA_HOST=127.0.0.1:${port} ollama run <model>"
  fi
}

# -----------------------------------------------------------------------------
# Job queue and control
# -----------------------------------------------------------------------------
hpcc-status() {
  ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu "squeue -u \$USER"
}
alias hpcc-jobs='hpcc-status'

# scontrol on login node — use for queued/running job details
# "show jobs" is limited to user sweeden. Examples: hpcc-scontrol show job 40249   hpcc-scontrol show jobs
hpcc-scontrol() {
  if [[ "$1" == "show" && "$2" == "jobs" ]]; then
    ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu "scontrol show jobs -u sweeden"
  else
    ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu "scontrol $@"
  fi
}
alias hpcc-queue='hpcc-scontrol show jobs'

hpcc-kill() {
  if [[ -z "$1" ]]; then
    echo "Usage: hpcc-kill JOBID"
    return 1
  fi
  ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu "scancel $1"
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
    ssh -q -i /Users/owner/.ssh/id_rsa -L "${port}:${node}:${port}" -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -N -f sweeden@login.hpcc.ttu.edu
    echo "Tunnel started! Run: hpcc-env   then   ollama list"
    return 0
  fi

  # Check job status first
  local job_status
  job_status=$(ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu "squeue -u \$USER -o '%T' -h" 2>/dev/null | head -1)
  job_status=$(echo "$job_status" | tr -d '\r\n' | xargs)
  
  if [[ "$job_status" != "RUNNING" ]]; then
    echo "Job status: $job_status (not RUNNING)"
    echo "Run 'hpcc-info' to check queue status"
    echo "Usage: hpcc-tunnel [MODEL]"
    echo "Example: hpcc-tunnel granite4:3b"
    return 1
  fi
  
  # Use info from ~/ollama-logs/ on the host (model-specific or latest)
  info_file=$(ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu "ls -t ~/ollama-logs/${model}*.info 2>/dev/null | head -1")
  if [[ -z "$info_file" ]]; then
    info_file=$(ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu "ls -t ~/ollama-logs/*.info 2>/dev/null | head -1")
  fi
  local job_info=""
  if [[ -n "$info_file" ]]; then
    job_info=$(ssh -q -i /Users/owner/.ssh/id_rsa sweeden@login.hpcc.ttu.edu "cat $info_file" 2>/dev/null)
  fi

  node=$(echo "$job_info" | grep '^NODE=' | cut -d= -f2)
  port=$(echo "$job_info" | grep '^PORT=' | cut -d= -f2)

  if [[ -z "$node" || -z "$port" ]]; then
    echo "No NODE/PORT found in ~/ollama-logs/ for model: $model"
    echo "Usage: hpcc-tunnel [MODEL]  or  hpcc-tunnel PORT NODE"
    return 1
  fi
  
  echo "=== Creating tunnel ==="
  echo "Model: $model"
  echo "Node: $node"
  echo "Port: $port"
  echo "Command: ssh -L ${port}:${node}:${port} sweeden@login.hpcc.ttu.edu -N -f"
  echo "========================"
  
  ssh -q -i /Users/owner/.ssh/id_rsa -L "${port}:${node}:${port}" -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -N -f sweeden@login.hpcc.ttu.edu

  echo "Tunnel started!"
  echo "Test: curl http://127.0.0.1:${port}/api/tags"
  echo "Set env and use ollama:  hpcc-env   then   ollama list"
  echo ""
  echo "If you get 'Connection reset by peer': on the compute node Ollama must listen on 0.0.0.0 (not 127.0.0.1)."
  echo "In your ~/job script set: OLLAMA_HOST=0.0.0.0:${port}  before starting ollama serve"
}

# -----------------------------------------------------------------------------
# Second hop: from login node to compute node (run after hpcc-tunnel-jump from Mac to establish login->node forward, then hpcc-tunnel PORT 127.0.0.1 to reach it from Mac)
# Usage: hpcc-tunnel-jump PORT NODE
# -----------------------------------------------------------------------------
hpcc-tunnel-jump() {
  local port="${1:?Usage: hpcc-tunnel-jump PORT NODE}"
  local node="${2:?Usage: hpcc-tunnel-jump PORT NODE}"
  ssh -q -i /Users/owner/.ssh/id_rsa -o ConnectTimeout=15 sweeden@login.hpcc.ttu.edu "ssh -o ConnectTimeout=10 -o BatchMode=yes -L ${port}:localhost:${port} ${node} -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -N -f"
  echo "Jump tunnel started (login -> $node:$port). From Mac run: hpcc-tunnel $port 127.0.0.1"
  echo "Then: hpcc-env   and   ollama list"
}

# -----------------------------------------------------------------------------
# Repo update on HPCC
# -----------------------------------------------------------------------------
hpcc-git-pull() {
  ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && git pull'
}
hpcc-git-add() {
  ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && git add ollama-*.o* ollama-*.e* 2>/dev/null; true'
}
hpcc-git-commit() {
  ssh -q sweeden@login.hpcc.ttu.edu "cd ~/ollama-hpcc && git commit -m \"$1\""
}
hpcc-git-push() {
  ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && git push'
}
hpcc-git-status() {
  ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && git status'
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

# Interactive model sessions (salloc + srun on GPU node)
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
    job_state=$(echo "$job_state" | tr -d '\r\n' | xargs)

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

  # Map short model name to .info filename prefix (MODEL_NAME on HPCC)
  local model_prefix="$model_name"
  case "$model_name" in
    granite) model_prefix="granite4" ;;
    deepseek) model_prefix="deepseek-r1" ;;
    qwen) model_prefix="qwen2.5-coder" ;;
    codellama) model_prefix="codellama" ;;
  esac

  # Poll for .info file (job script writes it after ollama serve is ready), up to 30s
  echo "Waiting for connection info..."
  local conn_info=""
  local out_content=""
  for _ in {1..30}; do
    conn_info=$("${HPCC_SSH[@]}" "grep -E '^NODE=|^PORT=' ~/ollama-logs/${model_prefix}_${job_id}.info 2>/dev/null" | tr -d '\r')
    if [[ -n "$conn_info" ]]; then
      break
    fi
    conn_info=$("${HPCC_SSH[@]}" "grep -E '^NODE=|^PORT=' ~/ollama-logs/*_${job_id}.info 2>/dev/null" | tr -d '\r')
    if [[ -n "$conn_info" ]]; then
      break
    fi
    # Fallback: parse NODE/PORT from Slurm .out file
    out_content=$("${HPCC_SSH[@]}" "cat ~/job/${job_id}_*.out 2>/dev/null" | tr -d '\r')
    if [[ -n "$out_content" ]]; then
      conn_info=$(echo "$out_content" | grep -E '^NODE=|^PORT=')
      if [[ -n "$conn_info" ]]; then
        break
      fi
    fi
    sleep 1
  done

  echo ""
  echo "=== Connection Info ==="
  if [[ -n "$conn_info" ]]; then
    echo "$conn_info"
  else
    echo "(No NODE/PORT found for job $job_id in ~/ollama-logs/ or ~/job/*.out)"
  fi

  local node=$(echo "$conn_info" | grep '^NODE=' | cut -d= -f2)
  local port=$(echo "$conn_info" | grep '^PORT=' | cut -d= -f2)

  if [[ -n "$node" && -n "$port" ]]; then
    echo ""
    echo "=== Next step: create tunnel (from your Mac) ==="
    echo "  hpcc-tunnel $port $node"
    echo ""
    echo "Then use Ollama locally:"
    echo "  OLLAMA_HOST=127.0.0.1:$port ollama list"
    echo "  OLLAMA_HOST=127.0.0.1:$port ollama run <model>"
  fi
}
