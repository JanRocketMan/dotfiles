-- [[ Configure and install plugins ]]
require('lazy').setup({
  -- set default colorscheme
  require 'plugins/utils',
  require 'plugins/treesitter',
  require 'plugins/autocompletion',
  require 'plugins/lsp',
  require 'plugins/linting_formatting',
  require 'plugins/git',
  require 'plugins/debug',
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
  -- Disable luarocks support to keep installation minimal
  rocks = {
    enabled = false,
  },
})

-- vim: ts=2 sts=2 sw=2 et
