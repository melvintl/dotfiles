return {

  -- **************************************
  -- tmux, job dispatch, REPL
  -- **************************************
  'christoomey/vim-tmux-navigator',
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
