export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git git-extras zsh-autosuggestions zsh-syntax-highlighting)

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

# Auto-activate a project .venv on directory change and deactivate on leaving.
# A chpwd hook rather than a cd() wrapper: zoxide (below) defines its own cd()
# and would silently replace a wrapper, but chpwd fires for cd, z, zi and pushd.
_venv_auto() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    [[ "$PWD"/ == "${VIRTUAL_ENV:h}"/* ]] && return
    # deactivate is undefined when VIRTUAL_ENV was inherited (new tmux pane)
    if typeset -f deactivate >/dev/null; then deactivate; else unset VIRTUAL_ENV; fi
  fi
  [[ -d ./.venv ]] && source ./.venv/bin/activate
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _venv_auto
_venv_auto   # new shells and tmux splits start inside a project directory

# zoxide (smart cd; `cdi` for interactive picker). Bound to `cd`; the venv
# logic above is a chpwd hook so it keeps working through zoxide's cd().
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
