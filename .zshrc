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

# mise: the tool layer (mise/config.toml). Before fzf/zoxide/direnv so their
# `command -v` checks see the mise-installed binaries, and before direnv so a
# project .envrc can still override tool versions.
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# fzf keybindings (C-r history, C-t files, **<Tab>) and completion. `fzf --zsh`
# (0.48+) works however fzf was installed; ~/.fzf.zsh is the older
# git-install fallback (bin/new_debian.sh, older fzf on Debian stable).
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  elif [ -f ~/.fzf.zsh ]; then
    source ~/.fzf.zsh
  fi
fi

eval "$(direnv hook zsh)"

# Emacs line editing; Alt+. / Alt+, move by word (Option sends Esc-prefixed
# keys in iTerm2/Ghostty). Check what a key sends with Ctrl+v.
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
