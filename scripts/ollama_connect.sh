#!/bin/bash
# =============================================================================
# ollama_connect.sh
# Utility: SSH port-forward a running OLLAMA server to your local machine
#
# To create a tunnel use this format (see README):
#   1. Login to interactive nocona: /etc/slurm/scripts/interactive -p nocona
#   2. Note NODE and port from job/session
#   3. From your Mac: ssh sweeden@login.hpcc.ttu.edu -L pppp:NODE:pppp
#
# This script runs the tunnel: ssh -L LOCAL_PORT:NODE:PORT sweeden@login.hpcc.ttu.edu -N
# =============================================================================
#
# Usage:
#   bash ollama_connect.sh [model_name] [local_port]
#
# Examples:
#   bash ollama_connect.sh granite         # auto-pick first granite server
#   bash ollama_connect.sh deepseek-r1 11435
#   bash ollama_connect.sh qwen2.5-coder 11436
#
# After the tunnel is up, use from your laptop:
#   curl http://localhost:<LOCAL_PORT>/api/tags
#   ollama run <model> --host http://localhost:<LOCAL_PORT>
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/model_versions.env"

FILTER="${1:-}"          # Optional model name filter
LOCAL_PORT="${2:-11434}" # Default local port to bind

HPCC_LOGIN="login.hpcc.ttu.edu"
HPCC_USER="sweeden"

# Find matching .info file
MATCHED_INFO=""
for info in "${OLLAMA_LOG_DIR}"/*.info; do
    [[ -f "${info}" ]] || continue
    model=$(grep '^MODEL=' "${info}" | cut -d= -f2)
    if [[ -z "${FILTER}" ]] || [[ "${model}" == *"${FILTER}"* ]]; then
        MATCHED_INFO="${info}"
        break
    fi
done

if [[ -z "${MATCHED_INFO}" ]]; then
    echo "ERROR: No running OLLAMA server found matching '${FILTER}'"
    echo "Run:  bash ollama_list_jobs.sh  to see available servers."
    exit 1
fi

NODE=$(grep '^NODE=' "${MATCHED_INFO}" | cut -d= -f2)
PORT=$(grep '^PORT=' "${MATCHED_INFO}" | cut -d= -f2)
MODEL=$(grep '^MODEL=' "${MATCHED_INFO}" | cut -d= -f2)
JOB_ID=$(grep '^JOB_ID=' "${MATCHED_INFO}" | cut -d= -f2)

echo "============================================================"
echo "Connecting to OLLAMA server"
echo "  Model:      ${MODEL}"
echo "  Remote:     ${NODE}:${PORT}"
echo "  Local:      localhost:${LOCAL_PORT}"
echo "  SLURM Job:  ${JOB_ID}"
echo "============================================================"
echo ""
echo "Starting SSH tunnel via ${HPCC_LOGIN} ..."
echo "Press Ctrl+C to disconnect."
echo ""
echo "Once connected, from your local machine you can run:"
echo "  curl http://localhost:${LOCAL_PORT}/api/tags"
echo "  OLLAMA_HOST=http://localhost:${LOCAL_PORT} ollama run ${MODEL}"
echo ""

# Two-hop not required: tunnel format is ssh sweeden@login.hpcc.ttu.edu -L pppp:NODE:pppp
ssh -N -L "${LOCAL_PORT}:${NODE}:${PORT}" "${HPCC_USER}@${HPCC_LOGIN}"
