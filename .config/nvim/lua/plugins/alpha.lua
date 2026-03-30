-- ─────────────────────────────────────────────────────────────
--  alpha.lua  —  startup dashboard  ☕  cà phê
-- ─────────────────────────────────────────────────────────────
return {
  {
    "goolord/alpha-nvim",
    event        = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha     = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      -- ── Header: CAPHE logo ────────────────────────────────
      dashboard.section.header.val = {
        " ██████╗ █████╗ ██████╗ ██╗  ██╗███████╗ ",
        "██╔════╝██╔══██╗██╔══██╗██║  ██║██╔════╝ ",
        "██║     ███████║██████╔╝███████║█████╗   ",
        "██║     ██╔══██║██╔═══╝ ██╔══██║██╔══╝   ",
        "╚██████╗██║  ██║██║     ██║  ██║███████╗ ",
        " ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝ ",
        "                                         ",
        "              ≋  cà phê  ≋               ",
      }
      dashboard.section.header.opts.hl = "AlphaHeader"

      -- ── Buttons ───────────────────────────────────────────
      dashboard.section.buttons.val = {
        dashboard.button("f", "󰍉  Find file",        "<cmd>Telescope find_files<cr>"),
        dashboard.button("r", "  Recent files",      "<cmd>Telescope oldfiles<cr>"),
        dashboard.button("g", "  Find text",         "<cmd>Telescope live_grep<cr>"),
        dashboard.button("n", "  New file",          "<cmd>ene <BAR> startinsert<cr>"),
        dashboard.button("s", "  Restore session",   "<cmd>SessionRestore<cr>"),
        dashboard.button("l", "󰒲  Lazy",              "<cmd>Lazy<cr>"),
        dashboard.button("q", "  Quit",              "<cmd>qa<cr>"),
      }

      -- Style each button
      for _, btn in ipairs(dashboard.section.buttons.val) do
        btn.opts.hl        = "AlphaButtons"
        btn.opts.hl_shortcut = "AlphaShortcut"
      end

      -- ── Footer ────────────────────────────────────────────
      local function footer()
        local stats   = require("lazy").stats()
        local ms      = math.floor(stats.startuptime * 10 + 0.5) / 10
        local version = vim.version()
        return string.format(
          "  nvim v%d.%d.%d  ·  󰒲 %d plugins  ·  ⚡ %.1fms",
          version.major, version.minor, version.patch,
          stats.count, ms
        )
      end

      dashboard.section.footer.val        = footer()
      dashboard.section.footer.opts.hl    = "AlphaFooter"

      -- ── Layout spacing ────────────────────────────────────
      dashboard.config.layout = {
        { type = "padding", val = 2 },
        dashboard.section.header,
        { type = "padding", val = 2 },
        dashboard.section.buttons,
        { type = "padding", val = 1 },
        dashboard.section.footer,
      }

      alpha.setup(dashboard.config)

      -- ── Highlight groups (catppuccin mocha pink-mauve) ────
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          local ok, palette = pcall(require, "catppuccin.palettes")
          if not ok then return end
          local c = palette.get_palette("mocha")
          vim.api.nvim_set_hl(0, "AlphaHeader",   { fg = c.mauve })
          vim.api.nvim_set_hl(0, "AlphaButtons",  { fg = c.blue })
          vim.api.nvim_set_hl(0, "AlphaShortcut", { fg = c.pink, bold = true })
          vim.api.nvim_set_hl(0, "AlphaFooter",   { fg = c.surface2, italic = true })
        end,
      })

      -- Apply immediately for first load
      vim.schedule(function()
        local ok, palette = pcall(require, "catppuccin.palettes")
        if not ok then return end
        local c = palette.get_palette("mocha")
        vim.api.nvim_set_hl(0, "AlphaHeader",   { fg = c.mauve })
        vim.api.nvim_set_hl(0, "AlphaButtons",  { fg = c.blue })
        vim.api.nvim_set_hl(0, "AlphaShortcut", { fg = c.pink, bold = true })
        vim.api.nvim_set_hl(0, "AlphaFooter",   { fg = c.surface2, italic = true })
      end)

      -- Hide bufferline + statusline on the dashboard
      vim.api.nvim_create_autocmd("User", {
        pattern  = "AlphaReady",
        callback = function()
          vim.opt_local.showtabline = 0
          vim.opt_local.laststatus  = 0
        end,
      })
      vim.api.nvim_create_autocmd("BufUnload", {
        buffer   = 0,
        callback = function()
          vim.opt.showtabline = 2
          vim.opt.laststatus  = 3
        end,
      })
    end,
  },
}
