-- Send a precise code reference (@path:Lstart-end) to the Pi pane in this tmux window.
-- The text is pasted without Enter and the Pi pane is focused, so you type the instruction.

-- Pi runs under node, so match the pane title ("π - …" / "pi:…") as well as the command
local function find_pi_pane()
  if vim.g.pi_pane then
    return vim.g.pi_pane
  end
  local out = vim.fn.systemlist({ 'tmux', 'list-panes', '-t', vim.env.TMUX_PANE or '', '-F', '#{pane_id}\t#{pane_current_command}\t#{pane_title}' })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  for _, line in ipairs(out) do
    local id, cmd, title = line:match('^(%S+)\t([^\t]*)\t(.*)$')
    if cmd == 'pi' or (cmd == 'node' and (title:match('^π') or title:match('^pi'))) then
      return id
    end
  end
end

local function send(text)
  if not vim.env.TMUX then
    vim.notify('Not inside tmux', vim.log.levels.ERROR)
    return
  end
  local pane = find_pi_pane()
  if not pane then
    vim.notify('No Pi pane in this tmux window (set vim.g.pi_pane to override)', vim.log.levels.ERROR)
    return
  end
  -- Bracketed paste (-p) inserts atomically, so Pi's @ file autocomplete doesn't pop up
  vim.fn.system({ 'tmux', 'load-buffer', '-b', 'pi-ref', '-' }, text)
  vim.fn.system({ 'tmux', 'paste-buffer', '-p', '-d', '-b', 'pi-ref', '-t', pane })
  vim.fn.system({ 'tmux', 'select-pane', '-t', pane })
end

local function relpath()
  local path = vim.fn.expand('%:.')
  if path == '' then
    vim.notify('Buffer has no file', vim.log.levels.ERROR)
  end
  return path
end

vim.keymap.set('n', '<leader>aa', function()
  local path = relpath()
  if path ~= '' then
    send(string.format('@%s:L%d ', path, vim.fn.line('.')))
  end
end, { desc = 'Send @path:Lline to Pi' })

vim.keymap.set('x', '<leader>aa', function()
  local path = relpath()
  if path == '' then
    return
  end
  -- 'v' and '.' are the live selection ends; '< '> are only set after leaving visual mode
  local s, e = vim.fn.line('v'), vim.fn.line('.')
  if s > e then
    s, e = e, s
  end
  vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'nx', false)
  send(string.format('@%s:L%d-%d ', path, s, e))
end, { desc = 'Send @path:Lstart-end to Pi' })

vim.keymap.set('n', '<leader>ad', function()
  local path = relpath()
  if path == '' then
    return
  end
  local lnum = vim.fn.line('.')
  local diags = vim.diagnostic.get(0, { lnum = lnum - 1 })
  if #diags == 0 then
    vim.notify('No diagnostics on this line', vim.log.levels.WARN)
    return
  end
  local msgs = vim.tbl_map(function(d)
    return (d.message:gsub('%s+', ' '))
  end, diags)
  send(string.format('@%s:L%d diagnostic: %s ', path, lnum, table.concat(msgs, '; ')))
end, { desc = 'Send line diagnostics to Pi' })
