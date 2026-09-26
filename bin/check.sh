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

# Compile-only Lua syntax check through Neovim's bundled LuaJIT, used when no
# standalone luac is installed (macOS without `brew install lua`).
lua_syntax_nvim() {
  nvim --clean --headless -l "$LUA_CHECK_SCRIPT" "$1"
}

# Start Neovim against this repo's config in a throwaway XDG tree so nothing
# in ~/.local/share/nvim is touched. `Lazy! restore` installs the plugins at the
# lazy-lock.json commits (network); the second start is the real test and
# fails on anything Neovim reports as an error while loading init.lua.
nvim_smoke() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/config" "$tmp/data" "$tmp/state" "$tmp/cache"
  ln -s "$ROOT/nvim" "$tmp/config/nvim"

  local rc=0
  (
    export XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
           XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache"
    nvim --headless '+Lazy! restore' '+qa' >"$tmp/restore.log" 2>&1 \
      || { echo "plugin restore failed:"; tail -20 "$tmp/restore.log"; exit 1; }
    nvim --headless '+qa' >"$tmp/start.log" 2>&1 \
      || { echo "startup exited non-zero:"; cat "$tmp/start.log"; exit 1; }
    if grep -Eq '(^|\s)E[0-9]+:|Error detected|Error executing|stack traceback' "$tmp/start.log"; then
      echo "errors during startup:"; cat "$tmp/start.log"; exit 1
    fi
  ) || rc=$?
  rm -rf "$tmp"
  return "$rc"
}

info "required files"
for path in \
  README.md \
  INSTALL.md \
  .bashrc \
  .zshrc \
  .tmux.conf \
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
elif command -v nvim >/dev/null 2>&1; then
  LUA_CHECK_SCRIPT="$(mktemp)"
  cat >"$LUA_CHECK_SCRIPT" <<'LUA'
local f, err = loadfile(arg[1])
if not f then io.stderr:write(err, "\n") os.exit(1) end
LUA
  while IFS= read -r path; do
    run_check "nvim loadfile $path" lua_syntax_nvim "$path"
  done < <(find nvim -type f -name '*.lua' | sort)
  rm -f "$LUA_CHECK_SCRIPT"
else
  warn "neither luac nor nvim found; skipping Neovim Lua syntax checks"
fi

info "Lua formatting"
if command -v stylua >/dev/null 2>&1; then
  run_check "stylua --check nvim" stylua --check nvim
else
  warn "stylua not found; skipping Lua format check (brew install stylua / cargo install stylua)"
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
