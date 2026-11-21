local map = vim.keymap.set
local opts = function(desc)
  return { desc = desc, silent = true }
end

-- Save and quit without overriding terminal flow-control keys.
map("n", "<leader>w", "<cmd>write<CR>", opts("Save file"))
map("n", "<leader>q", "<cmd>confirm quit<CR>", opts("Close window"))
map("n", "<leader>Q", "<cmd>confirm qall<CR>", opts("Quit Neovim"))
map("n", "<leader>l", "<cmd>Lazy<CR>", opts("Open plugin manager"))

-- Diagnostics
map("n", "<leader>d", vim.diagnostic.open_float, opts("Show diagnostic"))
map("n", "[d", vim.diagnostic.goto_prev, opts("Previous diagnostic"))
map("n", "]d", vim.diagnostic.goto_next, opts("Next diagnostic"))
map("n", "<leader>xx", vim.diagnostic.setloclist, opts("List diagnostics"))

-- Window navigation and splits
map("n", "<C-h>", "<C-w>h", opts("Focus left window"))
map("n", "<C-j>", "<C-w>j", opts("Focus lower window"))
map("n", "<C-k>", "<C-w>k", opts("Focus upper window"))
map("n", "<C-l>", "<C-w>l", opts("Focus right window"))
map("n", "<leader>sv", "<cmd>vsplit<CR>", opts("Vertical split"))
map("n", "<leader>sh", "<cmd>split<CR>", opts("Horizontal split"))

-- Buffers and embedded terminal
map("n", "]b", "<cmd>bnext<CR>", opts("Next buffer"))
map("n", "[b", "<cmd>bprevious<CR>", opts("Previous buffer"))
map("n", "<leader>bd", "<cmd>bdelete<CR>", opts("Close buffer"))
map("n", "<leader>tt", "<cmd>split | terminal<CR>", opts("Terminal below"))
map("n", "<leader>tv", "<cmd>vsplit | terminal<CR>", opts("Terminal right"))
map("t", "<Esc><Esc>", [[<C-\><C-n>]], opts("Leave terminal input"))

map("n", "<leader>?", "<cmd>WhichKey<CR>", opts("Show keymap guide"))
