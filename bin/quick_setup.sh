#!/usr/bin/env bash
# mkdir -p ~/myprojects
# cd myprojects
# git clone https://github.com/melvintl/dotfiles.git
# bash dotfiles/bin/quick_setup.sh

set -euo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOTFILES"

BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"

backup_path() {
  local target="$1"

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    return 0
  fi

  local relative="${target#$HOME/}"
  local backup="$BACKUP_DIR/$relative"
  mkdir -p "$(dirname "$backup")"

  mv "$target" "$backup"
  echo ">> Backed up $target to $backup"
}

link_file() {
  local source="$1"
  local target="$2"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    echo ">> $target already links to $source"
    return 0
  fi

  backup_path "$target"
  ln -s "$source" "$target"
}

copy_file() {
  local source="$1"
  local target="$2"

  # ! -L: a symlink whose content matches is still not the independent copy we want
  if [[ -f "$target" && ! -L "$target" ]] && cmp -s "$source" "$target"; then
    echo ">> $target already matches $source"
    return 0
  fi

  backup_path "$target"
  cp "$source" "$target"
}

link_file "$DOTFILES/.bashrc" ~/.bashrc
# ~/.tmux.conf takes precedence over ~/.config/tmux/tmux.conf, so don't shadow
# a config another tool owns (Omarchy ships one there)
if [[ -e ~/.config/tmux/tmux.conf ]]; then
  echo ">> ~/.config/tmux/tmux.conf exists; leaving tmux config alone"
else
  link_file "$DOTFILES/.tmux.conf" ~/.tmux.conf
fi
# .vimrc moved to legacy/; drop the symlink earlier runs created so Vim does
# not start with a dangling rc
if [[ -L ~/.vimrc && "$(readlink ~/.vimrc)" == "$DOTFILES/.vimrc" ]]; then
  rm ~/.vimrc
  echo ">> Removed stale ~/.vimrc link (config now lives in legacy/vimrc)"
fi
link_file "$DOTFILES/bin/tmux-session" ~/.tmux-session
link_file "$DOTFILES/.gitconfig" ~/.gitconfig
link_file "$DOTFILES/.gitignore" ~/.gitignore
# zsh is the Mac shell; only link it where zsh exists
if command -v zsh >/dev/null; then
  link_file "$DOTFILES/.zshrc" ~/.zshrc

  # What .zshrc sources. Shallow clones, skipped when already present; the
  # oh-my-zsh installer is avoided because it rewrites ~/.zshrc and runs chsh.
  clone_once() {
    local repo="$1" dest="$2"
    if [[ -d "$dest" ]]; then
      echo ">> $dest already present"
    else
      git clone --quiet --depth 1 "$repo" "$dest"
      echo ">> Cloned $repo -> $dest"
    fi
  }
  clone_once https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
  clone_once https://github.com/zsh-users/zsh-autosuggestions \
    ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  clone_once https://github.com/zsh-users/zsh-syntax-highlighting \
    ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
  clone_once https://github.com/chriskempson/base16-shell.git ~/.config/base16-shell
fi

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
copy_file "$DOTFILES/.config/yamllint/config" ~/.config/yamllint/config

mkdir -p ~/.config/pgcli/
copy_file "$DOTFILES/.config/pgcli/config" ~/.config/pgcli/config

# Link the file, not the directory: hunk keeps per-machine state.json next to its config
mkdir -p ~/.config/lazygit/ ~/.config/hunk/
link_file "$DOTFILES/.config/lazygit/config.yml" ~/.config/lazygit/config.yml
link_file "$DOTFILES/.config/hunk/config.toml" ~/.config/hunk/config.toml

# workmux global defaults; per-project .workmux.yaml files override them
mkdir -p ~/.config/workmux/
link_file "$DOTFILES/.config/workmux/config.yaml" ~/.config/workmux/config.yaml

# Hunk diff reviewer. Omarchy already ships it through mise
if ! command -v hunk >/dev/null; then
  if command -v mise >/dev/null; then
    mise use -g hunk
  else
    curl -fsSL https://hunk.dev/install.sh | sh
  fi
fi
