# Cursor IDE Setup

## SSH Key Configuration

This project uses SSH key authentication for connecting to remote HPCC nodes.

### SSH Key Location

```
~/projects/GlobPretect/id_ed25519_sweeden
```

### Setup Instructions

1. **Verify SSH key exists**:
   ```bash
   ls -la ~/projects/GlobPretect/id_ed25519_sweeden
   ```

2. **Add SSH key to agent**:
   ```bash
   ssh-add ~/projects/GlobPretect/id_ed25519_sweeden
   ```

3. **Configure SSH config**:
   Add to `~/.ssh/config`:
   ```
   Host hpcc-*
       IdentityFile ~/projects/GlobPretect/id_ed25519_sweeden
       IdentitiesOnly yes
   ```

## Cursor IDE Configuration

### Recommended Extensions

- Python
- Remote - SSH
- Docker
- YAML

### Remote Development

1. Open Cursor IDE
2. Click "Remote Explorer" in sidebar
3. Add new SSH target
4. Connect using the configured SSH key

### Project-Specific Settings

Create `.cursor/settings.json` in the project root:

```json
{
  "python.defaultInterpreterPath": "${env:HOME}/miniconda3/envs/LangSmith/bin/python",
  "files.exclude": {
    "**/__pycache__": true,
    "**/*.pyc": true
  }
}
```

## Connection Testing

Test SSH connection:
```bash
ssh -i ~/projects/GlobPretect/id_ed25519_sweeden user@hpcc-node
```
