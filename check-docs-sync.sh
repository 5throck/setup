#!/usr/bin/env bash
# Guards against SETUP.md drifting from the actual scripts.
# Checks: every CLI flag documented in SETUP.md exists (as a literal string)
# in its corresponding script, and vice versa for the flags advertised in
# each script's own usage comment.
set -uo pipefail

FAIL=0

check_flag() {
  local doc="$1" script="$2" flag="$3"
  if ! grep -q -- "$flag" "$doc"; then
    echo "❌ $doc is missing documentation for '$flag' (present in $script)"
    FAIL=1
  fi
  if ! grep -q -- "$flag" "$script"; then
    echo "❌ $script no longer supports '$flag' but SETUP.md still documents it"
    FAIL=1
  fi
}

check_flag SETUP.md setup-linux.sh "--wezterm"
check_flag SETUP.md setup-linux.sh "--docker"
check_flag SETUP.md setup-linux.sh "--force"
check_flag SETUP.md setup-mac.sh   "--wezterm"
check_flag SETUP.md setup-mac.sh   "--docker"
check_flag SETUP.md setup-mac.sh   "--force"
check_flag SETUP.md setup-windows.ps1 "-WSL2"
check_flag SETUP.md setup-windows.ps1 "-WezTerm"
check_flag SETUP.md setup-windows.ps1 "-Docker"
check_flag SETUP.md setup-windows.ps1 "-Force"
check_flag SETUP.md setup-common.ts   "--json"

if [[ $FAIL -eq 0 ]]; then
  echo "✅ SETUP.md flags are in sync with the scripts"
else
  exit 1
fi
