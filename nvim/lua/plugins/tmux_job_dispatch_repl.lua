return {

  -- **************************************
  -- tmux, job dispatch, REPL
  -- **************************************
  {
    -- C-h/j/k/l across Neovim splits and tmux panes. Not lazy-loaded: the
    -- plugin sets tmux's @pane-is-vim option at load, which .tmux.conf checks.
    'mrjones2014/smart-splits.nvim',
    lazy = false,
    config = function()
      local ss = require('smart-splits')
      ss.setup({})
      vim.keymap.set('n', '<C-h>', ss.move_cursor_left, { desc = 'Move to left split/pane' })
      vim.keymap.set('n', '<C-j>', ss.move_cursor_down, { desc = 'Move to lower split/pane' })
      vim.keymap.set('n', '<C-k>', ss.move_cursor_up, { desc = 'Move to upper split/pane' })
      vim.keymap.set('n', '<C-l>', ss.move_cursor_right, { desc = 'Move to right split/pane' })
      vim.keymap.set('n', '<C-\\>', ss.move_cursor_previous, { desc = 'Move to previous split/pane' })
    end,
  },
  'benmills/vimux',
  'tpope/vim-dispatch',
  {
    'jpalardy/vim-slime',
    config = function()
      vim.g.slime_target = 'tmux'
      -- $TMUX is "socket_path,pid,session"; only set when running inside tmux
      -- so startup doesn't error outside of it.
      local tmux = os.getenv('TMUX')
      if tmux then
        vim.g.slime_default_config = { socket_name = tmux:match('(.-),'), target_pane = ':.2' }
      end
    end,
  },
}
