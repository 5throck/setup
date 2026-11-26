#!/usr/bin/env bash
# Workshop Setup — Linux (Ubuntu/Debian)
# Usage: bash setup-linux.sh [--wezterm] [--docker] [--force] [--company <name>] [--help]
# --company installs an organization's additional tools (e.g. --company lotte).
# See company_install_url in setup-lib.sh for supported names.
#
# Env overrides for reproducible installs: BUN_VERSION, UV_VERSION, PYTHON_VERSION
# (default: latest). Example: BUN_VERSION=1.4.5 bash setup-linux.sh
#
# ⚠️ SECURITY NOTE: This script downloads and executes remote installers
# (curl | bash) for bun, Claude Code, NodeSource, Codex CLI, and Antigravity CLI. This is
# the standard official install path for these tools, but it carries
# supply-chain risk: the downloaded script runs with your user permissions
# before you can review it. Installers are downloaded to disk first (not
# piped directly) and their SHA-256 is printed/logged for auditability. For
# production/enterprise environments, prefer checking the installer's
# checksum/signature against a known-good value first, or installing from
# your distro's package manager.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup-lib.sh
# (sourced without extra args — setup-lib.sh reads this script's own "$@")
source "$SCRIPT_DIR/setup-lib.sh"

if [[ $HELP -eq 1 ]]; then
  cat <<'EOF'
Workshop Setup — Linux (Ubuntu/Debian)

Usage: bash setup-linux.sh [options]

Options:
  --wezterm          Also install WezTerm (GPU-accelerated terminal)
  --docker           Also install Docker
  --force            Reinstall all tools even if already installed
  --company <name>   Install an organization's additional tools (e.g. lotte)
  -h, --help         Show this help message and exit

Env overrides (default: latest):
  BUN_VERSION, UV_VERSION, PYTHON_VERSION
  Example: BUN_VERSION=1.4.5 bash setup-linux.sh
EOF
  exit 0
fi

init_logging "linux"

installed() { command -v "$1" &>/dev/null; }

# ── Root check ────────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  printf "${YELLOW}⚠️  Running as root. Recommended: run as normal user with sudo.${NC}\n"
fi

# ── sudo pre-auth ─────────────────────────────────────────────────────────────
printf "${CYAN}🔑  Administrator (sudo) access is required. Enter your password:${NC}\n"
sudo -v || { printf "${RED}❌  sudo authentication failed. Exiting.${NC}\n"; exit 1; }
# Refresh the sudo timestamp in the background so it doesn't expire mid-run
( while true; do sudo -n true; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!

# ── Header ────────────────────────────────────────────────────────────────────
clear
printf "${BOLD}${CYAN}"
cat << 'EOF'
  ╔══════════════════════════════════════════╗
  ║     Workshop Setup — Linux               ║
  ╚══════════════════════════════════════════╝
EOF
printf "${NC}\n"

if [[ $FORCE -eq 1 ]]; then
  printf "${YELLOW}🔧  Force mode: all tools will be reinstalled${NC}\n\n"
fi

preflight_checks

TOTAL=8

# ── 1. System update ──────────────────────────────────────────────────────────
section 1 $TOTAL "System update"
run_step "apt update & upgrade" bash -c 'sudo apt-get update -q && sudo apt-get upgrade -y -q'

# ── 2. Base tools ─────────────────────────────────────────────────────────────
section 2 $TOTAL "Base tools"
MISSING=()
for pkg in curl git unzip; do installed "$pkg" || MISSING+=("$pkg"); done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  run_step "Install ${MISSING[*]}" sudo apt-get install -y -q "${MISSING[@]}"
else
  for pkg in curl git unzip; do
    printf "${GREEN}✅${NC}  ${DIM}$(tool_version "$pkg") (already installed)${NC}\n"
  done
fi

if should_install gh; then
  run_step "Add GitHub CLI repo" bash -c '
    curl -fsSL --connect-timeout 10 --max-time 60 https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -q'
  run_step "Install gh" sudo apt-get install -y -q gh
else
  printf "${GREEN}✅${NC}  ${DIM}$(tool_version gh) (already installed)${NC}\n"
fi

# gitleaks ships no official install script; apt doesn't carry it either, so
# fetch the latest release tarball from GitHub and drop the binary on PATH.
install_gitleaks() {
  local arch tag tmp_dir tarball
  case "$(uname -m)" in
    x86_64)  arch="x64" ;;
    aarch64) arch="arm64" ;;
    *) echo "unsupported architecture for gitleaks: $(uname -m)"; return 1 ;;
  esac
  tag=$(curl -fsSL --connect-timeout 10 --max-time 60 https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep -m1 '"tag_name"' | cut -d'"' -f4)
  [[ -z "$tag" ]] && { echo "could not resolve latest gitleaks release"; return 1; }
  tmp_dir=$(mktemp -d)
  tarball="$tmp_dir/gitleaks.tar.gz"
  if ! curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 10 --max-time 600 \
      "https://github.com/gitleaks/gitleaks/releases/download/${tag}/gitleaks_${tag#v}_linux_${arch}.tar.gz" \
      -o "$tarball"; then
    rm -rf "$tmp_dir"
    return 1
  fi
  print_sha256 "$tarball"
  tar -xzf "$tarball" -C "$tmp_dir" gitleaks
  sudo install -m 0755 "$tmp_dir/gitleaks" /usr/local/bin/gitleaks
  rm -rf "$tmp_dir"
}

