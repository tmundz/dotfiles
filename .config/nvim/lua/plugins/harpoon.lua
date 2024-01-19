return {
    "ThePrimeagen/harpoon",
    enabled = true,

    -- ----------------------------------------------------------------------- }}}
    -- {{{ Define events to load Harpoon.

    keys = function()
        local mark = require("harpoon" .. ".mark")
        local ui = require("harpoon" .. ".ui")
        return {
            vim.keymap.set("n", "<leader>a", mark.add_file),
            vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu),

            vim.keymap.set("n", "<C-h>", function() ui.nav_file(1) end),
            vim.keymap.set("n", "<C-t>", function() ui.nav_file(2) end),
            vim.keymap.set("n", "<C-n>", function() ui.nav_file(3) end),
            vim.keymap.set("n", "<C-s>", function() ui.nav_file(4) end)
        }
    end,

    -- ----------------------------------------------------------------------- }}}
    -- {{{ Use Harpoon defaults or my customizations.

    opts = function(_, opts)
        opts.global_settings = {
            save_on_toggle = false,
            save_on_change = true,
            enter_on_sendcmd = false,
            tmux_autoclose_windows = false,
            excluded_filetypes = { "harpoon", "alpha", "dashboard", "gitcommit" },
            mark_branch = false,
        }
    end,

    -- {{{ Configure harpoon.

    config = function(_, opts)
        require("harpoon").setup(opts)
    end,

}
