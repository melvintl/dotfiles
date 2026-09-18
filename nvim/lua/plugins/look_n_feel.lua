return {
  {
    -- Shows pending keymaps after <leader>; every map needs a `desc` to be useful here.
    "folke/which-key.nvim",
    event = "VeryLazy",
    -- Icon provider; already installed for render-markdown, but lazy-loaded there.
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      spec = {
        { "<leader>c", group = "code" },
        { "<leader>g", group = "git" },
        { "<leader>h", group = "help" },
        { "<leader>t", group = "test" },
        { "<leader>y", group = "yank" },
      },
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
