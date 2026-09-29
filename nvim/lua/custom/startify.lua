vim.g.startify_change_to_dir = 0
vim.g.startify_change_to_vcs_root = 1
-- Use :SS to save a session
vim.g.startify_session_persistence = 1
vim.g.startify_files_number = 5
-- Startify falls back to its default fortune/cowsay header unless this is set.
vim.cmd('let g:startify_custom_header = []')
vim.g.startify_lists = {
  { type = 'sessions', header = { '   Sessions' } },
  { type = 'dir', header = { '   Recent Files' } },
}
