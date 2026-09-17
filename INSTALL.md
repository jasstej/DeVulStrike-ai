# DeVulStrike-ai - Installation Guide (SOURCE OF TRUTH)

> **AUTHORITATIVE DOCUMENT.** This file is the single source of truth for installing,
> configuring, and running DeVulStrike-ai. Any AI agent or human operator MUST follow
> EXACTLY the steps in this document. Do not improvise, skip steps, or assume tool
> availability. If a command requires a tool that is missing, install it from the
> official source of that tool and re-run from the point of failure.

---

## 1. What you are deploying

DeVulStrike-ai is a two-process cybersecurity automation platform:

| Process | File | Role |
|---|---|---|
| HTTP API Server | `DeVulStrike_server.py` | Flask HTTP API, listens on `127.0.0.1:8888` by default |
| MCP Bridge | `DeVulStrike_mcp.py` | MCP (Model Context Protocol) stdio client that talks to the API server |

Operation model:
1. The **API Server** MUST be running and reachable before anything else works.
2. The **MCP Bridge** connects to the API Server on startup and retries `MAX_RETRIES` times.
3. AI clients (opencode, Claude Desktop, Cursor, VS Code Copilot) spawn the MCP Bridge via a stdio config entry.

---

## 2. Prerequisites

- **OS:** Linux (Debian/Ubuntu-based recommended). macOS partially supported, Windows not supported.
- **Python:** `3.10` or newer (the virtualenv below pins nothing; 3.13 tested).
- **Package manager:** `apt`, `pip3`, `curl`.
- **git:** to clone the repository.

Verify before continuing:
```bash
python3 --version            # must print 3.10 or newer
git --version
curl --version
```

---

## 3. Clone the repository

Clone ONLY from the official repository:

```bash
git clone https://github.com/jasstej/DeVulStrike-ai.git
cd DeVulStrike-ai
```

The working directory is now `DeVulStrike-ai`. All relative steps below assume you are
inside this directory.

---

## 4. Create a virtual environment

Create the virtualenv with the EXACT name `DeVulStrike-env` (this name is referenced
throughout this guide and by `.gitignore`):

```bash
python3 -m venv DeVulStrike-env
```

Activate it:

```bash
source DeVulStrike-env/bin/activate
```

Your shell prompt should now be prefixed with `(DeVulStrike-env)`.

> If `python3-venv` is missing, install it first:
> `sudo apt update && sudo apt install -y python3-venv python3-pip`

---

## 5. Install Python dependencies

With the virtualenv ACTIVE, install the exact dependency set:

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

Do not modify `requirements.txt`. If an install fails, resolve the failing package's
system library dependency (e.g. build tools: `sudo apt install -y build-essential libssl-dev libffi-dev`) and retry.

---

## 6. (Recommended) Install security tooling

The platform shells out to the toolset listed in `README.md` (nmap, gobuster, nuclei,
sqlmap, etc.) and needs Chrome/Chromium for its Browser Agent. NOT installing these
disables some tools but does not break the server.

Chrome/Chromium for the Browser Agent:

```bash
sudo apt update
sudo apt install -y chromium-browser chromium-chromedriver
# OR
sudo apt install -y google-chrome-stable
```

---

## 7. Start the API Server

IMPORTANT: Start the server BEFORE the MCP bridge. With the virtualenv ACTIVE:

```bash
python3 DeVulStrike_server.py
```

Defaults:
- Host: `127.0.0.1`
- Port: `8888`

Customization (optional):

```bash
python3 DeVulStrike_server.py --port 8080   # different port
python3 DeVulStrike_server.py --debug       # debug logging
```

Environment variables honored by the server:

| Variable | Default | Purpose |
|---|---|---|
| `DeVulStrike_PORT` | `8888` | API server port |
| `DeVulStrike_HOST` | `127.0.0.1` | API server bind address |
| `DEBUG_MODE` | `0` | `1`/`true`/`yes` enables debug |

---

## 8. Verify the API Server

```bash
curl http://localhost:8888/health
```

