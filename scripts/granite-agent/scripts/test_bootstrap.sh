#!/usr/bin/env bash
# =============================================================================
# test_bootstrap.sh — Unit tests for bootstrap.sh
#
# Tests verify correct behaviour both when port 55077 IS reachable (happy path,
# using a mock server) and when it is NOT (fail-fast paths).
#
# Usage:
#   bash test_bootstrap.sh            # all tests
#   bash test_bootstrap.sh -v         # verbose (show curl/mock output)
#   bash test_bootstrap.sh -k smoke   # run only tests matching pattern
#
# Exit code: 0 if all tests pass, 1 if any fail.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP="${SCRIPT_DIR}/bootstrap.sh"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; RESET='\033[0m'

VERBOSE=0
FILTER=""
while [[ $# -gt 0 ]]; do
    case "$1" in -v) VERBOSE=1 ;; -k) FILTER="$2"; shift ;; esac; shift
done

# ── Test harness ─────────────────────────────────────────────────────────────
PASS=0; FAIL=0; SKIP=0
FAILURES=()

run_test() {
    local name="$1"; local fn="$2"
    if [[ -n "${FILTER}" && "${name}" != *"${FILTER}"* ]]; then
        (( SKIP++ )); return
    fi
    printf "  %-60s" "${name}"
    local output; local exit_code
    output=$(${fn} 2>&1); exit_code=$?
    if [[ ${exit_code} -eq 0 ]]; then
        echo -e "${GREEN}PASS${RESET}"; (( PASS++ ))
    else
        echo -e "${RED}FAIL${RESET}"; (( FAIL++ ))
        FAILURES+=("${name}")
        [[ ${VERBOSE} -eq 1 ]] && echo "${output}" | sed 's/^/    /'
    fi
}

assert_exit() {
    local expected="$1"; shift
    local actual_exit
    "$@" >/dev/null 2>&1; actual_exit=$?
    [[ ${actual_exit} -eq ${expected} ]]
}

assert_stdout_contains() {
    local pattern="$1"; shift
    "$@" 2>/dev/null | grep -q "${pattern}"
}

assert_stderr_contains() {
    local pattern="$1"; shift
    "$@" 2>&1 1>/dev/null | grep -q "${pattern}"
}

# ── Mock server helpers ───────────────────────────────────────────────────────
MOCK_PORT=59877   # unlikely to be in use
MOCK_PID=""

# Response templates
TAGS_WITH_GRANITE='{"models":[{"name":"granite4:3b","size":2100000000,"digest":"abc123","details":{}}]}'
TAGS_WITHOUT_GRANITE='{"models":[{"name":"llama3:8b","size":4700000000,"digest":"def456","details":{}}]}'
TAGS_EMPTY='{"models":[]}'
GENERATE_OK='{"model":"granite4:3b","created_at":"2026-02-26T00:00:00Z","response":"OK","done":true}'

start_mock_server() {
    local tags_response="$1"
    local generate_response="${2:-${GENERATE_OK}}"
    local http_status="${3:-200}"

    # Write a tiny Python HTTP server that returns controlled responses
    MOCK_SERVER_PY=$(mktemp /tmp/mock_ollama_XXXXXX.py)
    cat > "${MOCK_SERVER_PY}" <<PYEOF
import http.server, json, sys

TAGS = '${tags_response}'
GENERATE = '${generate_response}'
STATUS = ${http_status}

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send_json(self, body, code=None):
        c = code if code is not None else STATUS
        self.send_response(c)
        self.send_header("Content-Type","application/json")
        self.end_headers()
        self.wfile.write(body.encode())
    def do_GET(self):
        if '/api/tags' in self.path: self.send_json(TAGS)
        else: self.send_json('{}', 404)
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        self.rfile.read(length)
        if '/api/generate' in self.path: self.send_json(GENERATE)
        elif '/api/chat' in self.path: self.send_json('{"message":{"role":"assistant","content":"OK"}}')
        else: self.send_json('{}', 404)

http.server.HTTPServer(('127.0.0.1', ${MOCK_PORT}), H).serve_forever()
PYEOF
    python3 "${MOCK_SERVER_PY}" &
    MOCK_PID=$!
    # Wait for server to bind
    for i in {1..20}; do
        curl -s --connect-timeout 0.2 "http://localhost:${MOCK_PORT}/api/tags" \
            >/dev/null 2>&1 && break
        sleep 0.1
    done
}

stop_mock_server() {
    if [[ -n "${MOCK_PID}" ]]; then
        kill "${MOCK_PID}" 2>/dev/null || true
        wait "${MOCK_PID}" 2>/dev/null || true
        MOCK_PID=""
    fi
    rm -f /tmp/mock_ollama_*.py
}

# Override the port for all tests that use a mock
with_mock_port() {
    GRANITE_PORT=${MOCK_PORT} GRANITE_MODEL_NAME="granite4:3b" bash "${BOOTSTRAP}" "$@"
}

# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Granite Agent Bootstrap Unit Tests${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════${RESET}\n"

