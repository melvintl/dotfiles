#!/usr/bin/env bash
# Bootstrap a fresh Debian/Ubuntu box. Mirrors INSTALL.md (the source of
# truth for the tool list and fallbacks) — read both before running.

sudo apt update

# NB: apt `neovim` is usually older than the 0.12+ this nvim config needs;
# grab the official release instead if so — see nvim/README.md.
sudo apt install -y \
  zsh tmux neovim vim-gtk3 exuberant-ctags \
  ripgrep silversearcher-ag fd-find bat jq ncdu tldr \
  direnv pipx zoxide \
  pgcli pspg \
  yamllint \
  lazygit git-delta gh \
  visidata \
  git curl wget openssh-server build-essential

# fd and bat install under different names on Debian/older Ubuntu
mkdir -p ~/.local/bin
command -v fd  >/dev/null || ln -sf "$(command -v fdfind)" ~/.local/bin/fd
command -v bat >/dev/null || { command -v batcat >/dev/null && ln -sf "$(command -v batcat)" ~/.local/bin/bat; }

# fzf from upstream: apt's fzf predates `fzf --zsh`, so .zshrc falls back to the
# ~/.fzf.zsh this creates
[ -d ~/.fzf ] || git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --key-bindings --completion --no-update-rc

# yazi is in apt only on Ubuntu 24.04+; cargo/release fallbacks in INSTALL.md
sudo apt install -y yazi || echo ">> yazi not packaged here; see INSTALL.md"

# hunk — standalone binary in ~/.hunk (shell/common.sh puts it on PATH)
command -v hunk >/dev/null || curl -fsSL https://hunk.dev/install.sh | sh

# Not packaged on apt — see INSTALL.md for install options:
#   jless, difftastic, kanata, tree-sitter-cli (npm/cargo), workmux
