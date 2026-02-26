#!/usr/bin/env python3
from flask import Flask, request, jsonify
import subprocess
import json
import os
from datetime import datetime

app = Flask(__name__)

JOBS_FILE = os.path.expanduser("~/ollama-hpcc/jobs.json")


def load_jobs():
    if os.path.exists(JOBS_FILE):
        with open(JOBS_FILE, "r") as f:
            return json.load(f)
    return {}


def save_jobs(jobs):
    os.makedirs(os.path.dirname(JOBS_FILE), exist_ok=True)
    with open(JOBS_FILE, "w") as f:
        json.dump(jobs, f, indent=2)


COMMANDS = {
    "jobs": "ssh -q sweeden@login.hpcc.ttu.edu 'squeue -u sweeden'",
    "granite": "ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && sbatch scripts/run_granite_ollama.sh'",
    "deepseek": "ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && sbatch scripts/run_deepseek_ollama.sh'",
    "codellama": "ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && sbatch scripts/run_codellama_ollama.sh'",
    "qwen": "ssh -q sweeden@login.hpcc.ttu.edu 'cd ~/ollama-hpcc && sbatch scripts/run_qwen-coder_ollama.sh'",
    "cancel": lambda job_id: f"ssh -q sweeden@login.hpcc.ttu.edu 'scancel {job_id}'",
}


@app.route("/run/<command>", methods=["POST"])
@app.route("/run/<command>/<arg>", methods=["POST"])
def run_command(command, arg=None):
    if command not in COMMANDS:
        return jsonify({"error": "Unknown command"}), 404

    cmd = COMMANDS[command]
    if callable(cmd):
        cmd = cmd(arg)

    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=60
        )

        # Track job if it's a submit command
        if command in ["granite", "deepseek", "codellama", "qwen"]:
            job_id = result.stdout.strip()
            if job_id.isdigit():
                jobs = load_jobs()
                jobs[job_id] = {
                    "model": command,
                    "submitted": datetime.now().isoformat(),
                    "status": "submitted",
                }
                save_jobs(jobs)

        return jsonify(
            {
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode,
            }
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/job/<job_id>", methods=["GET"])
def get_job(job_id):
    jobs = load_jobs()
    if job_id in jobs:
        return jsonify(jobs[job_id])
    return jsonify({"error": "Job not found"}), 404


@app.route("/job/<job_id>/complete", methods=["POST"])
def job_complete(job_id):
    jobs = load_jobs()
    if job_id in jobs:
        jobs[job_id]["status"] = "completed"
        jobs[job_id]["completed"] = datetime.now().isoformat()
        save_jobs(jobs)
        return jsonify({"status": "completed", "job": jobs[job_id]})
    return jsonify({"error": "Job not found"}), 404


@app.route("/job/<job_id>/fail", methods=["POST"])
def job_fail(job_id):
    jobs = load_jobs()
    if job_id in jobs:
        jobs[job_id]["status"] = "failed"
        jobs[job_id]["failed"] = datetime.now().isoformat()
        save_jobs(jobs)
        return jsonify({"status": "failed", "job": jobs[job_id]})
    return jsonify({"error": "Job not found"}), 404


@app.route("/jobs", methods=["GET"])
def list_jobs():
    return jsonify(load_jobs())


@app.route("/commands", methods=["GET"])
def list_commands():
    return jsonify({"commands": list(COMMANDS.keys())})


if __name__ == "__main__":
    print("Starting HPCC command server on http://localhost:8765")
    print("Available commands: jobs, granite, deepseek, codellama, qwen")
    print("Job tracking endpoints:")
    print("  GET  /job/<job_id>     - Get job status")
    print("  POST /job/<job_id>/complete - Mark job complete")
    print("  POST /job/<job_id>/fail    - Mark job failed")
    print("  GET  /jobs            - List all tracked jobs")
    app.run(port=8765)
