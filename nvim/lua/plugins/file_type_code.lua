return {
  {
    -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    -- The 'master' branch is frozen and unsupported on Neovim 0.12+; 'main' is
    -- the rewrite. Pin it explicitly so a branch rename can't shift this.
    branch = 'main',
    -- Upstream does not support lazy-loading this plugin.
    lazy = false,
    build = ':TSUpdate',
  },
  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',

}
