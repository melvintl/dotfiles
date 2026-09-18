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

}
