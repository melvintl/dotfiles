#!/usr/bin/env bash
# Bootstrap or refresh a macOS box. Mirrors INSTALL.md (the source of truth
# for the tool list) — read both before running.
#
# Assumes Homebrew is already installed. Safe to re-run: installs what is
# missing and upgrades what is outdated, only for the tools listed here.
#
# Skips the Python linters/fixers ALE uses (ruff, pylint, flake8, mypy, black,
# reorder-python-imports); install those per project or via pipx — see
# INSTALL.md.

set -euo pipefail

if ! command -v brew >/dev/null; then
  echo "Homebrew not found: https://brew.sh" >&2
  exit 1
fi

FORMULAE=(
  zsh tmux neovim vim universal-ctags
  # nvim-treesitter (main) shells out to this to build parsers. The plain
  # `tree-sitter` formula is the C library only and ships no binary.
  tree-sitter-cli
  fzf ripgrep the_silver_searcher fd bat jq jless ncdu yazi tldr
  direnv pipx zoxide
  pgcli pspg
  yamllint
  kanata
  lazygit git-delta gh hunk difftastic
  visidata
  # Language servers packaged by brew
  lua-language-server rust-analyzer
  # node: npm globals below need it
  node
  # workmux — git-worktree + tmux orchestration (tmux prefix+a dashboard)
  raine/workmux/workmux
)

CASKS=(
  font-jetbrains-mono-nerd-font
  font-fontawesome
  # Virtual HID driver kanata needs
  karabiner-elements
)

NPM_GLOBALS=(
  pyright
  typescript typescript-language-server
  prettier eslint
)

PIPX_TOOLS=(
  jedi-language-server
)

echo "==> brew update"
brew update

echo "==> formulae"
brew tap raine/workmux >/dev/null 2>&1 || true
missing=()
for f in "${FORMULAE[@]}"; do
  brew list --formula "${f##*/}" >/dev/null 2>&1 || missing+=("$f")
done
if ((${#missing[@]})); then
  brew install "${missing[@]}"
fi

echo "==> casks"
missing=()
for c in "${CASKS[@]}"; do
  brew list --cask "$c" >/dev/null 2>&1 || missing+=("$c")
done
# karabiner-elements runs a sudo installer; without a TTY that fails, so
# don't let one cask abort the rest of the run.
if ((${#missing[@]})); then
  brew install --cask "${missing[@]}" \
    || echo ">> cask install failed (needs sudo?); rerun: brew install --cask ${missing[*]}"
fi

echo "==> upgrade outdated (listed tools only)"
outdated=()
while IFS= read -r name; do
  for f in "${FORMULAE[@]}" "${CASKS[@]}"; do
    [[ "$name" == "${f##*/}" ]] && outdated+=("$name") && break
  done
done < <(brew outdated --quiet)
if ((${#outdated[@]})); then
  brew upgrade "${outdated[@]}"
else
  echo ">> nothing to upgrade"
fi

echo "==> fzf shell integration"
# .zshrc sources ~/.fzf.zsh, which brew doesn't create.
[[ -f ~/.fzf.zsh ]] || "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc

echo "==> npm globals"
npm install -g "${NPM_GLOBALS[@]}"

echo "==> pipx tools"
pipx ensurepath >/dev/null
for t in "${PIPX_TOOLS[@]}"; do
  # Skip if already on PATH from another installer (uv tool, system package)
  command -v "$t" >/dev/null || pipx install "$t"
done

cat <<'EOF'

Done. Manual follow-ups (see INSTALL.md):
  - kanata: activate the Karabiner driver once, then approve it in
    System Settings → General → Login Items & Extensions → Driver Extensions:
      /Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate
  - Python linters for ALE (ruff, pylint, flake8, mypy) are not installed here.
  - Neovim: open it and run :Lazy clean, :TSUpdate, :checkhealth.
  - `brew autoremove` drops dependencies nothing uses any more (e.g. the
    deprecated tree-sitter@0.25 after a neovim upgrade).
EOF
