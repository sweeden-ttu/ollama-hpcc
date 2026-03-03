<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Wrong.  Use these instructions:

For most problems you will want to run ollama with GPU assistance. For batch sessions on Matador, you can request either one or two GPUs and a suitable number of cpus.
You can choose any number from 1 to 20 cpus for a single GPU job or from 1 to 40 cpus for a 2-GPU job. 8 should be fine

For further information, see our [Job Submission Guide](https://www.depts.ttu.edu/hpcc/userguides/JobSubmission.php). 
The commands below can be used in either the run script for a batch or in an interactive session.   For interactive sessions run login to the compute node on partition matador

`etc/slurm/scripts/interactive -c 8 -g 1 -p matador’

Should I ever use the default OLLAMA port number? 
No do not ever use the default OLLAMA port.  You will request a one-time free number before starting an instance of ollama server in the background as follows:
export OLPORT=$(python3 -c "import socket; s = socket.socket(); s.bind(('', 0));
print(s.getsockname()[1]);s.close()"); 
export OLLAMA_HOST=127.0.0.1:$OLPORT;

export OLLAMA_BASE_URL="http://localhost:\$OLPORT";

module load gcc/13.2.0 cuda/12.9.0;

~/ollama-latest/bin/ollama serve >ollama_$OLPORT.log 2>ollama_$OLPORT.err \&

Within that same session, you should be able to connect to the running ollama server on that node and port using the command

For example, the command below should work to start an instance of the llama3.1 model running on that particular ollama server in the background. This is just an example; you should be able to choose any of the available models from the [ollama library](https://ollama.com/library). The "--verbose" flag is optional but will allow you to see the speed of the responses to your prompts. If further information is needed, you can add "export OLLAMA_DEBUG=1" to the commands issued before starting the server above.
~/ollama-latest/bin/ollama run granite4:3b --verbose

You’re right—thanks for the correction and for providing the exact Texas Tech HPCC‑specific workflow. Here’s that text cleaned up into a clear, runnable set of instructions you can use on **RedRaider / Matador**.

***

### When to use GPU and how many resources

- Use **GPU assist** for most Ollama workloads.
- For **batch jobs on Matador**:
    - 1 GPU: request **1–20 CPUs** (8 is usually fine).
    - 2 GPUs: request **1–40 CPUs**. [text]

> For more details see the HPCC **Job Submission Guide**:
> [https://www.depts.ttu.edu/hpcc/userguides/JobSubmission.php](https://www.depts.ttu.edu/hpcc/userguides/JobSubmission.php)

***

### Interactive session on Matador

Run this on your login node to get to a Matador compute node:

```bash
/etc/slurm/scripts/interactive -c 8 -g 1 -p matador
```

This gives you 1 GPU and 8 CPUs; you can then load modules and start Ollama in that session. [text]

***

### Do **not** use the default Ollama port

Never hard‑code the default Ollama port number. Instead, generate a **one‑time free port** in each session:

```bash
export OLPORT=$(python3 -c "import socket; s = socket.socket(); s.bind(('', 0)); print(s.getsockname()[1]); s.close()")
export OLLAMA_HOST=127.0.0.1:$OLPORT
export OLLAMA_BASE_URL="http://localhost:$OLPORT"
```

This ensures you avoid port conflicts with other users on the shared node. [text]

***

### Start the Ollama server in the background

After setting the port and `OLLAMA_HOST`, load the required modules and start the server:

```bash
module load gcc/13.2.0 cuda/12.9.0
~/ollama-latest/bin/ollama serve >ollama_$OLPORT.log 2>ollama_$OLPORT.err &
```

This will:

- Start `ollama` in the background on the assigned port.

```
- Log output to `ollama_<PORT>.log` and errors to `ollama_<PORT>.err`. [text]
```

If you want more detail, you can enable debug output before starting the server:

```bash
export OLLAMA_DEBUG=1
```


***

### Run a model against the local Ollama server

Once the server is running, you can run any model from the Ollama library on that node. For example:

```bash
~/ollama-latest/bin/ollama run granite4:3b --verbose
```

- Replace `granite4:3b` with any model from the Ollama library: [https://ollama.com/library](https://ollama.com/library).
- The `--verbose` flag shows response speed and extra details; omit it if you prefer cleaner output. [text]

You can also run this same command pattern from a **batch script** (no interactive session required) as long as the `OLLAMA_HOST` and `OLLAMA_BASE_URL` environment are set in the script. [text]

***

If you tell me whether you want a **batch script template** (`.slurm`) for Matador (e.g., for `granite4:3b` or `llama3.1`) plus how many GPUs you plan to use, I can write out a ready‑to‑submit script you can paste into your HPCC environment.

