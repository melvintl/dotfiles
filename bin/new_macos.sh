#!/usr/bin/env bash
# Bootstrap or refresh a macOS box: the base layer via Homebrew, then the tool
# layer via mise (mise/config.toml, the one list shared by every OS). Read
# INSTALL.md first.
#
# Assumes Homebrew is already installed. Safe to re-run: installs what is
# missing and upgrades what is outdated, only for the tools listed here and in
# mise/config.toml.
#
# Skips the Python linters/fixers ALE uses (ruff, pylint, flake8, mypy, black,
# reorder-python-imports); install those per project — see INSTALL.md.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v brew >/dev/null; then
  echo "Homebrew not found: https://brew.sh" >&2
  exit 1
fi

# Base layer: system-level, needs root, or not in mise's registry. Everything
# else (neovim, ripgrep, lazygit, language servers, ...) is in mise/config.toml.
FORMULAE=(
  zsh tmux git vim universal-ctags
  the_silver_searcher ncdu pspg
  kanata
  mise
)

CASKS=(
  font-jetbrains-mono-nerd-font
  font-fontawesome
  # Virtual HID driver kanata needs
  karabiner-elements
)

echo "==> brew update"
brew update

echo "==> formulae"
missing=()
for f in "${FORMULAE[@]}"; do
  brew list --formula "$f" >/dev/null 2>&1 || missing+=("$f")
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
    [[ "$name" == "$f" ]] && outdated+=("$name") && break
  done
done < <(brew outdated --quiet)
if ((${#outdated[@]})); then
  brew upgrade "${outdated[@]}"
else
  echo ">> nothing to upgrade"
fi

# Read the repo file directly so this works before `make setup` has linked it
# to ~/.config/mise/config.toml.
echo "==> tool layer (mise/config.toml)"
export MISE_GLOBAL_CONFIG_FILE="$DOTFILES/mise/config.toml"
mise install --yes
mise upgrade --yes

cat <<'MSG'

Done. Manual follow-ups (see INSTALL.md):
  - Open a new shell: .zshrc runs `mise activate zsh` to put the tool layer
    on PATH. If brew also has a copy of something now in mise/config.toml
    (neovim, ripgrep, ...), `brew uninstall` it so only one copy runs.
  - kanata: activate the Karabiner driver once, then approve it in
    System Settings → General → Login Items & Extensions → Driver Extensions:
      /Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate
  - Python linters for ALE (ruff, pylint, flake8, mypy) are not installed here.
  - Neovim: open it and run :Lazy clean, :TSUpdate, :checkhealth.
  - `brew autoremove` drops dependencies nothing uses any more.
MSG
