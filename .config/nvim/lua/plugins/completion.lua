-- ─────────────────────────────────────────────────────────────
--  completion.lua  —  nvim-cmp + LuaSnip
-- ─────────────────────────────────────────────────────────────
return {
  {
    "hrsh7th/nvim-cmp",
    event        = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "saadparwaiz1/cmp_luasnip",
      -- Snippets
      {
        "L3MON4D3/LuaSnip",
        build = "make install_jsregexp",
        dependencies = {
          "rafamadriz/friendly-snippets",  -- large snippet collection
        },
        config = function()
          require("luasnip.loaders.from_vscode").lazy_load()
        end,
      },
      -- Tabnine-style icons for completion menu
      "onsails/lspkind.nvim",
    },
    config = function()
      local cmp     = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion    = cmp.config.window.bordered({
            border   = "rounded",
            winhighlight = "Normal:Normal,FloatBorder:BorderBG,CursorLine:PmenuSel",
          }),
          documentation = cmp.config.window.bordered({ border = "rounded" }),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]     = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<CR>"]      = cmp.mapping.confirm({ select = false }),  -- explicit only
          -- Tab: accept if completing, else jump snippet or indent
          ["<Tab>"]     = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"]   = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<C-j>"]     = cmp.mapping.select_next_item(),
          ["<C-k>"]     = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip",  priority = 750 },
          { name = "buffer",   priority = 500, keyword_length = 3 },
          { name = "path",     priority = 250 },
        }),
        formatting = {
          fields = { "kind", "abbr", "menu" },
          format = lspkind.cmp_format({
            mode        = "symbol_text",
            maxwidth    = 50,
            ellipsis_char = "...",
            menu = {
              nvim_lsp = "[LSP]",
              luasnip  = "[Snip]",
              buffer   = "[Buf]",
              path     = "[Path]",
            },
          }),
        },
        experimental = {
          ghost_text = { hl_group = "LspCodeLens" },
        },
      })

      -- Cmdline completion (/ and :)
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
          { { name = "path" } },
          { { name = "cmdline" } }
        ),
      })
    end,
  },
}
