local M = {}

M.tools = {
    "prettierd",
    "stylua",
    "selene",
    "luacheck",
    "eslint_d",
    "shellcheck",
    "shfmt",
    "black",
    "codelldb",
    "clang-format",
    "markdownlint",
    "flake8",
    "debugpy",
}

function M.check()
    local mr = require("mason-registry")
    for _, tool in ipairs(M.tools) do
        local p = mr.get_package(tool)
        if not p:is_installed() then
            p:install()
        end
    end
end

function M.config()
    local opts = {
        on_attach = require("plugins.lsp.handlers").on_attach,
        capabilities = require("plugins.lsp.handlers").capabilities,
    }

    require("mason").setup({
        ui = {
            border = "rounded",
        },
        log_level = vim.log.levels.INFO,
        max_concurrent_installers = 4,
    })

    require("mason-lspconfig").setup({
        ensure_installed = {
            "awk_ls",
            "bashls",
            "clangd",
            "html",
            "jsonls",
            "marksman",
            "gopls",
            "pyright",
            "rust_analyzer",
            "sumneko_lua",
            "tsserver",
            "yamlls",
        },
        automatic_installation = true,
    })

    require("mason-lspconfig").setup_handlers({
        -- The first entry (without a key) will be the default handler
        -- and will be called for each installed server that doesn't have
        -- a dedicated handler.
        function(server_name) -- default handler (optional)
            require("lspconfig")[server_name].setup(opts)
        end,

        ["rust_analyzer"] = function()
            local rust_opts = require("plugins.lsp.settings.rust")
            require("rust-tools").setup(rust_opts)
        end,

        ["clangd"] = function()
            local clangd_opts = require("plugins.lsp.settings.clangd")
            local clangd_opts_ext = vim.tbl_deep_extend("force", clangd_opts, opts)
            require("lspconfig").clangd.setup(clangd_opts_ext)
        end,

        ["jsonls"] = function()
            local jsonls_opts = require("plugins.lsp.settings.jsonls")
            local jsonls_opts_ext = vim.tbl_deep_extend("force", jsonls_opts, opts)
            require("lspconfig").jsonls.setup(jsonls_opts_ext)
        end,

        ["sumneko_lua"] = function()
            local sumneko_lua_opts = require("plugins.lsp.settings.sumneko_lua")
            local sumneko_lua_opts_ext = vim.tbl_deep_extend("force", sumneko_lua_opts, opts)
            require("lspconfig").sumneko_lua.setup(sumneko_lua_opts_ext)
        end,

        ["bashls"] = function()
            local bash_opts = require("plugins.lsp.settings.bash")
            local bash_opts_ext = vim.tbl_deep_extend("force", bash_opts, opts)
            require("lspconfig").bashls.setup(bash_opts_ext)
        end,


        ["pyright"] = function()
            local pyright_opts = require("plugins.lsp.settings.pyright")
            local pyright_opts_ext = vim.tbl_deep_extend("force", pyright_opts, opts)
            require("lspconfig").pyright.setup(pyright_opts_ext)
        end,
    })
end
return M
