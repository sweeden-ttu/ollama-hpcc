#!/usr/bin/env python3
"""
langchain_granite_example.py
────────────────────────────
LangChain integration with IBM Granite 4 (granite4:3b) served by OLLAMA
on localhost:55077 (TTU HPCC matador GPU cluster, Debug/VPN static port).

CS 5374 — Software Verification & Validation, Spring 2026
Texas Tech University

HOW TO INVOKE THE GRANITE AGENT AND RUN THIS SCRIPT
====================================================

Step 1 — Tell the agent to start Granite on HPCC (run in Cowork / terminal):
─────────────────────────────────────────────────────────────────────────────
  "Use the granite agent to submit a SLURM job on HPCC for the granite model
   and give me the SSH tunnel command for port 55077."

  Claude will:
    a) ssh sweeden@login.hpcc.ttu.edu
    b) cd ~/ollama-hpcc && sbatch scripts/run_granite_ollama.sh
    c) Wait for the job to start, then run ollama_port_map.sh --env debug
    d) Print the SSH tunnel command, e.g.:
         ssh -L 55077:127.0.0.1:<DYNAMIC_PORT> -i ~/.ssh/id_rsa \\
             sweeden@login.hpcc.ttu.edu

Step 2 — Open the SSH tunnel (copy-paste from Claude's output):
─────────────────────────────────────────────────────────────────
  ssh -L 55077:127.0.0.1:<DYNAMIC_PORT> -i ~/.ssh/id_rsa \\
      sweeden@login.hpcc.ttu.edu
  (leave this terminal open)

Step 3 — Install dependencies locally (once):
─────────────────────────────────────────────
  pip install langchain langchain-community langchain-ollama

Step 4 — Run this script:
─────────────────────────
  python3 langchain_granite_example.py

Step 5 — Verify granite agent health before any assignment task:
────────────────────────────────────────────────────────────────
  "Use the granite agent to check if port 55077 is healthy."
  Claude runs bootstrap.sh which exits 0 on success, or prints a
  clear error + fix instructions if the tunnel is not up.

USAGE
=====
  python3 langchain_granite_example.py                  # basic demo
  python3 langchain_granite_example.py --verify-only    # health check only
  python3 langchain_granite_example.py --prompt "..."   # single prompt
  python3 langchain_granite_example.py --vv             # V&V demo (CS 5374)
"""

import sys
import argparse
import subprocess
import json
import textwrap
from pathlib import Path

# ── Fail-fast bootstrap ───────────────────────────────────────────────────────
GRANITE_PORT = 55077
GRANITE_MODEL = "granite4:3b"
GRANITE_BASE_URL = f"http://localhost:{GRANITE_PORT}"
BOOTSTRAP_SCRIPT = Path(__file__).parent / "granite-agent" / "scripts" / "bootstrap.sh"


