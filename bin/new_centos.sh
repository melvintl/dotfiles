#!/usr/bin/env bash
# Bootstrap a fresh RHEL-family box (Rocky/Alma/CentOS Stream 9+, dnf): the
# base layer via dnf, then the tool layer via mise (mise/config.toml, the one
# list shared by every OS). Starting point only — read INSTALL.md first.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> base layer (dnf)"
sudo dnf install -y epel-release
sudo dnf update -y
sudo dnf install -y \
  zsh tmux git vim-enhanced \
  the_silver_searcher ncdu \
  curl wget openssh-server
# Check EPEL for the rest of the base layer (`dnf search ctags pspg`); neither
# is in mise's registry.

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
