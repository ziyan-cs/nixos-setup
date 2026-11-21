-- File navigation, search, syntax, Git, and explicit formatting.
return {
  -- 文件树
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "切换文件树" },
      { "<leader>E", "<cmd>Neotree reveal<CR>", desc = "在文件树中定位" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      close_if_last_window = true,
      window = { width = 32 },
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },

  -- 模糊查找
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
      },
    },
    keys = {
      { "<C-p>", "<cmd>Telescope find_files<CR>", desc = "快速查找文件" },
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "查找文件" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "全项目搜索" },
      { "<leader>fw", "<cmd>Telescope grep_string<CR>", desc = "搜索光标下单词" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "查找缓冲区" },
      { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "最近文件" },
      { "<leader>fd", "<cmd>Telescope diagnostics<CR>", desc = "查找诊断" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "帮助文档" },
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "当前文件内搜索" },
    },
    opts = {
      defaults = {
        layout_strategy = "flex",
        layout_config = { flex = { flip_columns = 120 } },
        file_ignore_patterns = { "node_modules", "%.git/", "dist/", "build/" },
      },
    },
    config = function(_, opts)
      require("telescope").setup(opts)
      pcall(require("telescope").load_extension, "fzf")
    end,
  },

  -- 语法高亮（nvim-treesitter main 分支的新 API）
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local parsers = {
        "c", "cpp", "lua", "vim", "vimdoc", "query", "nix",
        "python", "go", "bash",
        "json", "yaml", "toml",
        "markdown", "markdown_inline", "cmake",
        "gitcommit", "diff",
      }

      require("nvim-treesitter").setup()
      -- 已安装的会自动跳过
      if vim.fn.executable("tree-sitter") == 1 then
        require("nvim-treesitter").install(parsers)
      else
        vim.schedule(function()
          vim.notify("请安装 tree-sitter-cli 后重启 Neovim，以安装语法解析器", vim.log.levels.WARN)
        end)
      end

      -- main 分支不再自动开启高亮，需要手动为每个文件类型启动
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
        callback = function(ev)
          local buf = ev.buf
          local size = vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf))
          if size > 1024 * 1024 then
            return -- 大文件跳过
          end
          pcall(vim.treesitter.start, buf)
        end,
      })
    end,
  },

  -- Git 状态与操作
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "│" },
        change = { text = "│" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local map = vim.keymap.set
        map("n", "]h", gs.next_hunk, { buffer = bufnr, desc = "下一个改动" })
        map("n", "[h", gs.prev_hunk, { buffer = bufnr, desc = "上一个改动" })
        map("n", "<leader>gp", gs.preview_hunk, { buffer = bufnr, desc = "预览改动" })
        map("n", "<leader>gr", gs.reset_hunk, { buffer = bufnr, desc = "撤销改动" })
        map("n", "<leader>gb", gs.blame_line, { buffer = bufnr, desc = "行作者" })
        map("n", "<leader>gd", gs.diffthis, { buffer = bufnr, desc = "对比改动" })
      end,
    },
  },

  -- 缩进参考线
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "│" },
      scope = { enabled = false },
    },
  },

  -- 高亮光标下相同单词
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("illuminate").configure({
        filetypes_denylist = { "neo-tree", "TelescopePrompt", "markdown", "help" },
      })
    end,
  },

  -- 快速注释（gcc / gc）
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- Bracket pairing without changing terminal control keys.
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = { "hrsh7th/nvim-cmp" },
    opts = {
      check_ts = true,
      ts_config = {
        c = { "string_literal", "char_literal", "comment" },
        cpp = { "string_literal", "raw_string_literal", "char_literal", "comment" },
      },
      map_c_h = false,
      map_c_w = false,
      disable_filetype = { "TelescopePrompt", "neo-tree" },
    },
    config = function(_, opts)
      local pairs = require("nvim-autopairs")
      pairs.setup(opts)
      -- Pair brackets while leaving quote behavior unchanged.
      pairs.remove_rule('"')
      pairs.remove_rule("'")
      pairs.remove_rule("`")
      -- Avoid inserting pairs inside C/C++ comments.
      for _, opening in ipairs({ "(", "[", "{" }) do
        for _, rule in ipairs(pairs.get_rules(opening)) do
          rule:with_pair(function()
            if vim.bo.filetype ~= "c" and vim.bo.filetype ~= "cpp" then
              return true
            end
            local pos = vim.api.nvim_win_get_cursor(0)
            if pos[2] == 0 then
              return true
            end
            local parser = vim.treesitter.get_parser(0, nil, { error = false })
            if not parser then
              return true
            end
            parser:parse()
            local node = vim.treesitter.get_node({ pos = { pos[1] - 1, pos[2] - 1 } })
            if node and node:type() == "comment" then
              local text = vim.treesitter.get_node_text(node, 0)
              local _, _, end_row, end_col = node:range()
              -- 已闭合的块注释后面仍可以输入成对括号。
              return text:sub(-2) == "*/" and (pos[1] - 1 > end_row or pos[2] >= end_col)
            end
            return true
          end)
        end
      end
      require("cmp").event:on("confirm_done", require("nvim-autopairs.completion.cmp").on_confirm_done())
    end,
  },

  -- 格式化
  {
    "stevearc/conform.nvim",
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        desc = "格式化当前文件",
      },
    },
    opts = {
      formatters_by_ft = {
        python = { "ruff_format" },
        go = { "gofmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        nix = { "nixfmt" },
      },
    },
  },
}
