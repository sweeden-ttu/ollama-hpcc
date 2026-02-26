#!/bin/bash
# =============================================================================
# mpi_run.sh
# Submit OLLAMA SLURM batch scripts following the TTU HPCC Job Submission Guide.
#
# Pattern (per the guide):
#   1. This script calls `sbatch` to submit the job script to the scheduler
#   2. Inside each job script, `mpirun -np 1` launches the OLLAMA server so
#      SLURM properly manages the process under its allocated tasks/cores
#   3. Each submitted job lands on its own compute node with its own
#      dynamic port — use ollama_port_map.sh to get the SSH tunnel command
#
# Usage:
#   bash mpi_run.sh <run_script.sh> [num_nodes]
#
# Examples:
#   bash mpi_run.sh run_granite_ollama.sh          # 1 node (default)
#   bash mpi_run.sh run_deepseek_ollama.sh 4       # 4 independent nodes
#   bash mpi_run.sh run_qwen-coder_ollama.sh 2
#   bash mpi_run.sh run_codellama_ollama.sh 3
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/model_versions.env"

RUN_SCRIPT="${1}"
NUM_NODES="${2:-1}"

if [[ -z "${RUN_SCRIPT}" ]]; then
    echo "Usage: $0 <run_script.sh> [num_nodes]"
    echo ""
    echo "Available run scripts:"
    ls "${SCRIPT_DIR}"/run_*_ollama.sh 2>/dev/null | xargs -n1 basename
    exit 1
fi

# Resolve path
if [[ ! -f "${RUN_SCRIPT}" ]]; then
    RUN_SCRIPT="${SCRIPT_DIR}/${RUN_SCRIPT}"
fi

if [[ ! -f "${RUN_SCRIPT}" ]]; then
    echo "ERROR: Script not found: ${RUN_SCRIPT}"
    exit 1
fi

echo "============================================================"
echo "MPI-style OLLAMA launcher"
echo "  Script:     $(basename "${RUN_SCRIPT}")"
echo "  Nodes:      ${NUM_NODES}"
echo "  Partition:  ${HPCC_PARTITION}"
echo "  Submitted:  $(date)"
echo "============================================================"

JOB_IDS=()
for (( i=1; i<=NUM_NODES; i++ )); do
    JOB_ID=$(sbatch --parsable "${RUN_SCRIPT}")
    if [[ $? -eq 0 ]]; then
        echo "  Node ${i}: submitted job ${JOB_ID}"
        JOB_IDS+=("${JOB_ID}")
    else
        echo "  Node ${i}: sbatch FAILED"
    fi
done

echo ""
echo "Submitted ${#JOB_IDS[@]} job(s): ${JOB_IDS[*]}"
echo ""
echo "Monitor with:"
echo "  bash ${SCRIPT_DIR}/ollama_list_jobs.sh"
echo "  bash ${SCRIPT_DIR}/ollama_health_check.sh"
echo ""
echo "Connect to a server:"
echo "  bash ${SCRIPT_DIR}/ollama_connect.sh <model_name> [local_port]"
