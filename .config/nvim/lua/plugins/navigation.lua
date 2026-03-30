-- ─────────────────────────────────────────────────────────────
--  navigation.lua  —  aerial · harpoon2 · flash · neo-tree
--  The core of "jump to function / track files" workflow
-- ─────────────────────────────────────────────────────────────
return {

  -- ── Aerial: symbol outline (functions, classes, methods) ───
  {
    "stevearc/aerial.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>o",  "<cmd>AerialToggle!<cr>",  desc = "Toggle symbol outline" },
      { "<leader>O",  "<cmd>AerialNavToggle<cr>", desc = "Toggle aerial nav" },
      { "[s",         "<cmd>AerialPrev<cr>",      desc = "Prev symbol" },
      { "]s",         "<cmd>AerialNext<cr>",      desc = "Next symbol" },
      { "[[",         "<cmd>AerialPrevUp<cr>",    desc = "Prev symbol (up)" },
      { "]]",         "<cmd>AerialNextUp<cr>",    desc = "Next symbol (up)" },
    },
    opts = {
      backends          = { "treesitter", "lsp", "markdown", "asciidoc", "man" },
      layout = {
        max_width   = { 40, 0.2 },
        width       = nil,
        win_opts    = {},
        placement   = "window",
        resize_to_content = true,
        default_direction = "prefer_right",
      },
      attach_mode       = "window",
      filter_kind       = {
        "Class", "Constructor", "Enum", "Function",
        "Interface", "Module", "Method", "Struct",
      },
      highlight_on_hover = true,
      autoscroll        = true,
      float = {
        border      = "rounded",
        relative    = "cursor",
        max_height  = 0.9,
        height      = nil,
        min_height  = { 8, 0.1 },
      },
      treesitter = { update_delay = 300 },
      lsp = { update_delay = 500, diagnostics_trigger_update = true },
      show_guides = true,
      guides = {
        mid_item   = "├─",
        last_item  = "└─",
        nested_top = "│ ",
        whitespace = "  ",
      },
    },
  },

  -- ── Harpoon 2: bookmark & quick-jump to files ──────────────
  {
    "ThePrimeagen/harpoon",
    branch       = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ha", function() require("harpoon"):list():add() end,     desc = "Harpoon: add file" },
      { "<leader>hh", function()
          local harpoon = require("harpoon")
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,                                                               desc = "Harpoon: menu" },
      -- Quick-jump slots 1-5
      { "<leader>1",  function() require("harpoon"):list():select(1) end, desc = "Harpoon file 1" },
      { "<leader>2",  function() require("harpoon"):list():select(2) end, desc = "Harpoon file 2" },
      { "<leader>3",  function() require("harpoon"):list():select(3) end, desc = "Harpoon file 3" },
      { "<leader>4",  function() require("harpoon"):list():select(4) end, desc = "Harpoon file 4" },
      { "<leader>5",  function() require("harpoon"):list():select(5) end, desc = "Harpoon file 5" },
      -- Cycle through harpoon list
      { "<leader>hp", function() require("harpoon"):list():prev() end,    desc = "Harpoon: prev" },
      { "<leader>hn", function() require("harpoon"):list():next() end,    desc = "Harpoon: next" },
    },
    opts = {
      settings = {
        save_on_toggle = true,
        sync_on_ui_close = false,
      },
    },
  },

  -- ── Flash: lightning-fast cursor jumps anywhere ──────────
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts  = {
      labels = "asdfghjklqwertyuiopzxcvbnm",
      search = { mode = "fuzzy" },
      jump   = { nohlsearch = true },
      label  = {
        uppercase      = false,
        rainbow        = { enabled = true, shade = 5 },
        style          = "overlay",
      },
      modes = {
        char = {
          jump_labels  = true,
          multi_line   = false,
        },
      },
    },
    keys = {
      { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,
                 desc = "Flash jump" },
      { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,
                 desc = "Flash treesitter select" },
      { "r",     mode = "o",               function() require("flash").remote() end,
                 desc = "Flash remote" },
      { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end,
                 desc = "Flash treesitter search" },
      { "<C-s>", mode = "c",               function() require("flash").toggle() end,
                 desc = "Toggle flash in search" },
    },
  },

  -- ── Neo-tree: file explorer ──────────────────────────────
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch       = "v3.x",
    cmd          = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>E",  "<cmd>Neotree toggle<cr>",                              desc = "Toggle file tree" },
      { "<leader>nf", "<cmd>Neotree reveal<cr>",                              desc = "Reveal current file" },
      { "<leader>ng", "<cmd>Neotree git_status<cr>",                          desc = "Git status tree" },
    },
    opts = {
      close_if_last_window  = true,
      popup_border_style    = "rounded",
      enable_git_status     = true,
      enable_diagnostics    = true,
      window = {
        width  = 35,
        mappings = {
          ["<space>"] = "none",
          ["l"]       = "open",
          ["h"]       = "close_node",
        },
      },
      filesystem = {
        filtered_items = {
          visible       = true,
          hide_dotfiles = false,
          hide_gitignored = true,
          hide_by_name  = { ".DS_Store", "thumbs.db" },
        },
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
      },
      git_status = {
        window = { position = "float" },
      },
    },
  },

  -- ── Tmux navigator: seamless pane switching ──────────────
  {
    "christoomey/vim-tmux-navigator",
    cmd  = { "TmuxNavigateLeft", "TmuxNavigateDown",
             "TmuxNavigateUp",   "TmuxNavigateRight" },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  desc = "Move to left split/pane" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>",  desc = "Move to lower split/pane" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>",    desc = "Move to upper split/pane" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Move to right split/pane" },
    },
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
  },

  -- ── Trouble: diagnostics panel ──────────────────────────
  {
    "folke/trouble.nvim",
    cmd  = "Trouble",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",              desc = "Diagnostics (workspace)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Diagnostics (buffer)" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>",                  desc = "Location list" },
      { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>",                   desc = "Quickfix list" },
      { "<leader>xr", "<cmd>Trouble lsp_references toggle<cr>",           desc = "LSP references" },
    },
    opts = {
      modes = {
        lsp_references = { params = { include_declaration = true } },
      },
    },
  },

  -- ── illuminate: highlight other uses of word under cursor ─
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    opts  = {
      providers        = { "lsp", "treesitter", "regex" },
      delay            = 200,
      large_file_cutoff = 2000,
    },
    config = function(_, opts)
      require("illuminate").configure(opts)
      -- Navigate between references
      vim.keymap.set("n", "]]", function() require("illuminate").goto_next_reference(false) end,
        { desc = "Next reference (illuminate)" })
      vim.keymap.set("n", "[[", function() require("illuminate").goto_prev_reference(false) end,
        { desc = "Prev reference (illuminate)" })
    end,
  },
}
