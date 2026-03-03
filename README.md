1. How you know the node name and port
If you use the batch job (sbatch slurm_submit.sh):
After the job starts, the .out file (e.g. 12345_graniteGPU.out) is written in the directory where you ran sbatch.
It now contains lines like:
NODE=matador1 (or whatever node the job got)
PORT=41234 (the dynamic port)
TUNNEL_FROM_MAC: ssh -L 41234:matador1:41234 $USER@login.hpcc.ttu.edu
So you know the node name and port by reading that file:
# On HPCC, after job is running:grep -E 'NODE=|PORT=|TUNNEL_FROM_MAC' <jobid>_graniteGPU.out# Or:cat <jobid>_graniteGPU.out
You can also get the node from Slurm (from the same machine you submitted from):
squeue -u $USER -o "%.18i %.9P %.30j %.8u %.2t %.10M %.6D %R"# Nodelist is the last column (%R)
2. Port forward setup
Port forwarding is done on your Mac, not in the Slurm script. The script only prints the exact command you should run on your Mac.
On your Mac:
Get NODE and PORT from the job’s .out file (or from the TUNNEL_FROM_MAC line).
Start the tunnel (one SSH session, leave it open):
ssh -L PORT:NODE:PORT $USER@login.hpcc.ttu.edu
Example (if the .out file says port 41234 and node matador1):
ssh -L 41234:matador1:41234 sweeden@login.hpcc.ttu.edu
In another terminal on your Mac, use Ollama:
OLLAMA_HOST=127.0.0.1:41234 ollama listOLLAMA_HOST=127.0.0.1:41234 ollama run granite4:3b
So: port forward is set up on the Mac with that ssh -L command; the tunnel script on HPCC (slurm_tunnel.sh) only prints instructions and doesn’t create the forward itself.
3. Quick reference
Step	Where	Command / action
Start server	HPCC	sbatch job/slurm_submit.sh [granite\|deepseek\|codellama\|qwen]
Get node & port	HPCC	grep -E 'NODE=|PORT=|TUNNEL_FROM_MAC' <jobid>_*GPU.out
Create tunnel	Mac	ssh -L PORT:NODE:PORT sweeden@login.hpcc.ttu.edu (keep this session open)
Use Ollama	Mac	OLLAMA_HOST=127.0.0.1:PORT ollama run <model>
slurm_tunnel.sh is for getting an interactive Slurm shell (e.g. to run Ollama by hand in that shell). For your batch job, you only need the .out file to get NODE and PORT, then run the ssh -L and OLLAMA_HOST=... ollama commands on your Mac as above.