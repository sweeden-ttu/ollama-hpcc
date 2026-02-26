#!/bin/bash
# =============================================================================
# mpi_run_all.sh
# Convenience script: submit ALL four OLLAMA models to SLURM simultaneously.
# Each model gets its own job slot on the matador GPU partition.
#
# Usage:
#   bash mpi_run_all.sh [num_nodes_per_model]
#
# Example:
#   bash mpi_run_all.sh        # 1 node per model (4 jobs total)
#   bash mpi_run_all.sh 2      # 2 nodes per model (8 jobs total)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/model_versions.env"

N="${1:-1}"

echo "Submitting all OLLAMA model jobs (${N} node(s) each)..."
echo ""

for script in \
    run_granite_ollama.sh \
    run_deepseek_ollama.sh \
    "run_qwen-coder_ollama.sh" \
    run_codellama_ollama.sh
do
    echo ">>> ${script}"
    bash "${SCRIPT_DIR}/mpi_run.sh" "${SCRIPT_DIR}/${script}" "${N}"
    echo ""
done

echo "All models submitted. Check status with:"
echo "  bash ${SCRIPT_DIR}/ollama_list_jobs.sh"
