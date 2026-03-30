-- ─────────────────────────────────────────────────────────────
--  options.lua  —  sane defaults, security-researcher flavour
-- ─────────────────────────────────────────────────────────────

vim.g.mapleader      = " "
vim.g.maplocalleader = " "

local opt = vim.opt

-- ── Appearance ───────────────────────────────────────────────
opt.termguicolors  = true
opt.number         = true
opt.relativenumber = true
opt.cursorline     = true
opt.signcolumn     = "yes"         -- always show; prevents layout jumps
opt.scrolloff      = 8
opt.sidescrolloff  = 8
opt.wrap           = false
opt.showmode       = false         -- lualine shows mode
opt.laststatus     = 3            -- global statusline
opt.cmdheight      = 1
opt.winbar         = ""            -- disable winbar to prevent black top line
opt.list           = true
opt.listchars      = { tab = "→ ", trail = "·", nbsp = "␣" }
opt.fillchars      = {
  eob    = " ",
  fold   = " ",
  foldopen  = "▾",
  foldclose = "▸",
  foldsep   = " ",
}

-- ── Editing ──────────────────────────────────────────────────
opt.expandtab   = true
opt.shiftwidth  = 4
opt.tabstop     = 4
opt.softtabstop = 4
opt.smartindent = true
opt.autoindent  = true

-- ── Search ───────────────────────────────────────────────────
opt.ignorecase = true
opt.smartcase  = true
opt.hlsearch   = true
opt.incsearch  = true

-- ── Splits ───────────────────────────────────────────────────
opt.splitright = true
opt.splitbelow = true

-- ── Files / undo ─────────────────────────────────────────────
opt.undofile   = true
opt.swapfile   = false
opt.backup     = false
opt.updatetime = 200              -- fast CursorHold for LSP

-- ── Completion ───────────────────────────────────────────────
opt.completeopt = { "menu", "menuone", "noselect" }
opt.pumheight   = 12

-- ── Clipboard ────────────────────────────────────────────────
opt.clipboard = "unnamedplus"     -- system clipboard

-- ── Folds (treesitter-based) ─────────────────────────────────
opt.foldmethod     = "expr"
opt.foldexpr       = "nvim_treesitter#foldexpr()"
opt.foldlevel      = 99           -- start fully open
opt.foldlevelstart = 99

-- ── Misc ─────────────────────────────────────────────────────
opt.mouse         = "a"
opt.timeoutlen    = 300
opt.confirm       = true          -- ask instead of error on unsaved quit
opt.virtualedit   = "block"       -- free-range visual block
opt.inccommand    = "nosplit"     -- live :%s preview
opt.iskeyword:append("-")         -- treat dash-words as one word
opt.shortmess:append("c")        -- no "match 1 of N" noise
