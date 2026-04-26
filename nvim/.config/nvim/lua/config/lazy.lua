local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local lean = vim.fn.filereadable(vim.fn.expand("~/.nvim_lean")) == 1

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- extras: always on
    { import = "lazyvim.plugins.extras.ui.mini-animate" },
    { import = "lazyvim.plugins.extras.editor.telescope" },
    -- extras: full profile only
    not lean and { import = "lazyvim.plugins.extras.lang.python" } or nil,
    not lean and { import = "lazyvim.plugins.extras.lang.rust" } or nil,
    not lean and { import = "lazyvim.plugins.extras.lang.typescript" } or nil,
    -- local overrides
    { import = "plugins" },
  },
  defaults = { lazy = true, version = false },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = not lean, notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})
