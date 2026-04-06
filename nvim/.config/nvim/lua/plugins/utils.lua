return {
  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',
  -- Revert changes even without git
  {
    "jiaoshijie/undotree",
    dependencies = "nvim-lua/plenary.nvim",
    config = true,
    keys = {
      { "<leader>u", "<cmd>lua require('undotree').toggle()<cr>" },
    },
  },
  -- Navigate between class methods more conveniently
  {
  "bassamsdata/namu.nvim",
    config = function()
      require("namu").setup({
        namu_symbols = {enable = true },
        ui_select = { enable = false },
        colorscheme = { enable = false },
      })
    end,
  },
  -- File explorer
  {"vifm/vifm.vim"},
}
