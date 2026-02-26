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

2. **Note the node name and dynamic port** from the job output (or from interactive nocona session)

3. **Create SSH tunnel** (use this format):
   - Step 1: Login to interactive nocona on HPCC: `/etc/slurm/scripts/interactive -p nocona`
   - Step 2: Note the node name (e.g. `cpu-NN-nn`) and port from the job/session
   - Step 3: From your Mac:
   ```bash
   ssh sweeden@login.hpcc.ttu.edu -L pppp:NODE:pppp
   ```
   Substitute the node name and port from the previous step for `NODE` and `pppp` respectively.

4. **Connect locally** to `http://localhost:<pppp>`

See also: `docs/CONTAINER_DEPLOYMENT.md`, `docs/CONTEXT_KEYS.md`.
