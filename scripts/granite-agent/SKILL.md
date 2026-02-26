---
name: granite-agent
description: >
  Bootstraps a connection to the IBM Granite 4 LLM running on HPCC
  (dynamic port from SLURM job, accessed via SSH tunnel).
  Use this skill whenever the user wants to chat with Granite, send prompts to
  Granite, query the local Granite model, use the granite agent, test granite,
  or interact with the OLLAMA Granite instance. The skill hard-fails with a clear
  error if the Granite server is unreachable — never silently falls
  back to another model.
---

# Granite Agent

This skill wires up a connection to the IBM Granite 4 model (`granite4:3b`) that
is served by OLLAMA on a **dynamic port** from the HPCC `matador` GPU cluster.

The bootstrap.sh script automatically detects the running job's port.

## Startup sequence (always run first)

Before doing anything else, run the bootstrap check:

```bash
bash <skill_dir>/scripts/bootstrap.sh
```

- If it exits **0**: the server is healthy. Read the printed `GRANITE_BASE_URL`
  and `GRANITE_MODEL` from its stdout and use them for all subsequent API calls.
- If it exits **non-zero**: stop immediately. Print the error from the script and
  do NOT attempt any fallback. Tell the user exactly what failed and how to fix it
  (see "Troubleshooting" below).

This fail-fast behaviour is intentional: a silent fallback to a different model
would produce confusing, non-reproducible results for the user.

## Making requests

Use the OLLAMA REST API at the URL from bootstrap. All endpoints follow the
standard OLLAMA HTTP API:

### Chat (recommended)
```bash
curl -s http://localhost:$PORT/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite4:3b",
    "messages": [{"role": "user", "content": "<USER_PROMPT>"}],
    "stream": false
  }' | python3 -c "import sys,json; print(json.load(sys.stdin)['message']['content'])"
```

### Generate (single-shot)
```bash
curl -s http://localhost:$PORT/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model": "granite4:3b", "prompt": "<USER_PROMPT>", "stream": false}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

### List available models (sanity check)
```bash
curl -s http://localhost:$PORT/api/tags | python3 -m json.tool
```

## Passing user input safely

Always pass user-provided text as a JSON string — never interpolate raw text
into the shell command to avoid injection. Use Python to build the payload:

```python
import json, subprocess, sys

prompt = sys.argv[1]   # or however you receive it
payload = json.dumps({
    "model": "granite4:3b",
    "messages": [{"role": "user", "content": prompt}],
    "stream": False
})
result = subprocess.run(
    ["curl", "-s", "-X", "POST",
     f"http://localhost:$PORT/api/chat",
     "-H", "Content-Type: application/json",
     "-d", payload],
    capture_output=True, text=True, timeout=120
)
response = json.loads(result.stdout)
print(response["message"]["content"])
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Connection refused` | SSH tunnel is not up or job not running | Run `granite-interactive` or `granite` to start job |
| `model "granite4:3b" not found` | Model not pulled yet | The job will pull it automatically |
| `curl: (28) Operation timed out` | Compute node job ended | Resubmit with `granite` |

## Usage

1. Start job: `granite` or `granite-interactive`
2. Note the dynamic port from job output
3. Create SSH tunnel: `ssh -L <PORT>:127.0.0.1:<PORT> -i ~/.ssh/id_rsa sweeden@login.hpcc.ttu.edu`
4. Run bootstrap: `bash scripts/granite-agent/scripts/bootstrap.sh`
