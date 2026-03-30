-- ─────────────────────────────────────────────────────────────
--  keymaps.lua  —  all custom bindings (see which-key for cheatsheet)
--  Leader = <Space>
-- ─────────────────────────────────────────────────────────────

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ── Better escape ────────────────────────────────────────────
map("i", "jk",  "<Esc>",        opts)
-- map("i", "jj",  "<Esc>",        opts)

-- ── Save / Quit ──────────────────────────────────────────────
map("n", "<leader>w",  "<cmd>w<cr>",   { desc = "Save" })
map("n", "<leader>q",  "<cmd>q<cr>",   { desc = "Quit" })
map("n", "<leader>Q",  "<cmd>qa!<cr>", { desc = "Force quit all" })

-- ── Clear search highlight ───────────────────────────────────
map("n", "<Esc>", "<cmd>noh<cr>", opts)

-- ── Better movement ──────────────────────────────────────────
map("n", "j",      "gj", opts)
map("n", "k",      "gk", opts)
map("n", "H",      "^",  opts)      -- start of line
map("n", "L",      "$",  opts)      -- end of line
map("v", "H",      "^",  opts)
map("v", "L",      "$",  opts)
map("n", "<C-d>",  "<C-d>zz", opts) -- keep cursor centred when jumping
map("n", "<C-u>",  "<C-u>zz", opts)
map("n", "n",      "nzzzv", opts)   -- keep cursor centred when searching
map("n", "N",      "Nzzzv", opts)

-- ── Splits ───────────────────────────────────────────────────
-- (C-h/j/k/l is handled by vim-tmux-navigator)
map("n", "<leader>sv", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>sh", "<cmd>split<cr>",  { desc = "Horizontal split" })
map("n", "<leader>se", "<C-w>=",          { desc = "Equalise splits" })
map("n", "<leader>sx", "<cmd>close<cr>",  { desc = "Close split" })
-- Resize with arrows
map("n", "<C-Up>",    "<cmd>resize +2<cr>",          opts)
map("n", "<C-Down>",  "<cmd>resize -2<cr>",          opts)
map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>", opts)
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", opts)

-- ── Tabs ─────────────────────────────────────────────────────
map("n", "<leader><tab>n", "<cmd>tabnew<cr>",  { desc = "New tab" })
map("n", "<leader><tab>x", "<cmd>tabclose<cr>",{ desc = "Close tab" })
map("n", "<Tab>",     "<cmd>bnext<cr>",     opts)
map("n", "<S-Tab>",   "<cmd>bprevious<cr>", opts)
map("n", "<leader>bd","<cmd>bdelete<cr>",   { desc = "Delete buffer" })

-- ── Move lines up/down ───────────────────────────────────────
map("n", "<A-j>", "<cmd>m .+1<cr>==", opts)
map("n", "<A-k>", "<cmd>m .-2<cr>==", opts)
map("v", "<A-j>", ":m '>+1<cr>gv=gv", opts)
map("v", "<A-k>", ":m '<-2<cr>gv=gv", opts)

-- ── Better indenting (stay in visual mode) ───────────────────
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)

-- ── Copy / paste tweaks ──────────────────────────────────────
map("x", "<leader>p",  '"_dP',         { desc = "Paste without yanking" })
map("n", "<leader>y",  '"+y',          { desc = "Yank to clipboard" })
map("v", "<leader>y",  '"+y',          { desc = "Yank to clipboard" })
map("n", "<leader>Y",  '"+Y',          { desc = "Yank line to clipboard" })
map("n", "<leader>d",  '"_d',          { desc = "Delete (void reg)" })
map("v", "<leader>d",  '"_d',          { desc = "Delete (void reg)" })

-- ── Search & replace word under cursor ───────────────────────
map("n", "<leader>rw", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
  { desc = "Replace word under cursor" })

-- ── Make file executable ─────────────────────────────────────
map("n", "<leader>fx", "<cmd>!chmod +x %<cr>", { desc = "chmod +x current file" })

-- ── Quickfix ─────────────────────────────────────────────────
map("n", "<leader>cn", "<cmd>cnext<cr>",     { desc = "Next quickfix" })
map("n", "<leader>cp", "<cmd>cprev<cr>",     { desc = "Prev quickfix" })
map("n", "<leader>co", "<cmd>copen<cr>",     { desc = "Open quickfix" })
map("n", "<leader>cc", "<cmd>cclose<cr>",    { desc = "Close quickfix" })

-- ── Diagnostics (set in lsp.lua too but available globally) ──
map("n", "[d", vim.diagnostic.goto_prev,     { desc = "Prev diagnostic" })
map("n", "]d", vim.diagnostic.goto_next,     { desc = "Next diagnostic" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic" })

-- ── Dashboard ────────────────────────────────────────────────
map("n", "<leader>ud", "<cmd>Alpha<cr>", { desc = "Dashboard (alpha)" })

-- NOTE: Telescope, harpoon, aerial, terminal keymaps are set
-- inside their respective plugin specs for better lazy-loading.
