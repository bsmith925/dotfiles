local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to continue...", "" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- ~/.nvim_lean → minimal profile (VPS / shared machines)
local lean = vim.fn.filereadable(vim.fn.expand("~/.nvim_lean")) == 1

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- extras: always on
    { import = "lazyvim.plugins.extras.ui.mini-animate" },
    { import = "lazyvim.plugins.extras.editor.telescope" },

    -- extras: full profile only
    not lean and { import = "lazyvim.plugins.extras.lang.python" }     or nil,
    not lean and { import = "lazyvim.plugins.extras.lang.rust" }       or nil,
    not lean and { import = "lazyvim.plugins.extras.lang.typescript" } or nil,
    not lean and { import = "lazyvim.plugins.extras.lang.go" }         or nil,
    not lean and { import = "lazyvim.plugins.extras.lang.json" }       or nil,
    not lean and { import = "lazyvim.plugins.extras.lang.markdown" }   or nil,

    -- local overrides
    { import = "plugins" },
  },
  defaults = { lazy = true, version = false },
  install  = { colorscheme = { "tokyonight", "habamax" } },
  checker  = { enabled = not lean, notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})
