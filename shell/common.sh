# shellcheck shell=sh
# Sourced by both .bashrc and .zshrc — keep it POSIX-ish

export EDITOR=nvim
export VISUAL="$EDITOR"
export SUDO_EDITOR="$EDITOR"

# Skip missing dirs and duplicates (rc files get re-sourced by tmux splits etc.)
path_add() {
  [ -d "$1" ] || return 0
  case ":$PATH:" in *":$1:"*) ;; *) export PATH="$1:$PATH" ;; esac
}
path_add "$HOME/.cargo/bin"
path_add "$HOME/.local/bin"
path_add "$HOME/.bun/bin"
path_add "$HOME/.hunk/bin"

alias v=vim
alias n=nvim
alias l=lazygit
alias h="hunk diff --watch"
alias wm=workmux
alias cc=claude
alias glowt="glow --tui --pager=false"

# Make Glow wrap to the current terminal width by default.
glow() {
  case " $* " in
    *" --width "*|*" --width="*|*" -w "*|*" -w"*) command glow "$@" ;;
    *)
      _glow_width=${COLUMNS:-}
      if [ -z "$_glow_width" ] && command -v tput >/dev/null 2>&1; then
        _glow_width=$(tput cols 2>/dev/null)
      fi
      command glow --width "${_glow_width:-80}" "$@"
      unset _glow_width
      ;;
  esac
}

# Copy a file's contents (or stdin) to the local clipboard via OSC 52
# (works over SSH without X11 forwarding/xclip; in tmux needs `set-clipboard on`)
clipcopy() {
  printf '\033]52;c;%s\a' "$( { [ $# -ge 1 ] && cat -- "$1" || cat; } | base64 | tr -d '\n')"
}
