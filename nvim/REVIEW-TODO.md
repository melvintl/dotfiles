# Neovim config review TODO

Reviewed 2026-09-17 on branch `nvim-review-fixes`, Neovim 0.12.5. Rating: 7/10.
Config starts with no errors. All expected LSP servers, linters and formatters
are installed on this machine. Nothing below has been applied yet.

Convention: one small commit per item, message style `nvim: <what>, <why>`.
No Claude attribution in commits or PRs.

## Fixes, in priority order

- [~] **1. ALE starts duplicate language servers** (verified; servers done,
      ESLint duplication below still open)
  - `ale_disable_lsp` is `"auto"`, which checks `require('lspconfig.configs')`.
    Under `vim.lsp.enable` that table is empty (confirmed: returns `{}`), so
    ALE never skips its own servers.
  - Effect: TypeScript gets tsserver twice (ALE `tsserver` + `ts_ls`). Rust gets
    a second rust-analyzer, because ALE's default rust linters are
    `analyzer` + `cargo`.
  - Done in `lua/custom/ale.lua`: set `vim.g.ale_disable_lsp = 1`, removed
    `"tsserver"` from the typescript linters. Checked: one client each for
    Lua, TS, Rust; Python CLI linters (ruff/pylint/flake8/mypy) unaffected.
  - STILL OPEN (User deferred on 2026-09-17): ESLint runs twice, ALE CLI
    `eslint` and the `eslint` language server in `lua/custom/lsp.lua`.
    Measured with eslint 10.10.0 and a flat config:
    - Project with local `node_modules/eslint`: every problem shows twice
      (4 in namespace `ale` + 4 in `nvim.lsp.eslint`).
    - Project with only the system eslint: no duplicates, because the server
      prints `[lspconfig] Unable to find ESLint library` on open and lints
      nothing. ALE still works there.
    - Only the server gives code actions (`Disable <rule> for this line`,
      `Show documentation`, `Fix this problem`). Fix-on-save is ALE's fixers
      and survives either choice.
    - Option A (suggested): delete the two `eslint` lines in `lsp.lua`. Loses
      the code actions, drops the need for AUR `vscode-langservers-extracted`.
    - Option B: remove `"eslint"` from both `ale_linters` lists, keep the
      fixers. Keeps code actions, but no linting without a local eslint.

- [x] **2. `<C-k>` shadowed in LSP buffers** (verified)
  - `lua/custom/lsp.lua` maps buffer-local `<C-k>` to signature help. This
    overrides vim-tmux-navigator's global `<C-k>` (`:TmuxNavigateUp`).
  - Fix: delete the mapping. Neovim 0.11+ ships `<C-s>` in insert mode.

- [x] **3. `gr` waits out `timeoutlen` (300 ms)** (verified defaults exist)
  - Built-in `grr`, `grn`, `gra`, `gri` share the prefix.
  - Done: dropped the `gr` mapping from `lua/custom/lsp.lua`. References are
    now on the built-in `grr`.

- [-] **4. Markdown preview binds to all interfaces over SSH** (User skipped
      on 2026-09-17; confirmed the flag binds 0.0.0.0, `server.js:102`)
  - `lua/plugins/markdown.lua` sets `mkdp_open_to_the_world = 1` when headless.
    Plugin docs: "the preview server is available to others in your network".
  - SSH port forwarding only needs localhost. Fix: remove that line, keep
    `mkdp_browser = 'none'`, the fixed port and `mkdp_echo_preview_url`.
  - Check whether `mkdp_open_ip` is still wanted once the flag is gone.

- [x] **5. cmp capabilities never reach the servers** (low priority, measured)
  - Done: `vim.lsp.config('*', ...)` at the top of `lua/custom/lsp.lua`. Checked
    on lua_ls: commitCharactersSupport/preselectSupport false -> true,
    insertTextModeSupport set, resolve gains insertTextFormat + insertTextMode.
  - Measured on 0.12.5: snippet support is already on in Neovim's defaults, so
    this does NOT unlock snippets. The real gain is small: commit characters,
    preselect, insertTextMode, and lazy resolve of two more fields.
  - Fix in `lua/custom/lsp.lua`, before the enables:
    ```lua
    vim.lsp.config('*', {
      capabilities = require('cmp_nvim_lsp').default_capabilities(),
    })
    ```

