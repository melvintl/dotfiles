# Tracked in ~/myprojects/dotfiles — symlinked to ~/.bashrc by bin/quick_setup.sh
# Base layout comes from Omarchy's default ~/.bashrc; keep overrides at the bottom.

# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
[[ -r "$OMARCHY_PATH/default/bash/rc" ]] && source "$OMARCHY_PATH/default/bash/rc"

# Shared with .zshrc
DOTFILES="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
[[ -r "$DOTFILES/shell/common.sh" ]] && source "$DOTFILES/shell/common.sh"

alias ll=ls # specifically for omarchy

# mise tool layer (mise/config.toml). Omarchy's rc activates it already
# (MISE_SHELL set); this covers the bashrc on any other box.
[[ -z "${MISE_SHELL:-}" ]] && command -v mise >/dev/null && eval "$(mise activate bash)"

# Machine-local (untracked): API keys, client PATHs. Keep last so it wins.
[[ -r ~/.bashrc.local ]] && source ~/.bashrc.local
