local opt = vim.opt

-- Readable defaults
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.numberwidth = 4

-- Indentation (language-specific overrides are in autocmds.lua)
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.shiftround = true
opt.autoindent = true
opt.smartindent = true

-- Search and screen layout
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true
opt.inccommand = "split"
opt.termguicolors = true
opt.wrap = false
opt.breakindent = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.showmode = false
opt.pumheight = 12
opt.winborder = "rounded"
opt.laststatus = 3
opt.splitright = true
opt.splitbelow = true

-- Recovery and safe writes
opt.mouse = "a"
opt.undofile = true
opt.undolevels = 10000
opt.swapfile = true
opt.confirm = true
opt.completeopt = { "menu", "menuone", "noselect" }
opt.updatetime = 250
opt.timeoutlen = 400

local undodir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undodir, "p")
opt.undodir = undodir
