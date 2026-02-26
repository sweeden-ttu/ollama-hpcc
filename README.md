# ollama-hpcc

Ollama LLM server and client for HPCC RedRaider GPU clusters.

## Description

This project provides a complete solution for running Ollama LLM servers on HPCC (High Performance Computing Center) RedRaider GPU clusters. It includes container deployment, Slurm job integration, and Python client libraries.

## Features

- **GPU inference on HPCC**: Deploy Ollama models on NVIDIA GPU nodes
- **Slurm job integration**: Submit and manage Ollama servers as Slurm jobs
- **Podman containers**: Run Ollama in isolated containers using Podman
- **Python client**: Easy Python API for interacting with Ollama servers

## Ollama port mapping (canonical)

Same mapping across all Ollama projects. Workflows that use **@granite**, **@deepseek**, **@qwen-coder**, or **@codellama** call Ollama on the port for that model and environment.

| Environment        | granite | deepseek | qwen-coder | codellama |
|--------------------|---------|----------|------------|-----------|
| Debug (VPN)        | 55077   | 55088    | 66044      | 66033     |
| Testing +1 (macOS) | 55177   | 55188    | 66144      | 66133     |
| Testing +2 (Rocky) | 55277   | 55288    | 66244      | 66233     |
| Release +3        | 55377   | 55388    | 66344      | 66333     |

See **docs/AGENTS.md** for details.

## Related Projects

- [toolchain-module](https://github.com/sdw3098/toolchain-module)
- [module-toolchains](https://github.com/sdw3098/module-toolchains)
- [ollama-rocky](https://github.com/sdw3098/ollama-rocky)
- [ollama-mac](https://github.com/sdw3098/ollama-mac)
- [ollama-podman](https://github.com/sdw3098/ollama-podman)

## Installation

```bash
pip install -e src/python/
```

## Shell Aliases (macOS / zsh)

Source the aliases script in your `~/.zshrc`:

```bash
source /Users/owner/projects/ollama-hpcc/scripts/hpcc-aliases.zsh
```

Usage:
- `hpcc-login` - SSH into HPCC
- `hpcc "ls -la"` - run any command remotely
- `granite` - run granite script (DEBUG 55077)
- `granite RELEASE 55177` - override mode and port
- `codellama`, `deepseek`, `qwen` - same pattern

## License

MIT
