local M = {}

M.treesitter = {
  ensure_installed = {
    "vim",
    "lua",
    "tsx",
    "markdown",
    "rust",
    "go",
    "c",
    "cpp",
    "bash",
    "css",
    "html",
    "java",
    "javascript",
    "python",
    "typescript",
    "yaml",
    "json",
    -- "asm",
    "sql",
    "dockerfile",
    "c_sharp",
    "markdown_inline",
  },
  
  indent = {
    enable = true,
    -- disable = {
    --   "python"
    -- },
  },
}

--M.mason = {
--  ensure_installed = {
    -- lua stuff
--    "lua-language-server",
--    "stylua",

    -- web dev stuff
--    "css-lsp",
--    "html-lsp",
--    "typescript-language-server",
--    "deno",
--    "prettier",

    -- c/cpp stuff
    --"clangd",
    --"clang-format",

    -- shell stuff
    --"shfmt",
  --},
--}

-- git support in nvimtree
--M.nvimtree = {
--  git = {
--    enable = true,
--  },

--  renderer = {
--    highlight_git = true,
--    icons = {
--      show = {
--        git = true,
--      },
--    },
--  },
--}

return M
