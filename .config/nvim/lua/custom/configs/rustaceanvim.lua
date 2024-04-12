local on_attach = require("plugins.configs.lspconfig").on_attach
local capabilities = require("plugins.configs.lspconfig").capabilities

vim.g.rustaceanvim = {
  server = {
    capabilities = capabilities,
    on_attach = function(client, bufnr)
      require("lsp-inlayhints").on_attach(client, bufnr)
      on_attach(client, bufnr)
    end,
  },
  inlay_hints = {
    highlight = "NonText",
    auto = false,
  },
}
