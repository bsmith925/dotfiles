vim.g.mapleader      = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt
opt.relativenumber = true
opt.scrolloff      = 8
opt.sidescrolloff  = 8
opt.wrap           = false
opt.expandtab      = true
opt.shiftwidth     = 2
opt.tabstop        = 2
opt.confirm        = true
opt.clipboard      = "unnamedplus"

-- Ensure Mason / LSP spawners can find tools regardless of launch context
local function prepend_if_exists(p)
  if vim.fn.isdirectory(p) == 1 then
    vim.env.PATH = p .. ":" .. vim.env.PATH
  end
end
prepend_if_exists(vim.env.HOME .. "/.cargo/bin")     -- Rust (rustup)
prepend_if_exists(vim.env.HOME .. "/.local/go/bin")  -- Go (user install)
prepend_if_exists(vim.env.HOME .. "/go/bin")         -- GOPATH bins
prepend_if_exists(vim.env.HOME .. "/.local/bin")     -- misc user bins
