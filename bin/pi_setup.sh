#!/usr/bin/env bash
# Symlink pi coding-agent config from this repo into ~/.pi/agent.
#
# Anything already at a destination that is not the correct symlink is moved
# into a timestamped backup directory before the link is created.
#
# pi-plan-mode.json is copied rather than linked: the extension opens its
# settings with O_NOFOLLOW and ignores a symlink. Re-run this script after
# editing it in the repo.
#
# Usage: bin/pi_setup.sh [-n|--dry-run]

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DOTFILES/pi/agent"
DEST="${PI_AGENT_DIR:-$HOME/.pi/agent}"
BACKUP="$HOME/.pi/agent.backup-$(date +%Y%m%d-%H%M%S)"

LINK_ITEMS=(
  APPEND_SYSTEM.md
  settings.json
  models.json
  pi-lsp.json
  extensions
  prompts
  skills
  themes
)

COPY_ITEMS=(
  pi-plan-mode.json
)

dry_run=0
backed_up=0
case "${1:-}" in
  -n|--dry-run) dry_run=1 ;;
  "") ;;
  *) echo "usage: $0 [-n|--dry-run]" >&2; exit 2 ;;
esac

run() {
  if (( dry_run )); then
    echo "  would: $*"
  else
    "$@"
  fi
}

backup() {
  local path="$1"
  if (( ! backed_up )); then
    run mkdir -p "$BACKUP"
    backed_up=1
  fi
  run mv "$path" "$BACKUP/"
}

run mkdir -p "$DEST"

for item in "${LINK_ITEMS[@]}"; do
  src="$SRC/$item"
  dest="$DEST/$item"

  if [[ ! -e "$src" ]]; then
    echo "skip    $item (missing in dotfiles: $src)"
    continue
  fi

  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    echo "ok      $item"
    continue
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "backup  $item -> $BACKUP/"
    backup "$dest"
  fi

  echo "link    $item -> $src"
  run ln -s "$src" "$dest"
done

for item in "${COPY_ITEMS[@]}"; do
  src="$SRC/$item"
  dest="$DEST/$item"

  if [[ ! -f "$src" ]]; then
    echo "skip    $item (missing in dotfiles: $src)"
    continue
  fi

  if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$src" "$dest"; then
    echo "ok      $item (copy)"
    continue
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "backup  $item -> $BACKUP/"
    backup "$dest"
  fi

  echo "copy    $item <- $src"
  run cp "$src" "$dest"
done

if (( backed_up )); then
  echo
  echo "Previous files saved in: $BACKUP"
fi
