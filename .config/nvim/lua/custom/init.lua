vim.g.dap_virtual_text = true
vim.opt.colorcolumn = "80"
vim.opt.relativenumber = true  -- Relative line numbers
vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true


vim.api.nvim_set_hl(0, "LspInlayHint", { fg = "#cba6f7", bg = "#181825" })

-- Auto
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight_yank', {}),
  desc = 'Hightlight selection on yank',
  pattern = '*',
  callback = function()
    vim.highlight.on_yank { higroup = 'IncSearch', timeout = 100 }
  end,
})


