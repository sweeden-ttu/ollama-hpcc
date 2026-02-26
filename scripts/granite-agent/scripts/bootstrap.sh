#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Granite Agent bootstrap & connectivity check
#
# This script is the FIRST thing the granite-agent skill runs.
# It verifies the OLLAMA server on the dynamic port is reachable and serving
# the expected granite4:3b model before any prompts are sent.
#
# Exit codes:
#   0  — server healthy, model present; prints GRANITE_BASE_URL and GRANITE_MODEL
#   1  — port unreachable (tunnel likely not up)
#   2  — server reachable but granite4:3b model not found
#   3  — unexpected HTTP error from the OLLAMA API
#   4  — required tool missing (curl, python3)
#
# On success, stdout includes key=value lines the caller can eval:
#   GRANITE_BASE_URL=http://localhost:<PORT>
#   GRANITE_MODEL=granite4:3b
# =============================================================================

set -euo pipefail

# Get dynamic port from running job or use environment variable
get_granite_port() {
    if [ -n "${GRANITE_PORT:-}" ]; then
        echo "$GRANITE_PORT"
        return
    fi
    # Try to get from job output
    local port
    port=$(cat ~/ollama-hpcc/ollama-granite-*.out 2>/dev/null | grep '^Port:' | head -1 | awk '{print $2}' || true)
    if [ -n "$port" ]; then
        echo "$port"
        return
    fi
    echo "ERROR: Could not determine Granite port. Is the job running?" >&2
    exit 1
}

GRANITE_PORT="$(get_granite_port)"
GRANITE_MODEL_NAME="${GRANITE_MODEL_NAME:-granite4:3b}"
BASE_URL="http://localhost:${GRANITE_PORT}"
CONNECT_TIMEOUT=5    # seconds to wait for TCP connection
REQUEST_TIMEOUT=10   # seconds to wait for full HTTP response

# ---------------------------------------------------------------------------
# 1. Dependency check
# ---------------------------------------------------------------------------
for tool in curl python3; do
    if ! command -v "${tool}" &>/dev/null; then
        echo "ERROR [bootstrap]: Required tool '${tool}' not found in PATH." >&2
        echo "Install it and try again." >&2
        exit 4
    fi
done

# ---------------------------------------------------------------------------
# 2. TCP reachability — fast fail before waiting on HTTP
# ---------------------------------------------------------------------------
if ! curl --silent --connect-timeout "${CONNECT_TIMEOUT}" \
          --max-time "${CONNECT_TIMEOUT}" \
          --output /dev/null \
          "${BASE_URL}/api/tags" 2>/dev/null; then
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "║  GRANITE AGENT BOOTSTRAP FAILED — port ${GRANITE_PORT} unreachable  ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    echo "The OLLAMA server is not responding on localhost:${GRANITE_PORT}." >&2
    echo "" >&2
    echo "Most likely causes:" >&2
    echo "  1. The SSH tunnel to the compute node is not open." >&2
    echo "     Fix: run   bash scripts/ollama_port_map.sh --env debug" >&2
    echo "     and copy-paste the SSH command it prints." >&2
    echo "" >&2
    echo "  2. The SLURM job has ended (walltime exceeded or cancelled)." >&2
    echo "     Fix: resubmit with   sbatch scripts/run_granite_ollama.sh" >&2
    echo "     then re-open the SSH tunnel." >&2
    echo "" >&2
    echo "  3. Port ${GRANITE_PORT} is blocked by a firewall or already in use." >&2
    echo "     Check: lsof -i :${GRANITE_PORT}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. Model availability check
# ---------------------------------------------------------------------------
HTTP_BODY=$(curl --silent \
                 --connect-timeout "${CONNECT_TIMEOUT}" \
                 --max-time "${REQUEST_TIMEOUT}" \
                 --write-out "\n__HTTP_STATUS__%{http_code}" \
                 "${BASE_URL}/api/tags" 2>/dev/null)

HTTP_STATUS=$(echo "${HTTP_BODY}" | tail -1 | sed 's/__HTTP_STATUS__//')
JSON_BODY=$(echo "${HTTP_BODY}" | sed '$d')

if [[ "${HTTP_STATUS}" != "200" ]]; then
    echo "ERROR [bootstrap]: OLLAMA /api/tags returned HTTP ${HTTP_STATUS}." >&2
    echo "Response body:" >&2
    echo "${JSON_BODY}" >&2
    exit 3
fi

# Check if granite4:3b is in the model list
MODEL_FOUND=$(echo "${JSON_BODY}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
models = [m.get('name','') for m in data.get('models', [])]
target = '${GRANITE_MODEL_NAME}'
# Accept exact match OR name without digest suffix
found = any(m == target or m.startswith(target) for m in models)
print('yes' if found else 'no')
print('Available models: ' + ', '.join(models), file=sys.stderr)
" 2>/tmp/granite_bootstrap_models.txt)

cat /tmp/granite_bootstrap_models.txt >&2

if [[ "${MODEL_FOUND}" != "yes" ]]; then
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "║  GRANITE AGENT BOOTSTRAP FAILED — model not found           ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    echo "The OLLAMA server is running on port ${GRANITE_PORT}, but the model" >&2
    echo "'${GRANITE_MODEL_NAME}' is not loaded." >&2
    echo "" >&2
    echo "Fix: from the HPCC compute node, run:" >&2
    echo "  ollama pull ${GRANITE_MODEL_NAME}" >&2
    echo "" >&2
    echo "Or pre-pull all models with:" >&2
    echo "  sbatch scripts/ollama_pull_models.sh" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# 4. Quick smoke test — send a minimal prompt
# ---------------------------------------------------------------------------
SMOKE_RESPONSE=$(curl --silent \
    --connect-timeout "${CONNECT_TIMEOUT}" \
    --max-time 60 \
    -X POST "${BASE_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${GRANITE_MODEL_NAME}\", \"prompt\": \"Reply with the single word: OK\", \"stream\": false}" \
    2>/dev/null)

if [[ -z "${SMOKE_RESPONSE}" ]]; then
    echo "WARNING [bootstrap]: Smoke test got an empty response — model may be loading." >&2
    echo "Proceeding, but the first request may be slow." >&2
else
    SMOKE_TEXT=$(echo "${SMOKE_RESPONSE}" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('response','').strip())" 2>/dev/null || true)
    echo "Smoke test response: ${SMOKE_TEXT}" >&2
fi

# ---------------------------------------------------------------------------
# 5. Print connection info for the caller (eval-able)
# ---------------------------------------------------------------------------
echo "GRANITE_BASE_URL=${BASE_URL}"
echo "GRANITE_MODEL=${GRANITE_MODEL_NAME}"
echo "GRANITE_PORT=${GRANITE_PORT}"

echo "" >&2
echo "✓ Granite agent bootstrap successful." >&2
echo "  URL:   ${BASE_URL}" >&2
echo "  Model: ${GRANITE_MODEL_NAME}" >&2
exit 0
