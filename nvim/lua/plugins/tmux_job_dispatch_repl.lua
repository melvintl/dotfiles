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
      vim.g.slime_target = "tmux"
      -- vim.g.slime_default_config = {["socket_name"]= get(split($TMUX, ","), 0), ["target_pane"]= ":.2"}
      vim.g.slime_default_config = {["socket_name"]= string.match(os.getenv("TMUX"), "(.-),"), ["target_pane"]= ":.2"}
    end,
  },
}
