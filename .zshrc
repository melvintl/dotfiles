export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git git-extras)

source $ZSH/oh-my-zsh.sh

# Shared with .bashrc; :A resolves the ~/.zshrc symlink back to the repo
DOTFILES="${${(%):-%N}:A:h}"
[[ -r "$DOTFILES/shell/common.sh" ]] && source "$DOTFILES/shell/common.sh"

# Base16 Shell
BASE16_SHELL="$HOME/.config/base16-shell/"
[ -n "$PS1" ] && \
    [ -s "$BASE16_SHELL/profile_helper.sh" ] && \
        eval "$("$BASE16_SHELL/profile_helper.sh")"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

eval "$(direnv hook zsh)"

# This is to use shift arrow specifically for Putty
# to see which keys on Putty work Ctrl+v, SHIFT+Arrow Keys
# on macos->citrix->putty->zsh using Option+Command+< or >
bindkey -e
bindkey '^[.' forward-word
bindkey '^[,' backward-word

function cd() {
  builtin cd "$@"

  if [[ -z "$VIRTUAL_ENV" ]] ; then
    ## If vurtualenv folder is found then activate the vitualenv
      if [[ -d ./.venv ]] ; then
        source ./.venv/bin/activate
      fi
  else
    ## check the current folder belong to earlier VIRTUAL_ENV folder
    # if yes then do nothing
    # else deactivate
      parentdir="$(dirname "$VIRTUAL_ENV")"
      if [[ "$PWD"/ != "$parentdir"/* ]] ; then
        deactivate
      fi
  fi
}

# Auto activate virtual env in case of tmux split pane
if [[ $TMUX ]]; then
      if [[ -d ./.venv ]] ; then
        source ./.venv/bin/activate
      fi
fi

# zoxide (smart cd; `zi` for interactive picker). Bound to `cd`, so it
# overrides the venv-activating cd() above — must stay below that function.
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh --cmd cd)"

command -v workmux >/dev/null 2>&1 && eval "$(workmux completions zsh)"

[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
# Java: JDK paths differ per distro (Debian: java-11-openjdk-amd64, Arch:
# java-11-openjdk), so take the first candidate that actually exists.
for _jdk in /usr/lib/jvm/default /usr/lib/jvm/default-java /usr/lib/jvm/java-11-openjdk*(N); do
  if [ -x "$_jdk/bin/java" ]; then
    export JAVA_HOME="$_jdk"
    break
  fi
done
unset _jdk

# Machine-local (untracked): API keys, client PATHs. Keep last so it wins.
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
