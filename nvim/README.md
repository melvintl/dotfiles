# Setup

## Point to NeoVim setup
- Needs Neovim 0.12+ (the nvim-treesitter `main` branch requires it;
  `vim.lsp.config`/`vim.lsp.enable` need 0.11+). Distro packages are often
  older; use the [official release](https://github.com/neovim/neovim/releases)
  if so.
- `mkdir -p ~/.config`
- `ln -s ~/myprojects/dotfiles/nvim ~/.config/nvim`


## Other binaries that are required

Install these with your system's package manager:

- `git`, `make` and a C compiler: lazy.nvim clones plugins and some have a
  build step.
- `ripgrep`: used by Telescope live grep.
- `fzf` and `direnv`: optional, used outside Neovim.
- [`hunk`](https://github.com/modem-dev/hunk): optional, the diff reviewer behind
  `<leader>gd`. `bin/quick_setup.sh` installs it, or see `INSTALL.md`.

## Language servers

### To setup jedi server:

```bash
python3 -m pip install --user pipx
# python3 -m pip install --user pipx --break-system-packages
python3 -m pipx ensurepath
pipx install jedi-language-server
```

### To setup TypeScript language server:

```bash
# Install TypeScript language server
npm install -g typescript typescript-language-server

# Install ESLint for linting
npm install -g eslint

# Install Prettier for formatting
npm install -g prettier
```

See `docs/typescript-setup.md` for more detailed TypeScript setup instructions.

### To setup the Lua language server (optional):

Used by `lazydev.nvim` to give completion/hover/diagnostics for the Neovim Lua
API (`vim.*`) while editing this config. `lua_ls` is already enabled in
`lua/custom/lsp.lua`; it only needs the binary. Without it Neovim skips the
server silently (one line in `lsp.log`) and `lazydev` stays inert.

```bash
# Arch
sudo pacman -S lua-language-server

# macOS
brew install lua-language-server

# Debian/Ubuntu (or download a release from the LuaLS GitHub)
# sudo apt install lua-language-server
```

## Fonts

Install patched nerd fonts (eg JetBrains Mono) on the terminal 
Change the below in the `lua/plugins/look_n_feel.lua` file if you dont want to show icons
```lua
        icons_enabled = false,
```
