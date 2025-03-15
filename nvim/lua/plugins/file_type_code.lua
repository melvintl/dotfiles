return {
  -- "gc" to comment visual regions/lines
  'tpope/vim-commentary',


  {
    -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    build = ':TSUpdate',
  },
  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',

}
