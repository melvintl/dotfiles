-- Reload buffers a coding agent edits on disk, and yank code with its path for the agent.

-- Let Neovim silently reload files changed on disk (when buffer has no unsaved edits)
vim.opt.autoread = true

-- Poll disk on these events so autoread actually fires while editing
vim.api.nvim_create_autocmd(
  { "FocusGained", "TermLeave", "BufEnter", "CursorHold", "CursorHoldI" },
  { callback = function()
      if vim.fn.mode() ~= "c" then vim.cmd.checktime() end
  end }
)

-- Let me know when a buffer got reloaded so changes aren't invisible
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  callback = function()
    vim.notify("File changed on disk — buffer reloaded", vim.log.levels.INFO)
  end,
})

-- Yank selection + path:line range to clipboard, so pasting into a coding agent carries context
vim.keymap.set("v", "<leader>yr", function()
  local path = vim.fn.expand("%:.")
  vim.cmd('normal! "vy')
  -- '< and '> mark the start/end lines of the just-yanked selection
  local ref = string.format("%s:%d-%d", path, vim.fn.line("'<"), vim.fn.line("'>"))
  local code = vim.fn.getreg("v")
  vim.fn.setreg("+", string.format("%s\n```\n%s\n```", ref, code))
end, { desc = "Yank code + path:line (for agent)" })
