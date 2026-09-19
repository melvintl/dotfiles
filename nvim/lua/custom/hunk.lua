-- Persistent Hunk diff review in a hidden terminal buffer.
-- Quitting Hunk drops its live session (agent notes, review position), so the toggle only hides the buffer.

local hunk_buf = nil
local hunk_job = nil
local previous_buf = nil

local function is_alive()
  return hunk_buf ~= nil and vim.api.nvim_buf_is_valid(hunk_buf)
    -- jobwait with a 0 timeout returns -1 while the job is still running
    and hunk_job ~= nil and vim.fn.jobwait({ hunk_job }, 0)[1] == -1
end

-- Buffer to show in place of Hunk: the one we came from, else the alternate, else an empty one
local function fallback_buf()
  if previous_buf and vim.api.nvim_buf_is_valid(previous_buf) then return previous_buf end
  local alt = vim.fn.bufnr('#')
  if alt > 0 and alt ~= hunk_buf and vim.api.nvim_buf_is_valid(alt) then return alt end
  return vim.api.nvim_create_buf(true, false)
end

local toggle

local function start()
  if vim.fn.executable('hunk') ~= 1 then
    vim.notify('hunk not found on PATH, install it to use the Hunk review toggle', vim.log.levels.ERROR)
    return false
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'hide'
  -- jobstart with term = true attaches to the current buffer, so display it first
  vim.api.nvim_set_current_buf(buf)

  local job
  job = vim.fn.jobstart({ 'hunk', 'diff', '--watch' }, {
    term = true,
    cwd = vim.fn.getcwd(),
    on_exit = function()
      vim.schedule(function()
        -- A late exit from an old session must not clear a newer one
        if job ~= hunk_job then return end
        local target = fallback_buf()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(win) == buf then vim.api.nvim_win_set_buf(win, target) end
        end
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        hunk_buf, hunk_job = nil, nil
      end)
    end,
  })
  if job <= 0 then
    vim.api.nvim_set_current_buf(fallback_buf())
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.notify('Failed to start hunk diff --watch', vim.log.levels.ERROR)
    return false
  end

  hunk_buf, hunk_job = buf, job
  vim.bo[buf].filetype = 'hunk'
  vim.keymap.set('t', '<leader>gt', toggle, { buffer = buf, desc = 'Toggle persistent Hunk review' })
  return true
end

toggle = function()
  if is_alive() and vim.api.nvim_get_current_buf() == hunk_buf then
    vim.cmd.stopinsert()
    vim.api.nvim_set_current_buf(fallback_buf())
    return
  end

  previous_buf = vim.api.nvim_get_current_buf()
  if is_alive() then
    -- One terminal in two windows shrinks to the smaller one, so jump to it if already visible
    local win = vim.fn.bufwinid(hunk_buf)
    if win ~= -1 then
      vim.api.nvim_set_current_win(win)
    else
      vim.api.nvim_set_current_buf(hunk_buf)
    end
  elseif not start() then
    return
  end
  vim.cmd.startinsert()
end

vim.keymap.set('n', '<leader>gt', toggle, { desc = 'Toggle persistent Hunk review' })
