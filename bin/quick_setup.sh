#!/usr/bin/env bash
# mkdir -p ~/myprojects
# cd myprojects
# git clone https://github.com/melvintl/dotfiles.git
# bash dotfiles/bin/quick_setup.sh

set -euo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOTFILES"

ln -s -f "$DOTFILES/.bashrc" ~/.bashrc
# ~/.tmux.conf takes precedence over ~/.config/tmux/tmux.conf, so don't shadow
# a config another tool owns (Omarchy ships one there)
if [[ -e ~/.config/tmux/tmux.conf ]]; then
  echo ">> ~/.config/tmux/tmux.conf exists; leaving tmux config alone"
else
  ln -s -f "$DOTFILES/.tmux.conf" ~/.tmux.conf
  ln -s -f "$DOTFILES/.tmux.conf.local" ~/.tmux.conf.local
fi
ln -s -f "$DOTFILES/.vimrc" ~/.vimrc
ln -s -f "$DOTFILES/bin/tmux-session" ~/.tmux-session
ln -s -f "$DOTFILES/.gitconfig" ~/.gitconfig
ln -s -f "$DOTFILES/.gitignore" ~/.gitignore
# zsh is the Mac shell; only link it where zsh exists
command -v zsh >/dev/null && ln -s -f "$DOTFILES/.zshrc" ~/.zshrc

# Per-machine layer: identity + secrets live in ~/*.local, never in the repo.
if [[ ! -f ~/.gitconfig.local ]]; then
  cp "$DOTFILES/.gitconfig.local.example" ~/.gitconfig.local
  echo ">> Created ~/.gitconfig.local — edit it and set your name/email before committing anything."
fi
for rc in ~/.bashrc.local ~/.zshrc.local; do
  if [[ ! -f "$rc" ]]; then
    printf '# Machine-local shell config: API keys, client PATHs, proxies. Not tracked.\n' > "$rc"
    chmod 600 "$rc"
  fi
done

mkdir -p ~/.config/yamllint/
cp ./.config/yamllint/config ~/.config/yamllint/

mkdir -p ~/.config/pgcli/
cp ./.config/pgcli/config ~/.config/pgcli/

# Link the file, not the directory: hunk keeps per-machine state.json next to its config
mkdir -p ~/.config/lazygit/ ~/.config/hunk/
ln -s -f "$DOTFILES/.config/lazygit/config.yml" ~/.config/lazygit/config.yml
ln -s -f "$DOTFILES/.config/hunk/config.toml" ~/.config/hunk/config.toml

# Hunk diff reviewer. Omarchy already ships it through mise
if ! command -v hunk >/dev/null; then
  if command -v mise >/dev/null; then
    mise use -g hunk
  else
    curl -fsSL https://hunk.dev/install.sh | sh
  fi
fi
