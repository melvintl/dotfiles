# Install Checklist

Tools the configs in this repo expect on `PATH`, in two layers:

1. **Base layer**, per OS, from the system package manager: the shell, tmux,
   git, a C toolchain, anything that needs root (kanata), and the few tools
   mise's registry lacks (ctags, ag, ncdu, pspg). Short lists below.
2. **Tool layer**, from [`mise/config.toml`](mise/config.toml): editor, search
   tools, git tooling, language servers, Python CLIs. One list for every OS,
   installed per user under `~/.local/share/mise`, no sudo.

`make install-macos`, `make install-debian` and `make install-centos` run both
layers. On Arch, run the pacman block then `mise install`.

Scope: dev-environment tooling only. The Python linters/fixers ALE runs (ruff,
pylint, flake8, mypy, black, reorder-python-imports) are installed per project,
never globally. The retired i3 desktop config and its packages live under
[`legacy/`](legacy/README.md).

---

## Tool layer (all platforms)

```bash
mise install    # reads ~/.config/mise/config.toml, linked to mise/config.toml by `make setup`
mise upgrade    # later: bump everything pinned to "latest"
mise ls         # what is installed, from which config
```

`.zshrc` runs `mise activate zsh` and `shell/common.sh` puts mise's shims on
`PATH`, so new shells see the tools. Omarchy's own bash rc activates mise
already; `.bashrc` only activates it elsewhere.

Notes:
- **One owner per tool.** brew, apt and mise keep separate copies in separate
  places and do not update each other's. If the system package manager already
  installed something that is now in `mise/config.toml` (neovim, ripgrep, ...),
  remove that copy so it is obvious which binary runs. On Omarchy some
  duplicates are unavoidable because the distro ships them; the mise copy is
  earlier on `PATH` and wins.
- **Adding a tool:** `mise use -g <tool>` writes to the linked config, so the
  repo picks it up; commit it. `mise registry | grep <name>` shows what is
  available; `npm:`, `pipx:`, `cargo:` and `github:owner/repo` prefixes cover
  the rest.
- **rust-analyzer** comes from mise. If you install the Rust toolchain via
  rustup, prefer `rustup component add rust-analyzer` and drop it from
  `mise/config.toml` to avoid two copies on `PATH`.
- **Per-project pins:** a repo with its own `mise.toml` or `.tool-versions`
  overrides the global node/python version inside that directory.
- **Old glibc:** the tool layer is prebuilt binaries. Ubuntu, Debian stable and
  Rocky/Alma 9+ are fine; CentOS 7 is not.
- **ARM Linux:** `jless` ships no linux/arm64 binary. On an ARM box (or an
  arm64 container on Apple Silicon) run with `MISE_DISABLE_TOOLS=jless`, or
  `cargo install jless`.

---

## macOS (Homebrew)

`bin/new_macos.sh` runs everything below plus the tool layer, then upgrades.
Safe to re-run.

```bash
brew install \
  zsh tmux git vim universal-ctags \
  the_silver_searcher ncdu pspg \
  kanata \
  mise

# Casks (fonts + kanata driver)
brew install --cask \
  font-jetbrains-mono-nerd-font \
  font-fontawesome \
  karabiner-elements

# Activate the Karabiner virtual HID driver kanata needs (one-time):
/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate
# Then approve in System Settings → General → Login Items & Extensions → Driver Extensions.
# See .config/kanata/README.md for the full procedure.

mise install
```

---

## Debian / Ubuntu (apt)

`bin/new_debian.sh` runs this plus the mise installer and `mise install`.

```bash
sudo apt update && sudo apt install -y \
  zsh tmux git vim-gtk3 universal-ctags \
  silversearcher-ag ncdu pspg \
  curl wget openssh-server build-essential

curl -fsSL https://mise.run | sh    # installs to ~/.local/bin (on PATH via shell/common.sh)
mise install
```

Notes:
- The tool layer sidesteps the apt problems the old list had: no stale
  neovim or fzf, no `fdfind`/`batcat` renames, no missing yazi, jless or delta
  on older releases.
- Kanata isn't packaged on apt; grab the latest release binary from
  <https://github.com/jtroo/kanata/releases> if you want it on Linux.

---

