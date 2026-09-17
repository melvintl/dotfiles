return {
 
  {
    -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
  },

  -- Additional lua configuration, makes nvim config easier.
  -- Inert until a Lua LSP (lua_ls) is running -- see README "Language servers".
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },

  {
    -- Autocompletion
    'hrsh7th/nvim-cmp',
    -- Pinned: 2ffe79f (#2219) drops the first char typed after entering
    -- insert mode, so `x` + i/a + `.` shows no popup. Unpin once fixed upstream.
    commit = '7d850f3daf38462c4760adae9cfdbd3417bbc01c',
    dependencies = {
      -- Adds LSP completion capabilities
      'hrsh7th/cmp-nvim-lsp',
    },
  },



}
