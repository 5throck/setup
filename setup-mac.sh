#!/usr/bin/env bash
# Workshop Setup — macOS
# Usage: bash setup-mac.sh [--wezterm] [--docker] [--force] [--company <name>] [--help]
# --company installs an organization's additional tools (e.g. --company lotte).
# See company_install_url in setup-lib.sh for supported names.
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

if [[ $HELP -eq 1 ]]; then
  cat <<'EOF'
Workshop Setup — macOS

Usage: bash setup-mac.sh [options]

Options:
  --wezterm          Also install WezTerm (GPU-accelerated terminal)
  --docker           Also install Docker Desktop
  --force            Reinstall all tools even if already installed
  --company <name>   Install an organization's additional tools (e.g. lotte)
  -h, --help         Show this help message and exit

Env overrides (default: latest):
  BUN_VERSION, UV_VERSION, PYTHON_VERSION
  Example: BUN_VERSION=1.1.34 bash setup-mac.sh
EOF
  exit 0
fi

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
  add_brew_shellenv() { # eval + persist to .zprofile (idempotent)
    eval "$($1/brew shellenv)"
    touch "$HOME/.zprofile"
    grep -qF "$1/bin/brew shellenv" "$HOME/.zprofile" 2>/dev/null \
      || echo "eval \"\$($1/bin/brew shellenv)\"" >> "$HOME/.zprofile"
  }
  if [[ -f /opt/homebrew/bin/brew ]]; then
    add_brew_shellenv /opt/homebrew
  elif [[ -f /usr/local/bin/brew ]]; then
    # Intel Macs install Homebrew under /usr/local
    add_brew_shellenv /usr/local
  fi
fi

# ── 2. Base tools ─────────────────────────────────────────────────────────────
section 2 $TOTAL "Base tools"
for pkg in curl git gh gitleaks; do
  if should_install "$pkg"; then
    run_step "Install $pkg" brew install "$pkg"
  else
    printf "${GREEN}✅${NC}  $pkg ${DIM}(already installed)${NC}\n"
  fi
done

# ── 3. Runtime: bun ───────────────────────────────────────────────────────────
section 3 $TOTAL "Runtime: bun"
install_bun "$HOME/.zshrc" "$HOME/.bashrc"

# ── 4. Runtime: python3 ───────────────────────────────────────────────────────
section 4 $TOTAL "Runtime: python3"
if should_install python3; then
  PY_FORMULA="python3"
  [[ "$PYTHON_VERSION" != "latest" ]] && PY_FORMULA="python@${PYTHON_VERSION}"
  run_step "Install $PY_FORMULA" brew install "$PY_FORMULA"
else
  printf "${GREEN}✅${NC}  ${DIM}$(python3 --version) (already installed)${NC}\n"
fi

# ── 5. Runtime: uv ───────────────────────────────────────────────────────────
section 5 $TOTAL "Runtime: uv"
if should_install uv; then
  run_step "Install uv" brew install uv
  if [[ "$UV_VERSION" != "latest" ]]; then
    printf "${YELLOW}⚠️ ${NC}  Homebrew installs the latest uv; use 'uv self update --version %s' to pin.\n" "$UV_VERSION"
  fi
else
  printf "${GREEN}✅${NC}  ${DIM}$(uv --version) (already installed)${NC}\n"
fi

# ── 6. CLI tools ─────────────────────────────────────────────────────────────
section 6 $TOTAL "CLI tools"
if should_install claude; then
  run_step "Install Claude Code CLI" bun install -g @anthropic-ai/claude-code \
    || run_step "Install Claude Code CLI (npm fallback)" npm install -g @anthropic-ai/claude-code
else
  printf "${GREEN}✅${NC}  claude ${DIM}(already installed)${NC}\n"
fi

if should_install codex; then
  # The npm bin is a Node.js launcher, so use the brew-cask standalone binary
  # (no Node dependency); brew's bin dir is already on PATH via shellenv.
  run_step "Install Codex CLI" brew install --cask codex
else
  printf "${GREEN}✅${NC}  codex ${DIM}(already installed)${NC}\n"
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

# No brew cask exists for the Codex Desktop app, so install it the way the
# official `codex app` command does: download the DMG, verify the OpenAI
# signature, and copy the bundle — without launching the app afterwards.
# The bundle ships as Codex.app or ChatGPT.app, both with the com.openai.codex
# bundle id, so detection checks the id (a stock ChatGPT.app is com.openai.chat).
codex_desktop_installed() {
  local app
  for app in "/Applications/Codex.app" "/Applications/ChatGPT.app" \
             "$HOME/Applications/Codex.app" "$HOME/Applications/ChatGPT.app"; do
    [[ -d "$app" ]] || continue
    [[ "$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist" 2>/dev/null)" \
      == "com.openai.codex" ]] && return 0
  done
  return 1
}

install_codex_desktop() {
  local dmg_url tmp_dir mnt app_src
  case "$(uname -m)" in
    arm64) dmg_url="https://persistent.oaistatic.com/codex-app-prod/Codex.dmg" ;;
    *)     dmg_url="https://persistent.oaistatic.com/codex-app-prod/Codex-latest-x64.dmg" ;;
  esac
  tmp_dir=$(mktemp -d)
  if ! curl -fsSL --retry 3 --retry-delay 1 "$dmg_url" -o "$tmp_dir/Codex.dmg"; then
    rm -rf "$tmp_dir"
    return 1
  fi
  mnt=$(hdiutil attach -nobrowse -readonly "$tmp_dir/Codex.dmg" | awk -F'\t' 'END {print $NF}')
  app_src=$(find "$mnt" -maxdepth 1 -name '*.app' 2>/dev/null | head -n 1)
  # Only install a bundle signed by OpenAI (team 2DC432GLL2) as com.openai.codex
  if [[ -z "$app_src" ]] || ! codesign --verify --deep --strict \
      --requirement 'identifier "com.openai.codex" and certificate leaf[subject.OU] = "2DC432GLL2"' \
      "$app_src"; then
    [[ -n "$mnt" ]] && hdiutil detach "$mnt" -force >/dev/null 2>&1
    rm -rf "$tmp_dir"
    echo "refusing to install an unverified Codex Desktop app"
    return 1
  fi
  local rc=0
  ditto "$app_src" "/Applications/${app_src##*/}" \
    || ditto "$app_src" "$HOME/Applications/${app_src##*/}" \
    || rc=1
  hdiutil detach "$mnt" >/dev/null 2>&1
  rm -rf "$tmp_dir"
  return $rc
}

if codex_desktop_installed; then
  printf "${GREEN}✅${NC}  Codex Desktop ${DIM}(already installed)${NC}\n"
else
  run_step "Install Codex Desktop App" install_codex_desktop \
    || printf "${YELLOW}⚠️ ${NC}  Codex Desktop — install manually by running: ${CYAN}codex app${NC}\n"
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
    printf "${GREEN}✅${NC}  ${DIM}$(docker --version) (already installed)${NC}\n"
  fi
fi

install_company_tools

# ── 8. Git config check ───────────────────────────────────────────────────────
section 8 $TOTAL "Git & GitHub"
check_git_and_gh

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary
