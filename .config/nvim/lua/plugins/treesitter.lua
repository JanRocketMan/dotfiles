return {
  -- Highlight, edit, and navigate code
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {"bash", "c", "python", "markdown"},
      auto_install = false,  -- never auto-install on file open
      sync_install = true,   -- atomic installs to avoid half state
      highlight = {
        enable = true,
        -- Fix indentation issues
        additional_vim_regex_highlighting = true,
      },
    },

    config = function(_, opts)
      local parser_dir = vim.fn.stdpath("data") .. "/ts-parsers"
      vim.fn.mkdir(parser_dir, "p")
      -- Make Neovim see parsers from that folder
      vim.opt.runtimepath:append(parser_dir)

      -- Make installs predictable & less flaky
      local install = require("nvim-treesitter.install")
      install.prefer_git = false                    -- use released tarballs instead of git clones
      install.compilers = { "cc", "clang", "gcc" }  -- pick whatever exists on your box

      -- Tell Treesitter to put compiled .so files in parser_dir
      opts.parser_install_dir = parser_dir

      require("nvim-treesitter.configs").setup(opts)
    end,
  },
  -- Rainbow parentheses for convenicency
  {
    'HiPhish/rainbow-delimiters.nvim',
    -- Remove weird error when lazy installs it, see https://github.com/HiPhish/rainbow-delimiters.nvim/issues/169
    submodules = false,
  },
  -- Add motions to jump to current function definition
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    config = function()
      require'nvim-treesitter.configs'.setup{
        textobjects = {
          swap = {
            enable = true,
            swap_next = {
              ["<leader>S<right>"] = "@parameter.inner",
            },
            swap_previous = {
             ["<leader>S<left>"] = "@parameter.inner",
            },
          },
        },
      }
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
