#!/bin/bash
# =============================================================================
# ollama_list_jobs.sh
# Utility: Show all SLURM jobs related to OLLAMA for the current user
#
# Usage:  bash ollama_list_jobs.sh
# =============================================================================

echo "=== Active OLLAMA SLURM Jobs for ${USER} ==="
squeue -u "${USER}" --format="%.10i %.20j %.8T %.10M %.6D %R" \
    | grep -E "(JOBID|ollama)" || echo "(none)"

echo ""
echo "=== Discovered OLLAMA Server Info Files ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/model_versions.env"

info_files=("${OLLAMA_LOG_DIR}"/*.info)
if [[ ! -e "${info_files[0]}" ]]; then
    echo "(no .info files found in ${OLLAMA_LOG_DIR})"
else
    for info in "${OLLAMA_LOG_DIR}"/*.info; do
        [[ -f "${info}" ]] || continue
        echo ""
        echo "--- ${info} ---"
        cat "${info}"
    done
fi
