return {
 "folke/which-key.nvim",

  {
    -- Snacks.nvim - Required dependency for claudecode.nvim
    -- Only terminal module enabled to avoid conflicts with existing plugins
    "folke/snacks.nvim",
    opts = {
      bigfile = { enabled = false },
      dashboard = { enabled = false },  -- Keep vim-startify
      explorer = { enabled = false },   -- Keep NERDTree
      indent = { enabled = false },     -- Keep indent-blankline
      notifier = { enabled = false },
      picker = { enabled = false },     -- Keep Telescope
      quickfile = { enabled = false },
      scroll = { enabled = false },
      statuscolumn = { enabled = false },
      words = { enabled = false },
    },
  },

  {
    -- Theme inspired by Atom
    'navarasu/onedark.nvim',
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'onedark'
    end,
  },

  {
    -- Set lualine as statusline
    'nvim-lualine/lualine.nvim',
    -- See `:help lualine.txt`
    opts = {
      options = {
        globalstatus = true,
        icons_enabled = true,
        theme = 'onedark',
        component_separators = '|',
        section_separators = '',
      },
    },
  },

  {
      "lukas-reineke/indent-blankline.nvim",
      main = "ibl",
      ---@module "ibl"
      ---@type ibl.config
      opts = {},
  },

   'mhinz/vim-startify',

}