Expected: an HTTP 200 response reporting the server is operational.
If this fails, do NOT continue. Check the server logs, confirm the process is alive,
and fix connectivity before proceeding.

Additional smoke test:

```bash
curl -X POST http://localhost:8888/api/intelligence/analyze-target \
  -H "Content-Type: application/json" \
  -d '{"target": "example.com", "analysis_type": "comprehensive"}'
```

---

## 9. Start the MCP Bridge (manual smoke test)

With the virtualenv ACTIVE and the API server running:

```bash
python3 DeVulStrike_mcp.py --server http://localhost:8888
```

The bridge connects to the API server and reports successful connection. It runs over
stdio and stays attached to the terminal that spawned it. Stop it with `Ctrl+C`.
Debug mode: `python3 DeVulStrike_mcp.py --debug`.

---

## 10. Register with an MCP-compatible AI client

The AI client (NOT the shell) spawns the MCP bridge. Point it at the cloned repo's
virtualenv python:

### opencode (`~/.config/opencode/opencode.jsonc`)

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "DeVulStrike-ai": {
      "type": "local",
      "command": ["/ABSOLUTE/PATH/DeVulStrike-ai/DeVulStrike-env/bin/python", "/ABSOLUTE/PATH/DeVulStrike-ai/DeVulStrike_mcp.py", "--server", "http://localhost:8888"],
      "enabled": true,
      "environment": {
        "PATH": "/ABSOLUTE/PATH/DeVulStrike-ai/DeVulStrike-env/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      }
    }
  }
}
```

Replace `/ABSOLUTE/PATH/DeVulStrike-ai` with the real absolute clone path.

### Claude Desktop (`~/.config/Claude/claude_desktop_config.json`)

```json
{
  "mcpServers": {
    "DeVulStrike-ai": {
      "command": "/ABSOLUTE/PATH/DeVulStrike-ai/DeVulStrike-env/bin/python",
      "args": [
        "/ABSOLUTE/PATH/DeVulStrike-ai/DeVulStrike_mcp.py",
        "--server",
        "http://localhost:8888"
      ],
      "description": "DeVulStrike AI v6.0 - Advanced Cybersecurity Automation Platform",
      "timeout": 300,
      "disabled": false
    }
  }
}
```

After editing the config, fully restart the AI client so it re-reads the config and
re-spawns the MCP bridge.

---

## 11. Startup order (MANDATORY)

1. Start `DeVulStrike_server.py` first.
2. Confirm `curl http://localhost:8888/health` returns 200.
3. Start/restart the AI client (which spawns `DeVulStrike_mcp.py`).

If the MCP tools appear unavailable: the most common cause is the API server being down
or on a different port than the one in the MCP config. Both entries MUST use the same
port (8888 by default).

---

## 12. Shutdown

1. Stop the AI client / MCP bridge.
2. Stop the API server (`Ctrl+C` in its terminal, or `kill` the `DeVulStrike_server.py` process).

---

## 13. Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| `Connection refused to ...:8888` in bridge logs | API server not running. Start it (section 7). |
| MCP tools error on every call | Wrong port in client config vs server. Align both to 8888. |
| `python3 -m venv` fails | Install `python3-venv` (section 4 note). |
| Browser Agent fails | Install Chrome/Chromium (section 6). |
| Tool X reports "not found" | Install the missing security tool from its official source. |
| Systems says OS unsupported | Use Linux (Debian/Ubuntu-family). |

---

## 14. Repository hygiene rules (for AI agents)

- Never commit: virtualenv dirs, `__pycache__/`, `*.log`, `server_stdout.log` (see `.gitignore`).
- Never push to a different remote unless explicitly instructed.
- Never modify `deploy artifacts` (requirements.txt, DeVulStrike_server.py, DeVulStrike_mcp.py) without explicit instruction.
- After any rename, re-run the syntax check:
  ```bash
  DeVulStrike-env/bin/python -m py_compile DeVulStrike_server.py DeVulStrike_mcp.py
  ```