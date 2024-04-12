local M = {}

M.general = {
  n = {
    ["<leader>ht"] = {
      function()
        require("lsp-inlayhints").toggle()
      end,
      "Toggle LSP Inlay Hints",
    },
    ["<leader>hr"] = {
      function()
        require("lsp-inlayhints").reset()
      end,
      "Reset LSP Inlay Hints",
    },
    ["<leader><C-n>"] = {
      "<cmd>tabnew<CR>",
      "New Tab",
    },
    ["<leader><C-h>"] = {
      "<cmd>tabnext<CR>",
      "Next Tab",
    },
    ["<leader><C-l>"] = {
      "<cmd>tabprevious<CR>",
      "Previous Tab",
    },
    ["<leader><C-x>"] = {
      "<cmd>tabclose<CR>",
      "close Tab",
    },
    ["<S-l>"] = {
      "<cmd>bnext<CR>",
      "Next Buffer",
    },
    ["<S-h>"] = {
      "<cmd>bprevious<CR>",
      "Prev Buffer",
    },
  },
  --{
  --["<leader>gg"] = {
  --   "<cmd> :LazyGit<CR>",
  --},
  --},
}

-- DEBUGGER
M.dap = {
  plugin = true,
  n = {
    ["<leader>db"] = { "<cmd> DapToggleBreakpoint <CR>" },
    ["<leader>dus"] = {
      function()
        local widgets = require "dap.ui.widgets"
        local sidebar = widgets.sidebar(widgets.scopes)
        sidebar.open()
      end,
      "Open debugging sidebar",
    },
    ["<leader>dt"] = {
      "<cmd> lua require('dapui').toggle()<CR>",
      "Toggle Break Point",
    },
    ["<leader>dc"] = {
      "<cmd> DapContinue<CR>",
      "Start Or Continue Debugger",
    },
    ["<leader>dr"] = {
      "<cmd> lua require('dapui').open({reset=true})<CR>",
      "Reset Debugger UI",
    },
    ["<leader>di"] = {
      "<cmd> DapStepInto<CR>",
      "Step Into",
    },
    ["<leader>do"] = {
      "<cmd> DapStepOver<CR>",
      "Step Over",
    },
    ["<leader>dO"] = {
      "<cmd> DapStepOut<CR>",
      "Step Out",
    },
    ["<leader>de"] = {
      "<cmd> DapTerminate<CR>",
      "Terminate DAP",
    },
  },
}

M.crates = {
  plugin = true,
  n = {
    ["<leader>rcu"] = {
      function()
        require("crates").upgrade_all_crates()
      end,
      "update crates",
    },
  },
}

M.dap_go = {
  plugin = true,
  n = {
    ["<leader>dgt"] = {
      function()
        require("dap-go").debug_test()
      end,
      "Debug go test",
    },
    ["<leader>dgl"] = {
      function()
        require("dap-go").debug_last()
      end,
      "Debug last go test",
    },
  },
}

M.gopher = {
  plugin = true,
  n = {
    ["<leader>gsj"] = {
      "<cmd> GoTagAdd json <CR>",
      "Add json struct tags",
    },
    ["<leader>gsy"] = {
      "<cmd> GoTagAdd yaml <CR>",
      "Add yaml struct tags",
    },
  },
}

return M
