return {
  { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' } },

  { 'preservim/nerdtree' },
  -- Kept NERDTree on purpose over the modern Lua file trees:
  --  * a real project tree to see and discuss ; eg in Python
  --    the folder layout is the module layout, so seeing the tree matters
  --  * file operations from the `m` menu: add, move/rename, copy, delete
  --  * muscle memory: `I` toggles hidden files, `s`/`i` open in vertical/horizontal
  --    splits, `t` in a new tab
  -- Plain text and no icons, it just works. oil.nvim was considered and skipped,
  -- it edits one directory at a time and has no tree view.
}
