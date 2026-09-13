return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  -- Downloads the prebuilt server binary; no yarn/node build step needed.
  -- The plugin is lazy-loaded, so put it on the rtp first or the autoload
  -- function is unknown at build time.
  build = function(plugin)
    vim.opt.rtp:append(plugin.dir)
    vim.fn["mkdp#util#install"]()
  end,
  -- https://github.com/iamcco/markdown-preview.nvim/pull/9
  init = function()
    vim.g.mkdp_filetypes = { "markdown" }
    vim.g.mkdp_echo_preview_url = 1
    -- consistent for port forwarding
    vim.g.mkdp_port = 8080

    -- Headless if SSHed in, or on Linux without a display server.
    -- On Mac/local, leave mkdp_browser unset → :MarkdownPreview uses default browser.
    local is_ssh = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_TTY ~= nil
    local has_gui = vim.fn.has('mac') == 1
      or vim.env.DISPLAY ~= nil
      or vim.env.WAYLAND_DISPLAY ~= nil
    if is_ssh or not has_gui then
      vim.g.mkdp_open_to_the_world = 1
      vim.g.mkdp_open_ip = '127.0.0.1'
      vim.g.mkdp_browser = 'none'
    end
  end,
  ft = { "markdown" },
}
