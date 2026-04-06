-- This checks if Neovim was started with "-c DiffviewOpen" in which case we
-- generally want to quit neovim when exiting DiffView.
local function opened_on_boot()
  for i = 1, #vim.v.argv do
    if vim.v.argv[i] == "-c" and vim.v.argv[i + 1] and vim.v.argv[i + 1]:match("^Diffview") then
      return true
    end
  end
  return false
end

local function close_diffview()
  if opened_on_boot() then
    vim.cmd("qa")
    return
  end

  vim.cmd.DiffviewClose()
end

return {
  {
    'Spiegie/jj-conflict-highlight.nvim',
    version = "*",
    config = function()
        require("jj_conflict_highlight").setup({})
    end,
  },
  {
    "sindrets/diffview.nvim",
     keys = {
      { "<leader>g", "<cmd>DiffviewOpen<cr>", desc = "Diff view" },
    },
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    config = function()
      local actions = require("diffview.actions")
      require("diffview").setup({
        enhanced_diff_hl = true,
        use_icons = false,

        keymaps = {
          view = {
            ["q"] = close_diffview,
            {
              "n",
              "<C-Down>",
              actions.select_next_entry,
              { desc = "Open the diff for the next file" },
            },
            {
              "n",
              "<C-Up>",
              actions.select_prev_entry,
              { desc = "Open the diff for the previous file" },
            },
            {
              "n",
              "<leader>o",
              function()
                local pos = vim.api.nvim_win_get_cursor(0)
                vim.cmd.tabedit(vim.api.nvim_buf_get_name(0))
                vim.api.nvim_win_set_cursor(0, pos)
                vim.keymap.set("n", "q", "<cmd>tabclose<cr>", { buffer = 0, desc = "Close preview tab" })
              end,
              { desc = "Open current file in a new tab" },
            },
          },
          file_panel = {
            ["q"] = close_diffview,
            {
              "n",
              "<Right>",
              actions.select_entry,
              { desc = "Open the diff for the selected entry" },
            },
            {
              "n",
              "<cr>",
              actions.focus_entry,
              { desc = "Focus the diff entry" },
            },
          },
          file_history_panel = {
            ["q"] = close_diffview,

            {
              "n",
              "<Left>",
              actions.select_entry,
              { desc = "Open the diff for the selected entry" },
            },
            {
              "n",
              "<Right>",
              actions.select_entry,
              { desc = "Open the diff for the selected entry" },
            },
            {
              "n",
              "<cr>",
              actions.focus_entry,
              { desc = "Focus the diff entry" },
            },
          },
        }
      })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
