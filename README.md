# Workshop Environment Setup

[한국어](README_ko.md)

One-shot setup scripts that get a machine ready for the workshop: base tools, runtimes (`bun`, `python3`, `uv`), CLI tools (`gh`, `claude`, `codex`, `agy`, `gitleaks`), and desktop apps — installing what can be automated and clearly prompting for manual-only apps on macOS, Linux (Ubuntu/Debian), and Windows.

## Quick start

1. Read and complete [`SETUP_CHECKLIST.md`](SETUP_CHECKLIST.md) first.
2. Run the script for your OS (admin/sudo required):

```bash
# macOS
bash setup-mac.sh

# Linux (Ubuntu/Debian)
bash setup-linux.sh

# Windows (run PowerShell as Administrator)
powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

3. Verify everything installed correctly:

```bash
bun setup-common.ts
```

### Or let an AI agent install it

Instead of running the script yourself, you can ask an AI coding agent (Claude Code, Codex, Gemini CLI, Antigravity, …) to follow [`install.md`](install.md). Open the agent in this repository folder and say:

```text
Read install.md and install everything.
```

The agent detects your OS, runs the matching script, guides you in your system language (English / Korean / Japanese / Spanish) while it runs, and verifies with `bun setup-common.ts`. Logins and subscriptions stay with you — the agent never types passwords or tokens. To preview without changing anything, ask for a "dry-run".

Full instructions, optional flags (`--wezterm`, `--docker`, `-WSL2`, `--force`), and troubleshooting live in [`SETUP.md`](SETUP.md).

## Repository layout

| File | Purpose |
|---|---|
| [`SETUP.md`](SETUP.md) | Full setup guide (installation flow, flags, troubleshooting) |
| [`SETUP_CHECKLIST.md`](SETUP_CHECKLIST.md) | Pre-workshop checklist (accounts, subscriptions, prerequisites) |
| [`install.md`](install.md) | Step-by-step runbook for AI agents (Claude Code, Codex, etc.) to run the installation for you, with dry-run mode and multilingual guidance |
| `setup-mac.sh` / `setup-linux.sh` | OS-specific install scripts |
| `setup-lib.sh` | Shared bash helpers (sourced by the mac/linux scripts): progress UI, preflight checks, logging, `--force`, cleanup |
| `setup-windows.ps1` | Windows install script (PowerShell) |
| `setup-common.ts` | Cross-platform verification script (run after the OS script) |
| `check-docs-sync.sh` | CI guard — fails if `SETUP.md` / `SETUP_ko.md` drift from the scripts' actual flags |
| `.github/workflows/test-setup.yml` | CI: ShellCheck, a real dry-run of `setup-linux.sh` in a container, and a PowerShell syntax check |

Korean translations: [`SETUP_ko.md`](SETUP_ko.md), [`SETUP_CHECKLIST_ko.md`](SETUP_CHECKLIST_ko.md).

## Reproducible installs

Pin `bun`/`uv` versions on all platforms, and `python3` on macOS/Linux, instead of always installing latest:

```bash
BUN_VERSION=1.4.5 UV_VERSION=0.4.20 PYTHON_VERSION=3.13 bash setup-mac.sh
```

```powershell
$env:BUN_VERSION = "1.4.5"; $env:UV_VERSION = "0.4.20"; powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

## Security note

Some tools are installed via remote installer scripts, depending on platform — for example `bun`, Linux `uv`, Linux Codex CLI, and the Antigravity CLI. Rather than piping the download straight into a shell (`curl | bash` / `irm | iex`), each installer is downloaded to disk first, its SHA-256 is printed and logged, and only then executed — so the run is auditable even though the script itself isn't hand-reviewed before execution. See the security note at the top of each script for specifics.

## CI

Every change to a setup script triggers:
- **docs-sync** — `SETUP.md` flags must match the scripts
- **shellcheck** — lint `setup-linux.sh` / `setup-mac.sh` / `setup-lib.sh`
- **linux-integration** — actually runs `setup-linux.sh` in an Ubuntu container, then `setup-common.ts --json`
- **macos-integration** — actually runs `setup-mac.sh` on a macOS (ARM) runner under the stock bash 3.2, then `setup-common.ts --json`
- **windows-integration** — actually runs `setup-windows.ps1` on a Windows runner (launched via Windows PowerShell 5.1, so the auto-relaunch to PowerShell 7 is exercised), then `setup-common.ts --json`
- **windows-syntax-check** — parses `setup-windows.ps1` for syntax errors (no execution)
