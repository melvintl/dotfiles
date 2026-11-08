-- Paste selected code into the first agent pane in this tmux window, without submitting.
vim.keymap.set('x', '<leader>as', function()
  if not vim.env.TMUX_PANE or vim.fn.executable('tmux') == 0 then
    vim.notify('Run Neovim inside tmux to send to an agent', vim.log.levels.WARN)
    return
  end

  local function tmux(args, stdin)
    local result = vim.system(vim.list_extend({ 'tmux' }, args), { text = true, stdin = stdin }):wait()
    if result.code ~= 0 then
      vim.notify('tmux: ' .. result.stderr, vim.log.levels.ERROR)
      return
    end
    return result.stdout
  end

  local panes = tmux({ 'list-panes', '-t', vim.env.TMUX_PANE, '-F', '#{pane_id} #{pane_current_command}' })
  if not panes then
    return
  end
  local target
  -- list-panes returns panes in pane-index order, and -t scopes it to our window.
  for pane, command in panes:gmatch('(%S+) (%S+)') do
    if command == 'claude' or command == 'pi' then
      target = pane
      break
    end
  end
  if not target then
    vim.notify('No Claude Code or pi pane in this tmux window', vim.log.levels.WARN)
    return
  end

  local start = vim.fn.getpos('v')
  local finish = vim.fn.getpos('.')
  local lines = vim.fn.getregion(start, finish, { type = vim.fn.mode(), exclusive = vim.o.selection == 'exclusive' })
  local ref = string.format('%s:%d-%d', vim.fn.expand('%:p'), math.min(start[2], finish[2]), math.max(start[2], finish[2]))
  local message = string.format('%s\n```\n%s\n```\n', ref, table.concat(lines, '\n'))
  local buffer = 'nvim-agent-' .. vim.fn.getpid()
  if tmux({ 'load-buffer', '-b', buffer, '-' }, message) then
    if tmux({ 'paste-buffer', '-p', '-d', '-b', buffer, '-t', target }) then
      tmux({ 'select-pane', '-t', target })
    end
  end
end, { desc = 'Send selection to agent' })
