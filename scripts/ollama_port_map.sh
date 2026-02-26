#!/bin/bash
# =============================================================================
# ollama_port_map.sh
# Generate a JSON mapping of dynamic OLLAMA ports → static environment ports,
# and print ready-to-use SSH tunnel commands for each environment.
#
# Static port table:
#   Environment         granite  deepseek  qwen-coder  codellama
#   Debug (VPN)          55077    55088      66044       66033
#   Testing +1 (macOS)   55177    55188      66144       66133
#   Testing +2 (Rocky)   55277    55288      66244       66233
#   Release +3           55377    55388      66344       66333
#
# Usage:
#   bash ollama_port_map.sh                   # human-readable table + SSH cmds
#   bash ollama_port_map.sh --json            # write port_map.json to log dir
#   bash ollama_port_map.sh --json --stdout   # print JSON to stdout
#   bash ollama_port_map.sh --env debug       # only debug environment
#   bash ollama_port_map.sh --env testing1
#   bash ollama_port_map.sh --env testing2
#   bash ollama_port_map.sh --env release
#
# The generated SSH commands use (see README: interactive nocona, then):
#   ssh sweeden@login.hpcc.ttu.edu -L <LOCAL_PORT>:<NODE>:<REMOTE_PORT>
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/model_versions.env"

# ---------------------------------------------------------------------------
# Static port table  [env][model] = static_port
# ---------------------------------------------------------------------------
declare -A STATIC_PORTS
STATIC_PORTS[debug,granite]=55077
STATIC_PORTS[debug,deepseek]=55088
STATIC_PORTS[debug,qwen-coder]=66044
STATIC_PORTS[debug,codellama]=66033

STATIC_PORTS[testing1,granite]=55177
STATIC_PORTS[testing1,deepseek]=55188
STATIC_PORTS[testing1,qwen-coder]=66144
STATIC_PORTS[testing1,codellama]=66133

STATIC_PORTS[testing2,granite]=55277
STATIC_PORTS[testing2,deepseek]=55288
STATIC_PORTS[testing2,qwen-coder]=66244
STATIC_PORTS[testing2,codellama]=66233

STATIC_PORTS[release,granite]=55377
STATIC_PORTS[release,deepseek]=55388
STATIC_PORTS[release,qwen-coder]=66344
STATIC_PORTS[release,codellama]=66333

declare -A ENV_LABELS
ENV_LABELS[debug]="Debug (VPN)"
ENV_LABELS[testing1]="Testing +1 (macOS)"
ENV_LABELS[testing2]="Testing +2 (Rocky)"
ENV_LABELS[release]="Release +3"

ENVS=(debug testing1 testing2 release)
MODELS=(granite deepseek qwen-coder codellama)
HPCC_USER="sweeden"
HPCC_LOGIN="login.hpcc.ttu.edu"
SSH_KEY="~/.ssh/id_rsa"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
JSON_MODE=0
JSON_STDOUT=0
ENV_FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)       JSON_MODE=1 ;;
        --stdout)     JSON_STDOUT=1 ;;
        --env)        ENV_FILTER="$2"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Read dynamic ports from .info files
# ---------------------------------------------------------------------------
declare -A DYNAMIC_PORTS   # [model_key] = port  (model_key: granite|deepseek|qwen-coder|codellama)
declare -A DYNAMIC_NODES   # [model_key] = hostname
declare -A DYNAMIC_JOBS    # [model_key] = job_id

MODEL_KEYS=(granite deepseek qwen-coder codellama)
MODEL_PATTERNS=(
    "${GRANITE_MODEL}"
    "${DEEPSEEK_MODEL}"
    "${QWENCODER_MODEL}"
    "${CODELLAMA_MODEL}"
)

