#!/bin/bash
# =============================================================================
# ollama_teardown.sh
# Utility: Cancel all running OLLAMA SLURM jobs for the current user
# and clean up *.info files from completed jobs.
#
# Usage:
#   bash ollama_teardown.sh [--all | --model <name> | --job <job_id>]
#
# Options:
#   --all              Cancel ALL ollama jobs (default)
#   --model <name>     Cancel only jobs matching this model name substring
#   --job <job_id>     Cancel one specific job by SLURM job ID
#   --clean            Remove stale .info files for completed jobs only
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/model_versions.env"

MODE="all"
FILTER=""
TARGET_JOB=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)    MODE="all" ;;
        --model)  MODE="model"; FILTER="$2"; shift ;;
        --job)    MODE="job";   TARGET_JOB="$2"; shift ;;
        --clean)  MODE="clean" ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

case "${MODE}" in
    # -----------------------------------------------------------------------
    all)
        echo "Cancelling all OLLAMA jobs for ${USER}..."
        mapfile -t JOB_IDS < <(
            squeue -u "${USER}" -h -o "%i %j" \
            | grep "ollama" \
            | awk '{print $1}'
        )
        if [[ ${#JOB_IDS[@]} -eq 0 ]]; then
            echo "No OLLAMA jobs found."
        else
            for jid in "${JOB_IDS[@]}"; do
                echo "  Cancelling job ${jid}..."
                scancel "${jid}"
            done
            echo "Cancelled ${#JOB_IDS[@]} job(s)."
        fi
        ;;
    # -----------------------------------------------------------------------
    model)
        echo "Cancelling OLLAMA jobs matching '${FILTER}' for ${USER}..."
        mapfile -t JOB_IDS < <(
            squeue -u "${USER}" -h -o "%i %j" \
            | grep -i "ollama.*${FILTER}\|${FILTER}.*ollama" \
            | awk '{print $1}'
        )
        if [[ ${#JOB_IDS[@]} -eq 0 ]]; then
            echo "No matching jobs found."
        else
            for jid in "${JOB_IDS[@]}"; do
                echo "  Cancelling job ${jid}..."
                scancel "${jid}"
            done
        fi
        ;;
    # -----------------------------------------------------------------------
    job)
        echo "Cancelling job ${TARGET_JOB}..."
        scancel "${TARGET_JOB}" && echo "Done." || echo "Failed."
        ;;
    # -----------------------------------------------------------------------
    clean)
        echo "Cleaning up stale .info files in ${OLLAMA_LOG_DIR}..."
        cleaned=0
        for info in "${OLLAMA_LOG_DIR}"/*.info; do
            [[ -f "${info}" ]] || continue
            job_id=$(grep '^JOB_ID=' "${info}" | cut -d= -f2)
            state=$(squeue -j "${job_id}" -h -o "%T" 2>/dev/null)
            if [[ -z "${state}" ]]; then
                echo "  Removing stale: ${info} (job ${job_id} no longer running)"
                rm -f "${info}"
                (( cleaned++ ))
            fi
        done
        echo "Removed ${cleaned} stale .info file(s)."
        ;;
esac

echo ""
echo "Remaining OLLAMA jobs:"
squeue -u "${USER}" --format="%.10i %.25j %.8T %.10M" | grep -E "(JOBID|ollama)" || echo "(none)"
