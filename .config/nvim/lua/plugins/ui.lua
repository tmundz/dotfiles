-- ─────────────────────────────────────────────────────────────
--  ui.lua  —  lualine · bufferline · which-key · indent ·
--             todo-comments · noice · dressing
-- ─────────────────────────────────────────────────────────────
return {

  -- ── Lualine: statusline ──────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    event        = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local colors = require("catppuccin.palettes").get_palette("mocha")

      -- Custom theme based on catppuccin
      local custom_theme = {
        normal   = {
          a = { bg = colors.blue,    fg = colors.mantle, gui = "bold" },
          b = { bg = colors.surface0,fg = colors.text },
          c = { bg = colors.base,   fg = colors.subtext0 },
        },
        insert   = { a = { bg = colors.green,   fg = colors.mantle, gui = "bold" } },
        visual   = { a = { bg = colors.mauve,   fg = colors.mantle, gui = "bold" } },
        replace  = { a = { bg = colors.red,     fg = colors.mantle, gui = "bold" } },
        command  = { a = { bg = colors.peach,   fg = colors.mantle, gui = "bold" } },
        terminal = { a = { bg = colors.teal,    fg = colors.mantle, gui = "bold" } },
        inactive = {
          a = { bg = colors.base,   fg = colors.surface2 },
          b = { bg = colors.base,   fg = colors.surface2 },
          c = { bg = colors.base,   fg = colors.surface2 },
        },
      }

      -- Show active LSP clients
      local function lsp_clients()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients == 0 then return "" end
        local names = {}
        for _, c in ipairs(clients) do
          table.insert(names, c.name)
        end
        return " " .. table.concat(names, ", ")
      end

      -- Show harpoon slot for current file
      local function harpoon_slot()
        local ok, harpoon = pcall(require, "harpoon")
        if not ok then return "" end
        local list    = harpoon:list()
        local current = vim.fn.expand("%:p")
        for i, item in ipairs(list.items) do
          if item.value == current then
            return "󰀱 " .. i
          end
        end
        return ""
      end

      require("lualine").setup({
        options = {
          theme                = custom_theme,
          component_separators = { left = "", right = "" },
          section_separators   = { left = "", right = "" },
          globalstatus         = true,
          disabled_filetypes   = { statusline = { "dashboard", "alpha", "neo-tree" } },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = {
            { "filename", path = 1, symbols = { modified = "●", readonly = "", unnamed = "?" } },
            { harpoon_slot, color = { fg = colors.peach } },
          },
          lualine_x = {
            { lsp_clients, color = { fg = colors.blue } },
            "filetype",
          },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "location" },
        },
        extensions = { "neo-tree", "aerial", "toggleterm", "trouble", "lazy" },
      })
    end,
  },

  -- ── Bufferline: tabline showing open buffers ─────────────
  {
    "akinsho/bufferline.nvim",
    event        = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    version      = "*",
    opts = {
      options = {
        mode                    = "buffers",
        separator_style         = "slant",
        always_show_bufferline  = false,
        show_buffer_close_icons = true,
        show_close_icon         = false,
        color_icons             = true,
        diagnostics       = "nvim_lsp",
        diagnostics_indicator = function(_, _, diag)
          local icons = { error = " ", warning = " ", info = " " }
          local s = {}
          for level, icon in pairs(icons) do
            if diag[level] and diag[level] > 0 then
              table.insert(s, icon .. diag[level])
            end
          end
          return table.concat(s, " ")
        end,
        offsets = {
          { filetype = "neo-tree", text = "File Explorer", text_align = "center",
            separator = true },
          { filetype = "aerial",   text = "Symbols",       text_align = "center" },
        },
      },
    },
  },

  -- ── Which-key: live cheat sheet ──────────────────────────
  {
    "folke/which-key.nvim",
    event   = "VeryLazy",
    version = "v3.*",
    opts = {
      preset = "modern",
      delay  = 300,
      spec = {
        -- Group labels for the cheat sheet
        { "<leader>f",  group = " Find / Telescope" },
        { "<leader>g",  group = " Git" },
        { "<leader>h",  group = "󰛢 Harpoon" },
        { "<leader>l",  group = " LSP" },
        { "<leader>n",  group = " Neo-tree" },
        { "<leader>r",  group = " Refactor" },
        { "<leader>s",  group = " Splits" },
        { "<leader>t",  group = " Terminal" },
        { "<leader>u",  group = " UI toggles" },
        { "<leader>w",  group = " Workspace" },
        { "<leader>x",  group = " Trouble / Diagnostics" },
        { "<leader>c",  group = " Code" },
        { "g",          group = "Go to" },
        { "]",          group = "Next" },
        { "[",          group = "Prev" },
      },
    },
    keys = {
      { "<leader>?",  function() require("which-key").show({ global = false }) end,
        desc = "Buffer local keymaps (which-key)" },
    },
  },

  -- ── Indent blankline: visual indentation guides ──────────
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    main  = "ibl",
    opts  = {
      indent = { char = "│", tab_char = "│" },
      scope  = {
        enabled         = true,
        show_start      = true,
        show_end        = false,
        highlight       = { "Function", "Label" },
        priority        = 500,
      },
      exclude = {
        filetypes = { "help", "dashboard", "neo-tree", "Trouble", "lazy",
                     "mason", "notify", "toggleterm" },
      },
    },
  },

  -- ── Todo comments: highlight TODO/FIXME/HACK/NOTE ────────
  {
    "folke/todo-comments.nvim",
    event        = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "]t",         function() require("todo-comments").jump_next() end, desc = "Next TODO" },
      { "[t",         function() require("todo-comments").jump_prev() end, desc = "Prev TODO" },
      { "<leader>ft", "<cmd>TodoTelescope<cr>",                           desc = "Find TODOs" },
    },
    -- Custom keywords for security research context
    opts = {
      keywords = {
        FIX   = { icon = " ", color = "error",   alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
        TODO  = { icon = " ", color = "info" },
        HACK  = { icon = " ", color = "warning", alt = { "UNSAFE" } },
        WARN  = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF  = { icon = " ", color = "default", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE  = { icon = " ", color = "hint",    alt = { "INFO" } },
        TEST  = { icon = "⏲ ", color = "test",   alt = { "TESTING", "PASSED", "FAILED" } },
        -- Security-specific
        VULN  = { icon = " ", color = "error",   alt = { "CVE" } },
        SINK  = { icon = " ", color = "error" },
        TAINT = { icon = " ", color = "warning" },
        OOB   = { icon = " ", color = "error" },
      },
      colors = {
        error   = { "DiagnosticError", "ErrorMsg", "#ea6962" },
        warning = { "DiagnosticWarn",  "WarningMsg","#d8a657" },
        info    = { "DiagnosticInfo",               "#7daea3" },
        hint    = { "DiagnosticHint",               "#a9b665" },
        default = { "Identifier",                   "#cba6f7" },
        test    = { "Identifier",                   "#74c7ec" },
      },
    },
  },

  -- ── Noice: better cmdline / messages UI ──────────────────
  {
    "folke/noice.nvim",
    event        = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"]                = true,
          ["cmp.entry.get_documentation"]                  = true,
        },
        signature = { enabled = true },
      },
      presets = {
        bottom_search        = true,
        command_palette      = true,
        long_message_to_split = true,
        inc_rename           = false,
        lsp_doc_border       = true,
      },
      views = {
        cmdline_popup = { border = { style = "rounded" } },
      },
    },
  },

  -- ── Dressing: better vim.ui.select / vim.ui.input ────────
  {
    "stevearc/dressing.nvim",
    lazy = true,
    init = function()
      vim.ui.select = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.select(...)
      end
      vim.ui.input = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.input(...)
      end
    end,
  },

  -- ── nvim-notify: pretty notifications ────────────────────
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    opts  = {
      timeout      = 3000,
      max_height   = function() return math.floor(vim.o.lines * 0.75) end,
      max_width    = function() return math.floor(vim.o.columns * 0.75) end,
      on_open      = function(win)
        vim.api.nvim_win_set_config(win, { zindex = 100 })
      end,
      render       = "compact",
      stages       = "fade_in_slide_out",
      background_colour = "#1e1e2e",
    },
    config = function(_, opts)
      require("notify").setup(opts)
      vim.notify = require("notify")
    end,
  },

  -- ── Autopairs ────────────────────────────────────────────
  {
    "windwp/nvim-autopairs",
    event  = "InsertEnter",
    opts   = {
      check_ts      = true,
      ts_config     = { lua = { "string" }, javascript = { "template_string" } },
      fast_wrap     = {
        map         = "<M-e>",
        chars       = { "{", "[", "(", '"', "'" },
        pattern     = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
        offset      = 0,
        end_key     = "$",
        keys        = "qwertyuiopzxcvbnmasdfghjkl",
        check_comma = true,
        highlight   = "Search",
      },
    },
    config = function(_, opts)
      local autopairs = require("nvim-autopairs")
      autopairs.setup(opts)
      -- Hook into nvim-cmp
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },

  -- ── Comment.nvim: smart comment/uncomment ─────────────────
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts  = {
      padding   = true,
      sticky    = true,
      toggler   = { line = "gcc", block = "gbc" },
      opleader  = { line = "gc",  block = "gb" },
      extra     = { above = "gcO", below = "gco", eol = "gcA" },
      mappings  = { basic = true, extra = true },
    },
  },

  -- ── Gitsigns: inline git blame + hunk navigation ─────────
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts  = {
      signs = {
        add           = { text = "▎" },
        change        = { text = "▎" },
        delete        = { text = "" },
        topdelete     = { text = "" },
        changedelete  = { text = "▎" },
        untracked     = { text = "▎" },
      },
      on_attach = function(bufnr)
        local gs   = package.loaded.gitsigns
        local bmap = function(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end
        -- Navigation
        bmap("n", "]h", gs.next_hunk,  "Next hunk")
        bmap("n", "[h", gs.prev_hunk,  "Prev hunk")
        -- Actions
        bmap("n", "<leader>hs", gs.stage_hunk,    "Stage hunk")
        bmap("n", "<leader>hr", gs.reset_hunk,    "Reset hunk")
        bmap("v", "<leader>hs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage hunk")
        bmap("n", "<leader>hS", gs.stage_buffer,  "Stage buffer")
        bmap("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")
        bmap("n", "<leader>hR", gs.reset_buffer,  "Reset buffer")
        bmap("n", "<leader>hp", gs.preview_hunk,  "Preview hunk")
        bmap("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
        bmap("n", "<leader>hd", gs.diffthis,      "Diff this")
        bmap("n", "<leader>hD", function() gs.diffthis("~") end, "Diff against HEAD~")
        -- Toggle
        bmap("n", "<leader>ub", gs.toggle_current_line_blame, "Toggle blame")
      end,
    },
  },
}
