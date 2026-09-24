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

# Copy a file's contents (or stdin) to the local clipboard via OSC 52
# (works over SSH without X11 forwarding/xclip; in tmux needs `set-clipboard on`)
clipcopy() {
  printf '\033]52;c;%s\a' "$( { [ $# -ge 1 ] && cat -- "$1" || cat; } | base64 | tr -d '\n')"
}
