-- leader 必须在加载插件前设置
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.platform")
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- 引导 lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "安装 lazy.nvim 失败:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\n按任意键退出...", "MoreMsg" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "catppuccin", "habamax" } },
  checker = { enabled = false, notify = false },
  change_detection = { notify = false },
  rocks = { enabled = false }, -- 不使用 luarocks 插件，避免 hererocks 依赖
  ui = { border = "rounded" },
})
