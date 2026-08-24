#!/usr/bin/env bash
# Workshop Setup — Linux (Ubuntu/Debian)
# Usage: bash setup-linux.sh [--wezterm] [--docker] [--force]
#
# Env overrides for reproducible installs: BUN_VERSION, UV_VERSION, PYTHON_VERSION
# (default: latest). Example: BUN_VERSION=1.1.34 bash setup-linux.sh
#
# ⚠️ SECURITY NOTE: This script downloads and executes remote installers
# (curl | bash) for bun, NodeSource, and Antigravity CLI. This is the standard
# official install path for these tools, but it carries supply-chain risk:
# the downloaded script runs with your user permissions before you can review it.
# Installers are downloaded to disk first (not piped directly) and their
# SHA-256 is printed/logged for auditability. For production/enterprise
# environments, prefer checking the installer's checksum/signature against a
# known-good value first, or installing from your distro's package manager.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup-lib.sh
# (sourced without extra args — setup-lib.sh reads this script's own "$@")
source "$SCRIPT_DIR/setup-lib.sh"

init_logging "linux"

installed() { command -v "$1" &>/dev/null; }

# ── Root check ────────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  printf "${YELLOW}⚠️  Running as root. Recommended: run as normal user with sudo.${NC}\n"
fi

# ── sudo pre-auth ─────────────────────────────────────────────────────────────
printf "${CYAN}🔑  sudo 권한이 필요합니다. 암호를 입력하세요:${NC}\n"
sudo -v || { printf "${RED}❌  sudo 인증 실패. 스크립트를 종료합니다.${NC}\n"; exit 1; }
# 스크립트 실행 중 sudo 세션이 만료되지 않도록 백그라운드에서 갱신
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
  printf "${GREEN}✅${NC}  curl, git, unzip ${DIM}(already installed)${NC}\n"
fi

if should_install gh; then
  run_step "Add GitHub CLI repo" bash -c '
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -q'
  run_step "Install gh" sudo apt-get install -y -q gh
else
  printf "${GREEN}✅${NC}  gh ${DIM}(already installed)${NC}\n"
fi

# ── 3. Runtime: bun ───────────────────────────────────────────────────────────
section 3 $TOTAL "Runtime: bun"
if should_install bun; then
  BUN_TMP=$(mktemp)
  if curl -fsSL https://bun.sh/install -o "$BUN_TMP"; then
    BUN_SUM=$(command -v sha256sum &>/dev/null && sha256sum "$BUN_TMP" | cut -d' ' -f1 || shasum -a 256 "$BUN_TMP" | cut -d' ' -f1)
    printf "     ${DIM}installer sha256: %s${NC}\n" "$BUN_SUM"
    if [[ "$BUN_VERSION" != "latest" ]]; then
      run_step "Install bun ($BUN_VERSION)" bash "$BUN_TMP" "$BUN_VERSION"
    else
      run_step "Install bun (latest)" bash "$BUN_TMP"
    fi
  else
    printf "${RED}❌${NC}  Failed to download bun installer\n"
    ERRORS+=("Install bun")
  fi
  rm -f "$BUN_TMP"
  export PATH="$HOME/.bun/bin:$PATH"
  grep -qF '.bun/bin' "$HOME/.bashrc" 2>/dev/null \
    || echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.bashrc"
else
  printf "${GREEN}✅${NC}  bun ${DIM}$(bun --version) (already installed)${NC}\n"
fi

# ── 4. Runtime: python3 ───────────────────────────────────────────────────────
section 4 $TOTAL "Runtime: python3"
if should_install python3; then
  PY_PKG="python3"
  [[ "$PYTHON_VERSION" != "latest" ]] && PY_PKG="python${PYTHON_VERSION}"
  run_step "Install $PY_PKG" sudo apt-get install -y -q "$PY_PKG" python3-pip python3-venv
else
  printf "${GREEN}✅${NC}  python3 ${DIM}$(python3 --version) (already installed)${NC}\n"
fi

# ── 5. Runtime: uv ───────────────────────────────────────────────────────────
section 5 $TOTAL "Runtime: uv"
if should_install uv; then
  UV_URL="https://astral.sh/uv/install.sh"
  [[ "$UV_VERSION" != "latest" ]] && UV_URL="https://astral.sh/uv/${UV_VERSION}/install.sh"
  run_step "Install uv ($UV_VERSION)" fetch_and_run "$UV_URL" sh
  export PATH="$HOME/.local/bin:$PATH"
