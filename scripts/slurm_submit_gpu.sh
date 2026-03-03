#!/bin/bash
#SBATCH --job-name=graniteGPU
#SBATCH --output=%j_%x.out
#SBATCH --error=%j_%x.err
#SBATCH --partition=matador
#SBATCH --cpus-per-task=1
#SBATCH --mem=8192
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=04:30:00
#
# GPU job template. Replace as needed:
#   --partition: matador (V100) or toreador (A100). Do not use gpu-build (no GPUs).
#   --job-name: your job name.
# Memory: at least 8GB total (--mem=8192) and 2048MB per CPU.

echo "Job $SLURM_JOB_ID started on $(hostname) at $(date)"
echo "Partition: $SLURM_JOB_PARTITION  Node: $SLURM_NODELIST  GPUs: $CUDA_VISIBLE_DEVICES"

# Your commands here, e.g.:
#   source .../bin/activate && ollama run granite4:3b
# Or pass a command:  sbatch slurm_submit_gpu.sh -- yourcommand
if [ $# -gt 0 ]; then exec "$@"; fi
