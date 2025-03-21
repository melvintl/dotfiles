return {
  {'nvim-telescope/telescope.nvim', tag = '0.1.2',
    -- or                              , branch = '0.1.x',
    dependencies = { 'nvim-lua/plenary.nvim' }
  },

  {'preservim/nerdtree' },


  -- {
  --   "folke/flash.nvim",
  --   event = "VeryLazy",
  --   ---@type Flash.Config
  --   opts = {},
  --   keys = {
  --     {
  --       "s",
  --       mode = { "n", "x", "o" },
  --       function()
  --         require("flash").jump()
  --       end,
  --       desc = "Flash",
  --     },
  --     {
  --       "S",
  --       mode = { "n", "o", "x" },
  --       function()
  --         require("flash").treesitter()
  --       end,
  --       desc = "Flash Treesitter",
  --     },
  --     {
  --       "r",
  --       mode = "o",
  --       function()
  --         require("flash").remote()
  --       end,
  --       desc = "Remote Flash",
  --     },
  --     {
  --       "R",
  --       mode = { "o", "x" },
  --       function()
  --         require("flash").treesitter_search()
  --       end,
  --       desc = "Flash Treesitter Search",
  --     },
  --     {
  --       "<c-s>",
  --       mode = { "c" },
  --       function()
  --         require("flash").toggle()
  --       end,
  --       desc = "Toggle Flash Search",
  --     },
  --   },
  -- }
  --
}
