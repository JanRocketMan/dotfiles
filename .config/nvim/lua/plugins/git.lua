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

      -- ; repeats the last ]c/[c change motion like f's ; repeats the last
      -- char search (same direction). With no earlier ]c/[c it acts as ]c.
      -- The Session wraps below record which motion ran last.
      local last_chunk_motion
      local function repeat_chunk_motion()
        local session = state.sessions[vim.api.nvim_get_current_tabpage()]
        if not session or session.disposed then
          return
        end
        if last_chunk_motion == "prev" then
          session:goto_prev_chunk()
        else
          session:goto_next_chunk()
        end
      end

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

      -- <Tab> toggles the file panel: the panel of the active diff session,
      -- or a standalone commit panel for the tab when no diff is open.
      local function toggle_file_panel()
        local tab = vim.api.nvim_get_current_tabpage()
        local session = state.sessions[tab]
        if session and not session.disposed and type(session.toggle_commit_panel) == "function" then
          session:toggle_commit_panel()
          return
        end
        local panel = state.panels[tab]
        if panel and not panel.disposed and type(panel.toggle_commit_panel) == "function" then
          panel:toggle_commit_panel()
        end
      end

      -- <Tab> toggles the panel from every buffer the session owns: the
      -- content panes and the panel list itself.
      local function install_panel_toggle_map(buf)
        if vim.api.nvim_buf_is_valid(buf) and diffbandit.is_running({ buf = buf }) then
          vim.keymap.set("n", "<Tab>", toggle_file_panel, { buffer = buf, nowait = true, silent = true, desc = "Toggle file panel" })
        end
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
            remove_map_if_ours(buf, "<Tab>", toggle_file_panel)
            remove_map_if_ours(buf, "<PageDown>", scroll_down)
            remove_map_if_ours(buf, "<PageUp>", scroll_up)
            remove_map_if_ours(buf, ";", repeat_chunk_motion)
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
                install_panel_toggle_map(buf)
              end
            end, 50)
          end
          install_panel_toggle_map(buf)

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

      -- ]c/[c at a file boundary jump straight into the prev/next changed
      -- file; the plugin wants a confirming second press first and only
      -- warns. At the queue ends (nothing to jump to) the plugin behavior
      -- stands.
      local session_confirm_file_boundary = Session.confirm_file_boundary
      function Session:confirm_file_boundary(direction)
        local queue = self.file_queue
        local target = (self.file_queue_index or 1) + (direction == "next" and 1 or -1)
        if queue and (queue.entries or {})[target] then
          self:goto_queue_file(target, "top")
          return true
        end
        return session_confirm_file_boundary(self, direction)
      end

      -- Record which change motion ran last so ; can repeat it.
      local session_goto_next_chunk = Session.goto_next_chunk
      function Session:goto_next_chunk()
        last_chunk_motion = "next"
        return session_goto_next_chunk(self)
      end
      local session_goto_prev_chunk = Session.goto_prev_chunk
      function Session:goto_prev_chunk()
        last_chunk_motion = "prev"
        return session_goto_prev_chunk(self)
      end

      -- ; goes on the content panes next to the plugin's ]c/[c maps.
      local session_setup_keymaps = Session.setup_keymaps
      function Session:setup_keymaps()
        session_setup_keymaps(self)
        for _, buf in ipairs({ self.left_buf, self.right_buf }) do
          if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.keymap.set("n", ";", repeat_chunk_motion,
              { buffer = buf, nowait = true, silent = true, desc = "Repeat last change motion" })
          end
        end
      end

      local Merge = require("diffbandit.merge")
      local merge_goto_queue_file = Merge.goto_queue_file
      function Merge:goto_queue_file(index, chunk_position, opts)
        return merge_goto_queue_file(self, wrap_queue_index(self, index), chunk_position, opts)
      end

      -- ---- File panel ----------------------------------------------------
      -- The panel file list is a flat buffer built by panel/init.lua
      -- (build_rows): one section header per group, then a row per file with
      -- its parent directory dotted at the right. The wrappers below give it
      -- directory header rows, drop the status/stage signs, drive the file
      -- highlights, drop the commit-message window, open the panel with
      -- :DiffBanditGit, and keep the diff panes balanced when it toggles.
      local Panel = require("diffbandit.panel")
      local Config = require("diffbandit.config")
      local ui = require("diffbandit.util.ui")
      local nvim_util = require("diffbandit.util.nvim")
      local layout_util = require("diffbandit.util.layout")

      local function parent_dir(path)
        local dir = vim.fn.fnamemodify(path or "", ":h")
        return dir == "." and "" or dir
      end

      -- Same status letters the plugin's own row builder uses.
      local function entry_kind(entry)
        entry = entry or {}
        if entry.kind and entry.kind ~= "" then
          return entry.kind
        end
        if entry.untracked then
          return "untracked"
        end
        if entry.status == "A" then
          return "added"
        elseif entry.status == "D" then
          return "deleted"
        elseif entry.status == "R" then
          return "renamed"
        elseif entry.status == "C" then
          return "copied"
        elseif entry.status == "U" then
          return "unmerged"
        end
        return "modified"
      end

      local function file_highlight(entry)
        local kind = entry_kind(entry)
        if kind == "added" or kind == "untracked" then
          return "DiffBanditAdd"
        end
        if kind == "deleted" or kind == "unmerged" then
          return "DiffBanditDelete"
        end
        return nil
      end

      -- Rows show the file name only: no stage box, no status glyph, no
      -- dotted parent (the directory header above the file carries it).
      local panel_build_rows = Panel.build_rows
      Panel.build_rows = function(session)
        local width = math.max(20, tonumber(Config.section(session.config, "git", "panel").width) or 42)
        local rows = {}
        local last_parent
        for _, row in ipairs(panel_build_rows(session)) do
          if row.type == "section" then
            last_parent = nil
          elseif row.type == "file" then
            local parent = parent_dir(row.entry and row.entry.path)
            -- Root-level entries share the directory headers' level; a file
            -- under a header sits one level deeper than the header.
            local indent = parent ~= "" and 4 or 2
            if parent ~= "" and parent ~= last_parent then
              rows[#rows + 1] = {
                type = "dir",
                text = "  " .. ui.truncate_display(parent .. "/", width - 2),
                name_col = 2,
              }
            end
            local name = ui.truncate_display(vim.fn.fnamemodify((row.entry and row.entry.path) or "", ":t"), width - indent)
            row.text = string.rep(" ", indent) .. name
            row.name_col = indent
            row.name_end_col = indent + #name
            last_parent = parent
          end
          rows[#rows + 1] = row
        end
        return rows
      end

      -- The plugin's highlight pass runs inside the original render, so
      -- repaint the nav buffer afterwards: modified files stay plain,
      -- added/untracked stay green, deleted/unmerged stay red, and the diff
      -- that is open in the viewer gets the change (blue) highlight.
      local function repaint_nav(session)
        local panel = session.panel
        if not (panel and panel.nav_buf and vim.api.nvim_buf_is_valid(panel.nav_buf)) then
          return
        end
        vim.api.nvim_buf_clear_namespace(panel.nav_buf, session.ns, 0, -1)
        local current = session.file_queue_index or (session.file_queue or {}).index
        for line, row in ipairs(panel.rows or {}) do
          local group
          if row.type == "section" then
            group = "DiffBanditStatusAccent"
          elseif row.type == "dir" then
            group = "DiffBanditMutedText"
          elseif row.type == "file" then
            if current and row.index == current then
              group = "DiffBanditChangeLeft"
            else
              group = file_highlight(row.entry)
            end
          end
          if group then
            vim.api.nvim_buf_add_highlight(panel.nav_buf, session.ns, group, line - 1, row.name_col or 0, row.name_end_col or -1)
          end
        end
      end

      local panel_render_nav = Panel.render_nav
      Panel.render_nav = function(session, preferred_entry_index, opts)
        panel_render_nav(session, preferred_entry_index, opts)
        repaint_nav(session)
      end

      -- The panel is the file list only: open the nav window and skip the
      -- commit-message window the plugin pairs with it.
      local panel_open_windows = Panel.open_windows
      Panel.open_windows = function(host, anchor)
        local width = Config.section(host.config, "git", "panel").width or 42
        local nav_win = vim.api.nvim_open_win(host.panel.nav_buf, false, {
          split = "left",
          win = anchor,
          width = width,
        })
        host.panel.nav_win = nav_win
        host.panel.commit_win = nil
        host.panel.visible = true
        nvim_util.set_window_options(nav_win, layout_util.win_opts.panel())
        nvim_util.set_window_width(nav_win, width)
        return nav_win
      end

      -- The plugin's is_open also demands the commit window, which is gone.
      Panel.is_open = function(host)
        local panel = host and host.panel
        if not (panel and panel.visible and panel.nav_win and vim.api.nvim_win_is_valid(panel.nav_win)) then
          return false
        end
        return true
      end

      -- Closing the panel gives its columns back, which needs a resize; the
      -- plugin only does that in its own show/hide entry points.
      local panel_close = Panel.close
      Panel.close = function(session)
        panel_close(session)
        if session and not session.disposed and type(session.resize_layout) == "function" then
          session:resize_layout()
        end
      end

      -- q in the file panel closes the whole viewer (the session tab goes
      -- away, the TabClosed hook then quits neovim) instead of only hiding
      -- the panel. Boot sessions ("-c DiffBanditGit") get the quit; <leader>g
      -- keeps the plugin's hide-the-panel q so the editor stays open.
      local panel_setup_keymaps = Panel.setup_keymaps
      Panel.setup_keymaps = function(session)
        panel_setup_keymaps(session)
        local nav_buf = session.panel and session.panel.nav_buf
        if not (opened_on_boot() and nav_buf and vim.api.nvim_buf_is_valid(nav_buf)) then
          return
        end
        vim.keymap.set("n", "q", function()
          session:close()
        end, { buffer = nav_buf, nowait = true, silent = true, desc = "Close diff view" })
      end

      -- The plugin's resize math bails out in this layout (its window list
      -- starts with the nil overview entry and holds the closed number
      -- panes' stale handles), so split the content panes here: what is
      -- left of the fixed-width connector is shared evenly.
      local function balance_content_panes(session)
        local left, right = session.left_win, session.right_win
        if not (left and right and vim.api.nvim_win_is_valid(left) and vim.api.nvim_win_is_valid(right)) then
          return
        end
        local content = vim.api.nvim_win_get_width(left) + vim.api.nvim_win_get_width(right)
        if content < 4 then
          return
        end
        local left_width = math.floor(content / 2)
        nvim_util.set_window_width(left, left_width)
        nvim_util.set_window_width(right, content - left_width)
        -- The connector keeps its fixed width through the rebalance.
        nvim_util.set_window_width(session.connector_win, session.connector_core_width)
      end

      -- :DiffBanditGit and <leader>g open with the file panel, like the old
      -- diffview flow. git.panel.focus_on_open still picks the focus.
      local git_command = diffbandit.git
      function diffbandit.git(opts)
        local session, err = git_command(opts)
        if session and not session.disposed and type(session.show_commit_panel) == "function" then
          session:show_commit_panel()
          if Config.section(session.config, "git", "panel").focus_on_open ~= "panel" then
            Panel.focus_diff(session)
          end
        end
        return session, err
      end

      -- Minimal diff chrome: a git diff shows only the two content panes
      -- and the connector between them. The overview strips (the
      -- signcolumn-looking bars at the far edges) and the status/header
      -- row are plain config knobs below; the line-number panes are not
      -- configurable, so the session layout is wrapped instead.
      local session_layout = require("diffbandit.session.layout")

      -- Two-way diff sessions only; the merge host builds its own layout.
      local function is_two_way(session)
        return session ~= nil and session.left_num_win ~= nil and session.connector_win ~= nil
      end

      -- Close the number panes. First keep their buffers alive (the plugin
      -- sets bufhidden=wipe on them, and their wipeout auto-disposes the
      -- whole session); rendering keeps writing into the buffers, and the
      -- dispose wrapper below wipes them for real.
      local function remove_number_panes(session)
        if not is_two_way(session) then
          return
        end
        for _, field in ipairs({ "left_num_buf", "right_num_buf" }) do
          local buf = session[field]
          if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
          end
        end
        for _, field in ipairs({ "left_num_win", "right_num_win" }) do
          local win = session[field]
          if win and vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end
      end

      local session_layout_open = session_layout.open
      session_layout.open = function(session)
        session_layout_open(session)
        remove_number_panes(session)
        -- Hand the closed panes' columns to the content panes.
        session:resize_layout()
      end

      local session_layout_resize = session_layout.resize
      session_layout.resize = function(session)
        if not is_two_way(session) then
          return session_layout_resize(session)
        end
        -- Without the number panes the fixed-width budget holds only the
        -- connector; zeroing the pane metrics makes the original math
        -- split the rest between the content panes (their windows are
        -- already closed, so no width is lost or double-counted).
        local left_pane = session.left_number_pane_width
        local right_pane = session.right_number_pane_width
        session.left_number_pane_width = 0
        session.right_number_pane_width = 0
        session_layout_resize(session)
        session.left_number_pane_width = left_pane
        session.right_number_pane_width = right_pane
        -- The original returns early for this layout, so balance here to
        -- keep the panes even when the panel opens or closes.
        balance_content_panes(session)
      end

      local session_dispose = Session.dispose
      function Session:dispose()
        session_dispose(self)
        -- Wipe the number-pane buffers the layout no longer displays, so
        -- they do not accumulate as hidden buffers after tab close.
        if is_two_way(self) then
          for _, field in ipairs({ "left_num_buf", "right_num_buf" }) do
            local buf = self[field]
            if buf and vim.api.nvim_buf_is_valid(buf) then
              pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
          end
        end
      end

      diffbandit.setup({
        ui = {
          -- No overview strips and no header row: just content, connector,
          -- content.
          overview = { enabled = false },
          status = { enabled = false },
        },
        git = {
          -- Half the plugin's 42-column default: the file list only shows
          -- names, so the diff panes get the freed columns.
          panel = { width = 21 },
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