def bootstrap_check() -> dict:
    """
    Run bootstrap.sh before any LangChain call.
    Exits the process with a clear error if the granite server is unreachable.
    Returns a dict with GRANITE_BASE_URL, GRANITE_MODEL, GRANITE_PORT on success.
    """
    print(f"[bootstrap] Checking Granite server on port {GRANITE_PORT}...")

    if BOOTSTRAP_SCRIPT.exists():
        result = subprocess.run(
            ["bash", str(BOOTSTRAP_SCRIPT)],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print("\n" + "═" * 60)
            print("  GRANITE AGENT BOOTSTRAP FAILED")
            print("═" * 60)
            print(result.stderr)
            print("═" * 60)
            print("\nThis script requires the granite4:3b OLLAMA server on port 55077.")
            print("To start it:")
            print("  1. ssh sweeden@login.hpcc.ttu.edu")
            print("     cd ~/ollama-hpcc && sbatch scripts/run_granite_ollama.sh")
            print("  2. bash ~/ollama-hpcc/scripts/ollama_port_map.sh --env debug")
            print("  3. Copy-paste the printed SSH tunnel command and leave it open.")
            sys.exit(result.returncode)

        # Parse eval-able key=value output
        env_vars = {}
        for line in result.stdout.strip().splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                env_vars[k] = v
        print(f"[bootstrap] ✓ Connected — {env_vars.get('GRANITE_MODEL')} "
              f"at {env_vars.get('GRANITE_BASE_URL')}")
        return env_vars
    else:
        # Fallback: direct HTTP check if bootstrap.sh not present
        import urllib.request, urllib.error
        try:
            with urllib.request.urlopen(
                f"{GRANITE_BASE_URL}/api/tags", timeout=5
            ) as resp:
                data = json.loads(resp.read())
            models = [m["name"] for m in data.get("models", [])]
            if not any(GRANITE_MODEL in m for m in models):
                print(f"[bootstrap] ✗ Model {GRANITE_MODEL} not found. "
                      f"Available: {models}")
                sys.exit(2)
            print(f"[bootstrap] ✓ {GRANITE_MODEL} ready at {GRANITE_BASE_URL}")
            return {
                "GRANITE_BASE_URL": GRANITE_BASE_URL,
                "GRANITE_MODEL": GRANITE_MODEL,
                "GRANITE_PORT": str(GRANITE_PORT),
            }
        except (urllib.error.URLError, OSError) as e:
            print(f"\n[bootstrap] ✗ Cannot reach {GRANITE_BASE_URL}: {e}")
            print("Is the SSH tunnel open? Run:")
            print("  bash scripts/ollama_port_map.sh --env debug")
            sys.exit(1)


# ── LangChain setup ───────────────────────────────────────────────────────────
def build_llm(base_url: str, model: str):
    """
    Build a LangChain LLM pointing at the local OLLAMA Granite server.
    Uses langchain-ollama (preferred) or langchain-community as fallback.
    """
    try:
        from langchain_ollama import OllamaLLM
        llm = OllamaLLM(
            model=model,
            base_url=base_url,
            temperature=0.1,       # low temp → deterministic, good for V&V
            num_predict=512,
        )
        print(f"[langchain] Using langchain-ollama OllamaLLM")
        return llm
    except ImportError:
        pass

    try:
        from langchain_community.llms import Ollama
        llm = Ollama(
            model=model,
            base_url=base_url,
            temperature=0.1,
            num_predict=512,
        )
        print(f"[langchain] Using langchain-community Ollama")
        return llm
    except ImportError:
        print("ERROR: Install langchain-ollama or langchain-community:")
        print("  pip install langchain langchain-ollama")
        sys.exit(1)


def build_chat_model(base_url: str, model: str):
    """
    Build a LangChain ChatModel for multi-turn conversation.
    """
    try:
        from langchain_ollama import ChatOllama
        return ChatOllama(
            model=model,
            base_url=base_url,
            temperature=0.1,
            num_predict=512,
        )
    except ImportError:
        pass
    try:
        from langchain_community.chat_models import ChatOllama
        return ChatOllama(
            model=model,
            base_url=base_url,
            temperature=0.1,
        )
    except ImportError:
        return None


# ── Demo tasks ────────────────────────────────────────────────────────────────
def demo_basic(llm):
    """Simple single-prompt invocation."""
    print("\n" + "─" * 60)
    print("DEMO 1: Basic prompt invocation")
    print("─" * 60)
    prompt = "In one sentence, what is IBM Granite 4?"
    print(f"Prompt: {prompt}\n")
    response = llm.invoke(prompt)
    print(f"Granite: {response.strip()}")


def demo_chain(llm):
    """LangChain prompt template + chain."""
    from langchain_core.prompts import PromptTemplate

    print("\n" + "─" * 60)
    print("DEMO 2: PromptTemplate chain")
    print("─" * 60)

    template = PromptTemplate.from_template(
        "You are a software testing expert. "
        "List 3 {test_type} test cases for a function that {description}. "
        "Be concise — one line per test case."
    )
    chain = template | llm

    result = chain.invoke({
        "test_type": "boundary value",
        "description": "returns True if a given integer is prime"
    })
    print("Prompt: Boundary value tests for isPrime(n)")
    print(f"\nGranite:\n{result.strip()}")


def demo_vv_workflow(llm):
    """
    CS 5374 Software V&V demo:
    Simulate a verification & validation workflow using LangChain chains.
    Models: requirements → test oracle → test verdict
    """
    from langchain_core.prompts import PromptTemplate
    from langchain_core.output_parsers import StrOutputParser

    print("\n" + "─" * 60)
    print("DEMO 3: CS 5374 V&V Workflow — Requirements → Oracle → Verdict")
    print("─" * 60)

    parser = StrOutputParser()

    # Stage 1: Formalise a requirement
    req_prompt = PromptTemplate.from_template(
        "You are a software requirements analyst. "
        "Formalise the following informal requirement into a precise, "
        "testable requirement statement (one sentence, no bullet points):\n\n"
        "Informal: {informal_req}"
    )
    req_chain = req_prompt | llm | parser

    # Stage 2: Generate a test oracle from the formalised requirement
    oracle_prompt = PromptTemplate.from_template(
        "You are a software test engineer. "
        "Given this formalised requirement:\n  {formal_req}\n\n"
        "Write a Python assert statement (one line) that serves as a test oracle "
        "for the function call shown. Use realistic input/output values.\n"
        "Function call: {func_call}"
    )
    oracle_chain = oracle_prompt | llm | parser

    # Stage 3: Determine pass/fail verdict
    verdict_prompt = PromptTemplate.from_template(
        "You are a test execution engine. "
        "Given the test oracle:\n  {oracle}\n\n"
        "And the actual output:\n  {actual_output}\n\n"
        "Reply with exactly one word: PASS or FAIL, then a one-sentence explanation."
    )
    verdict_chain = verdict_prompt | llm | parser

    # Run the workflow
    informal = "The login function should reject empty passwords"
    func_call = "login(username='alice', password='')"
    actual = "Returns False (login rejected)"

    print(f"\nInformal requirement: \"{informal}\"")
    print(f"Function under test:  {func_call}")
    print(f"Actual output:        {actual}")

    print("\n[Stage 1] Formalising requirement...")
    formal_req = req_chain.invoke({"informal_req": informal})
    print(f"  → {formal_req.strip()}")

    print("\n[Stage 2] Generating test oracle...")
    oracle = oracle_chain.invoke({
        "formal_req": formal_req.strip(),
        "func_call": func_call
    })
    print(f"  → {oracle.strip()}")

    print("\n[Stage 3] Computing verdict...")
    verdict = verdict_chain.invoke({
        "oracle": oracle.strip(),
        "actual_output": actual
    })
    print(f"  → {verdict.strip()}")


def demo_conversation(chat_model):
    """Multi-turn chat session with memory."""
    from langchain_core.messages import HumanMessage, SystemMessage

    print("\n" + "─" * 60)
    print("DEMO 4: Multi-turn conversation (ChatOllama)")
    print("─" * 60)

    messages = [
        SystemMessage(content=(
            "You are a concise software V&V assistant for CS 5374 at Texas Tech. "
            "Keep answers to 2 sentences max."
        )),
        HumanMessage(content="What is the difference between verification and validation?"),
    ]

    print("User: What is the difference between verification and validation?")
    response = chat_model.invoke(messages)
    print(f"Granite: {response.content.strip()}")

    messages.append(response)
    messages.append(HumanMessage(
        content="Give me one real-world example of each from embedded systems."
    ))

    print("\nUser: Give me one real-world example of each from embedded systems.")
    response2 = chat_model.invoke(messages)
    print(f"Granite: {response2.content.strip()}")


# ── Entry point ───────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="LangChain + Granite4 on HPCC port 55077"
    )
    parser.add_argument("--verify-only", action="store_true",
                        help="Only check bootstrap, don't run demos")
    parser.add_argument("--prompt", type=str, default=None,
                        help="Send a single prompt and print the response")
    parser.add_argument("--vv", action="store_true",
                        help="Run the CS 5374 V&V workflow demo only")
    args = parser.parse_args()

    print("\n" + "═" * 60)
    print("  LangChain → Granite4:3b @ localhost:55077")
    print("  TTU RedRaider HPCC | CS 5374 Spring 2026")
    print("═" * 60)

    # ── Step 1: Bootstrap (always) ────────────────────────────────────────────
    env = bootstrap_check()
    base_url = env.get("GRANITE_BASE_URL", GRANITE_BASE_URL)
    model    = env.get("GRANITE_MODEL",    GRANITE_MODEL)

    if args.verify_only:
        print("\n✓ Bootstrap passed — server is healthy.")
        return

    # ── Step 2: Build LangChain LLM ───────────────────────────────────────────
    llm        = build_llm(base_url, model)
    chat_model = build_chat_model(base_url, model)

    # ── Step 3: Run demos ─────────────────────────────────────────────────────
    if args.prompt:
        print(f"\nPrompt: {args.prompt}\n")
        print(llm.invoke(args.prompt).strip())
        return

    if args.vv:
        demo_vv_workflow(llm)
        return

    # Full demo suite
    demo_basic(llm)
    demo_chain(llm)
    demo_vv_workflow(llm)
    if chat_model:
        demo_conversation(chat_model)
    else:
        print("\n[Skipping Demo 4 — ChatOllama not available]")

    print("\n" + "═" * 60)
    print("  All demos complete.")
    print(f"  Model: {model} | URL: {base_url}")
    print("═" * 60 + "\n")


if __name__ == "__main__":
    main()
