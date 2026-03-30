-- ─────────────────────────────────────────────────────────────
--  autocmds.lua
-- ─────────────────────────────────────────────────────────────

local augroup = vim.api.nvim_create_augroup
local au      = vim.api.nvim_create_autocmd

-- ── Highlight on yank ────────────────────────────────────────
augroup("YankHighlight", { clear = true })
au("TextYankPost", {
  group    = "YankHighlight",
  callback = function() vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 }) end,
})

-- ── Restore cursor position ──────────────────────────────────
augroup("RestoreCursor", { clear = true })
au("BufReadPost", {
  group    = "RestoreCursor",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- ── Auto-resize splits on window resize ──────────────────────
augroup("AutoResize", { clear = true })
au("VimResized", {
  group    = "AutoResize",
  callback = function() vim.cmd("tabdo wincmd =") end,
})

-- ── Remove trailing whitespace on save ───────────────────────
augroup("TrailingWhitespace", { clear = true })
au("BufWritePre", {
  group   = "TrailingWhitespace",
  pattern = "*",
  command = [[%s/\s\+$//e]],
})

-- ── Language-specific indent settings ────────────────────────
augroup("LangIndent", { clear = true })
au("FileType", {
  group   = "LangIndent",
  pattern = { "javascript", "typescript", "html", "css", "json", "yaml", "lua" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop    = 2
  end,
})
au("FileType", {
  group   = "LangIndent",
  pattern = { "go" },
  callback = function()
    vim.opt_local.expandtab = false  -- Go uses real tabs
    vim.opt_local.tabstop   = 4
  end,
})

-- ── Close certain filetypes with q ───────────────────────────
augroup("QuickClose", { clear = true })
au("FileType", {
  group   = "QuickClose",
  pattern = { "qf", "help", "man", "notify", "lspinfo", "checkhealth" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- ── Zig / C / C++ — associate .h with c ──────────────────────
augroup("FileTypes", { clear = true })
au({ "BufRead", "BufNewFile" }, {
  group   = "FileTypes",
  pattern = "*.h",
  callback = function() vim.bo.filetype = "c" end,
})
au({ "BufRead", "BufNewFile" }, {
  group   = "FileTypes",
  pattern = "*.zig",
  callback = function() vim.bo.filetype = "zig" end,
})
