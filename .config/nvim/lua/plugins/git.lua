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

      local state = require("diffbandit.state")

      -- Two-way diff sessions only: the merge and folder hosts use other
      -- window fields, so this check keeps their per-pane scrolling intact.
      local function diff_session_for_buf(buf, tab)
        local session = state.sessions[tab or vim.api.nvim_get_current_tabpage()]
        if not session or session.disposed or not (session.left_num_win and session.connector_win) then
          return nil
        end
        if buf ~= session.left_buf and buf ~= session.right_buf then
          return nil
        end
        return session
      end

      -- Shift a window's viewport by `delta` lines while keeping its cursor
      -- on the same screen row (the native scroll rule). The cursor never
      -- lands outside the new viewport, so 'scrolloff' has nothing to
      -- re-adjust when that pane is focused later.
      local function shift_viewport(win, delta)
        if delta == 0 or not (win and vim.api.nvim_win_is_valid(win)) then
          return
        end
        vim.api.nvim_win_call(win, function()
          local buf = vim.api.nvim_win_get_buf(win)
          local height = vim.api.nvim_win_get_height(win)
          local line_count = math.max(1, vim.api.nvim_buf_line_count(buf))
          local view = vim.fn.winsaveview()
          local max_topline = math.max(1, line_count - height + 1)
          local new_topline = math.max(1, math.min(max_topline, view.topline + delta))
          if new_topline == view.topline then
            return
          end
          view.lnum = math.max(1, math.min(line_count, new_topline + (view.lnum - view.topline)))
          view.topline = new_topline
          vim.fn.winrestview(view)
        end)
      end

      -- PageDown/PageUp scroll the focused content pane by half a window
      -- (the same amount as the global <PageDown> -> <C-d>zz mapping) and
      -- shift the twin pane by exactly the same number of lines, each pane
      -- clamped to its own buffer ends. <C-d>/<C-u> stay native, so they
      -- still jump only the pane they are pressed in.
      local function scroll_both_panes(dir)
        local session = diff_session_for_buf(vim.api.nvim_get_current_buf())
        if not session then
          return
        end
        local win = vim.api.nvim_get_current_win()
        local other_win
        if win == session.left_win then
          other_win = session.right_win
        elseif win == session.right_win then
          other_win = session.left_win
        end
        if not other_win then
          return
        end

        local count = math.max(1, math.floor(vim.api.nvim_win_get_height(win) / 2))
        local buf = vim.api.nvim_win_get_buf(win)
        local height = vim.api.nvim_win_get_height(win)
        local line_count = math.max(1, vim.api.nvim_buf_line_count(buf))
        local delta = 0
        vim.api.nvim_win_call(win, function()
          local view = vim.fn.winsaveview()
          local max_topline = math.max(1, line_count - height + 1)
          -- Clamp like Vim does at buffer ends; a pane that cannot move
          -- further leaves its twin in place too.
          local new_topline
          if dir > 0 then
            new_topline = math.min(max_topline, view.topline + count)
          else
            new_topline = math.max(1, view.topline - count)
          end
          if new_topline == view.topline then
            return
          end
          local old_topline = view.topline
          view.lnum = math.max(1, math.min(line_count, new_topline + (view.lnum - old_topline)))
          view.topline = new_topline
          vim.fn.winrestview(view)
          delta = new_topline - old_topline
        end)
        shift_viewport(other_win, delta)
      end

      local function scroll_down()
        scroll_both_panes(1)
      end

      local function scroll_up()
        scroll_both_panes(-1)
      end

      -- Install the twin-scroll maps when `buf` is a content pane of a
      -- two-way diff session. Returns false when the session is not
      -- registered yet (see the deferred retry in the enter handler).
      local function install_page_maps(buf, tab)
        if not diff_session_for_buf(buf, tab) then
          return false
        end
        vim.keymap.set("n", "<PageDown>", scroll_down, { buffer = buf, nowait = true, silent = true, desc = "Scroll both diff panes down" })
        vim.keymap.set("n", "<PageUp>", scroll_up, { buffer = buf, nowait = true, silent = true, desc = "Scroll both diff panes up" })
        return true
      end

      local function remove_map_if_ours(buf, lhs, cb)
        if map_is(buf, lhs, cb) then
          vim.keymap.del("n", lhs, { buffer = buf })
        end
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

      vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
        group = augroup,
        callback = function(args)
          local buf = args.buf
          -- The diff tab can close while this callback is queued; the
          -- session-close wipe then fires WinEnter for a dead buffer.
          if not vim.api.nvim_buf_is_valid(buf) then
            return
          end
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
            remove_map_if_ours(buf, "q", close_preview_tab)
            remove_map_if_ours(buf, "<leader>o", open_file_in_tab)
            remove_map_if_ours(buf, "<PageDown>", scroll_down)
            remove_map_if_ours(buf, "<PageUp>", scroll_up)
          end

          -- PageDown/PageUp on either content pane scroll both panes; the
          -- plugin rerenders the connector gutters via its WinScrolled hook.
          -- The first BufEnter runs before the session is registered in
          -- state (register() follows Session.start), so a failed install
          -- is retried once the layout has finished opening.
          if not install_page_maps(buf, tab) then
            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(buf) then
                install_page_maps(buf, tab)
              end
            end, 50)
          end

          if not diffbandit.is_running({ buf = buf }) then
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