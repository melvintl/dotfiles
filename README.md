# dotfiles

My personal config across shell, editor, multiplexer, and a few small tools.

## Layout

```text
.bashrc / .zshrc     bash (Linux/Omarchy) and zsh (macOS); shared aliases/PATH in shell/common.sh
.tmux.conf[.local]   tmux, based on oh-my-tmux
.gitconfig           delta as pager, aliases — identity stays in ~/.gitconfig.local (see below)
.vimrc               legacy; Neovim is the daily driver
nvim/                Neovim setup
pi/agent/            pi coding-agent config (skills, prompts, models, themes)
.config/             kanata keyboard remap · i3 + i3status (Linux) · omarchy One Dark theme · misc tools
bin/                 small scripts
```

More detail in the sub-READMEs: [`nvim/`](nvim/README.md), [`kanata`](.config/kanata/README.md), [`omarchy One Dark theme`](.config/omarchy/themes/one-dark/README.md).

## Install

See [INSTALL.md](INSTALL.md) for the full per-platform tooling list (macOS Homebrew, Debian apt, Arch pacman/AUR, npm globals, pipx, Rust, AI tools).

Symlink the bits you want into place, e.g.:

```bash
ln -s ~/myprojects/dotfiles/.zshrc       ~/.zshrc
ln -s ~/myprojects/dotfiles/.tmux.conf   ~/.tmux.conf
ln -s ~/myprojects/dotfiles/.gitconfig   ~/.gitconfig
ln -s ~/myprojects/dotfiles/nvim         ~/.config/nvim
ln -s ~/myprojects/dotfiles/.config/kanata ~/.config/kanata
ln -s ~/myprojects/dotfiles/.config/omarchy/themes/one-dark ~/.config/omarchy/themes/one-dark
```

`bin/quick_setup.sh`, `bin/new_debian.sh`, and `bin/new_centos.sh` are starting points for bootstrapping a fresh box — read them before running.

## Per-machine layer

Identity and secrets never go in this repo. Each config sources an untracked `~/*.local` file last:

- `~/.gitconfig.local` — name/email, signing key, `includeIf` for work dirs (template: `.gitconfig.local.example`)
- `~/.bashrc.local`, `~/.zshrc.local` — API keys, client PATHs

`quick_setup.sh` seeds them if missing; `.gitignore` keeps them out of every repo.


## Linux desktop (i3)

The i3 window manager config in `.config/i3/` expects these system packages on Debian/Ubuntu:

```bash
sudo apt-get install i3 i3status suckless-tools i3lock rofi \
                     arandr xbacklight alsa-utils pulseaudio \
                     gnome-sound-applet indicator-sound volumeicon-alsa
```

## Windows notes

- Use Windows Terminal with the `JetBrainsMono Nerd Font Mono` patched font.
- Theme: `One Half Dark`.
- Recent Windows Terminal + Ubuntu 24+ handles clipboard with no extra setup.