if should_install gitleaks; then
  run_step "Install gitleaks" install_gitleaks
else
  printf "${GREEN}✅${NC}  ${DIM}$(tool_version gitleaks) (already installed)${NC}\n"
fi

# ── 3. Runtime: bun ───────────────────────────────────────────────────────────
section 3 $TOTAL "Runtime: bun"
install_bun "$HOME/.bashrc" "$HOME/.zshrc"

# ── 4. Runtime: python3 ───────────────────────────────────────────────────────
section 4 $TOTAL "Runtime: python3"
if should_install python3; then
  PY_PKGS=(python3 python3-pip python3-venv)
  if [[ "$PYTHON_VERSION" != "latest" ]]; then
    # Distro repos only carry the versions Ubuntu/Debian ship (e.g. Ubuntu
    # 24.04 has 3.12; 3.13 needs 24.10+ or the deadsnakes PPA). Fall back to
    # the distro python3 instead of failing the whole run (parity with the
    # macOS UV_VERSION caveat).
    if apt-cache show "python${PYTHON_VERSION}" &>/dev/null; then
      PY_PKGS=("python${PYTHON_VERSION}" python3-pip python3-venv)
    else
      printf "${YELLOW}⚠️ ${NC}  python%s is not in this distro's repos — installing distro python3 instead.\n" "$PYTHON_VERSION"
    fi
  fi
  run_step "Install ${PY_PKGS[0]}" sudo apt-get install -y -q "${PY_PKGS[@]}"
else
  printf "${GREEN}✅${NC}  ${DIM}$(python3 --version) (already installed)${NC}\n"
fi

# ── 5. Runtime: uv ───────────────────────────────────────────────────────────
section 5 $TOTAL "Runtime: uv"
if should_install uv; then
  UV_URL="https://astral.sh/uv/install.sh"
  [[ "$UV_VERSION" != "latest" ]] && UV_URL="https://astral.sh/uv/${UV_VERSION}/install.sh"
  run_step "Install uv ($UV_VERSION)" fetch_and_run "$UV_URL" sh
  export PATH="$HOME/.local/bin:$PATH"
else
  printf "${GREEN}✅${NC}  ${DIM}$(uv --version) (already installed)${NC}\n"
fi

# ── 6. CLI tools ──────────────────────────────────────────────────────────────
section 6 $TOTAL "CLI tools"
if should_install claude; then
  # Anthropic's native installer is the recommended path (auto-updating
  # binary, no Node dependency); bun/npm remain as fallbacks.
  if ! run_step "Install Claude Code CLI" fetch_and_run https://claude.ai/install.sh bash; then
    drop_last_error   # the bun fallback below decides the outcome
    if ! run_step "Install Claude Code CLI (bun fallback)" bun install -g @anthropic-ai/claude-code; then
      drop_last_error   # the NodeSource/npm fallback below decides the outcome
      NODE_SETUP=$(mktemp)
      run_step "Install Node.js (fallback)" bash -c "curl -fsSL --connect-timeout 10 --max-time 60 https://deb.nodesource.com/setup_lts.x -o '$NODE_SETUP' && sudo bash '$NODE_SETUP' && rm -f '$NODE_SETUP' && sudo apt-get install -y -q nodejs"
      run_step "Install Claude Code CLI (npm)" npm install -g @anthropic-ai/claude-code
    fi
  fi
  export PATH="$HOME/.local/bin:$PATH"
