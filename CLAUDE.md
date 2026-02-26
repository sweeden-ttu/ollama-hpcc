This folder is the slurm scripts for running multiple OLLAMA instances which can be connected to over static port numbers

The commands below can be used in either the run script for a batch or in an interactive session.

Use mpi_run run_$MODEL_ollama.sh

```slurm
export OLPORT=$(python3 -c "import socket; s = socket.socket(); 
s.bind(('', 0));
print(s.getsockname()[1]);s.close()"); 
export OLLAMA_HOST=127.0.0.1:$OLPORT; 
export OLLAMA_BASE_URL="http://localhost:$OLPORT"; 

module load gcc;
module load cuda/12.9.0;

~/ollama-latest/bin/ollama serve > ~/$MODEL_$OLPORT.log 2>~/$MODEL_$OLPORT.err &

# wait 5 seconds 

# Within that same session, you should be able to 
# connect to the running ollama server on that node
# and port using the command 

~/ollama-latest/bin/ollama run $MODEL$MODEL_VERSION --verbose

```

The choice of $MODEL=[granite deepseek qwen-coder codellama]

The $MODEL_VERSION should be looked up on ollama.com for the latest version which can be pulled and is less than 10billion parameters big.

Help me generate all of the utility scripts and slurm scripts and mpi run helpers which can be run on the HPCC RedRaider cluster.  Use this guide for scheduling jobs:
https://www.depts.ttu.edu/hpcc/userguides/Job_User_Guide.pdf