# AGENTS.md - ollama-hpcc

Ollama on HPCC cluster. Port mapping aligns with **GlobPretect/docs/AGENTS.md**.

## Ollama port mapping (canonical)

| Environment | granite | deepseek | qwen-coder | codellama |
|-------------|---------|----------|------------|-----------|
| **Debug (VPN)** | 55077 | 55088 | 66044 | 66033 |
| **Testing +1 (macOS)** | 55177 | 55188 | 66144 | 66133 |
| **Testing +2 (RockyLinux)** | 55277 | 55288 | 66244 | 66233 |
| **Release +3** | 55377 | 55388 | 66344 | 66333 |

**GitHub workflow actions:** Workflows that use **@granite**, **@deepseek**, **@qwen-coder**, or **@codellama** must call the Ollama API on the port for that model (see table above for the environment in use).

See also: `docs/CONTAINER_DEPLOYMENT.md`, `docs/CONTEXT_KEYS.md`.
