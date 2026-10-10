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
├── .config/          app configs: kanata, lazygit, yazi, etc.
├── bin/              helper scripts and bootstrap scripts
└── legacy/           retired Vim/i3 configs kept for reference
```

More detail in the sub-READMEs: [nvim](nvim/README.md), [kanata](.config/kanata/README.md), [voxtype](.config/voxtype/README.md), [Omarchy One Dark theme](.config/omarchy/themes/one-dark/README.md), [legacy](legacy/README.md).

## Setup

For shell and app configs, use `make setup` on both new and existing machines. [Pi config](#pi-config) uses the separate `make setup-pi` target. `make setup` is idempotent — existing links and clones are detected and skipped, only what's missing gets applied — so the fresh-machine command and the routine update command are the same. Preview any run with `make setup-dry-run`; inspect current state with `make doctor`.

### New machine

```bash
git clone https://github.com/melvintl/dotfiles.git ~/myprojects/dotfiles
cd ~/myprojects/dotfiles

# 1. Install the CLI/tooling first. Pick one platform target after reading it.
make install-macos
# make install-debian
# make install-centos

# 2. Optional: check what's already there — useful if the machine had a
#    previous setup, or the distro ships its own default configs.
make doctor          # inspect current links/tools
make setup-dry-run   # preview what setup would change

# 3. Then wire up the dotfiles.
make setup           # link configs and bootstrap shell deps
```

Tooling is documented in [INSTALL.md](INSTALL.md), including [what each tool is for](INSTALL.md#what-each-tool-is-for); read the underlying install script before running one.

### Existing machine: pulling changes merged elsewhere

After a PR lands on master (e.g. from another computer):

```bash
git pull
make setup
```

Configs are symlinked into the repo, so edits to already-linked files take effect on pull by themselves — just reload the app (`prefix+r` for tmux, restart nvim). `make setup` is for what pull can't do: a commit that added a *new* config link or dependency clone does nothing until setup applies it. Running it after every pull is safe; skipping it when nothing new was added is also fine.

One thing neither pull nor setup does: update the cloned dependencies themselves (`clone_once` is clone-if-missing). To update oh-my-zsh or a tmux plugin, `git pull` inside its clone.

### What `make setup` does

- backs up existing targets into `~/.dotfiles-backup/...`
- links configs into place
- links [agent skills](#agent-skills) if that repo is cloned next to this one
- writes `~/.dotfiles.env` with the actual clone path (`DOTFILES_DIR`)
- clones shell dependencies that `.zshrc` sources: oh-my-zsh, its two plugins, and base16-shell
- clones the tmux plugins `.tmux.conf` loads: extrakto (prefix+e) and tmux-floax (prefix+f) into `~/.tmux/plugins/`

It does **not** install CLI tools — that's the `make install-*` targets. For partial setup, `make setup-links` runs only the config links and `make setup-bootstrap` only the shell/tmux dependency clones; together they equal `make setup`.

If you only want a subset, manually symlink the pieces you care about instead. Common examples:

```bash
ln -s ~/myprojects/dotfiles/.zshrc     ~/.zshrc
ln -s ~/myprojects/dotfiles/.tmux.conf ~/.tmux.conf
ln -s ~/myprojects/dotfiles/nvim       ~/.config/nvim
```

### Pi config

`make setup` does not apply the Pi coding-agent config. If you use Pi, run its separate setup target from the repo root:

```bash
make setup-pi-dry-run   # preview changes
make setup-pi           # apply Pi config
```

These targets wrap `bin/pi_setup.sh`, which links the shared config from `pi/agent/` into `~/.pi/agent/` (everything except skills, see [Agent skills](#agent-skills)), backing up conflicting files in `~/.pi/agent.backup-...`. It copies `pi-plan-mode.json` rather than linking it. Re-run `make setup-pi` after pulling changes that add Pi config items or update that copied file. It does not install Pi or extension dependencies; see [INSTALL.md](INSTALL.md#ai-tools) for Pi installation and [pi/SANDBOX.md](pi/SANDBOX.md#setup-on-a-new-machine) for sandbox dependencies.

### Agent skills

Skills for Claude Code and Pi are not kept in this repo. They live in a separate `agent-skills` repo, which symlinks each skill into the agents it is for.

`make setup` looks for that repo at `$AGENT_SKILLS_DIR`, defaulting to an `agent-skills` directory next to this one. If it is there, setup runs its linker and `make doctor` includes its report. If it is not, setup prints a one-line note and carries on; it never clones it.

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

When changing Neovim config, opt into the heavier startup test — everything `make check` does, plus booting Neovim headless against the repo config with plugins restored from `lazy-lock.json` (slow, needs network):

```bash
make check-smoke
```