- [x] **6. Enable `lua_ls`**
  - Done: enabled in `lua/custom/lsp.lua`, README section updated. Binary came
    from the pacman line in `INSTALL.md`. A missing binary is harmless: 0.12
    skips the server with one `lsp.log` line, no notification. Needed item 1's
    `ale_disable_lsp`, otherwise ALE's own copy reports `vim` as undefined.

- [x] **7. Guard the autoread poll in the command-line window** (verified)
  - `lua/custom/autoread.lua` runs `checktime` on CursorHold. Reproduced in a
    detached tmux session (headless cannot enter the cmdwin): open `q:`, wait,
    and CursorHold raises `E11: Invalid in command-line window`.
  - Done: also require `vim.fn.getcmdwintype() == ''`. Re-ran the same test:
    no error, `:messages` empty.

## Dead weight

- [x] `nvim-treesitter-textobjects` has no mappings (`af` confirmed unmapped).
      Done: removed. Came in with the kickstart template on 2023-07-08
      (`e5e58a6`) and was never configured.
- [x] `trouble.nvim` has no keymaps. Done: removed. README-template spec from
      2023-07-08 (`e5e58a6`), never configured; loclist + Telescope cover it.
- [ ] `lua/custom/startify.lua`: first `g:startify_list_order` assignment is
      overwritten by the second. `list_order` is the legacy name; the plugin
      converts it to `g:startify_lists`. Migrate to `startify_lists`.
- [ ] `lua/plugins/copilot.lua_temp_remove`: delete, git history keeps it.
- [x] Stale Pyright comments: `init.lua` lines 1-2 and the F6 comment in
      `lua/custom/autocmd.lua`. The config uses jedi.
- [x] Empty `config = function() end` in `lua/plugins/linter_fixer.lua` (ALE)
      and `lua/plugins/testing.lua` (vim-test). Done: removed. No behaviour
      change, lazy.nvim runs nothing without `config`/`opts`.
- [x] Large commented-out flash.nvim block in `lua/plugins/nav_search.lua`.

## README drift

- [x] Says Neovim 0.11+. nvim-treesitter `main` now requires 0.12+.
- [ ] Missing requirement: `tree-sitter-cli` 0.26.1+ from the system package
      manager, not npm. Also `curl` and `tar`.
- [x] Typo: "JetBrans Mono".

## Small hygiene

- [x] `lua/custom/set.lua`: `command Q` / `command W` lack `!`, so re-sourcing
      errors. Use `command!` or `nvim_create_user_command`.
- [ ] `lua/custom/autocmd.lua`: `augroup run_buffer` has no `autocmd!`, so
      autocmds duplicate on re-source. The `BufReadPost` autocmd has no group.
- [x] `lua/custom/autocmd.lua`: F10/F12 pytest maps are global and use
      recursive `map`/`imap`. Done differently (User's call on 2026-09-17):
      commented out, they were no longer used. If revived, make them
      `noremap` and Python-buffer-local.

## Leave alone (deliberate choices)

NERDTree, vim-startify (reverted to on purpose in PR #24), ALE alongside LSP,
`:w!` on `<leader>w`.

## Startup time (measured 2026-09-17)

Measured inside a detached tmux session, because `--startuptime` writes an
empty log in headless mode. Neovim 0.12.5, warm cache, 5 runs.

- Opening `init.lua`: 111-124 ms, median 115 ms.
- No file argument (startify screen): 74 ms.
- `nvim --clean`: 6 ms.
- Where the time goes when opening a Lua file: `init.lua` and every plugin,
  60 ms (nothing is lazy-loaded); opening the buffer, 19 ms (treesitter, LSP
  attach, gitsigns); the Lua ftplugin, 7 ms; first screen draw, 6 ms.
- Biggest single plugin: NERDTree at 2.7 ms. No plugin stands out.
- Verdict: no action. Lazy-loading everything would save at most ~40 ms.

## Verify after the fixes

```bash
nvim --headless "+qa"                 # no startup errors
nvim some.ts  ->  :LspInfo / :ALEInfo # one tsserver, one eslint
nvim some.rs  ->  :LspInfo / :ALEInfo # one rust-analyzer
# in an LSP buffer inside tmux: <C-k> moves to the pane above
# grr opens references
```
