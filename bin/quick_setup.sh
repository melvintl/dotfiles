#!/usr/bin/env bash
# mkdir -p ~/myprojects
# cd myprojects
# git clone https://github.com/melvintl/dotfiles.git
# bash dotfiles/bin/quick_setup.sh

set -euo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOTFILES"

MODE="setup"
DRY_RUN=0
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"

usage() {
  cat <<'EOF'
Usage: bin/quick_setup.sh [--dry-run] [--doctor|--links-only|--bootstrap-only]

Modes:
  setup             Link configs and clone shell/tmux deps (default)
  --links-only      Link/copy configs only; skip dependency clones
  --bootstrap-only  Clone shell/tmux deps only (existing clones are left
                    untouched, never updated); skip config links/copies
  --doctor          Report link/tool status without changing anything

Options:
  --dry-run         Print changes that would be made without writing
  -h, --help        Show this help
EOF
}

while (($#)); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --doctor) MODE="doctor" ;;
    --links-only) MODE="links" ;;
    --bootstrap-only) MODE="bootstrap" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

log() { printf '>> %s\n' "$*"; }

run() {
  if ((DRY_RUN)); then
    printf 'dry-run: '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

mkdir_p() {
  if [[ -d "$1" ]]; then
    return 0
  fi
  run mkdir -p "$1"
}

backup_path() {
  local target="$1"

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    return 0
  fi

  local relative="${target#"$HOME"/}"
  local backup="$BACKUP_DIR/$relative"
  mkdir_p "$(dirname "$backup")"

  run mv "$target" "$backup"
  log "Backed up $target to $backup"
}

link_file() {
  local source="$1"
  local target="$2"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    log "$target already links to $source"
    return 0
  fi

  backup_path "$target"
  run ln -s "$source" "$target"
}

copy_file() {
  local source="$1"
  local target="$2"

  # ! -L: a symlink whose content matches is still not the independent copy we want
  if [[ -f "$target" && ! -L "$target" ]] && cmp -s "$source" "$target"; then
    log "$target already matches $source"
    return 0
  fi

  backup_path "$target"
  run cp "$source" "$target"
}

remove_file() {
  local target="$1"
  run rm "$target"
}

write_file() {
  local target="$1"
  local content="$2"

  if [[ -f "$target" ]] && [[ "$(<"$target")" == "$content" ]]; then
    log "$target already up to date"
    return 0
  fi

  backup_path "$target"
  if ((DRY_RUN)); then
    log "Would write $target"
  else
    printf '%s' "$content" > "$target"
  fi
}

create_dotfiles_env() {
  local quoted_dotfiles
  printf -v quoted_dotfiles '%q' "$DOTFILES"
  write_file "$HOME/.dotfiles.env" "export DOTFILES_DIR=$quoted_dotfiles
"
}

clone_once() {
  local repo="$1" dest="$2"

  if [[ -d "$dest" ]]; then
    log "$dest already present"
  else
    run git clone --quiet --depth 1 "$repo" "$dest"
    log "Cloned $repo -> $dest"
  fi
}

link_status() {
  local source="$1" target="$2"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    printf 'ok: %s -> %s\n' "$target" "$source"
  elif [[ -e "$target" || -L "$target" ]]; then
    printf 'warn: %s exists but does not link to %s\n' "$target" "$source"
  else
    printf 'missing: %s -> %s\n' "$target" "$source"
  fi
}

file_status() {
  local source="$1" target="$2"

  if [[ -f "$target" && ! -L "$target" ]] && cmp -s "$source" "$target"; then
    printf 'ok: %s matches %s\n' "$target" "$source"
  elif [[ -e "$target" || -L "$target" ]]; then
    printf 'warn: %s exists but differs from %s\n' "$target" "$source"
  else
    printf 'missing: %s copy of %s\n' "$target" "$source"
  fi
}

doctor() {
  echo "==> dotfiles repo"
  printf 'ok: DOTFILES=%s\n' "$DOTFILES"
  if [[ -r "$HOME/.dotfiles.env" ]]; then
    printf 'ok: ~/.dotfiles.env exists\n'
  else
    printf 'missing: ~/.dotfiles.env (created by setup; exports DOTFILES_DIR)\n'
  fi

  echo "==> links"
  link_status "$DOTFILES/.bashrc" "$HOME/.bashrc"
  if [[ -e "$HOME/.config/tmux/tmux.conf" ]]; then
    printf 'warn: ~/.config/tmux/tmux.conf exists; setup leaves ~/.tmux.conf alone\n'
  else
    link_status "$DOTFILES/.tmux.conf" "$HOME/.tmux.conf"
  fi
  link_status "$DOTFILES/bin/tmux-session" "$HOME/.local/bin/tmux-session"
  link_status "$DOTFILES/.gitconfig" "$HOME/.gitconfig"
  link_status "$DOTFILES/.gitignore" "$HOME/.gitignore"
  link_status "$DOTFILES/nvim" "$HOME/.config/nvim"
  link_status "$DOTFILES/.config/kanata" "$HOME/.config/kanata"
  link_status "$DOTFILES/.config/omarchy/themes/one-dark" "$HOME/.config/omarchy/themes/one-dark"
  link_status "$DOTFILES/.config/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
  link_status "$DOTFILES/.config/hunk/config.toml" "$HOME/.config/hunk/config.toml"
  link_status "$DOTFILES/.config/workmux/config.yaml" "$HOME/.config/workmux/config.yaml"
  link_status "$DOTFILES/.config/glow/glow.yml" "$HOME/.config/glow/glow.yml"
  for f in yazi.toml theme.toml package.toml; do
    link_status "$DOTFILES/.config/yazi/$f" "$HOME/.config/yazi/$f"
  done
  if command -v zsh >/dev/null; then
    link_status "$DOTFILES/.zshrc" "$HOME/.zshrc"
  else
    printf 'warn: zsh not found; setup skips ~/.zshrc\n'
  fi

  echo "==> copied configs"
  file_status "$DOTFILES/.config/yamllint/config" "$HOME/.config/yamllint/config"
  file_status "$DOTFILES/.config/pgcli/config" "$HOME/.config/pgcli/config"

  echo "==> tools"
  for cmd in git zsh tmux nvim rg fd fzf jq lazygit delta glow hunk workmux; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf 'ok: %s found\n' "$cmd"
    else
      printf 'warn: %s not found\n' "$cmd"
    fi
  done
}

link_configs() {
  create_dotfiles_env

  link_file "$DOTFILES/.bashrc" "$HOME/.bashrc"
  # ~/.tmux.conf takes precedence over ~/.config/tmux/tmux.conf, so don't shadow
  # a config another tool owns (Omarchy ships one there)
  if [[ -e "$HOME/.config/tmux/tmux.conf" ]]; then
    log "$HOME/.config/tmux/tmux.conf exists; leaving tmux config alone"
  else
    link_file "$DOTFILES/.tmux.conf" "$HOME/.tmux.conf"
  fi
  # .vimrc moved to legacy/; drop the symlink earlier runs created so Vim does
  # not start with a dangling rc
  if [[ -L "$HOME/.vimrc" && "$(readlink "$HOME/.vimrc")" == "$DOTFILES/.vimrc" ]]; then
    remove_file "$HOME/.vimrc"
    if ((DRY_RUN)); then
      log "Would remove stale ~/.vimrc link (config now lives in legacy/vimrc)"
    else
      log "Removed stale ~/.vimrc link (config now lives in legacy/vimrc)"
    fi
  fi
  # tmux-session goes on PATH; ~/.tmux-session must not point at the script
  if [[ -L "$HOME/.tmux-session" && "$(readlink "$HOME/.tmux-session")" == "$DOTFILES/bin/tmux-session" ]]; then
    remove_file "$HOME/.tmux-session"
    if ((DRY_RUN)); then
      log "Would remove stale ~/.tmux-session link (script now in ~/.local/bin)"
    else
      log "Removed stale ~/.tmux-session link (script now in ~/.local/bin)"
    fi
  fi
  mkdir_p "$HOME/.local/bin"
  link_file "$DOTFILES/bin/tmux-session" "$HOME/.local/bin/tmux-session"
  link_file "$DOTFILES/.gitconfig" "$HOME/.gitconfig"
  link_file "$DOTFILES/.gitignore" "$HOME/.gitignore"

  # Editor config.
  mkdir_p "$HOME/.config"
  link_file "$DOTFILES/nvim" "$HOME/.config/nvim"

  # Keyboard remap and Omarchy theme configs
  mkdir_p "$HOME/.config/omarchy/themes"
  link_file "$DOTFILES/.config/kanata" "$HOME/.config/kanata"
  link_file "$DOTFILES/.config/omarchy/themes/one-dark" "$HOME/.config/omarchy/themes/one-dark"

  # zsh is the Mac shell; only link it where zsh exists
  if command -v zsh >/dev/null; then
    link_file "$DOTFILES/.zshrc" "$HOME/.zshrc"
  fi

  # Per-machine layer: identity + secrets live in ~/*.local, never in the repo.
  if [[ ! -f "$HOME/.gitconfig.local" ]]; then
    copy_file "$DOTFILES/.gitconfig.local.example" "$HOME/.gitconfig.local"
    if ((DRY_RUN)); then
      log "Would create ~/.gitconfig.local from template"
    else
      log "Created ~/.gitconfig.local — edit it and set your name/email before committing anything."
    fi
  fi
  for rc in "$HOME/.bashrc.local" "$HOME/.zshrc.local"; do
    if [[ ! -f "$rc" ]]; then
      write_file "$rc" '# Machine-local shell config: API keys, client PATHs, proxies. Not tracked.
'
      run chmod 600 "$rc"
    fi
  done

  mkdir_p "$HOME/.config/yamllint"
  copy_file "$DOTFILES/.config/yamllint/config" "$HOME/.config/yamllint/config"

  mkdir_p "$HOME/.config/pgcli"
  copy_file "$DOTFILES/.config/pgcli/config" "$HOME/.config/pgcli/config"

  # Link the file, not the directory: hunk keeps per-machine state.json next to its config
  mkdir_p "$HOME/.config/lazygit"
  mkdir_p "$HOME/.config/hunk"
  link_file "$DOTFILES/.config/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
  link_file "$DOTFILES/.config/hunk/config.toml" "$HOME/.config/hunk/config.toml"

  # workmux global defaults; per-project .workmux.yaml files override them
  mkdir_p "$HOME/.config/workmux"
  link_file "$DOTFILES/.config/workmux/config.yaml" "$HOME/.config/workmux/config.yaml"

  # Glow markdown renderer defaults.
  mkdir_p "$HOME/.config/glow"
  link_file "$DOTFILES/.config/glow/glow.yml" "$HOME/.config/glow/glow.yml"

  # Link the files, not the directory: `ya pkg` installs flavors/ and plugins/
  # next to them per machine.
  mkdir_p "$HOME/.config/yazi"
  for f in yazi.toml theme.toml package.toml; do
    link_file "$DOTFILES/.config/yazi/$f" "$HOME/.config/yazi/$f"
  done
}

bootstrap_shell_deps() {
  if command -v zsh >/dev/null; then
    # What .zshrc sources. Shallow clones, skipped when already present; the
    # oh-my-zsh installer is avoided because it rewrites ~/.zshrc and runs chsh.
    clone_once https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
    clone_once https://github.com/zsh-users/zsh-autosuggestions \
      "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    clone_once https://github.com/zsh-users/zsh-syntax-highlighting \
      "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    clone_once https://github.com/chriskempson/base16-shell.git "$HOME/.config/base16-shell"
  else
    log "zsh not found; skipping zsh dependency bootstrap"
  fi

  # tmux plugins that .tmux.conf loads with run-shell (no plugin manager).
  clone_once https://github.com/laktak/extrakto "$HOME/.tmux/plugins/extrakto"
  clone_once https://github.com/omerxx/tmux-floax "$HOME/.tmux/plugins/tmux-floax"
}

case "$MODE" in
  setup)
    link_configs
    bootstrap_shell_deps
    ;;
  links)
    link_configs
    ;;
  bootstrap)
    bootstrap_shell_deps
    ;;
  doctor)
    doctor
    ;;
  *)
    echo "internal error: unknown mode $MODE" >&2
    exit 2
    ;;
esac
