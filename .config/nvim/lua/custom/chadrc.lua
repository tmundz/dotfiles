---@type ChadrcConfig 
local M = {}
M.ui = {theme = 'catppuccin'}
M.plugins = "custom.plugins"
vim.api.nvim_create_autocmd("Colorscheme", {
    pattern = "*",
    callback = function()
        vim.api.nvim_set_hl(0, "LspInlayHint", { bg = "#1e1e2e" })
    end,
})

M.mappings = require "custom.mappings"
return M
