#!/bin/bash
# =============================================================================
# ollama_health_check.sh
# Utility: Check the health and status of all running OLLAMA servers
# discovered via *.info files written by each SLURM job.
#
# Usage:  bash ollama_health_check.sh [--json]
#   --json   Output machine-readable JSON instead of human-readable table
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/model_versions.env"

JSON_MODE=0
[[ "${1}" == "--json" ]] && JSON_MODE=1

info_files=("${OLLAMA_LOG_DIR}"/*.info)

if [[ ! -e "${info_files[0]}" ]]; then
    echo "No running OLLAMA servers found in ${OLLAMA_LOG_DIR}"
    exit 0
fi

if [[ ${JSON_MODE} -eq 0 ]]; then
    printf "\n%-20s %-15s %-10s %-35s %-10s\n" \
        "MODEL" "NODE" "PORT" "OLLAMA_BASE_URL" "STATUS"
    printf "%-20s %-15s %-10s %-35s %-10s\n" \
        "--------------------" "---------------" "----------" \
        "-----------------------------------" "----------"
fi

[[ ${JSON_MODE} -eq 1 ]] && echo "["

first=1
for info in "${OLLAMA_LOG_DIR}"/*.info; do
    [[ -f "${info}" ]] || continue

    # Parse info file
    job_id=$(grep '^JOB_ID=' "${info}" | cut -d= -f2)
    model=$(grep '^MODEL=' "${info}" | cut -d= -f2)
    node=$(grep '^NODE=' "${info}" | cut -d= -f2)
    port=$(grep '^PORT=' "${info}" | cut -d= -f2)
    base_url=$(grep '^OLLAMA_BASE_URL=' "${info}" | cut -d= -f2)

    # Determine if job is still running in SLURM
    job_state=$(squeue -j "${job_id}" -h -o "%T" 2>/dev/null || echo "UNKNOWN")
    [[ -z "${job_state}" ]] && job_state="COMPLETED"

    # Try HTTP health check (works only if we're on the same node or via SSH tunnel)
    http_status="N/A"
    if [[ "$(hostname)" == "${node}" ]]; then
        http_status=$(curl -s -o /dev/null -w "%{http_code}" \
            "${base_url}/api/tags" --max-time 3 2>/dev/null || echo "ERR")
        [[ "${http_status}" == "200" ]] && http_status="OK" || http_status="FAIL"
    fi

    if [[ ${JSON_MODE} -eq 1 ]]; then
        [[ ${first} -eq 0 ]] && echo ","
        first=0
        cat <<JSONEOF
  {
    "job_id": "${job_id}",
    "model": "${model}",
    "node": "${node}",
    "port": "${port}",
    "base_url": "${base_url}",
    "slurm_state": "${job_state}",
    "http_status": "${http_status}"
  }
JSONEOF
    else
        printf "%-20s %-15s %-10s %-35s %-10s\n" \
            "${model}" "${node}" "${port}" "${base_url}" \
            "${job_state}/${http_status}"
    fi
done

[[ ${JSON_MODE} -eq 1 ]] && echo "]"
echo ""
