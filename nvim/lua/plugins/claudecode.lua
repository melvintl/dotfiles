return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    port_range = { min = 10000, max = 65535 },
    auto_start = true,
    log_level = "info",
    terminal_cmd = "/opt/homebrew/bin/claude",
    track_selection = true,
    terminal = {
      split_side = "right",
      split_width_percentage = 0.40,
      provider = "auto",
      auto_close = true,
    },
  },
  config = function(_, opts)
    require("claudecode").setup(opts)

    -- Terminal navigation keybindings for easier navigation
    -- These work in terminal mode to navigate back to editor
    vim.api.nvim_create_autocmd("TermOpen", {
      pattern = "*",
      callback = function()
        local bufname = vim.api.nvim_buf_get_name(0)
        -- Only apply to Claude Code terminals
        if bufname:match("claude") or bufname:match("ClaudeCode") then
          -- Ctrl+h to move left (back to editor)
          vim.keymap.set('t', '<C-h>', '<C-\\><C-n><C-w>h', { buffer = true, desc = "Move to left window" })
          -- Ctrl+j to move down
          vim.keymap.set('t', '<C-j>', '<C-\\><C-n><C-w>j', { buffer = true, desc = "Move to window below" })
          -- Ctrl+k to move up
          vim.keymap.set('t', '<C-k>', '<C-\\><C-n><C-w>k', { buffer = true, desc = "Move to window above" })
          -- Ctrl+l to move right
          vim.keymap.set('t', '<C-l>', '<C-\\><C-n><C-w>l', { buffer = true, desc = "Move to right window" })
        end
      end,
    })
  end,
  keys = {
    { "<leader>a", nil, desc = "AI/Claude Code" },
    { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
    { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
  },
}
