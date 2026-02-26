---
name: granite-agent
description: >
  Bootstraps a connection to the IBM Granite 4 LLM running locally on port 55077
  (Debug/VPN static port mapped to the matador GPU cluster via SSH tunnel).
  Use this skill whenever the user wants to chat with Granite, send prompts to
  Granite, query the local Granite model, use the granite agent, test granite,
  or interact with the OLLAMA Granite instance. The skill hard-fails with a clear
  error if the Granite server on port 55077 is unreachable — never silently falls
  back to another model.
---

# Granite Agent

This skill wires up a connection to the IBM Granite 4 model (`granite4:3b`) that
is served by OLLAMA on **localhost:55077** — the static Debug/VPN port mapped
from the `matador` GPU cluster via the SSH tunnel created by `ollama_port_map.sh`.

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

Use the OLLAMA REST API at `http://localhost:55077`. All endpoints follow the
standard OLLAMA HTTP API:

### Chat (recommended)
```bash
curl -s http://localhost:55077/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite4:3b",
    "messages": [{"role": "user", "content": "<USER_PROMPT>"}],
    "stream": false
  }' | python3 -c "import sys,json; print(json.load(sys.stdin)['message']['content'])"
```

### Generate (single-shot)
```bash
curl -s http://localhost:55077/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model": "granite4:3b", "prompt": "<USER_PROMPT>", "stream": false}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

### List available models (sanity check)
```bash
curl -s http://localhost:55077/api/tags | python3 -m json.tool
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
     "http://localhost:55077/api/chat",
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
| `Connection refused` on port 55077 | SSH tunnel is not up | Run `bash scripts/ollama_port_map.sh --env debug` to get the SSH command, then open the tunnel |
| `model "granite4:3b" not found` | Model not pulled yet | Connect to the compute node and run `ollama pull granite4:3b` |
| `curl: (28) Operation timed out` | Compute node job ended | Resubmit with `sbatch scripts/run_granite_ollama.sh` |
| Port 55077 in use by another process | Port conflict | Check with `lsof -i :55077` and kill the conflicting process |

## Port reference

| Environment | Static port | SSH tunnel command |
|---|---|---|
| Debug (VPN) | **55077** | see `ollama_port_map.sh --env debug` |
| Testing macOS | 55177 | see `ollama_port_map.sh --env testing1` |
| Testing Rocky | 55277 | see `ollama_port_map.sh --env testing2` |
| Release | 55377 | see `ollama_port_map.sh --env release` |