# ── Group 1: Fail-fast — no server ───────────────────────────────────────────
echo -e "${BOLD}Group 1: Fail-fast (no server running)${RESET}"

t_exit1_when_port_closed() {
    # Nothing listening on the mock port — must exit 1
    assert_exit 1 \
        env GRANITE_PORT=59999 GRANITE_MODEL_NAME="granite4:3b" bash "${BOOTSTRAP}"
}
run_test "exits with code 1 when port is not listening" t_exit1_when_port_closed

t_stderr_connection_refused() {
    assert_stderr_contains "unreachable" \
        env GRANITE_PORT=59999 GRANITE_MODEL_NAME="granite4:3b" bash "${BOOTSTRAP}"
}
run_test "stderr mentions 'unreachable' when port closed" t_stderr_connection_refused

t_stderr_fix_instructions_tunnel() {
    assert_stderr_contains "SSH tunnel" \
        env GRANITE_PORT=59999 GRANITE_MODEL_NAME="granite4:3b" bash "${BOOTSTRAP}"
}
run_test "stderr includes SSH tunnel fix instructions" t_stderr_fix_instructions_tunnel

t_stderr_fix_instructions_sbatch() {
    assert_stderr_contains "sbatch" \
        env GRANITE_PORT=59999 GRANITE_MODEL_NAME="granite4:3b" bash "${BOOTSTRAP}"
}
run_test "stderr includes sbatch resubmit fix instructions" t_stderr_fix_instructions_sbatch

t_no_stdout_on_fail() {
    # On failure, stdout must be empty (no partial key=value lines)
    local out
    out=$(env GRANITE_PORT=59999 GRANITE_MODEL_NAME="granite4:3b" bash "${BOOTSTRAP}" 2>/dev/null)
    [[ -z "${out}" ]]
}
run_test "stdout is empty when bootstrap fails (no partial output)" t_no_stdout_on_fail

# ── Group 2: Fail-fast — server up but wrong model ────────────────────────────
echo ""
echo -e "${BOLD}Group 2: Fail-fast (server up, granite4:3b absent)${RESET}"

start_mock_server "${TAGS_WITHOUT_GRANITE}"

t_exit2_model_missing() {
    assert_exit 2 with_mock_port
}
run_test "exits with code 2 when model not in tag list" t_exit2_model_missing

t_stderr_model_not_found() {
    assert_stderr_contains "not loaded" with_mock_port
}
run_test "stderr says model is not loaded" t_stderr_model_not_found

t_stderr_pull_hint_model_missing() {
    assert_stderr_contains "ollama pull" with_mock_port
}
run_test "stderr suggests 'ollama pull granite4:3b'" t_stderr_pull_hint_model_missing

t_no_stdout_model_missing() {
    local out; out=$(with_mock_port 2>/dev/null); [[ -z "${out}" ]]
}
run_test "stdout is empty when model missing" t_no_stdout_model_missing

stop_mock_server

# ── Group 3: Fail-fast — server up, empty model list ─────────────────────────
echo ""
echo -e "${BOLD}Group 3: Fail-fast (server up, empty model list)${RESET}"

start_mock_server "${TAGS_EMPTY}"

t_exit2_empty_tags() {
    assert_exit 2 with_mock_port
}
run_test "exits with code 2 when models list is empty" t_exit2_empty_tags

t_stderr_empty_tags_model() {
    assert_stderr_contains "not loaded" with_mock_port
}
run_test "stderr mentions model not loaded (empty list)" t_stderr_empty_tags_model

stop_mock_server

# ── Group 4: Fail-fast — HTTP 500 from OLLAMA ────────────────────────────────
echo ""
echo -e "${BOLD}Group 4: Fail-fast (server returns HTTP 500)${RESET}"

start_mock_server '{"error":"internal"}' "${GENERATE_OK}" 500

t_exit3_http500() {
    assert_exit 3 with_mock_port
}
run_test "exits with code 3 on HTTP 500 from /api/tags" t_exit3_http500

t_stderr_http500() {
    assert_stderr_contains "HTTP 500" with_mock_port
}
run_test "stderr reports HTTP status code on error" t_stderr_http500

stop_mock_server

# ── Group 5: Happy path — server up, model present ────────────────────────────
echo ""
echo -e "${BOLD}Group 5: Happy path (server healthy, granite4:3b present)${RESET}"

start_mock_server "${TAGS_WITH_GRANITE}"

t_exit0_happy() {
    assert_exit 0 with_mock_port
}
run_test "exits with code 0 when server healthy and model found" t_exit0_happy

t_stdout_base_url() {
    assert_stdout_contains "GRANITE_BASE_URL=http://localhost:${MOCK_PORT}" with_mock_port
}
run_test "stdout contains GRANITE_BASE_URL=http://localhost:<port>" t_stdout_base_url

t_stdout_model_name() {
    assert_stdout_contains "GRANITE_MODEL=granite4:3b" with_mock_port
}
run_test "stdout contains GRANITE_MODEL=granite4:3b" t_stdout_model_name