else
  printf "${GREEN}✅${NC}  ${DIM}$(tool_version claude) (already installed)${NC}\n"
fi

if should_install codex; then
  # The npm bin is a Node.js launcher, so use the official standalone
  # installer instead (no Node dependency); it installs to ~/.local/bin
  # and registers itself in .bashrc.
  run_step "Install Codex CLI" fetch_and_run https://chatgpt.com/codex/install.sh bash
  export PATH="$HOME/.local/bin:$PATH"
else
  printf "${GREEN}✅${NC}  ${DIM}$(tool_version codex) (already installed)${NC}\n"
fi

if should_install agy; then
  run_step "Install Antigravity CLI" fetch_and_run https://antigravity.google/cli/install.sh bash
else
  printf "${GREEN}✅${NC}  ${DIM}$(tool_version agy) (already installed)${NC}\n"
fi

# ── 7. Desktop apps ───────────────────────────────────────────────────────────
section 7 $TOTAL "Desktop apps"
if installed google-chrome || installed google-chrome-stable; then
  printf "${GREEN}✅${NC}  Google Chrome ${DIM}(already installed)${NC}\n"
elif [ "$(uname -m)" != "x86_64" ]; then
  # Google publishes no arm64 .deb for Linux — guide a manual install instead
  # of failing on the amd64-only download.
  printf "${YELLOW}⚠️ ${NC}  Google Chrome — no arm64 build for Linux; install manually: ${CYAN}https://www.google.com/chrome${NC}\n"
else
  CHROME_DEB=$(mktemp)
  run_step "Download Chrome .deb" bash -c \
    "curl -fsSL --retry 3 --connect-timeout 10 --max-time 600 https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o '$CHROME_DEB'"
  run_step "Install Google Chrome" bash -c \
    "sudo dpkg -i '$CHROME_DEB' || sudo apt-get install -f -y -q; rm -f '$CHROME_DEB'"
fi

printf "${YELLOW}⚠️ ${NC}  Claude Desktop — check availability at ${CYAN}https://claude.ai/download${NC}\n"
printf "${YELLOW}⚠️ ${NC}  Codex Desktop — not available on Linux (use Codex CLI)\n"
printf "${YELLOW}⚠️ ${NC}  Antigravity Desktop — install manually: ${CYAN}https://antigravity.google${NC}\n"
printf "${YELLOW}⚠️ ${NC}  Mark (Markdown viewer) — install manually: ${CYAN}https://playloom.app/mark${NC}\n"

if [[ " $* " == *" --docker "* ]]; then
  if should_install docker; then
    run_step "Install Docker" fetch_and_run https://get.docker.com sudo sh
    run_step "Add user to docker group" bash -c "sudo usermod -aG docker ${USER:-$(whoami)}"
    printf "${YELLOW}⚠️ ${NC}  Log out and back in for docker group to take effect.\n"
  else
    printf "${GREEN}✅${NC}  ${DIM}$(docker --version) (already installed)${NC}\n"
  fi
fi

if [[ " $* " == *" --wezterm "* ]]; then
  if should_install wezterm; then
    run_step "Add WezTerm repo" bash -c '
      curl -fsSL --connect-timeout 10 --max-time 60 https://apt.fury.io/wez/gpg.key \
        | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
      echo "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" \
        | sudo tee /etc/apt/sources.list.d/wezterm.list
      sudo apt-get update -q'
    run_step "Install WezTerm" sudo apt-get install -y -q wezterm
  else
    printf "${GREEN}✅${NC}  ${DIM}$(tool_version wezterm) (already installed)${NC}\n"
  fi
fi

install_company_tools

# ── 8. Git config check ───────────────────────────────────────────────────────
section 8 $TOTAL "Git & GitHub"
check_git_and_gh

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary
