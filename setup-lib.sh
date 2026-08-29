#!/usr/bin/env bash
# Workshop Setup — shared bash helpers (sourced by setup-linux.sh / setup-mac.sh)
# Not meant to be executed directly.

# ── ANSI colors ───────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m';  BOLD='\033[1m';      DIM='\033[2m';  NC='\033[0m'

# ── Animation helpers ─────────────────────────────────────────────────────────
SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
ERRORS=()
BG_PIDS=()

# ── Flags ─────────────────────────────────────────────────────────────────────
FORCE=0
for arg in "$@"; do
  [[ "$arg" == "--force" ]] && FORCE=1
done

# ── Version pins (override via env, e.g. BUN_VERSION=1.1.34 bash setup-linux.sh) ──
BUN_VERSION="${BUN_VERSION:-latest}"
UV_VERSION="${UV_VERSION:-latest}"
PYTHON_VERSION="${PYTHON_VERSION:-latest}"

section() {
  local num=$1 total=$2 label="$3"
  local pct=$(( num * 100 / total ))
  local width=22
  local filled=$(( width * pct / 100 ))
  local bar="" i=0
  while [ $i -lt $filled ]; do bar="${bar}█"; i=$((i + 1)); done
  while [ $i -lt $width ];  do bar="${bar}░"; i=$((i + 1)); done
  printf "\n${BOLD}${CYAN}[%d/%d]${NC} %-32s ${YELLOW}[%s] %3d%%${NC}\n" \
    "$num" "$total" "$label" "$bar" "$pct"
}

run_step() {
  local label="$1"; shift
  local tmplog; tmplog=$(mktemp)
  local i=0

  "$@" >"$tmplog" 2>&1 &
  local pid=$!
  BG_PIDS+=("$pid")

  while kill -0 "$pid" 2>/dev/null; do
    local ch="${SPIN:$(( i % ${#SPIN} )):1}"
    printf "\r  ${CYAN}%s${NC}  %s" "$ch" "$label"
    i=$(( i + 1 ))
    sleep 0.08
  done

  wait "$pid"; local rc=$?
  if [[ $rc -eq 0 ]]; then
    printf "\r${GREEN}✅${NC}  %s\n" "$label"
  else
    printf "\r${RED}❌${NC}  %s\n" "$label"
    # tail: errors usually appear at the end of output (matches PS RunStep)
    sed 's/^/     /' "$tmplog" | tail -5 || true
    ERRORS+=("$label")
  fi
  rm -f "$tmplog"
  return $rc
}

installed() { command -v "$1" &>/dev/null; }

# Skip an install step unless the tool is missing or --force was passed.
should_install() {
  ! installed "$1" || [[ $FORCE -eq 1 ]]
}

# Print the SHA-256 of a downloaded installer for auditability.
print_sha256() {
  local sum
  sum=$(command -v sha256sum &>/dev/null && sha256sum "$1" | cut -d' ' -f1 || shasum -a 256 "$1" | cut -d' ' -f1)
  printf "     ${DIM}installer sha256: %s${NC}\n" "$sum"
}

# Download a remote installer to a temp file, print its SHA-256 for auditability,
# then execute it — safer than a bare `curl | bash` because the script is on disk
# (reviewable, loggable) before it runs.
fetch_and_run() {
  local url="$1"; shift
  local runner=("$@")
  local tmp; tmp=$(mktemp)
  if ! curl -fsSL --retry 3 --retry-delay 1 "$url" -o "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  print_sha256 "$tmp"
  "${runner[@]}" "$tmp"
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# Install bun via the official installer, or `bun upgrade` when already present
# (parity with setup-windows.ps1). Accepts shell rc file paths as arguments;
# a PATH export line is appended to each (idempotent).
install_bun() {
  local rc_files=("$@")
  if installed bun && [[ $FORCE -eq 0 ]]; then
    run_step "Update bun" bun upgrade
    export PATH="$HOME/.bun/bin:$PATH"
  else
    local tmp; tmp=$(mktemp)
    if curl -fsSL --retry 3 --retry-delay 1 https://bun.sh/install -o "$tmp"; then
      print_sha256 "$tmp"
      if [[ "$BUN_VERSION" != "latest" ]]; then
        run_step "Install bun ($BUN_VERSION)" bash "$tmp" "$BUN_VERSION"
      else
        run_step "Install bun (latest)" bash "$tmp"
      fi
    else
      printf "${RED}❌${NC}  Failed to download bun installer\n"
      ERRORS+=("Install bun")
      rm -f "$tmp"
      return 1
    fi
    rm -f "$tmp"
    export PATH="$HOME/.bun/bin:$PATH"
  fi
  for rc in "${rc_files[@]}"; do
    # touch: default shell rc may not exist yet (fresh accounts)
    touch "$rc"
    grep -qF '.bun/bin' "$rc" 2>/dev/null \
      || echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$rc"
  done
}

# Verify git identity and gh auth status, warning when unconfigured.
check_git_and_gh() {
  local git_name git_email
  git_name=$(git config --global user.name  2>/dev/null || true)
  git_email=$(git config --global user.email 2>/dev/null || true)
  if [[ -n "$git_name" && -n "$git_email" ]]; then
    printf "${GREEN}✅${NC}  git config: ${CYAN}%s <%s>${NC}\n" "$git_name" "$git_email"
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
}

# Final summary; exits 1 when any step failed.
print_summary() {
  printf "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}\n"
  if [[ ${#ERRORS[@]} -eq 0 ]]; then
    printf "${GREEN}✅  All steps complete!${NC}\n"
    printf "\n  Next → ${CYAN}bun setup-common.ts${NC}\n"
  else
    printf "${RED}❌  Failed: %s${NC}\n" "${ERRORS[*]}"
    exit 1
  fi
  printf "${BOLD}${CYAN}══════════════════════════════════════════${NC}\n\n"
}

# ── Preflight checks: internet, disk space, OS info ───────────────────────────
preflight_checks() {
  printf "${CYAN}🔍  Preflight checks...${NC}\n"

  # Probe with whichever downloader exists — curl isn't always preinstalled
  # (fresh containers/servers); Base tools installs it right after this.
  local have_downloader=0 net_ok=1
  if command -v curl &>/dev/null; then
    have_downloader=1
    curl -fsS --max-time 5 -o /dev/null https://github.com && net_ok=0
  elif command -v wget &>/dev/null; then
    have_downloader=1
    wget -q --timeout=5 -O /dev/null https://github.com && net_ok=0
  fi
  # Fallback host guards against DNS/CDN hiccups blocking a working network.
  if [[ $have_downloader -eq 1 && $net_ok -ne 0 ]]; then
    if command -v curl &>/dev/null; then
      curl -fsS --max-time 5 -o /dev/null https://1.1.1.1 && net_ok=0
    else
      wget -q --timeout=5 -O /dev/null https://1.1.1.1 && net_ok=0
    fi
  fi

  if [[ $have_downloader -eq 0 ]]; then
    printf "${YELLOW}⚠️ ${NC}  No curl/wget yet — skipping internet check (Base tools installs curl).\n"
  elif [[ $net_ok -eq 0 ]]; then
    printf "${GREEN}✅${NC}  Internet connection OK\n"
  else
    printf "${RED}❌${NC}  No internet connection. Check your network and retry.\n"
    exit 1
  fi

  local avail_kb
  if avail_kb=$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}'); then
    local avail_gb=$(( avail_kb / 1024 / 1024 ))
    if [[ $avail_gb -lt 5 ]]; then
      printf "${RED}❌${NC}  Low disk space: ${avail_gb}GB free (5GB required)\n"
      exit 1
    else
      printf "${GREEN}✅${NC}  Disk space: ${avail_gb}GB free\n"
    fi
  fi

  printf "${GREEN}✅${NC}  OS: %s\n" "$(uname -srm)"
}

# ── Logging: tee all output to a timestamped log file ─────────────────────────
init_logging() {
  local platform="$1"
  local log_dir="$HOME/workshop-setup-logs"
  mkdir -p "$log_dir"
  LOG_FILE="$log_dir/setup-${platform}-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

# ── Cleanup: kill any stray background jobs on exit/interrupt ────────────────
cleanup() {
  for pid in "${BG_PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf "${DIM}  📝  Log saved: %s${NC}\n" "$LOG_FILE"
  fi
}
trap cleanup EXIT
# Exit explicitly on signals so Ctrl+C actually stops the script
# (a bare `trap cleanup INT` would resume execution after the handler).
trap 'exit 130' INT
trap 'exit 143' TERM
