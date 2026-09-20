return {



  -- **************************************
  -- Git stuff
  -- **************************************
  'tpope/vim-fugitive',
  {
    -- Adds git-related signs to the gutter, as well as utilities for managing changes
    -- common commands :Gitsigns diffthis
    'lewis6991/gitsigns.nvim',
    opts = {
      -- See `:help gitsigns.txt`
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked    = { text = '' }, -- Dont want new files to look noisy
      },
      on_attach = function(bufnr)
        local gs = require('gitsigns')
        -- next_hunk/prev_hunk are deprecated; nav_hunk takes the direction as an argument
        vim.keymap.set('n', '<leader>gp', function() gs.nav_hunk('prev') end, { buffer = bufnr, desc = '[G]o to [P]revious Hunk' })
        vim.keymap.set('n', '<leader>gn', function() gs.nav_hunk('next') end, { buffer = bufnr, desc = '[G]o to [N]ext Hunk' })
        vim.keymap.set('n', '<leader>gh', gs.preview_hunk, { buffer = bufnr, desc = '[G]it preview [H]unk' })
      end,
    },
  },

  {
    -- Git diff viewer with better visualization
    'sindrets/diffview.nvim',
    config = function()
      -- Custom highlight groups for better visibility with onedark theme
      -- These provide higher contrast for added, deleted, and modified lines

      -- Added lines - darker green background with lighter green text
      vim.api.nvim_set_hl(0, 'DiffAdd', { bg = '#2d4a2e', fg = '#a3d39c' })
      vim.api.nvim_set_hl(0, 'DiffviewDiffAdd', { bg = '#2d4a2e', fg = '#a3d39c' })
      vim.api.nvim_set_hl(0, 'DiffviewDiffAddAsChar', { bg = '#3d5a3e', fg = '#5fb053', bold = true })

      -- Deleted lines - darker red background with lighter red text
      vim.api.nvim_set_hl(0, 'DiffDelete', { bg = '#4a2d2d', fg = '#ef9995' })
      vim.api.nvim_set_hl(0, 'DiffviewDiffDelete', { bg = '#4a2d2d', fg = '#ef9995' })
      vim.api.nvim_set_hl(0, 'DiffviewDiffDeleteAsChar', { bg = '#5a3d3d', fg = '#e06c75', bold = true })

      -- Modified/changed lines - darker blue background with bright highlights for inline changes
      vim.api.nvim_set_hl(0, 'DiffChange', { bg = '#2d3d4a' })
      vim.api.nvim_set_hl(0, 'DiffviewDiffChange', { bg = '#2d3d4a' })
      vim.api.nvim_set_hl(0, 'DiffText', { bg = '#4a5a2d', fg = '#e5c07b', bold = true })
      vim.api.nvim_set_hl(0, 'DiffviewDiffModifiedAsChar', { bg = '#3d4d5a', fg = '#61afef', bold = true })

      -- Refresh the open diffview when files change on disk, so a coding agent's edits show live
      vim.api.nvim_create_autocmd("FileChangedShellPost", {
        callback = function()
          local ok, lib = pcall(require, "diffview.lib")
          if ok and lib.get_current_view() then
            require("diffview.actions").refresh_files()
          end
        end,
      })
    end,
  },


}
