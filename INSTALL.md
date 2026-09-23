# Install Checklist

Tools the configs in this repo expect on `PATH`. Copy the block for your platform — each section is one command (or one per package manager).

Scope: dev-environment tooling only. The i3 window manager and its helpers (i3, i3status, i3lock, rofi, dmenu, arandr, feh, etc.) are Linux-desktop concerns and live in `README.md`, not here.

---

## macOS (Homebrew)

```bash
# Formulae
brew install \
  zsh tmux neovim vim universal-ctags \
  tree-sitter-cli \
  fzf ripgrep the_silver_searcher fd bat jq jless ncdu yazi tldr \
  direnv pipx zoxide \
  pgcli pspg \
  yamllint \
  kanata \
  lazygit git-delta gh hunk difftastic \
  visidata

# NB: `tree-sitter-cli` is the binary nvim-treesitter (main branch) shells out
# to when building parsers. The similarly named `tree-sitter` formula is the C
# library only — installing it does NOT put a `tree-sitter` command on PATH,
# and without the CLI every Neovim startup re-downloads all parsers and fails
# to compile them ("ENOENT: 'tree-sitter'").

# fzf keybindings: .zshrc sources ~/.fzf.zsh, which brew doesn't create.
# Generate it once:
"$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc

# workmux — git-worktree + tmux orchestration for parallel agents
# (tapped formula; the `.tmux.conf.local` prefix+a dashboard popup expects it
# on PATH)
brew install raine/workmux/workmux

# Casks (fonts + kanata driver)
brew install --cask \
  font-jetbrains-mono-nerd-font \
  font-fontawesome \
  karabiner-elements

# Activate the Karabiner virtual HID driver kanata needs (one-time):
/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate
# Then approve in System Settings → General → Login Items & Extensions → Driver Extensions.
# See .config/kanata/README.md for the full procedure.
```

---

## Debian / Ubuntu (apt)

```bash
sudo apt update && sudo apt install -y \
  zsh tmux neovim vim-gtk3 exuberant-ctags \
  fzf ripgrep silversearcher-ag fd-find bat jq ncdu tldr \
  direnv pipx zoxide \
  pgcli pspg \
  yamllint \
  lazygit git-delta gh \
  visidata \
  git curl wget openssh-server build-essential
```

