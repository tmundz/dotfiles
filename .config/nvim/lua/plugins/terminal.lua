-- ─────────────────────────────────────────────────────────────
--  terminal.lua  —  toggleterm with dedicated sessions
--  claude-code · gdb/pwngdb · lazygit · general shell
-- ─────────────────────────────────────────────────────────────
return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      -- Main floating terminal toggle
      { "<leader>tt", "<cmd>ToggleTerm direction=float<cr>",      desc = "Float terminal" },
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Horizontal terminal" },
      { "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>",   desc = "Vertical terminal" },
    },
    config = function()
      require("toggleterm").setup({
        size = function(term)
          if term.direction == "horizontal" then return 18
          elseif term.direction == "vertical" then return math.floor(vim.o.columns * 0.4)
          end
        end,
        open_mapping   = nil,  -- we handle manually via keys above
        hide_numbers   = true,
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings  = true,
        persist_size     = true,
        persist_mode     = true,
        direction        = "float",
        close_on_exit    = true,
        shell            = vim.o.shell,
        auto_scroll      = true,
        float_opts = {
          border    = "curved",
          winblend  = 0,
          width     = function() return math.floor(vim.o.columns * 0.85) end,
          height    = function() return math.floor(vim.o.lines * 0.80) end,
          title_pos = "center",
        },
      })

      -- ── <Esc> to exit terminal mode cleanly ──────────────
      function _G.set_terminal_keymaps()
        local opts = { buffer = 0 }
        vim.keymap.set("t", "<Esc>",  [[<C-\><C-n>]],       opts)
        vim.keymap.set("t", "jk",     [[<C-\><C-n>]],       opts)
        vim.keymap.set("t", "<C-h>",  [[<Cmd>TmuxNavigateLeft<cr>]],  opts)
        vim.keymap.set("t", "<C-j>",  [[<Cmd>TmuxNavigateDown<cr>]],  opts)
        vim.keymap.set("t", "<C-k>",  [[<Cmd>TmuxNavigateUp<cr>]],    opts)
        vim.keymap.set("t", "<C-l>",  [[<Cmd>TmuxNavigateRight<cr>]], opts)
      end
      vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

      local Terminal = require("toggleterm.terminal").Terminal

      -- ── Claude Code ──────────────────────────────────────
      local claude = Terminal:new({
        cmd       = "claude",
        dir       = "git_dir",
        direction = "float",
        hidden    = true,
        float_opts = { title = "  Claude Code" },
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>",
            { noremap = true, silent = true })
        end,
      })
      vim.keymap.set("n", "<leader>tc", function() claude:toggle() end,
        { desc = "Toggle Claude Code" })

      -- ── Lazygit ──────────────────────────────────────────
      local lazygit = Terminal:new({
        cmd       = "lazygit",
        dir       = "git_dir",
        direction = "float",
        hidden    = true,
        float_opts = { title = " Lazygit" },
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>",
            { noremap = true, silent = true })
        end,
      })
      vim.keymap.set("n", "<leader>tg", function() lazygit:toggle() end,
        { desc = "Toggle Lazygit" })

      -- ── GDB / pwngdb ─────────────────────────────────────
      local gdb = Terminal:new({
        cmd       = "gdb -q",
        direction = "horizontal",
        hidden    = true,
        float_opts = { title = " GDB" },
      })
      vim.keymap.set("n", "<leader>tG", function() gdb:toggle() end,
        { desc = "Toggle GDB" })

      -- ── Python REPL ───────────────────────────────────────
      local python = Terminal:new({
        cmd       = "python3",
        direction = "horizontal",
        hidden    = true,
      })
      vim.keymap.set("n", "<leader>tp", function() python:toggle() end,
        { desc = "Toggle Python REPL" })

      -- ── Scratch shell (horizontal, quick commands) ────────
      vim.keymap.set("n", "<leader>ts", "<cmd>ToggleTerm direction=horizontal<cr>",
        { desc = "Scratch terminal (horizontal)" })
    end,
  },
}
