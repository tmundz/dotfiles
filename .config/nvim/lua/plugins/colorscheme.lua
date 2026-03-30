-- ─────────────────────────────────────────────────────────────
--  colorscheme.lua  —  catppuccin mocha, security-researcher override
--  Mocha base + boosted contrast + red/green accent swap for vulns
-- ─────────────────────────────────────────────────────────────
return {
  {
    "catppuccin/nvim",
    name    = "catppuccin",
    lazy    = false,
    priority = 1000,   -- load first
    opts = {
      flavour               = "mocha",
      background            = { light = "latte", dark = "mocha" },
      transparent_background = false,
      show_end_of_buffer    = false,
      term_colors           = true,
      dim_inactive = {
        enabled    = true,
        shade      = "dark",
        percentage = 0.12,
      },
      styles = {
        comments    = { "italic" },
        conditionals= { "italic" },
        loops       = {},
        functions   = { "bold" },
        keywords    = { "italic" },
        strings     = {},
        variables   = {},
        numbers     = {},
        booleans    = { "bold", "italic" },
        properties  = {},
        types       = { "bold" },
        operators   = {},
      },
      integrations = {
        aerial           = true,
        cmp              = true,
        gitsigns         = true,
        harpoon          = true,
        illuminate       = { enabled = true },
        indent_blankline = { enabled = true, scope_color = "lavender" },
        lsp_trouble      = true,
        mason            = true,
        native_lsp = {
          enabled          = true,
          virtual_text = {
            errors      = { "italic" },
            hints       = { "italic" },
            warnings    = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors      = { "underline" },
            hints       = { "underline" },
            warnings    = { "underline" },
            information = { "underline" },
          },
          inlay_hints = { background = true },
        },
        neotree        = true,
        telescope      = { enabled = true, style = "nvchad" },
        treesitter     = true,
        which_key      = true,
      },
      -- Custom highlight overrides — security researcher palette
      -- Hotter red for errors, vivid green for strings, amber for warnings
      -- Pink-mauve shift: mauve pushed warmer/pinker (#e06ea0 vs stock #cba6f7)
      color_overrides = {
        mocha = {
          mauve   = "#e06ea0",  -- warmer, pinker mauve (stock: #cba6f7)
          pink    = "#f5a0c0",  -- brighter pink to complement
          lavender= "#d08fcc",  -- pulled slightly toward pink too
        },
      },
      custom_highlights = function(colors)
        return {
          -- Punch up function names so they pop during code review
          ["@function"]           = { fg = colors.blue,    style = { "bold" } },
          ["@function.call"]      = { fg = colors.sapphire },
          ["@function.builtin"]   = { fg = colors.peach,   style = { "bold" } },
          -- Make string literals slightly dimmer so logic stands out
          ["@string"]             = { fg = colors.green,   style = {} },
          -- Vivid red for keywords that matter in vuln hunting
          ["@keyword.return"]     = { fg = colors.red,     style = { "bold", "italic" } },
          ["@keyword.operator"]   = { fg = colors.red },
          -- Highlight unsafe/unsafe block in Rust
          ["@keyword.exception"]  = { fg = colors.red,     style = { "bold" } },
          -- Numbers / constants stand out (useful for offsets/sizes)
          ["@number"]             = { fg = colors.peach,   style = { "bold" } },
          ["@constant"]           = { fg = colors.peach },
          ["@constant.builtin"]   = { fg = colors.peach,   style = { "bold" } },
          -- Type names use the pinkier mauve
          ["@type"]               = { fg = colors.mauve,   style = { "bold" } },
          ["@type.builtin"]       = { fg = colors.mauve,   style = { "italic" } },
          -- Properties/fields pick up the pink hue
          ["@property"]           = { fg = colors.pink },
          ["@field"]              = { fg = colors.pink },
          -- Telescope styling — borders now use the pinker mauve
          TelescopeBorder         = { fg = colors.mauve },
          TelescopePromptBorder   = { fg = colors.pink },
          TelescopeResultsBorder  = { fg = colors.surface2 },
          TelescopePreviewBorder  = { fg = colors.teal },
          -- Diff colours (useful when reviewing patches)
          DiffAdd                 = { bg = "#1a2f1a" },
          DiffChange              = { bg = "#1a1f2f" },
          DiffDelete              = { bg = "#2f1a1a" },
          -- Aerial symbol colours
          AerialFunctionIcon      = { fg = colors.blue },
          AerialStructIcon        = { fg = colors.yellow },
          AerialClassIcon         = { fg = colors.mauve },
          -- Fix black line at top (TabLineFill + WinBar)
          TabLineFill             = { bg = colors.base },
          WinBar                  = { bg = colors.base,   fg = colors.subtext0 },
          WinBarNC                = { bg = colors.mantle, fg = colors.surface2 },
        }
      end,
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
