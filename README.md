# dotfiles

My personal config across shell, editor, multiplexer, and a few small tools.

## Layout

```text
.bashrc / .zshrc     bash (Linux/Omarchy) and zsh (macOS); shared aliases/PATH in shell/common.sh
.tmux.conf           tmux, plain config (no framework)
.gitconfig           delta as pager, aliases — identity stays in ~/.gitconfig.local (see below)
nvim/                Neovim setup
pi/agent/            pi coding-agent config (skills, prompts, models, themes)
.config/             kanata keyboard remap · omarchy One Dark theme · workmux, lazygit, hunk, yazi, pgcli, yamllint
bin/                 small scripts
legacy/              retired configs kept for reference: classic .vimrc, i3 + i3status
```

More detail in the sub-READMEs: [`nvim/`](nvim/README.md), [`kanata`](.config/kanata/README.md), [`omarchy One Dark theme`](.config/omarchy/themes/one-dark/README.md), [`legacy/`](legacy/README.md).

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

`bin/quick_setup.sh` links the configs into place and clones what `.zshrc` sources (oh-my-zsh, its two plugins, base16-shell). `bin/new_macos.sh`, `bin/new_debian.sh`, and `bin/new_centos.sh` install the tooling per platform — read them before running. The macOS one is idempotent, so re-run it to upgrade the listed tools.

## Health check

Run the non-destructive repo checks before pushing changes:

```bash
bash bin/check.sh
```

The same check runs in GitHub Actions, where it also starts Neovim headless against `nvim/` and runs `stylua --check`. Locally those need `nvim`, `stylua` and `RUN_NVIM_SMOKE=1`; the check only warns when an optional tool is missing.

Format the Neovim config with `stylua nvim` (settings in `.stylua.toml`).

When changing Neovim config, opt into a heavier headless startup smoke test:

```bash
RUN_NVIM_SMOKE=1 bash bin/check.sh
```

## Per-machine layer

Identity and secrets never go in this repo. Each config sources an untracked `~/*.local` file last:

- `~/.gitconfig.local` — name/email, signing key, `includeIf` for work dirs (template: `.gitconfig.local.example`)
- `~/.bashrc.local`, `~/.zshrc.local` — API keys, client PATHs

`quick_setup.sh` seeds them if missing; `.gitignore` keeps them out of every repo.


## Windows notes

- Use Windows Terminal with the `JetBrainsMono Nerd Font Mono` patched font.
- Theme: `One Half Dark`.
- Recent Windows Terminal + Ubuntu 24+ handles clipboard with no extra setup.
