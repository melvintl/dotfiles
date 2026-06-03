return {
 "folke/which-key.nvim",

  {
    -- Snacks.nvim - Required dependency for claudecode.nvim
    -- Only terminal module enabled to avoid conflicts with existing plugins
    "folke/snacks.nvim",
    opts = {
      bigfile = { enabled = false },
      dashboard = {                     -- Replaces vim-startify (numbered recent files)
        enabled = true,
        formats = {
          -- Show paths relative to cwd (":.") instead of relative to home ("~")
          file = function(item, ctx)
            local fname = vim.fn.fnamemodify(item.file, ":.")
            local dir, base = fname:match("^(.*/)(.+)$")
            return dir and { { dir, hl = "dir" }, { base, hl = "file" } } or { { fname, hl = "file" } }
          end,
        },
        sections = {
          { section = "recent_files", cwd = true, limit = 8, padding = 1 },
        },
      },
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

}
