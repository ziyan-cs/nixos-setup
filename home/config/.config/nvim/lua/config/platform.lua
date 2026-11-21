-- 平台相关设置：Windows / Linux / macOS 的差异集中在这里
local opt = vim.opt

if vim.fn.has("win32") == 1 then
  -- 固定 cmd.exe，避免从 Git Bash 启动时 shellcmdflag 不匹配
  opt.shell = "cmd.exe"
  opt.shellcmdflag = "/s /c"
  opt.shellquote = '"'
  opt.shellxquote = ""

  -- tree-sitter build 在 Windows 上默认探测 cl.exe；强制使用 gcc
  vim.env.CC = "gcc"
end

-- 剪贴板：只在存在 provider 时启用 unnamedplus，
-- 避免无图形界面的 Linux / 服务器启动时报警告
local has_clipboard_provider = vim.fn.has("win32") == 1
  or vim.fn.has("mac") == 1
  or (vim.env.WAYLAND_DISPLAY ~= nil
    and vim.fn.executable("wl-copy") == 1 and vim.fn.executable("wl-paste") == 1)
  or (vim.env.DISPLAY ~= nil
    and (vim.fn.executable("xclip") == 1 or vim.fn.executable("xsel") == 1))

if has_clipboard_provider then
  opt.clipboard = "unnamedplus"
end

-- SSH：只把显式复制/剪切发送到客户端；普通 Vim 寄存器仍在本地。
-- Windows 剪贴板粘贴由终端 Ctrl+Shift+V 负责，不发 OSC 52 读取请求。
if vim.env.SSH_CONNECTION or vim.env.SSH_TTY then
  local cached = { { "" }, "v" }
  local send = require("vim.ui.clipboard.osc52").copy("+")
  local function copy(lines, regtype)
    cached = { vim.deepcopy(lines), regtype }
    send(lines)
  end
  local function paste()
    return vim.deepcopy(cached)
  end
  vim.g.clipboard = {
    name = "SSH OSC 52 copy",
    copy = { ["+"] = copy, ["*"] = copy },
    paste = { ["+"] = paste, ["*"] = paste },
    cache_enabled = 0,
  }
  opt.clipboard = ""
end

-- 不使用 Neovim 内置的远程插件 provider，
-- 关闭后可消除 checkhealth 警告并减少启动开销
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
