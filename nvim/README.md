# Setup

## Point to NeoVim setup
- Needs Neovim 0.11+ (`vim.lsp.config`/`vim.lsp.enable` and the nvim-treesitter
  `main` branch require it). Distro packages are often older; use the
  [official release](https://github.com/neovim/neovim/releases) if so.
- `mkdir -p ~/.config`
- `ln -s ~/myprojects/dotfiles/nvim ~/.config/nvim`


## Other binaries that are required

```bash
# LazyVim will install via build so has other binary dependency 
sudo apt install make build-essential

# Search utils:
sudo apt install fzf
sudo apt install ripgrep silversearcher-ag

# Others:
sudo apt install direnv
```

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
API (`vim.*`) while editing this config. `lazydev` is installed but stays inert
until `lua_ls` is running.

```bash
# macOS
brew install lua-language-server

# Debian/Ubuntu (or download a release from the LuaLS GitHub)
# sudo apt install lua-language-server
```

Then enable it in `lua/custom/lsp.lua` alongside the other servers:

```lua
vim.lsp.config('lua_ls', {})
vim.lsp.enable('lua_ls')
```

## Fonts

Install patched nerd fonts (eg JetBrans Mono) on the terminal 
Change the below in the `lua/plugins/look_n_feel.lua` file if you dont want to show icons
```lua
        icons_enabled = false,
```