else
  printf "${GREEN}✅${NC}  uv ${DIM}$(uv --version) (already installed)${NC}\n"
fi

# ── 6. CLI tools ──────────────────────────────────────────────────────────────
section 6 $TOTAL "CLI tools"
if should_install claude; then
  if ! run_step "Install Claude Code CLI" bun install -g @anthropic-ai/claude-code; then
    run_step "Install Node.js (fallback)" bash -c \
      'curl -fsSL https://deb.nodesource.com/setup_lts.x -o /tmp/nodesource.sh && sudo bash /tmp/nodesource.sh && rm -f /tmp/nodesource.sh && sudo apt-get install -y -q nodejs'
    run_step "Install Claude Code CLI (npm)" npm install -g @anthropic-ai/claude-code
  fi
else
  printf "${GREEN}✅${NC}  claude ${DIM}(already installed)${NC}\n"
fi

if should_install agy; then
  run_step "Install Antigravity CLI" fetch_and_run https://antigravity.google/cli/install.sh bash
else
  printf "${GREEN}✅${NC}  agy ${DIM}(already installed)${NC}\n"
fi

# ── 7. Desktop apps ───────────────────────────────────────────────────────────
section 7 $TOTAL "Desktop apps"
if installed google-chrome || installed google-chrome-stable; then
  printf "${GREEN}✅${NC}  Google Chrome ${DIM}(already installed)${NC}\n"
else
  run_step "Download Chrome .deb" bash -c \
    'curl -fsSL --retry 3 https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb'
  run_step "Install Google Chrome" bash -c \
    'sudo dpkg -i /tmp/chrome.deb || sudo apt-get install -f -y -q; rm -f /tmp/chrome.deb'
fi

printf "${YELLOW}⚠️ ${NC}  Claude Desktop — check availability at ${CYAN}https://claude.ai/download${NC}\n"
printf "${YELLOW}⚠️ ${NC}  Antigravity Desktop — install manually: ${CYAN}https://antigravity.google${NC}\n"
printf "${YELLOW}⚠️ ${NC}  Mark (Markdown viewer) — install manually: ${CYAN}https://playloom.app/mark${NC}\n"

if [[ " $* " == *" --docker "* ]]; then
  if should_install docker; then
    run_step "Install Docker" fetch_and_run https://get.docker.com sudo sh
    run_step "Add user to docker group" bash -c "sudo usermod -aG docker ${USER:-$(whoami)}"
    printf "${YELLOW}⚠️ ${NC}  Log out and back in for docker group to take effect.\n"
  else
    printf "${GREEN}✅${NC}  Docker ${DIM}$(docker --version) (already installed)${NC}\n"
  fi
fi

if [[ " $* " == *" --wezterm "* ]]; then
  if should_install wezterm; then
    run_step "Add WezTerm repo" bash -c '
      curl -fsSL https://apt.fury.io/wez/gpg.key \
        | sudo gpg --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
      echo "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" \
        | sudo tee /etc/apt/sources.list.d/wezterm.list
      sudo apt-get update -q'
    run_step "Install WezTerm" sudo apt-get install -y -q wezterm
  else
    printf "${GREEN}✅${NC}  WezTerm ${DIM}(already installed)${NC}\n"
  fi
fi

# ── 8. Git config check ───────────────────────────────────────────────────────
section 8 $TOTAL "Git & GitHub"
GIT_NAME=$(git config --global user.name  2>/dev/null || true)
GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
if [[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]]; then
  printf "${GREEN}✅${NC}  git config: ${CYAN}%s <%s>${NC}\n" "$GIT_NAME" "$GIT_EMAIL"
else
  printf "${YELLOW}⚠️ ${NC}  git user not configured\n"
  printf "     ${DIM}git config --global user.name 'Your Name'${NC}\n"
  printf "     ${DIM}git config --global user.email 'you@example.com'${NC}\n"
fi

if gh auth status &>/dev/null; then
  printf "${GREEN}✅${NC}  gh auth: logged in\n"
else
  printf "${YELLOW}⚠️ ${NC}  gh auth: not logged in — run ${CYAN}gh auth login${NC} before the workshop\n"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}\n"
if [[ ${#ERRORS[@]} -eq 0 ]]; then
  printf "${GREEN}✅  All steps complete!${NC}\n"
  printf "\n  Next → ${CYAN}bun setup-common.ts${NC}\n"
else
  printf "${RED}❌  Failed: %s${NC}\n" "${ERRORS[*]}"
  exit 1
fi
printf "${BOLD}${CYAN}══════════════════════════════════════════${NC}\n\n"
