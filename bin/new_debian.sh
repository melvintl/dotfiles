#!/usr/bin/env bash
# Bootstrap a fresh Debian/Ubuntu box: the base layer via apt, then the tool
# layer via mise (mise/config.toml, the one list shared by every OS). Read
# INSTALL.md first. Safe to re-run.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Base layer: system-level, needs root, or not in mise's registry. Everything
# else (neovim, ripgrep, fzf, lazygit, language servers, ...) is in
# mise/config.toml, which also sidesteps apt's stale neovim/fzf and the
# fdfind/batcat renames.
echo "==> base layer (apt)"
sudo apt update
sudo apt install -y \
  zsh tmux git vim-gtk3 universal-ctags \
  silversearcher-ag ncdu pspg \
  curl wget openssh-server build-essential

# mise itself: https://mise.jdx.dev/installing-mise.html. The installer puts it
# in ~/.local/bin, which shell/common.sh already has on PATH.
echo "==> mise"
if ! command -v mise >/dev/null && [[ ! -x "$HOME/.local/bin/mise" ]]; then
  curl -fsSL https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"

# Read the repo file directly so this works before `make setup` has linked it
# to ~/.config/mise/config.toml.
echo "==> tool layer (mise/config.toml)"
export MISE_GLOBAL_CONFIG_FILE="$DOTFILES/mise/config.toml"
mise install --yes
mise upgrade --yes

# Not on apt and not in mise: kanata — GitHub release binary, see INSTALL.md.
