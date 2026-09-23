# dotfiles

My personal config across shell, editor, multiplexer, and a few small tools.

## Layout

| Path | What's there |
| --- | --- |
| `.bashrc` | Bash config (Linux/Omarchy) |
| `.zshrc` | zsh config (macOS: oh-my-zsh, base16, zoxide, direnv, fzf) |
| `shell/common.sh` | Aliases and exports shared by both shells |
| `.tmux.conf`, `.tmux.conf.local` | tmux config (based on oh-my-tmux) |
| `.vimrc` | Legacy Vim config — kept around but Neovim is the daily driver |
| `.gitconfig` | Git config (delta as pager, aliases) — no identity, see below |
| `.gitconfig.local.example` | Template for the untracked per-machine git identity |
| `nvim/` | Neovim setup — see [`nvim/README.md`](nvim/README.md) |
| `pi/agent/` | `pi` coding-agent config (skills, prompts, models, themes) |
| `.config/kanata/` | Kanata keyboard remap — see [`.config/kanata/README.md`](.config/kanata/README.md) |
| `.config/i3/`, `.config/i3status/` | i3 window manager + status bar (Linux) |
| `.config/omarchy/themes/one-dark/` | Omarchy (Hyprland) theme matching the nvim/tmux One Dark palette — see [`its README`](.config/omarchy/themes/one-dark/README.md) |
| `.config/<>` | Misc tool configs |
| `bin/` | Small scripts |
| `INSTALL.md` | Every CLI tool the configs expect on `PATH` |

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
