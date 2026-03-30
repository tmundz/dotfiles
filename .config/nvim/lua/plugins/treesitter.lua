-- ─────────────────────────────────────────────────────────────
--  treesitter.lua
--  lazy=false: treesitter is a core dep (aerial, context, text-objects
--  all need it), lazy-loading it causes rtp-timing failures.
-- ─────────────────────────────────────────────────────────────
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",  -- v1.x main requires nvim 0.12+; master = stable legacy API
    build = ":TSUpdate",
    lazy  = false,   -- load at startup; solves rtp-timing issues
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
      "windwp/nvim-ts-autotag",
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "c", "cpp", "go", "rust", "zig", "python",
          "java", "kotlin", "javascript", "typescript",
          "html", "css", "c_sharp",
          "lua", "bash", "json", "yaml", "toml", "xml",
          "dockerfile", "make", "cmake",
          "regex", "sql",
          "markdown", "markdown_inline", "vimdoc",
        },
        auto_install = true,
        highlight = {
          enable                            = true,
          additional_vim_regex_highlighting = false,
        },
        indent   = { enable = true },
        autotag  = { enable = true },
        textobjects = {
          select = {
            enable    = true,
            lookahead = true,
            keymaps = {
              ["af"] = { query = "@function.outer", desc = "outer function" },
              ["if"] = { query = "@function.inner", desc = "inner function" },
              ["ac"] = { query = "@class.outer",    desc = "outer class" },
              ["ic"] = { query = "@class.inner",    desc = "inner class" },
              ["aa"] = { query = "@parameter.outer",desc = "outer argument" },
              ["ia"] = { query = "@parameter.inner",desc = "inner argument" },
              ["ab"] = { query = "@block.outer",    desc = "outer block" },
              ["ib"] = { query = "@block.inner",    desc = "inner block" },
              ["al"] = { query = "@loop.outer",     desc = "outer loop" },
              ["il"] = { query = "@loop.inner",     desc = "inner loop" },
              ["ai"] = { query = "@conditional.outer", desc = "outer if" },
              ["ii"] = { query = "@conditional.inner", desc = "inner if" },
            },
          },
          move = {
            enable    = true,
            set_jumps = true,
            goto_next_start = {
              ["]f"] = { query = "@function.outer", desc = "Next function start" },
              ["]c"] = { query = "@class.outer",    desc = "Next class start" },
              ["]a"] = { query = "@parameter.inner",desc = "Next argument start" },
            },
            goto_next_end = {
              ["]F"] = { query = "@function.outer", desc = "Next function end" },
              ["]C"] = { query = "@class.outer",    desc = "Next class end" },
            },
            goto_previous_start = {
              ["[f"] = { query = "@function.outer", desc = "Prev function start" },
              ["[c"] = { query = "@class.outer",    desc = "Prev class start" },
              ["[a"] = { query = "@parameter.inner",desc = "Prev argument start" },
            },
            goto_previous_end = {
              ["[F"] = { query = "@function.outer", desc = "Prev function end" },
              ["[C"] = { query = "@class.outer",    desc = "Prev class end" },
            },
          },
          swap = {
            enable        = true,
            swap_next     = { ["<leader>cs"] = "@parameter.inner" },
            swap_previous = { ["<leader>cS"] = "@parameter.inner" },
          },
        },
      })
    end,
  },

  -- context is its own spec — depends on treesitter being loaded first
  {
    "nvim-treesitter/nvim-treesitter-context",
    lazy = false,
    opts = {
      enable            = true,
      max_lines         = 4,
      min_window_height = 20,
      trim_scope        = "outer",
      mode              = "cursor",
      separator         = "─",
    },
    keys = {
      { "<leader>ut", "<cmd>TSContextToggle<cr>", desc = "Toggle treesitter context" },
    },
  },
}
