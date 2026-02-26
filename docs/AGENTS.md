# AGENTS.md - ollama-hpcc

Ollama on HPCC cluster using dynamic ports.

## Dynamic Ports

Jobs use dynamic ports assigned by the operating system. The port is:
1. Displayed in the job output when the job starts
2. Available from the `.info` files in `~/ollama-logs/`
3. Automatically detected by `bootstrap.sh` in the granite-agent

## Usage

1. **Start a job:**
   - Batch: `granite`, `deepseek`, `codellama`, or `qwen`
   - Interactive: `granite-interactive`, etc.

2. **Note the dynamic port** from the job output

3. **Create SSH tunnel:**
   ```bash
   ssh -L <PORT>:127.0.0.1:<PORT> -i ~/.ssh/id_rsa sweeden@login.hpcc.ttu.edu
   ```

4. **Connect locally** to `http://localhost:<PORT>`

See also: `docs/CONTAINER_DEPLOYMENT.md`, `docs/CONTEXT_KEYS.md`.
