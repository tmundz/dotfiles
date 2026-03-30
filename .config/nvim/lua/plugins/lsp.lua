-- ─────────────────────────────────────────────────────────────
--  lsp.lua  —  mason + lspconfig for all target languages
--  C/C++ · Go · Rust · Zig · Python · Java · Kotlin · JS/TS
--  HTML · CSS · C# · (pwngdb handled via terminal)
-- ─────────────────────────────────────────────────────────────
return {
  -- ── Mason: auto-install LSPs ─────────────────────────────
  {
    "williamboman/mason.nvim",
    cmd  = "Mason",
    build = ":MasonUpdate",
    opts = {
      ui = {
        border  = "rounded",
        icons = {
          package_installed   = "✓",
          package_pending     = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    -- NOTE: config is handled inside nvim-lspconfig's config block below
    opts = {
      ensure_installed = {
        "clangd",             -- C / C++
        "gopls",              -- Go
        "rust_analyzer",      -- Rust
        "zls",                -- Zig
        "pyright",            -- Python
        "jdtls",              -- Java
        "kotlin_language_server",
        "ts_ls",              -- JavaScript / TypeScript
        "html",
        "cssls",
        "omnisharp",          -- C# / .NET
        "lua_ls",             -- Lua (for editing this config!)
        "jsonls",
        "yamlls",
        "bashls",
      },
      automatic_installation = true,
    },
  },

  -- ── nvim-lspconfig ───────────────────────────────────────
  {
    "neovim/nvim-lspconfig",
    event        = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      -- Nice LSP status in the bottom right
      { "j-hui/fidget.nvim", opts = { notification = { window = { winblend = 0 } } } },
      -- Extra lua neovim typedefs
      { "folke/neodev.nvim", opts = {} },
    },
    config = function()
      -- ── Diagnostic UI ──────────────────────────────────────
      vim.diagnostic.config({
        virtual_text = {
          prefix   = "●",
          source   = "if_many",
          spacing  = 4,
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN]  = " ",
            [vim.diagnostic.severity.INFO]  = " ",
            [vim.diagnostic.severity.HINT]  = "󰌵 ",
          },
        },
        underline      = true,
        update_in_insert = false,
        severity_sort  = true,
        float = {
          border  = "rounded",
          source  = "always",
          header  = "",
          prefix  = "",
        },
      })

      -- ── On-attach: keymaps that apply to every LSP buffer ──
      local on_attach = function(_, bufnr)
        local bmap = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        -- Navigation
        bmap("n", "gd",         vim.lsp.buf.definition,         "Go to definition")
        bmap("n", "gD",         vim.lsp.buf.declaration,        "Go to declaration")
        bmap("n", "gi",         vim.lsp.buf.implementation,     "Go to implementation")
        bmap("n", "gt",         vim.lsp.buf.type_definition,    "Go to type definition")
        bmap("n", "gr",         vim.lsp.buf.references,         "References")
        bmap("n", "K",          vim.lsp.buf.hover,              "Hover docs")
        bmap("n", "<C-k>",      vim.lsp.buf.signature_help,     "Signature help")
        bmap("i", "<C-k>",      vim.lsp.buf.signature_help,     "Signature help")

        -- Actions
        bmap("n", "<leader>ca", vim.lsp.buf.code_action,        "Code action")
        bmap("v", "<leader>ca", vim.lsp.buf.code_action,        "Code action (visual)")
        bmap("n", "<leader>rn", vim.lsp.buf.rename,             "Rename symbol")
        bmap("n", "<leader>lf", function()
          vim.lsp.buf.format({ async = true })
        end,                                                     "Format buffer")

        -- Workspace
        bmap("n", "<leader>wa", vim.lsp.buf.add_workspace_folder,    "Add workspace folder")
        bmap("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
        bmap("n", "<leader>wl", function()
          print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end,                                                         "List workspace folders")

        -- Inlay hints toggle (nvim 0.10+)
        if vim.lsp.inlay_hint then
          bmap("n", "<leader>uh", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
          end, "Toggle inlay hints")
        end
      end

      -- ── Capabilities (extended by nvim-cmp) ────────────────
      local capabilities = vim.tbl_deep_extend(
        "force",
        vim.lsp.protocol.make_client_capabilities(),
        require("cmp_nvim_lsp").default_capabilities()
      )

      -- ── Per-server settings ─────────────────────────────────
      local lspconfig = require("lspconfig")

      local servers = {
        -- C / C++ — clangd with extra flags useful for vuln research
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=google",
          },
          init_options = {
            usePlaceholders = true,
            completeUnimported = true,
            clangdFileStatus = true,
          },
        },

        -- Go
        gopls = {
          settings = {
            gopls = {
              analyses       = { unusedparams = true },
              staticcheck    = true,
              gofumpt        = true,
              usePlaceholders = true,
            },
          },
        },

        -- Rust
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo       = { allFeatures = true },
              checkOnSave = { command = "clippy" },
              inlayHints  = {
                bindingModeHints       = { enable = false },
                chainingHints          = { enable = true },
                closingBraceHints      = { enable = true, minLines = 25 },
                closureReturnTypeHints = { enable = "with_block" },
                parameterHints         = { enable = true },
                typeHints              = { enable = true },
              },
            },
          },
        },

        -- Zig
        zls = {},

        -- Python
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode   = "basic",
                autoSearchPaths    = true,
                useLibraryCodeForTypes = true,
              },
            },
          },
        },

        -- TypeScript / JavaScript
        ts_ls = {
          settings = {
            typescript = { inlayHints = {
              includeInlayParameterNameHints            = "all",
              includeInlayFunctionParameterTypeHints    = true,
              includeInlayVariableTypeHints             = true,
              includeInlayPropertyDeclarationTypeHints  = true,
              includeInlayFunctionLikeReturnTypeHints   = true,
            }},
          },
        },

        -- HTML / CSS
        html  = { filetypes = { "html", "htmldjango" } },
        cssls = {},

        -- C# / .NET
        omnisharp = {},

        -- Lua (for this config)
        lua_ls = {
          settings = {
            Lua = {
              workspace  = { checkThirdParty = false },
              telemetry  = { enable = false },
              completion = { callSnippet = "Replace" },
            },
          },
        },

        -- Bash
        bashls = {},
        jsonls = {},
        yamlls = {},
      }

      -- Java: jdtls needs special setup, use nvim-jdtls plugin instead
      -- (handled separately below)

      -- mason-lspconfig v2: handlers go inside setup(), not setup_handlers()
      require("mason-lspconfig").setup({
        handlers = {
          function(server_name)
            local cfg = servers[server_name] or {}
            cfg.on_attach    = on_attach
            cfg.capabilities = capabilities
            lspconfig[server_name].setup(cfg)
          end,
          ["jdtls"] = function() end,
        },
      })
    end,
  },

  -- ── Java: nvim-jdtls for full JDTLS support ──────────────
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
  },

  -- ── Extra C/C++ tooling ───────────────────────────────────
  {
    "p00f/clangd_extensions.nvim",
    ft = { "c", "cpp" },
    opts = {
      inlay_hints = { show_parameter_hints = true },
      ast = {
        role_icons  = { type = "", declaration = "", expression = "", statement = ";",
                        specifier = "", ["template argument"] = "" },
        kind_icons  = { compound = "", recovery = "", translationUnit = "",
                        packExpansion = "", templateTypeParm = "", templateTemplateParm = "",
                        templateParamObject = "" },
      },
    },
  },
}
