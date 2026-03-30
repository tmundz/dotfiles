-- ─────────────────────────────────────────────────────────────
--  telescope.lua  —  fuzzy finding + ripgrep integration
--  Primary search tool for bug bounty / source code review
-- ─────────────────────────────────────────────────────────────
return {
  {
    "nvim-telescope/telescope.nvim",
    cmd          = "Telescope",
    version      = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- fzf native sorter (much faster for large codebases)
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond  = function() return vim.fn.executable("make") == 1 end,
      },
      -- Telescope file browser
      "nvim-telescope/telescope-file-browser.nvim",
      -- Live grep with args (lets you filter rg results inline)
      "nvim-telescope/telescope-live-grep-args.nvim",
      -- UI select override
      "nvim-telescope/telescope-ui-select.nvim",
    },
    keys = {
      -- ── Files ──────────────────────────────────────────────
      { "<leader>ff", "<cmd>Telescope find_files<cr>",                      desc = "Find files" },
      { "<leader>fF", "<cmd>Telescope find_files hidden=true<cr>",          desc = "Find files (hidden)" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>",                        desc = "Recent files" },
      -- ── Grep / search ──────────────────────────────────────
      { "<leader>fg", "<cmd>Telescope live_grep<cr>",                       desc = "Live grep (rg)" },
      { "<leader>fG", ":lua require('telescope').extensions.live_grep_args.live_grep_args()<cr>",
                                                                             desc = "Grep with args" },
      { "<leader>fw", "<cmd>Telescope grep_string<cr>",                     desc = "Grep word under cursor" },
      { "<leader>fW", function()
          require("telescope.builtin").grep_string({
            additional_args = { "--hidden", "--no-ignore" },
          })
        end,                                                                 desc = "Grep word (all files)" },
      -- ── Buffers / tabs ─────────────────────────────────────
      { "<leader>fb", "<cmd>Telescope buffers sort_mru=true<cr>",           desc = "Buffers" },
      -- ── Symbols (LSP + treesitter) ─────────────────────────
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>",            desc = "Document symbols" },
      { "<leader>fS", "<cmd>Telescope lsp_workspace_symbols<cr>",           desc = "Workspace symbols" },
      { "<leader>ft", "<cmd>Telescope treesitter<cr>",                      desc = "Treesitter symbols" },
      -- ── Code navigation ────────────────────────────────────
      { "<leader>fd", "<cmd>Telescope lsp_definitions<cr>",                 desc = "Definitions" },
      { "<leader>fi", "<cmd>Telescope lsp_implementations<cr>",             desc = "Implementations" },
      { "<leader>fR", "<cmd>Telescope lsp_references<cr>",                  desc = "References" },
      { "<leader>fx", "<cmd>Telescope diagnostics<cr>",                     desc = "Diagnostics (workspace)" },
      -- ── Git ────────────────────────────────────────────────
      { "<leader>gc", "<cmd>Telescope git_commits<cr>",                     desc = "Git commits" },
      { "<leader>gb", "<cmd>Telescope git_branches<cr>",                    desc = "Git branches" },
      { "<leader>gs", "<cmd>Telescope git_status<cr>",                      desc = "Git status" },
      -- ── Misc ───────────────────────────────────────────────
      { "<leader>fk", "<cmd>Telescope keymaps<cr>",                         desc = "Keymaps" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>",                       desc = "Help tags" },
      { "<leader>fm", "<cmd>Telescope man_pages<cr>",                       desc = "Man pages" },
      { "<leader>fc", "<cmd>Telescope commands<cr>",                        desc = "Commands" },
      -- ── File browser ───────────────────────────────────────
      { "<leader>fe", function()
          require("telescope").extensions.file_browser.file_browser({
            path          = "%:p:h",
            select_buffer = true,
          })
        end,                                                                 desc = "File browser" },
      -- ── Resume last picker ─────────────────────────────────
      { "<leader>f.", "<cmd>Telescope resume<cr>",                          desc = "Resume last picker" },
    },
    config = function()
      local telescope = require("telescope")
      local actions   = require("telescope.actions")

      telescope.setup({
        defaults = {
          -- ripgrep as default vimgrep program
          vimgrep_arguments = {
            "rg", "--color=never", "--no-heading", "--with-filename",
            "--line-number", "--column", "--smart-case", "--hidden",
            "--glob=!.git/",
          },
          prompt_prefix   = "  ",
          selection_caret = "  ",
          multi_icon      = " ",
          path_display    = { "truncate" },
          sorting_strategy = "ascending",
          layout_strategy  = "horizontal",
          layout_config = {
            horizontal = {
              prompt_position = "top",
              preview_width   = 0.55,
              results_width   = 0.8,
            },
            vertical = {
              mirror = false,
            },
            width  = 0.87,
            height = 0.80,
            preview_cutoff = 120,
          },
          mappings = {
            i = {
              ["<C-j>"]     = actions.move_selection_next,
              ["<C-k>"]     = actions.move_selection_previous,
              ["<C-q>"]     = actions.send_to_qflist + actions.open_qflist,
              ["<C-s>"]     = actions.select_horizontal,
              ["<C-v>"]     = actions.select_vertical,
              ["<C-t>"]     = actions.select_tab,
              ["<C-u>"]     = false, -- don't clear prompt with C-u
              ["<esc>"]     = actions.close,
            },
          },
          file_ignore_patterns = {
            "%.git/", "node_modules/", "target/", "build/", "dist/",
            "%.o$", "%.a$", "%.so$", "%.class$",
          },
          color_devicons   = true,
          set_env          = { ["COLORTERM"] = "truecolor" },
        },
        pickers = {
          find_files = {
            find_command = { "fd", "--type", "f", "--hidden", "--follow",
                             "--exclude", ".git" },
          },
          live_grep = {
            additional_args = { "--hidden" },
          },
          buffers = {
            show_all_buffers = true,
            sort_lastused    = true,
            mappings = {
              i = { ["<C-d>"] = actions.delete_buffer },
            },
          },
        },
        extensions = {
          fzf = {
            fuzzy                   = true,
            override_generic_sorter = true,
            override_file_sorter    = true,
            case_mode               = "smart_case",
          },
          file_browser = {
            theme            = "ivy",
            hijack_netrw     = true,
            hidden           = { file_browser = true, folder_browser = true },
          },
          ["ui-select"] = {
            require("telescope.themes").get_dropdown({}),
          },
          live_grep_args = {
            auto_quoting = true,
          },
        },
      })

      -- Load extensions
      telescope.load_extension("fzf")
      telescope.load_extension("file_browser")
      telescope.load_extension("live_grep_args")
      telescope.load_extension("ui-select")
    end,
  },
}
