-- ╔══════════════════════════════════════════════════════════════╗
-- ║  necronom :: nvim  —  bug bounty + source analysis config   ║
-- ║  lazy.nvim · treesitter · telescope/rg · aerial · harpoon  ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load core config first (options sets leader before plugins load)
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Load all plugins from lua/plugins/
require("lazy").setup("plugins", {
  change_detection = { notify = false },
  ui = { border = "rounded" },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "matchit", "matchparen", "netrwPlugin",
        "tarPlugin", "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})
