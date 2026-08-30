# Workshop Environment Setup

[한국어](README_ko.md)

One-shot setup scripts that get a machine ready for the workshop: base tools, runtimes (`bun`, `python3`, `uv`), CLI tools (`gh`, `claude`, `agy`), and desktop apps — for macOS, Linux (Ubuntu/Debian), and Windows.

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

Full instructions, optional flags (`--wezterm`, `--docker`, `-WSL2`, `--force`), and troubleshooting live in [`SETUP.md`](SETUP.md).

## Repository layout

| File | Purpose |
|---|---|
| [`SETUP.md`](SETUP.md) | Full setup guide (installation flow, flags, troubleshooting) |
| [`SETUP_CHECKLIST.md`](SETUP_CHECKLIST.md) | Pre-workshop checklist (accounts, subscriptions, prerequisites) |
| `setup-mac.sh` / `setup-linux.sh` | OS-specific install scripts |
| `setup-lib.sh` | Shared bash helpers (sourced by the mac/linux scripts): progress UI, preflight checks, logging, `--force`, cleanup |
| `setup-windows.ps1` | Windows install script (PowerShell) |
| `setup-common.ts` | Cross-platform verification script (run after the OS script) |
| `check-docs-sync.sh` | CI guard — fails if `SETUP.md` drifts from the scripts' actual flags |
| `.github/workflows/test-setup.yml` | CI: ShellCheck, a real dry-run of `setup-linux.sh` in a container, and a PowerShell syntax check |

Korean translations: [`SETUP_ko.md`](SETUP_ko.md), [`SETUP_CHECKLIST_ko.md`](SETUP_CHECKLIST_ko.md).

## Reproducible installs

Pin `bun`/`uv`/`python3` versions instead of always installing latest:

```bash
BUN_VERSION=1.1.34 UV_VERSION=0.4.20 bash setup-mac.sh
```

```powershell
$env:BUN_VERSION = "1.1.34"; $env:UV_VERSION = "0.4.20"; powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

## Security note

The scripts install `bun`, `uv`, and the Antigravity CLI via their official remote installers. Rather than piping the download straight into a shell (`curl | bash` / `irm | iex`), each installer is downloaded to disk first, its SHA-256 is printed and logged, and only then executed — so the run is auditable even though the script itself isn't hand-reviewed before execution. See the security note at the top of each script for specifics.

## CI

Every change to a setup script triggers:
- **docs-sync** — `SETUP.md` flags must match the scripts
- **shellcheck** — lint `setup-linux.sh` / `setup-mac.sh` / `setup-lib.sh`
- **linux-dry-run** — actually runs `setup-linux.sh` in an Ubuntu container, then `setup-common.ts --json`
- **windows-syntax-check** — parses `setup-windows.ps1` for syntax errors (no execution)