Notes:
- apt `neovim` is usually older than the 0.12+ this nvim config needs (see `nvim/README.md`); use the [official release](https://github.com/neovim/neovim/releases) if so.
- apt `fzf` doesn't create the `~/.fzf.zsh` that `.zshrc` sources — clone upstream and run its installer instead: `git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --key-bindings --completion --no-update-rc`.
- `fd-find` installs the binary as `fdfind`; alias it: `ln -s $(which fdfind) ~/.local/bin/fd`.
- `bat` installs as `batcat` on older Ubuntu; same trick: `ln -s $(which batcat) ~/.local/bin/bat`.
- `lazygit`, `git-delta`, `gh` require recent Ubuntu (24.04+) or their respective PPAs; fall back to the GitHub releases on older distros.
- `zoxide` shell integration is already wired up in `.zshrc` and only kicks in once the binary is on `PATH`.
- `jless` isn't packaged on apt — install via `cargo install jless` or grab a binary from <https://github.com/PaulJuliusMartinez/jless/releases>.
- `yazi` lands in apt only on Ubuntu 24.04+; on older releases use `cargo install --locked yazi-fm yazi-cli` or the GitHub releases.
- `hunk` isn't packaged on apt: `curl -fsSL https://hunk.dev/install.sh | sh` (standalone binary in `~/.hunk`) or `mise use -g hunk`.
- `difftastic` (`difft`, behind the `git dft` alias) isn't packaged on apt — install via `cargo install --locked difftastic`.
- Kanata isn't packaged on apt; grab the latest release binary from <https://github.com/jtroo/kanata/releases> if you want it on Linux.
- `tree-sitter` CLI (needed by nvim-treesitter to build parsers) isn't packaged on apt — install via `npm install -g tree-sitter-cli` or `cargo install tree-sitter-cli`.
- `workmux` isn't packaged on apt — install via `curl -fsSL https://raw.githubusercontent.com/raine/workmux/main/scripts/install.sh | bash`, `cargo install workmux`, or Homebrew on Linux (`brew install raine/workmux/workmux`).

---

## Arch Linux (pacman + AUR)

Omarchy and other Arch boxes. Most Neovim language servers and linters are in the
official repos here, so prefer pacman over `npm -g` / `pipx` on this platform.

```bash
# Base dev tooling (official repos)
sudo pacman -S --needed \
  zsh tmux neovim vim ctags \
  tree-sitter-cli \
  fzf ripgrep the_silver_searcher fd bat jq jless ncdu yazi tldr \
  direnv python-pipx zoxide \
  pgcli \
  yamllint \
  lazygit git-delta github-cli difftastic \
  visidata \
  git curl wget openssh base-devel

# Language servers + linters/formatters for Neovim (official repos)
sudo pacman -S --needed \
  jedi-language-server typescript-language-server pyright rust-analyzer lua-language-server \
  ruff python-pylint python-flake8 mypy python-black \
  prettier eslint \
  python-debugpy

# AUR (via yay, shipped with Omarchy)
yay -S pspg
# kanata is AUR too, if you want it on Linux: yay -S kanata
```

Notes:
- `ctags` on Arch *is* universal-ctags — no separate package, no `exuberant-ctags`.
- `hunk` ships with Omarchy through mise. On other Arch boxes: `mise use -g hunk` or `curl -fsSL https://hunk.dev/install.sh | sh`.
- `reorder-python-imports` (an ALE Python fixer) isn't packaged: `pipx install reorder-python-imports`.
- `rust-analyzer` from pacman is standalone and needs no rustup. If you install the
  Rust toolchain via `rustup` instead, use `rustup component add rust-analyzer` and
  skip the pacman package to avoid two copies on `PATH`.
- `workmux` isn't in the official repos — install via `mise use -g cargo:raine/workmux` (fits Omarchy) or `cargo install workmux`.
- Skip the npm-globals section below on Arch unless a tool is missing from the repos —
  and note that if `node` comes from a version manager (mise, nvm, asdf), `npm -g`
  binaries live inside that runtime's directory and disappear when you change versions.

---

## npm globals (language servers + JS tooling for Neovim)

Assumes `node`/`npm` on `PATH` — none of the platform lists above install it.
Use mise (`mise use -g node@lts`, ships with Omarchy) or nvm.

```bash
npm install -g \
  pyright \
  typescript typescript-language-server \
  prettier eslint
```

---

## pipx / pip (Python tooling for Neovim + CLI)

```bash
# pipx for tools you invoke as commands
pipx install ruff
pipx install pylint
pipx install flake8
pipx install mypy
pipx install black
pipx install reorder-python-imports
pipx install jedi-language-server

# pip (inside a venv / project) for libraries Neovim's DAP and pytest hooks load
pip install debugpy pytest pytest-picked pytest-testmon
```

---

## Rust (rust-analyzer LSP)

```bash
# If rustup is already installed:
rustup component add rust-analyzer

# Otherwise, install rustup first:
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

---

## Manual / one-off

- **oh-my-zsh**: `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"`
- **base16-shell**: `git clone https://github.com/chriskempson/base16-shell.git ~/.config/base16-shell`
- **bun** (optional JS runtime): `curl -fsSL https://bun.sh/install | bash` — `shell/common.sh` puts `~/.bun/bin` on `PATH` and `.zshrc` loads its completions when present.

---

## AI tools

CLIs for AI coding workflows. Install whichever you use.

```bash
# Claude Code — Anthropic's CLI coding agent
curl -fsSL https://claude.ai/install.sh | bash        # macOS / Linux / WSL (auto-updates)

# ollama — local LLM runtime
brew install ollama                              # macOS
# curl -fsSL https://ollama.com/install.sh | sh  # Linux

# aider — CLI pair-programmer
pipx install aider-chat

# Pi — minimal terminal coding harness (pi.dev)
curl -fsSL https://pi.dev/install.sh | sh
```

---

## What each tool is for

| Category | Tools |
| --- | --- |
| Shell | `zsh`, `oh-my-zsh` (theme `robbyrussell`, plugins `git`, `git-extras`), `base16-shell`, `direnv`, `tmux`, `fzf`, `zoxide`, `pipx` |
| Editors | `vim`, `neovim`, `universal-ctags`, `tree-sitter-cli` (parser builds for nvim-treesitter) |
| Search / files | `ripgrep`, `the_silver_searcher` (`ag`), `fd`, `bat`, `jq`, `jless`, `ncdu`, `yazi`, `tldr`, `visidata` |
| Neovim LSPs | `jedi-language-server`, `pyright`, `typescript-language-server`, `rust-analyzer` |
| Neovim linters / formatters (via ALE) | `ruff`, `pylint`, `flake8`, `mypy`, `black`, `reorder-python-imports`, `prettier`, `eslint` |
| Neovim debug / test | `debugpy`, `pytest`, `pytest-picked`, `pytest-testmon` |
| Git tooling | `lazygit`, `git-delta`, `gh`, `difftastic` (`difft`, syntax-aware diffs via `git dft`), `hunk` (diff review of agent changes), `workmux` (git-worktree + tmux orchestration for parallel agents; tmux prefix+a dashboard) |
| AI | `claude`, `ollama`, `aider`, `pi` |
| JS runtime | `node` (via mise/nvm; npm globals need it), `bun` (optional) |
| Database | `pgcli`, `pspg` |
| Lint | `yamllint` |
| Keyboard | `kanata` (+ Karabiner driver on macOS) |
| Fonts | JetBrainsMono Nerd Font (Mono), FontAwesome |
