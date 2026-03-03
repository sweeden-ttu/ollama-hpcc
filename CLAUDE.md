<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# HPCC Ollama Job Submission Pipeline

Here's an **updated automated pipeline** that integrates the **ollama-hpcc README instructions** for proper Ollama job submission using the provided aliases and tunneling procedures.[^1]

## Batch Job Pipeline (Recommended)

### Step 1. Check Current Jobs

```bash
hpcc-jobs
```


### Step 2. Submit Ollama Batch Job

Use model-specific aliases for one-command submission:

```bash
granite          # granite4:3b model (default)
deepseek         # deepseek-coder model  
codellama        # codellama model
qwen             # qwen model
```

**Example output:**

```
Submitted batch job 12345
Node: cpu-01-42
Port: 34935
```


### Step 3. Create SSH Tunnel (From Mac)

Using the **node** and **port** from Step 2 output:

```bash
ssh sweeden@login.hpcc.ttu.edu -L 34935:cpu-01-42:34935
```


### Step 4. Connect Locally to Ollama

```bash
OLLAMA_HOST=127.0.0.1:34935 ollama list
OLLAMA_HOST=127.0.0.1:34935 ollama run granite4:3b
```


***

## Interactive Pipeline

### Step 1. Start Interactive GPU Session

```bash
granite-interactive    # or deepseek-interactive, etc.
```

This automatically:

1. Requests GPU node via `/etc/slurm/scripts/interactive -p nocona`
2. Starts Ollama server on dynamic port
3. Displays **hostname** and **port**

### Step 2. Note Host/Port from Output

```
Node: cpu-01-42
Port: 34935
```


### Step 3. Tunnel from Mac (Same as Batch)

```bash
ssh sweeden@login.hpcc.ttu.edu -L 34935:cpu-01-42:34935
```


***

## Complete Automation Script

Save as `~/scripts/hpcc-ollama-pipeline.zsh`:

```zsh
#!/bin/zsh
# Automated Ollama HPCC Pipeline

MODEL=${1:-granite}

echo "🔍 Checking jobs..."
hpcc-jobs

echo "🚀 Submitting $MODEL batch job..."
NODE_PORT=$($MODEL 2>&1 | grep -E "(Node|Port):" | paste -sd ' ')

if [[ -z "$NODE_PORT" ]]; then
    echo "❌ Job submission failed"
    exit 1
fi

read NODE PORT <<< "$NODE_PORT"
echo "✅ Job submitted! Node: $NODE, Port: $PORT"

echo "🌉 Creating tunnel..."
ssh sweeden@login.hpcc.ttu.edu -L $PORT:$NODE:$PORT -N &
TUNNEL_PID=$!

echo "🔗 Ollama ready at 127.0.0.1:$PORT"
echo "💡 Test with: OLLAMA_HOST=127.0.0.1:$PORT ollama list"
echo "🛑 Kill tunnel: kill $TUNNEL_PID"

# Debug info
echo ""
echo "Tunnel debugging:"
echo "lsof -i :$PORT"
echo "curl -v http://127.0.0.1:$PORT/api/tags"
```

**Usage:**

```bash
chmod +x ~/scripts/hpcc-ollama-pipeline.zsh
hpcc-ollama-pipeline.zsh granite
hpcc-ollama-pipeline.zsh deepseek
```


***

## Job Management Commands

| Command | Purpose |
| :-- | :-- |
| `hpcc-jobs` | View queued/running jobs |
| `hpcc-login` | SSH to login node |
| `hpcc "squeue -u $USER"` | Run any Slurm command remotely |
| `hpcc-git-pull` | Update ollama-hpcc repo on HPCC |


***

## Tunnel Debugging Checklist

If connection fails:

1. **Verify tunnel:**

```bash
lsof -i :34935           # Should show SSH process
curl -v http://127.0.0.1:34935/api/tags
```

2. **Correct format:** `ssh sweeden@login.hpcc.ttu.edu -L pppp:NODE:pppp`
3. **Node name** must match exactly from interactive output (e.g., `cpu-01-42`)

This pipeline eliminates manual steps and follows the exact **ollama-hpcc** procedures from your README![^1]

<div align="center">⁂</div>

[^1]: README.md

