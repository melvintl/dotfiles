return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  config = function()
    require("copilot").setup({
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<C-y>",      -- Ctrl+y to accept (also works via Tab if no cmp popup see changes in cmp.lua)
          accept_word = false,
          accept_line = false,
          next = "<M-]>",        -- Alt+] for next suggestion
          prev = "<M-[>",        -- Alt+[ for previous suggestion
          dismiss = "<C-]>",
        },
      },
      panel = {
        enabled = true,
        auto_refresh = false,
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<C-\\>"        -- Ctrl+\ to open panel (works in insert mode)
        },
      },
      filetypes = {
        yaml = false,
        markdown = true,
        help = false,
        gitcommit = false,
        gitrebase = false,
        hgcommit = false,
        svn = false,
        cvs = false,
        ["."] = false, -- Ignore dot conf files  
      },
    })
  end,
}
