-- This checks if Neovim was started with "-c DiffBanditGit" in which case we
-- generally want to quit neovim when exiting the diff view.
local function opened_on_boot()
  for i = 1, #vim.v.argv do
    if vim.v.argv[i] == "-c" and vim.v.argv[i + 1] and vim.v.argv[i + 1]:match("^DiffBandit") then
      return true
    end
  end
  return false
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
    "CoreyKaylor/diffbandit.nvim",
    -- DiffBandit commands map onto the old diffview muscle memory:
    --   <leader>g  DiffviewOpen          -> DiffBanditGit
    --   <leader>G  DiffviewOpen main     -> DiffBanditGit --base main
    keys = {
      { "<leader>g", "<cmd>DiffBanditGit<cr>", desc = "Diff view" },
      { "<leader>G", "<cmd>DiffBanditGit --base main<cr>", desc = "Diff view against main" },
    },
    cmd = {
      "DiffBandit",
      "DiffBanditBuffers",
      "DiffBanditGit",
      "DiffBanditGitCurrent",
      "DiffBanditCommitPanel",
      "DiffBanditGitMenu",
      "DiffBanditGitLog",
      "DiffBanditGitCommit",
      "DiffBanditGitCompare",
      "DiffBanditGitCheckout",
      "DiffBanditMerge",
      "DiffBanditFolderDiff",
    },
    config = function()
      local diffbandit = require("diffbandit")

      local augroup = vim.api.nvim_create_augroup("DiffBanditKeymaps", { clear = true })

      -- Tabpages opened by <leader>o (tab -> buffer shown there).
      local preview_tabs = {}

      local function map_is(buf, lhs, cb)
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
          if m.lhs == lhs then
            return m.callback == cb or m.rhs == cb
          end
        end
        return false
      end

      -- q closes the preview tab. On the diff session's own buffer the
      -- plugin keeps its q (which tabcloses the session tab for git diffs),
      -- so this callback never runs there.
      local function close_preview_tab()
        vim.cmd("tabclose")
      end

      -- diffview's <leader>o: open the file under the diff in a new tab and
      -- make q close that tab again.
      local function open_file_in_tab()
        if not diffbandit.is_running() then
          return
        end
        local tab = vim.api.nvim_get_current_tabpage()
        if preview_tabs[tab] then
          return
        end
        local name = vim.api.nvim_buf_get_name(0)
        if name == "" then
          return
        end
        local pos = vim.api.nvim_win_get_cursor(0)
        vim.cmd.tabedit(vim.fn.fnameescape(name))
        vim.api.nvim_win_set_cursor(0, pos)
        preview_tabs[vim.api.nvim_get_current_tabpage()] = vim.api.nvim_get_current_buf()
        vim.keymap.set("n", "q", close_preview_tab, { buffer = 0, nowait = true, silent = true, desc = "Close preview tab" })
      end

      vim.api.nvim_create_autocmd("BufEnter", {
        group = augroup,
        callback = function(args)
          local buf = args.buf
          local tab = vim.api.nvim_get_current_tabpage()

          if preview_tabs[tab] == buf then
            -- The plugin schedules a reassert of its own mappings on its
            -- buffers; rebind q afterwards so it keeps closing the preview.
            vim.defer_fn(function()
              if preview_tabs[vim.api.nvim_get_current_tabpage()] == buf and vim.api.nvim_buf_is_valid(buf) then
                vim.keymap.set("n", "q", close_preview_tab, { buffer = buf, nowait = true, silent = true, desc = "Close preview tab" })
              end
            end, 1)
            return
          end

          -- Buffer is no longer part of a diff session: drop our maps so
          -- they cannot leak into normal editing.
          if not diffbandit.is_running({ buf = buf }) then
            if map_is(buf, "q", close_preview_tab) then
              vim.keymap.del("n", "q", { buffer = buf })
            end
            if map_is(buf, "<leader>o", open_file_in_tab) then
              vim.keymap.del("n", "<leader>o", { buffer = buf })
            end
            return
          end

          -- Only the editable target side (a real file buffer) gets the
          -- diffview-style <leader>o; the read-only source panes skip it.
          if vim.api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then
            return
          end
          vim.keymap.set("n", "<leader>o", open_file_in_tab, { buffer = buf, nowait = true, desc = "Open current file in a new tab" })
        end,
      })

      vim.api.nvim_create_autocmd("TabClosed", {
        group = augroup,
        callback = function()
          for tab in pairs(preview_tabs) do
            if not vim.api.nvim_tabpage_is_valid(tab) then
              preview_tabs[tab] = nil
            end
          end
          -- Quit when the boot "-c DiffBanditGit" session was closed; the
          -- old diffview config did the same (qa) in that case.
          if opened_on_boot() and #vim.api.nvim_list_tabpages() == 1 and not diffbandit.has_any_session() then
            vim.cmd("qa")
          end
        end,
      })

      -- Cycle the changed-file queue: <C-Up>/<C-Down> (and the panel's
      -- file keys) wrap around the first/last file instead of stopping.
      -- All queue navigation funnels through these two methods.
      local function wrap_queue_index(host, index)
        local entries = host.file_queue and host.file_queue.entries
        if not entries or #entries == 0 then
          return index
        end
        if index > #entries or index < 1 then
          return ((index - 1) % #entries) + 1
        end
        return index
      end

      local Session = require("diffbandit.session")
      local session_goto_queue_file = Session.goto_queue_file
      function Session:goto_queue_file(index, chunk_position, opts)
        return session_goto_queue_file(self, wrap_queue_index(self, index), chunk_position, opts)
      end

      local Merge = require("diffbandit.merge")
      local merge_goto_queue_file = Merge.goto_queue_file
      function Merge:goto_queue_file(index, chunk_position, opts)
        return merge_goto_queue_file(self, wrap_queue_index(self, index), chunk_position, opts)
      end

      diffbandit.setup({
        git = {
          -- diffview keys: <C-Up>/<C-Down> moved between changed files.
          -- The plugin's ]c/[c hunk keys also cross file boundaries with a
          -- confirmation, and q always closes the view.
          file_keys = {
            next = "<C-Down>",
            prev = "<C-Up>",
          },
          -- The commit panel already uses diffview's <cr> to focus the
          -- selected entry and q to close; j/k move the selection.
        },
      })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et