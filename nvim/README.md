# Setup

## Point to NeoVim setup
- Needs Neovim 0.12+ (the nvim-treesitter `main` branch requires it;
  `vim.lsp.config`/`vim.lsp.enable` need 0.11+). Distro packages are often
  older; use the [official release](https://github.com/neovim/neovim/releases)
  if so.
- `mkdir -p ~/.config`
- `ln -s ~/myprojects/dotfiles/nvim ~/.config/nvim`


## Other binaries that are required

Neovim itself, the `tree-sitter` CLI, `ripgrep` and every language server
below come from the repo's `mise/config.toml` (`mise install`, see
`../INSTALL.md`). From the system package manager you still need `git`, `make`
and a C compiler: lazy.nvim clones plugins and some have a build step.

- `tree-sitter` CLI: the nvim-treesitter `main` branch shells out to it to
  build parsers. Without it, every startup re-downloads all parsers and fails
  compiling with `ENOENT: no such file or directory (cmd): 'tree-sitter'`.
  If you install it by hand instead of via mise: on macOS the brew formula is
  `tree-sitter-cli`; the plain `tree-sitter` formula is only the C library.
- `ripgrep`: used by Telescope live grep.

## Language servers

All installed by `mise install` from `mise/config.toml`: `jedi-language-server`
(Python), `typescript-language-server` + `typescript`, `eslint` and `prettier`
(TypeScript/JavaScript; see `docs/typescript-setup.md`), `rust-analyzer`, and
`lua-language-server`.

`lua-language-server` drives `lazydev.nvim`, which gives completion, hover and
diagnostics for the Neovim Lua API (`vim.*`) while editing this config.
`lua_ls` is enabled in `lua/custom/lsp.lua`; without the binary Neovim skips
the server silently (one line in `lsp.log`) and `lazydev` stays inert.

## Fonts

Install patched nerd fonts (eg JetBrains Mono) on the terminal 
Change the below in the `lua/plugins/look_n_feel.lua` file if you dont want to show icons
```lua
        icons_enabled = false,
```
