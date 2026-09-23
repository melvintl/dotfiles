#!/usr/bin/env bash
# Bootstrap a fresh RHEL-family box (Rocky/Alma/CentOS Stream 9+, dnf).
# Starting point only — INSTALL.md is the source of truth; read both first.

sudo dnf install -y epel-release
sudo dnf update -y

# NB: EPEL `neovim` may lag the 0.12+ this nvim config needs — see nvim/README.md.
sudo dnf install -y \
  zsh tmux neovim vim-enhanced \
  ripgrep fd-find bat jq ncdu \
  direnv zoxide \
  yamllint \
  the_silver_searcher \
  git curl wget openssh-server

# fzf from upstream: creates the ~/.fzf.zsh that .zshrc sources
[ -d ~/.fzf ] || git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --key-bindings --completion --no-update-rc

# hunk — standalone binary in ~/.hunk (shell/common.sh puts it on PATH)
command -v hunk >/dev/null || curl -fsSL https://hunk.dev/install.sh | sh

# Not in base/EPEL — see INSTALL.md for the usual fallbacks:
#   lazygit (copr: atim/lazygit), git-delta + difftastic (cargo or GitHub
#   releases), gh (https://cli.github.com/packages), pgcli/pspg/visidata
#   (pipx / source), jless, yazi, tldr (npm/pipx), tree-sitter-cli, workmux
