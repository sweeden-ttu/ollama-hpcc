#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${OLLAMA_HPCC_DIR:-$SCRIPT_DIR}"
BRANCH="${OLLAMA_HPCC_BRANCH:-main}"

echo "=========================================="
echo "Daily GitHub Sync - ollama-hpcc"
echo "Date: $(date)"
echo "=========================================="

cd "$PROJECT_DIR"

echo "Checking git repository..."
if [ ! -d .git ]; then
    echo "Error: Not a git repository. Initialize with: git init"
    exit 1
fi

echo "Fetching latest changes from remote..."
git fetch origin

echo "Pulling remote changes..."
git pull origin "$BRANCH"

echo "Checking for local changes..."
if git diff --quiet HEAD 2>/dev/null; then
    echo "No local changes to push."
else
    echo "Adding all changes..."
    git add -A
    
    echo "Committing changes..."
    git commit -m "Daily sync $(date '+%Y-%m-%d %H:%M')"
    
    echo "Pushing to remote..."
    git push origin "$BRANCH"
fi

echo "=========================================="
echo "Sync completed successfully!"
echo "=========================================="