## Arch Linux (pacman + AUR)

Omarchy and other Arch boxes. Omarchy ships mise, so only the base layer
comes from pacman.

```bash
sudo pacman -S --needed \
  zsh tmux git vim ctags \
  the_silver_searcher ncdu \
  curl wget openssh base-devel \
  mise

# AUR (via yay, shipped with Omarchy)
yay -S pspg
# kanata is AUR too, if you want it on Linux: yay -S kanata

mise install
```

Notes:
- `ctags` on Arch *is* universal-ctags; no separate package.
- Language servers, linters and formatters used to come from pacman here. They
  now come from `mise/config.toml` like everywhere else; skip the pacman
  packages for those so only one copy is on `PATH`.

---

## RHEL family (dnf)

Rocky/Alma/CentOS Stream 9+. `bin/new_centos.sh` runs this plus the mise
installer and `mise install`; it is a starting point, not a tested path.

```bash
sudo dnf install -y epel-release
sudo dnf install -y \
  zsh tmux git vim-enhanced \
  the_silver_searcher ncdu \
  curl wget openssh-server
# ctags and pspg: check EPEL (`dnf search ctags pspg`)

curl -fsSL https://mise.run | sh
mise install
```

---

## Manual / one-off

- **oh-my-zsh, zsh-autosuggestions, zsh-syntax-highlighting, base16-shell**:
  cloned by `bin/quick_setup.sh` when zsh is present (shallow clones into
  `~/.oh-my-zsh`, `~/.oh-my-zsh/custom/plugins/`, `~/.config/base16-shell`).
  Re-run the script to add them on an existing machine.
- **bun** (optional JS runtime): `curl -fsSL https://bun.sh/install | bash` — `shell/common.sh` puts `~/.bun/bin` on `PATH` and `.zshrc` loads its completions when present.
- **Per-project Python tooling** (inside the project's venv): `pip install debugpy pytest pytest-picked pytest-testmon` for Neovim's DAP and pytest hooks, plus whichever of ruff/pylint/flake8/mypy the project uses.

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
uv tool install aider-chat

# Pi — minimal terminal coding harness (pi.dev)
curl -fsSL https://pi.dev/install.sh | sh
```

---

## What each tool is for

Layer column: **base** = system package manager, **mise** = `mise/config.toml`,
**project** = per-project install.

| Category | Tools |
| --- | --- |
| Shell | base: `zsh`, `tmux`, `oh-my-zsh` (theme `robbyrussell`, plugins `git`, `git-extras`), `base16-shell` · mise: `direnv`, `fzf`, `zoxide`, `mise` itself (base) |
| Editors | base: `vim`, `universal-ctags` · mise: `neovim`, `tree-sitter` (parser builds for nvim-treesitter) |
| Search / files | base: `the_silver_searcher` (`ag`), `ncdu` · mise: `ripgrep`, `fd`, `bat`, `jq`, `jless`, `yazi`, `tealdeer` (`tldr`), `visidata` |
| Neovim LSPs | mise: `jedi-language-server`, `pyright`, `typescript-language-server`, `rust-analyzer`, `lua-language-server` |
| Neovim linters / formatters (via ALE) | mise: `prettier`, `eslint` · project: `ruff`, `pylint`, `flake8`, `mypy`, `black`, `reorder-python-imports` |
| Neovim debug / test | project: `debugpy`, `pytest`, `pytest-picked`, `pytest-testmon` |
| Git tooling | mise: `lazygit`, `delta`, `gh`, `difftastic` (`difft`, syntax-aware diffs via `git dft`), `hunk` (diff review of agent changes), `workmux` (git-worktree + tmux orchestration for parallel agents; tmux prefix+a dashboard) |
| AI | `claude`, `ollama`, `aider`, `pi` |
| JS runtime | mise: `node` (LTS; the npm-backed tools above need it) · optional: `bun` |
| Python | mise: `uv` (runs the `pipx:` tools) |
| Database | mise: `pgcli` · base: `pspg` |
| Lint / format | mise: `yamllint`, `shellcheck`, `stylua` |
| Keyboard | base: `kanata` (+ Karabiner driver on macOS) |
| Fonts | JetBrainsMono Nerd Font (Mono), FontAwesome |
