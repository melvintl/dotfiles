# dotfiles

Terminal-first dotfiles for a keyboard-driven workflow: shell, tmux, Neovim, git, agent tooling, and small CLI utilities.

See [what each tool is for](INSTALL.md#what-each-tool-is-for) for a quick map of the terminal stack.

## Layout

```text
.
├── .bashrc / .zshrc  shell entrypoints: bash for Omarchy, zsh elsewhere
├── .tmux.conf        plain tmux config, no framework
├── .gitconfig        git aliases, delta pager, local identity include
├── shell/            shared aliases, PATH setup, and shell helpers
├── nvim/             Neovim setup
├── pi/               pi coding-agent config and specs
├── .config/          app configs: kanata, omarchy theme, lazygit, yazi, etc.
├── bin/              helper scripts and bootstrap scripts
└── legacy/           retired Vim/i3 configs kept for reference
```

More detail in the sub-READMEs: [nvim](nvim/README.md), [kanata](.config/kanata/README.md), [Omarchy One Dark theme](.config/omarchy/themes/one-dark/README.md), [legacy](legacy/README.md).

## Bootstrap

Recommended order on a fresh machine:

```bash
git clone https://github.com/melvintl/dotfiles.git ~/myprojects/dotfiles
cd ~/myprojects/dotfiles

# 1. Install the CLI/tooling first. Pick one platform target after reading it.
make install-macos
# make install-debian
# make install-centos

# 2. Then link configs and bootstrap shell dependencies.
make doctor          # inspect current links/tools
make setup-dry-run   # preview what setup would change
make setup           # link configs and bootstrap shell deps
```

Tooling is documented in [INSTALL.md](INSTALL.md), including [what each tool is for](INSTALL.md#what-each-tool-is-for). Platform install targets are `make install-macos`, `make install-debian`, and `make install-centos`; read the underlying script before running one.

`make setup` does the dotfile wiring:

- backs up existing targets into `~/.dotfiles-backup/...`
- links configs into place
- writes `~/.dotfiles.env` with the actual clone path (`DOTFILES_DIR`)
- clones shell dependencies that `.zshrc` sources: oh-my-zsh, its two plugins, and base16-shell

It does **not** install CLI tools. For partial setup, use `make links` for config links only or `make bootstrap` for shell dependency clones only.

If you only want a subset, manually symlink the pieces you care about instead. Common examples:

```bash
ln -s ~/myprojects/dotfiles/.zshrc     ~/.zshrc
ln -s ~/myprojects/dotfiles/.tmux.conf ~/.tmux.conf
ln -s ~/myprojects/dotfiles/nvim       ~/.config/nvim
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

## Development checks

Run the non-destructive repo checks before pushing changes:

```bash
make check
```

The same check runs in GitHub Actions, where it also runs ShellCheck, starts Neovim headless against `nvim/`, and runs `stylua --check`. Locally those need `shellcheck`, `nvim`, `stylua` and `RUN_NVIM_SMOKE=1`; the check only warns when an optional tool is missing.

Format the Neovim config with `make fmt` (settings in `.stylua.toml`).

When changing Neovim config, opt into a heavier headless startup smoke test:

```bash
make smoke
```
