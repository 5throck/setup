#!/usr/bin/env bash
# Workshop Setup — macOS
# Usage: bash setup-mac.sh [--wezterm] [--docker] [--force]
#
# Env overrides for reproducible installs: BUN_VERSION, UV_VERSION, PYTHON_VERSION
# (default: latest). Example: BUN_VERSION=1.1.34 bash setup-mac.sh
#
# ⚠️ SECURITY NOTE: This script downloads and executes remote installers
# (curl | bash) for bun and Antigravity CLI. This is the standard official
# install path for these tools, but it carries supply-chain risk: the
# downloaded script runs with your user permissions before you can review it.
# Installers are downloaded to disk first (not piped directly) and their
# SHA-256 is printed/logged for auditability. For production/enterprise
# environments, prefer checking the installer's checksum/signature against a
# known-good value first, or installing via Homebrew instead.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup-lib.sh
# (sourced without extra args — setup-lib.sh reads this script's own "$@")
source "$SCRIPT_DIR/setup-lib.sh"

init_logging "mac"

installed() { command -v "$1" &>/dev/null; }

# ── Header ────────────────────────────────────────────────────────────────────
clear
printf "${BOLD}${CYAN}"
cat << 'EOF'
  ╔══════════════════════════════════════════╗
  ║     Workshop Setup — macOS               ║
  ╚══════════════════════════════════════════╝
EOF
printf "${NC}\n"

if [[ $FORCE -eq 1 ]]; then
  printf "${YELLOW}🔧  Force mode: all tools will be reinstalled${NC}\n\n"
fi

preflight_checks

TOTAL=8

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
section 1 $TOTAL "Package manager (Homebrew)"
if installed brew; then
  run_step "brew update & upgrade" brew upgrade --quiet
else
  run_step "Install Homebrew" fetch_and_run \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh bash
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  elif [[ -f /usr/local/bin/brew ]]; then
    # Intel Macs install Homebrew under /usr/local
    eval "$(/usr/local/bin/brew shellenv)"
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
  fi
fi

# ── 2. Base tools ─────────────────────────────────────────────────────────────
section 2 $TOTAL "Base tools"
for pkg in curl git gh; do
  if should_install "$pkg"; then
    run_step "Install $pkg" brew install "$pkg"
  else
    printf "${GREEN}✅${NC}  $pkg ${DIM}(already installed)${NC}\n"
  fi
done

# ── 3. Runtime: bun ───────────────────────────────────────────────────────────
section 3 $TOTAL "Runtime: bun"
if should_install bun; then
  BUN_TMP=$(mktemp)
  if curl -fsSL https://bun.sh/install -o "$BUN_TMP"; then
    BUN_SUM=$(shasum -a 256 "$BUN_TMP" | cut -d' ' -f1)
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
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    # touch: default shell rc may not exist yet (fresh accounts)
    touch "$rc"
    grep -qF '.bun/bin' "$rc" \
      || echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$rc"
  done
else
  printf "${GREEN}✅${NC}  bun ${DIM}$(bun --version) (already installed)${NC}\n"
fi

# ── 4. Runtime: python3 ───────────────────────────────────────────────────────
section 4 $TOTAL "Runtime: python3"
if should_install python3; then
  PY_FORMULA="python3"
  [[ "$PYTHON_VERSION" != "latest" ]] && PY_FORMULA="python@${PYTHON_VERSION}"
  run_step "Install $PY_FORMULA" brew install "$PY_FORMULA"
else
  printf "${GREEN}✅${NC}  python3 ${DIM}$(python3 --version) (already installed)${NC}\n"
fi

# ── 5. Runtime: uv ───────────────────────────────────────────────────────────
section 5 $TOTAL "Runtime: uv"
if should_install uv; then
  run_step "Install uv" brew install uv
  if [[ "$UV_VERSION" != "latest" ]]; then
    printf "${YELLOW}⚠️ ${NC}  Homebrew installs the latest uv; use 'uv self update --version %s' to pin.\n" "$UV_VERSION"
  fi
else
  printf "${GREEN}✅${NC}  uv ${DIM}$(uv --version) (already installed)${NC}\n"
fi

# ── 6. CLI tools ─────────────────────────────────────────────────────────────
section 6 $TOTAL "CLI tools"
if should_install claude; then
  run_step "Install Claude Code CLI" bun install -g @anthropic-ai/claude-code \
    || run_step "Install Claude Code CLI (npm fallback)" npm install -g @anthropic-ai/claude-code
else
  printf "${GREEN}✅${NC}  claude ${DIM}(already installed)${NC}\n"
fi

if should_install agy; then
  run_step "Install Antigravity CLI" fetch_and_run https://antigravity.google/cli/install.sh bash
else
  printf "${GREEN}✅${NC}  agy ${DIM}(Antigravity CLI, already installed)${NC}\n"
fi

# ── 7. Desktop apps ───────────────────────────────────────────────────────────
section 7 $TOTAL "Desktop apps"
if [[ -d "/Applications/Google Chrome.app" ]]; then
  printf "${GREEN}✅${NC}  Google Chrome ${DIM}(already installed)${NC}\n"
else
  run_step "Install Google Chrome" brew install --cask google-chrome
fi

if [[ -d "/Applications/Claude.app" ]]; then
  printf "${GREEN}✅${NC}  Claude Desktop ${DIM}(already installed)${NC}\n"
else
  run_step "Install Claude Desktop App" brew install --cask claude
fi

if [[ -d "/Applications/Antigravity.app" ]]; then
  printf "${GREEN}✅${NC}  Antigravity Desktop ${DIM}(already installed)${NC}\n"
else
  printf "${YELLOW}⚠️ ${NC}  Antigravity Desktop — install manually: ${CYAN}https://antigravity.google${NC}\n"
fi

if [[ -d "/Applications/Mark.app" ]]; then
  printf "${GREEN}✅${NC}  Mark (Markdown viewer) ${DIM}(already installed)${NC}\n"
else
  printf "${YELLOW}⚠️ ${NC}  Mark (Markdown viewer) — install manually: ${CYAN}https://playloom.app/mark${NC}\n"
fi

if [[ " $* " == *" --wezterm "* ]]; then
  if [[ -d "/Applications/WezTerm.app" ]]; then
    printf "${GREEN}✅${NC}  WezTerm ${DIM}(already installed)${NC}\n"
  else
    run_step "Install WezTerm" brew install --cask wezterm
  fi
fi

if [[ " $* " == *" --docker "* ]]; then
  if should_install docker; then
    run_step "Install Docker Desktop" brew install --cask docker
    printf "${YELLOW}⚠️ ${NC}  Launch Docker Desktop once to complete setup.\n"
  else
    printf "${GREEN}✅${NC}  Docker ${DIM}$(docker --version) (already installed)${NC}\n"
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
