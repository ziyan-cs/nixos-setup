-- Theme, statusline, and shortcut hints.
return {
  -- Dark plum-lavender with restrained pink accents to match Chrome's palette.
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = false,
        term_colors = true,
        no_italic = true,
        color_overrides = {
          mocha = {
            rosewater = "#F0B6CC",
            flamingo = "#E89AB7",
            pink = "#E5A4D0",
            mauve = "#C5A0E8",
            red = "#E782A2",
            maroon = "#D98BAA",
            peach = "#E6A0B6",
            yellow = "#E5C1A8",
            green = "#A3C6B0",
            teal = "#9EC8C9",
            sky = "#A8C8E8",
            sapphire = "#9AAEE8",
            blue = "#A3A9EA",
            lavender = "#C5B3F0",
            text = "#E7E0F2",
            subtext1 = "#C9C0DA",
            subtext0 = "#ADA3C5",
            overlay2 = "#978DAF",
            overlay1 = "#817794",
            overlay0 = "#6C637F",
            surface2 = "#5E566F",
            surface1 = "#494257",
            surface0 = "#393344",
            base = "#252131",
            mantle = "#211D2B",
            crust = "#191722",
          },
        },
        integrations = {
          cmp = true,
          gitsigns = true,
          indent_blankline = { enabled = true },
          native_lsp = {
            enabled = true,
            virtual_text = { errors = true, hints = true, warnings = true, information = true },
            underlines = { errors = true, hints = true, warnings = true, information = true },
          },
          neo_tree = true,
          telescope = true,
          treesitter = true,
          which_key = true,
        },
      })
      vim.o.background = "dark"
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- 状态栏
  {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "catppuccin",
        globalstatus = true,
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  -- 按键提示
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "classic",
      spec = {
        { "<leader>b", group = "缓冲区" },
        { "<leader>c", group = "代码" },
        { "<leader>f", group = "查找" },
        { "<leader>g", group = "Git" },
        { "<leader>q", group = "退出" },
        { "<leader>t", group = "终端" },
        { "<leader>x", group = "诊断" },
      },
    },
  },
}
