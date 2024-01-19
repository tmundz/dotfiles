return {
  {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = true,
    cmd = 'ToggleTerm',
    keys = {
      {'n', '<leader>td', '<cmd>ToggleTerm<cr>', desc = 'toggle floating terminal'}
    },
    opts = {
      open_mapping = [[<leader>td]],
      direction = 'float',
      shade_filetypes = {},
      hide_numbers = true,
      insert_mappings = true,
      terminal_mappings = true,
      start_in_insert = true,
      close_on_exit = true,
    },
  },
}