for i in "${!MODEL_KEYS[@]}"; do
    key="${MODEL_KEYS[$i]}"
    pattern="${MODEL_PATTERNS[$i]}"
    DYNAMIC_PORTS[$key]="N/A"
    DYNAMIC_NODES[$key]="N/A"
    DYNAMIC_JOBS[$key]="N/A"

    for info in "${OLLAMA_LOG_DIR}"/*.info; do
        [[ -f "${info}" ]] || continue
        model_val=$(grep '^MODEL=' "${info}" | cut -d= -f2)
        if [[ "${model_val}" == *"${pattern}"* ]]; then
            DYNAMIC_PORTS[$key]=$(grep '^PORT=' "${info}" | cut -d= -f2)
            DYNAMIC_NODES[$key]=$(grep '^NODE=' "${info}" | cut -d= -f2)
            DYNAMIC_JOBS[$key]=$(grep '^JOB_ID=' "${info}" | cut -d= -f2)
            break
        fi
    done
done

# ---------------------------------------------------------------------------
# Determine which environments to show
# ---------------------------------------------------------------------------
if [[ -n "${ENV_FILTER}" ]]; then
    ENVS=("${ENV_FILTER}")
fi

# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------
if [[ ${JSON_MODE} -eq 1 ]]; then
    JSON_FILE="${OLLAMA_LOG_DIR}/port_map.json"
    mkdir -p "${OLLAMA_LOG_DIR}"

    {
        echo "{"
        echo "  \"generated\": \"$(date --iso-8601=seconds)\","
        echo "  \"hpcc_user\": \"${HPCC_USER}\","
        echo "  \"hpcc_login\": \"${HPCC_LOGIN}\","
        echo "  \"environments\": {"

        env_count=${#ENVS[@]}
        env_idx=0
        for env in "${ENVS[@]}"; do
            (( env_idx++ ))
            echo "    \"${env}\": {"
            echo "      \"label\": \"${ENV_LABELS[$env]}\","
            echo "      \"models\": {"

            model_count=${#MODELS[@]}
            model_idx=0
            for model in "${MODELS[@]}"; do
                (( model_idx++ ))
                static_port="${STATIC_PORTS[$env,$model]}"
                dynamic_port="${DYNAMIC_PORTS[$model]}"
                node="${DYNAMIC_NODES[$model]}"
                job_id="${DYNAMIC_JOBS[$model]}"

                # Build SSH command only if dynamic port is known
                if [[ "${dynamic_port}" != "N/A" ]] && [[ "${node}" != "N/A" ]]; then
                    ssh_cmd="ssh -L ${static_port}:${node}:${dynamic_port} -i ${SSH_KEY} ${HPCC_USER}@${HPCC_LOGIN}"
                    tunnel_active="false"
                    # Check if a tunnel on this static port already exists
                    if ss -tlnp 2>/dev/null | grep -q ":${static_port} " || \
                       netstat -tlnp 2>/dev/null | grep -q ":${static_port} "; then
                        tunnel_active="true"
                    fi
                else
                    ssh_cmd="null"
                    tunnel_active="false"
                fi

                comma=""
                [[ ${model_idx} -lt ${model_count} ]] && comma=","
                cat <<MODELEOF
        "${model}": {
          "static_port": ${static_port},
          "dynamic_port": "${dynamic_port}",
          "node": "${node}",
          "job_id": "${job_id}",
          "ollama_base_url": "http://localhost:${static_port}",
          "ssh_tunnel_cmd": "${ssh_cmd}",
          "tunnel_active": ${tunnel_active}
        }${comma}
MODELEOF
            done

            echo "      }"
            comma=""
            [[ ${env_idx} -lt ${env_count} ]] && comma=","
            echo "    }${comma}"
        done

        echo "  }"
        echo "}"
    } > "${JSON_FILE}"

    if [[ ${JSON_STDOUT} -eq 1 ]]; then
        cat "${JSON_FILE}"
    else
        echo "Port map written to: ${JSON_FILE}"
        echo ""
        cat "${JSON_FILE}"
    fi

    exit 0
fi

# ---------------------------------------------------------------------------
# Human-readable table + SSH commands
# ---------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║              OLLAMA Static ↔ Dynamic Port Mapping                       ║"
echo "║              Generated: $(date '+%Y-%m-%d %H:%M:%S')                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Dynamic port discovery summary
echo "=== Discovered Dynamic Ports ==="
printf "  %-14s %-12s %-10s %s\n" "MODEL" "JOB_ID" "PORT" "NODE"
for model in "${MODELS[@]}"; do
    printf "  %-14s %-12s %-10s %s\n" \
        "${model}" "${DYNAMIC_JOBS[$model]}" "${DYNAMIC_PORTS[$model]}" "${DYNAMIC_NODES[$model]}"
done
echo ""

# Port mapping table per environment
for env in "${ENVS[@]}"; do
    echo "--- ${ENV_LABELS[$env]} ---"
    printf "  %-14s %10s %10s   %s\n" "MODEL" "STATIC" "DYNAMIC" "SSH TUNNEL COMMAND"
    printf "  %-14s %10s %10s   %s\n" "--------------" "----------" "----------" "---------------------------------------------"
    for model in "${MODELS[@]}"; do
        static_port="${STATIC_PORTS[$env,$model]}"
        dynamic_port="${DYNAMIC_PORTS[$model]}"
        node="${DYNAMIC_NODES[$model]}"

        if [[ "${dynamic_port}" != "N/A" ]] && [[ "${node}" != "N/A" ]]; then
            ssh_cmd="ssh -L ${static_port}:${node}:${dynamic_port} -i ${SSH_KEY} ${HPCC_USER}@${HPCC_LOGIN}"
        else
            ssh_cmd="(server not running or node unknown)"
        fi

        printf "  %-14s %10s %10s   %s\n" \
            "${model}" "${static_port}" "${dynamic_port}" "${ssh_cmd}"
    done
    echo ""
done

echo "TIP: Run with --json to write ${OLLAMA_LOG_DIR}/port_map.json"
echo "     Run with --env debug|testing1|testing2|release to filter one environment"
echo ""
