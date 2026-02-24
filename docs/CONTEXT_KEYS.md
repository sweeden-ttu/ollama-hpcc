# 20 Unique Context Keys (5 SSH Environments × 4 Ollama Models)

Each key **uniquely identifies context, sender, and receiver** for a given SSH environment and Ollama model. Use these keys in configs, commit messages, and automation to specify exactly which environment and model a message or job refers to.

## Naming scheme

- **Key format:** `{ssh_env}_{ollama_model}`
- **ssh_env** = short code for the SSH_KEY_IDENTIFIER (sender → receiver).
- **ollama_model** = short code for the OLLAMA_MODEL_IDENTIFIER.

So each of the 20 keys is **unique** and encodes:
- **Context** = which of the 20 (env + model).
- **Sender** = origin machine/user (from SSH env).
- **Receiver** = remote or consumer (HPCC, GitHub, or Ollama model).

## SSH environment codes (5)

| # | SSH_KEY_IDENTIFIER | Short code | Sender | Receiver |
|---|--------------------|------------|--------|----------|
| 1 | owner_owner_sweeden_hpcc | owner_hpcc | @macos @maclaptop (owner) | @hpcc |
| 2 | owner_owner_sweeden-ttu_github | owner_github | @macos @maclaptop (owner) | @github-actions / GitHub |
| 3 | sweeden_hpcc_sweeden-ttu_github | hpcc_github | @hpcc (sweeden) | @github-actions / GitHub |
| 4 | quay_sdw3098_sweeden_hpcc | quay_hpcc | @rockylinux @rockydesktop (quay) | @hpcc |
| 5 | quay_sdw3098_sweeden-ttu_github | quay_github | @rockylinux @rockydesktop (quay) | @github-actions / GitHub |

## Ollama model codes (4)

| # | Model identifier | Short code |
|---|------------------|------------|
| 1 | granite4 | granite |
| 2 | deepseek-r1 | deepseek |
| 3 | qwen-coder | qwen |
| 4 | codellama | codellama |

## The 20 unique keys

| # | Key | SSH env | Sender | Receiver | Model |
|---|-----|---------|--------|----------|-------|
| 1 | owner_hpcc_granite | owner_owner_sweeden_hpcc | owner@macOS | HPCC | @granite |
| 2 | owner_hpcc_deepseek | owner_owner_sweeden_hpcc | owner@macOS | HPCC | @deepseek |
| 3 | owner_hpcc_qwen | owner_owner_sweeden_hpcc | owner@macOS | HPCC | @qwen |
| 4 | owner_hpcc_codellama | owner_owner_sweeden_hpcc | owner@macOS | HPCC | @codellama |
| 5 | owner_github_granite | owner_owner_sweeden-ttu_github | owner@macOS | GitHub | @granite |
| 6 | owner_github_deepseek | owner_owner_sweeden-ttu_github | owner@macOS | GitHub | @deepseek |
| 7 | owner_github_qwen | owner_owner_sweeden-ttu_github | owner@macOS | GitHub | @qwen |
| 8 | owner_github_codellama | owner_owner_sweeden-ttu_github | owner@macOS | GitHub | @codellama |
| 9 | hpcc_github_granite | sweeden_hpcc_sweeden-ttu_github | sweeden@HPCC | GitHub | @granite |
| 10 | hpcc_github_deepseek | sweeden_hpcc_sweeden-ttu_github | sweeden@HPCC | GitHub | @deepseek |
| 11 | hpcc_github_qwen | sweeden_hpcc_sweeden-ttu_github | sweeden@HPCC | GitHub | @qwen |
| 12 | hpcc_github_codellama | sweeden_hpcc_sweeden-ttu_github | sweeden@HPCC | GitHub | @codellama |
| 13 | quay_hpcc_granite | quay_sdw3098_sweeden_hpcc | sdw3098@quay | HPCC | @granite |
| 14 | quay_hpcc_deepseek | quay_sdw3098_sweeden_hpcc | sdw3098@quay | HPCC | @deepseek |
| 15 | quay_hpcc_qwen | quay_sdw3098_sweeden_hpcc | sdw3098@quay | HPCC | @qwen |
| 16 | quay_hpcc_codellama | quay_sdw3098_sweeden_hpcc | sdw3098@quay | HPCC | @codellama |
| 17 | quay_github_granite | quay_sdw3098_sweeden-ttu_github | sdw3098@quay | GitHub | @granite |
| 18 | quay_github_deepseek | quay_sdw3098_sweeden-ttu_github | sdw3098@quay | GitHub | @deepseek |
| 19 | quay_github_qwen | quay_sdw3098_sweeden-ttu_github | sdw3098@quay | GitHub | @qwen |
| 20 | quay_github_codellama | quay_sdw3098_sweeden-ttu_github | sdw3098@quay | GitHub | @codellama |

## Where the action runs (from the key)

From the key you can decide **who performs the action**:

| Key contains | Action is taken by / at |
|--------------|-------------------------|
| **github**   | **GitHub workflow action agent** (CI, push, comments, releases) |
| **hpcc**     | **HPCC cluster** (jobs, Ollama, compute) |
| **owner** (origin) | **Local client: macbook** (@macos @maclaptop) |
| **quay** (origin)  | **Local client: rockydesktop** (@rockylinux @rockydesktop) |

Parsed by `context-key.sh` and exported for scripts:

- **CONTEXT_ACTION_WHERE** = `github` \| `hpcc` — where the automated action runs (GitHub Actions or HPCC).
- **CONTEXT_ACTION_CLIENT** = `macbook` \| `rockydesktop` \| `` — which local client the key refers to (owner → macbook, quay → rockydesktop).

So: keys with **github** → action by the GitHub workflow/actions agent; keys with **hpcc** → action at the HPCC cluster; keys with **owner** or **quay** identify the local client (macbook or rockydesktop) where actions can be taken locally.

## Usage

- **Config / env:** Set `CONTEXT_KEY=owner_hpcc_granite` (or one of the 20) so scripts know sender, receiver, and model.
- **Scripts:** All scripts under `scripts/` accept one of the 20 keys as first argument or via `CONTEXT_KEY`; they then make decisions (e.g. connect-hpcc only for *_hpcc_* keys, daily-github-sync only for *_github_* keys). See `scripts/context-key.sh` and each script’s header.
- **Git messages / notifications:** Reference the key so reviewers know context, e.g. `Context: owner_hpcc_granite` or `Key: quay_github_qwen`.
- **Ollama jobs:** Use the key to select both the SSH path (who pushes/runs) and the model (e.g. @granite on owner→HPCC = owner_hpcc_granite).

These 20 keys are the only valid combinations; use them consistently across projects (see AGENTS.md, COMMIT_MESSAGE_STANDARD.md).
