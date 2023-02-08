return {
  "nvim-telescope/telescope.nvim",
  keys = {
    -- disable the keymap to grep files
    {"<leader>/", false},
    -- change a keymap
    { "<leader>ff", "Telescope find_files", desc = "Find Files" },
    -- add a keymap to browse plugin files
    
  },
}
