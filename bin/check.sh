#!/usr/bin/env bash
# Repository health checks for these dotfiles.
# Safe by default: parses configs and scripts, but does not install tools or
# write into the user's home directory.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=0
warnings=0

info() { printf '==> %s\n' "$*"; }
ok() { printf 'ok: %s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }

run_check() {
  local label="$1"
  shift

  if "$@"; then
    ok "$label"
  else
    fail "$label"
  fi
}

require_file() {
  local path="$1"
  [[ -e "$path" ]]
}

git_config_parses() {
  git config --file .gitconfig --list >/dev/null
}

nvim_smoke() {
  nvim --headless -u nvim/init.lua '+qa'
}

info "required files"
for path in \
  README.md \
  INSTALL.md \
  .bashrc \
  .zshrc \
  .tmux.conf \
  .tmux.conf.local \
  .gitconfig \
  .gitconfig.local.example \
  shell/common.sh \
  nvim/init.lua
  do
  run_check "$path exists" require_file "$path"
done

info "bash syntax"
while IFS= read -r path; do
  run_check "bash -n $path" bash -n "$path"
done < <(find bin -maxdepth 1 -type f \( -name '*.sh' -o -perm -111 \) | sort)
run_check "bash -n .bashrc" bash -n .bashrc
run_check "bash -n shell/common.sh" bash -n shell/common.sh

info "zsh syntax"
if command -v zsh >/dev/null 2>&1; then
  run_check "zsh -n .zshrc" zsh -n .zshrc
else
  warn "zsh not found; skipping .zshrc parse check"
fi

info "git config"
run_check "git config parses" git_config_parses

info "Lua syntax"
lua_compiler=""
for candidate in luac luac5.4 luac5.3 luac5.2 luac5.1; do
  if command -v "$candidate" >/dev/null 2>&1; then
    lua_compiler="$candidate"
    break
  fi
done

if [[ -n "$lua_compiler" ]]; then
  while IFS= read -r path; do
    run_check "$lua_compiler -p $path" "$lua_compiler" -p "$path"
  done < <(find nvim -type f -name '*.lua' | sort)
else
  warn "luac not found; skipping Neovim Lua syntax checks"
fi

info "Neovim smoke test"
if [[ "${RUN_NVIM_SMOKE:-0}" == "1" ]]; then
  if command -v nvim >/dev/null 2>&1; then
    run_check "nvim --headless startup" nvim_smoke
  else
    fail "RUN_NVIM_SMOKE=1 but nvim not found"
  fi
else
  warn "skipping Neovim startup smoke test; set RUN_NVIM_SMOKE=1 to enable"
fi

info "optional tool availability"
for cmd in git tmux nvim rg fd fzf jq lazygit delta hunk workmux; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd found"
  else
    warn "$cmd not found"
  fi
done

printf '\nSummary: %d failure(s), %d warning(s)\n' "$failures" "$warnings"

if (( failures > 0 )); then
  exit 1
fi
