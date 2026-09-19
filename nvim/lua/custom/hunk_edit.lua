-- $EDITOR for the Hunk terminal (see hunk.lua). Hunk runs it as `nvim --clean -l hunk_edit.lua +LINE FILE`.
-- It hands the file to the Neovim that owns the terminal, so `e` does not start a nested Neovim inside it.

local line, file = 1, nil
for _, a in ipairs(arg) do
  if a:match('^%+%d+$') then line = tonumber(a:sub(2)) else file = a end
end

-- Neovim sets $NVIM to its server address for every terminal job
local chan = vim.fn.sockconnect('pipe', vim.env.NVIM, { rpc = true })
vim.rpcrequest(chan, 'nvim_exec_lua', "require('custom.hunk').open(...)", { file, line })
