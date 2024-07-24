local cmp = require "cmp"

local plugins = {
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = require("custom.configs.overrides").treesitter,
  },
  {
    "nvimtools/none-ls.nvim",
    event = "VeryLazy",
    opts = function()
      return require "custom.configs.null-ls"
    end,
  },
  -- LSP
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "rust-analyzer",
        "lua-language-server",
        "gopls",
        "clangd",
        "tailwindcss-language-server",
        "typescript-language-server",
        "eslint-lsp",
        "jdtls",
        --formats
        "clang-format",
        "prettierd",
        "biome",
        "stylua",
        "zls",
        --lint

        -- Debuggers
        "delve",
        "codelldb",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "plugins.configs.lspconfig"
      require "custom.configs.lspconfig"
    end,
  },
  { "nvim-neotest/nvim-nio" },
  {
    "lvimuser/lsp-inlayhints.nvim",
    opts = {
      highlight = "#1e1e2e",
    },
  },
  -- GO
  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = {
      "mfussenegger/nvim-dap",
      "lvimuser/lsp-inlayhints.nvim",
    },

    config = function(_, opts)
      require("dap-go").setup(opts)
      require("core.utils").load_mappings "dap_go"
    end,
  },
  {
    "olexsmir/gopher.nvim",
    ft = "go",
    config = function(_, opts)
      require("gopher").setup(opts)
      require("core.utils").load_mappings "gopher"
    end,
    build = function()
      vim.cmd [[silent! GoInstallDeps]]
    end,
  },

  -- RUST
  {
    "mrcjkb/rustaceanvim",
    version = "^4",
    ft = { "rust" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "lvimuser/lsp-inlayhints.nvim",
    },
    config = function()
      require "custom.configs.rustaceanvim"
    end,
  },
  {
    "saecki/crates.nvim",
    ft = { "toml" },
    config = function(_, opts)
      local crates = require "crates"
      crates.setup(opts)
      require("cmp").setup.buffer {
        sources = { { name = "crates" } },
      }
      crates.show()
      require("core.utils").load_mappings "crates"
    end,
  },
  {
    "rust-lang/rust.vim",
    ft = "rust",
    init = function()
      vim.g.rustfmt_autosave = 1
    end,
  },
  -- JS/TS
  {
    "windwp/nvim-ts-autotag",
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    config = function()
      require("nvim-ts-autotag").setup()
    end,
  },
  -- DEBUGGING
  {
    "mfussenegger/nvim-dap",
    init = function()
      require "custom.configs.dap"
      require("core.utils").load_mappings "dap"
    end,
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    lazy = false,
    config = function(_, opts)
      require("nvim-dap-virtual-text").setup()
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    lazy = false,
    dependencies = "mfussenegger/nvim-dap",
    config = function()
      local dapui = require "dapui"
      local dap = require "dap"
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = {
      handlers = {},
    },
  },
  -- CODE COMPLETION
  {
    "hrsh7th/nvim-cmp",
    opts = function()
      local M = require "plugins.configs.cmp"
      M.completion.completeopt = "menu,menuone,noselect"
      M.mapping["<CR>"] = cmp.mapping.confirm {
        behavior = cmp.ConfirmBehavior.Insert,
        select = false,
      }
      table.insert(M.sources, { name = "crates" })
      return M
    end,
  },
  -- STYLES
  {
    "folke/noice.nvim",
    dependencies = "MunifTanjim/nui.nvim",
    event = "VeryLazy",
    config = function()
      require("noice").setup {
        lsp = {
          signature = {
            enabled = false,
          },
          hover = {
            enabled = false,
          },

          -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
            ["lsp.hover.enabled"] = false, -- requires hrsh7th/nvim-cmp
          },
        },
        -- you can enable a preset for easier configuration
        presets = {
          bottom_search = true,         -- use a classic bottom cmdline for search
          command_palette = true,       -- position the cmdline and popupmenu together
          long_message_to_split = true, -- long messages will be sent to a split
          inc_rename = false,           -- enables an input dialog for inc-rename.nvim
          lsp_doc_border = false,       -- add a border to hover docs and signature help
        },
      }
    end,
  },
  {
    "kdheepak/lazygit.nvim",
    lazy = true,
    requires = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("lazygit").setup()
      require("telescope").load_extension "lazygit"
    end,
  },
  {
    "kdheepak/lazygit.nvim",
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    -- optional for floating window border decoration
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    -- setting the keybinding for LazyGit with 'keys' is recommended in
    -- order to load the plugin when the command is run for the first time
    keys = {
      { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
    },
  },
}
return plugins