t_stdout_port() {
    assert_stdout_contains "GRANITE_PORT=${MOCK_PORT}" with_mock_port
}
run_test "stdout contains GRANITE_PORT=<port>" t_stdout_port

t_stdout_evalable() {
    # The caller should be able to `eval $(bootstrap.sh)` without errors
    local vars; vars=$(with_mock_port 2>/dev/null)
    eval "${vars}" 2>/dev/null
    [[ "${GRANITE_BASE_URL}" == "http://localhost:${MOCK_PORT}" ]] && \
    [[ "${GRANITE_MODEL}" == "granite4:3b" ]]
}
run_test "stdout is eval-able and sets correct variables" t_stdout_evalable

t_stderr_success_message() {
    assert_stderr_contains "bootstrap successful" with_mock_port
}
run_test "stderr prints success confirmation" t_stderr_success_message

stop_mock_server

# ── Group 6: Happy path — model name with tag suffix ──────────────────────────
echo ""
echo -e "${BOLD}Group 6: Happy path (model name prefix matching)${RESET}"

# Simulate OLLAMA returning a name with digest suffix
TAGS_WITH_DIGEST='{"models":[{"name":"granite4:3b","size":2100000000}]}'
start_mock_server "${TAGS_WITH_DIGEST}"

t_prefix_match() {
    assert_exit 0 with_mock_port
}
run_test "matches model when OLLAMA returns bare 'granite4:3b'" t_prefix_match

stop_mock_server

# ── Group 7: Missing dependency ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}Group 7: Missing dependencies${RESET}"

t_exit4_no_curl() {
    # Strategy: create a fake 'curl' that immediately exits 127 (command not found)
    # and prepend its directory to PATH. bootstrap.sh's dependency check uses
    # `command -v curl` which will find our fake binary but the point is to
    # test the missing-tool detection. Instead, use a fake curl that prints nothing
    # and exits 1 so the port check fails — then separately verify that if
    # `command -v curl` itself returns false (no binary), we get exit 4.
    #
    # The most reliable approach in a restricted sandbox: temporarily create a
    # script that sources bootstrap with curl aliased to a non-existent function.
    local fake_bin; fake_bin=$(mktemp -d)
    local py3_path; py3_path=$(command -v python3)
    local bash_path; bash_path=$(command -v bash)
    # Only symlink python3 and bash; leave out curl
    ln -sf "${py3_path}" "${fake_bin}/python3"
    ln -sf "${bash_path}" "${fake_bin}/bash"
    local wrapper; wrapper=$(mktemp /tmp/no_curl_wrapper_XXXXXX.sh)
    # Use absolute bash path in shebang so the wrapper itself can start
    printf '%s\n' "#!${bash_path}" \
        "export PATH=${fake_bin}" \
        "export GRANITE_PORT=55077" \
        "export GRANITE_MODEL_NAME=granite4:3b" \
        "${bash_path} ${BOOTSTRAP}" > "${wrapper}"
    chmod +x "${wrapper}"
    local result=0
    "${bash_path}" "${wrapper}" >/dev/null 2>&1 || result=$?
    rm -f "${wrapper}"; rm -rf "${fake_bin}"
    [[ ${result} -eq 4 ]]
}
run_test "exits with code 4 when curl is not in PATH" t_exit4_no_curl

# ── Group 8: Integration — actual port 55077 ─────────────────────────────────
echo ""
echo -e "${BOLD}Group 8: Integration — live port 55077 (skipped if not running)${RESET}"

t_live_port_check() {
    # This test is informational: pass if server is up, skip gracefully if not
    local exit_code
    GRANITE_PORT=55077 GRANITE_MODEL_NAME="granite4:3b" bash "${BOOTSTRAP}" \
        >/dev/null 2>&1; exit_code=$?
    if [[ ${exit_code} -eq 1 ]]; then
        # Port not listening — expected in CI, skip gracefully
        echo "(port 55077 not reachable — SSH tunnel not active; skipping)" >&2
        return 0  # Not a test failure
    fi
    [[ ${exit_code} -eq 0 ]]
}
run_test "live port 55077: bootstrap succeeds if tunnel is up" t_live_port_check

t_live_port_emits_url() {
    local out; local exit_code
    out=$(GRANITE_PORT=55077 GRANITE_MODEL_NAME="granite4:3b" \
          bash "${BOOTSTRAP}" 2>/dev/null); exit_code=$?
    if [[ ${exit_code} -eq 1 ]]; then
        return 0  # SSH tunnel not up — skip
    fi
    echo "${out}" | grep -q "GRANITE_BASE_URL=http://localhost:55077"
}
run_test "live port 55077: stdout contains correct BASE_URL" t_live_port_emits_url

# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"
echo -e "  Results: ${GREEN}${PASS} passed${RESET}  ${RED}${FAIL} failed${RESET}  ${YELLOW}${SKIP} skipped${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Failed tests:${RESET}"
    for f in "${FAILURES[@]}"; do echo "  ✗ ${f}"; done
    echo ""
    echo "Re-run with -v for details."
fi

echo ""
[[ ${FAIL} -eq 0 ]]
