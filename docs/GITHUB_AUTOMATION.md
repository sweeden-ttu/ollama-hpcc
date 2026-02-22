# GitHub Automation

## Daily Sync

This project uses automated daily synchronization to keep local and remote repositories in sync.

### Sync Script

The daily sync is handled by `scripts/daily-github-sync.sh`.

### How It Works

1. The script runs daily (via cron or manually)
2. It pulls the latest changes from GitHub
3. It pushes local changes to GitHub
4. It reports sync status

### Setup Cron Job

Add to crontab:
```bash
0 8 * * * /home/sdw3098/projects/ollama-hpcc/scripts/daily-github-sync.sh >> /home/sdw3098/projects/ollama-hpcc/logs/sync.log 2>&1
```

### Manual Sync

Run the sync script manually:
```bash
./scripts/daily-github-sync.sh
```

### Prerequisites

- Git installed
- GitHub CLI (`gh`) installed and authenticated
- SSH key configured for GitHub

### Configuration

The script can be configured via environment variables:
- `OLLAMA_HPCC_DIR`: Project directory (default: current directory)
- `OLLAMA_HPCC_BRANCH`: Git branch to sync (default: main)
