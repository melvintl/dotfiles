return {
 
  {
    -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
  },

  -- Additional lua configuration, makes nvim config easier
  'folke/neodev.nvim',

  {
    -- Autocompletion
    'hrsh7th/nvim-cmp',
    dependencies = {
      -- Adds LSP completion capabilities
      'hrsh7th/cmp-nvim-lsp',
    },
  },



}
