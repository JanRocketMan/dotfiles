-- Configuration for minimal version of frozen.nvim that doesn't use lazy or any plugins
-- You can use it as a drop-in replacement for large files with `nvim -u`
-- 1. [[ Setting options ]]

-- Set leader keys, enable nerd font, disable highlight of current line
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true
vim.o.cursorline = false
vim.o.termguicolors = true

-- Disable swap files
vim.opt.swapfile = false

-- Enable mouse, hide status and minimize cmd bar, hide any bar stats
vim.opt.mouse = 'a'
vim.o.cmdheight = 1
vim.o.ruler = false
vim.o.showcmd = false
vim.opt.showmode = false
vim.o.laststatus = 0
vim.o.cmdwinheight = 1

-- Support indents in multi-line strings, keep the undo history for buffer with file if we close it
vim.opt.breakindent = true
vim.o.undofile = true

-- Use OS clipboard and fix pasting errors when copying over ssh/tmux sessions. See https://github.com/neovim/neovim/discussions/28010#discussioncomment-987749
vim.o.clipboard = 'unnamedplus'
local osc52 = require('vim.ui.clipboard.osc52')
local function paste()
  return {
    vim.fn.split(vim.fn.getreg(""), "\n"),
    vim.fn.getregtype(""),
  }
end
if (os.getenv('SSH_TTY') ~= nil)
then
  vim.g.clipboard = {
     name = 'OSC 52',
     copy = {
       ['+'] = osc52.copy('+'),
       ['*'] = osc52.copy('*'),
     },
     paste = {
       ['+'] = paste,
       ['*'] = paste,
     },
  }
end

-- Improve search, reduce update time
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.g.cursorhold = 50
vim.opt.path:append("**")

-- Improve symbols repr
vim.opt.list = true
vim.opt.fillchars = { eob = ' ' }
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
vim.opt.signcolumn = 'no'
vim.opt.splitbelow = true

-- Replace tabs with four spaces when you write them in insert mode or for indentations
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.softtabstop = -1

-- Remove startup message, enable live substitutions, highlight on yank
vim.opt.shortmess:append 'sI'
vim.opt.inccommand = 'split'
vim.opt.scrolloff = 10
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- disable global shada; create separate shadafile for each workspace
local workspace_path = vim.fn.getcwd()
local cache_dir = vim.fn.stdpath("data")
local unique_id = vim.fn.fnamemodify(workspace_path, ":t") ..
    "_" .. vim.fn.sha256(workspace_path):sub(1, 8) ---@type string
local file = cache_dir .. "/shadas/" .. unique_id .. ".shada"
vim.opt.shadafile = file

-- Show recent files within current dir when we open neovim without any files
-- Note this requires us to set `recent_files_picker` function which we do below
vim.api.nvim_create_autocmd("VimEnter", {
  group = minimal_group,
  callback = function()
    -- If any command-line arguments were given (files/dirs/“-”), do nothing.
    if vim.fn.argc() > 0 then
      return
    end
    if vim.api.nvim_buf_get_offset(0, 0) <= 0 then
      local handle = io.open(vim.api.nvim_buf_get_name(0))
      if handle == nil then
        recent_files_picker()
      end
    end
  end,
})

-- 2. [[ Basic Keymaps ]]

-- Disable copy when we delete/change symbols from normal mode, keep last yanked when pasting
vim.keymap.set('n', 'd', '"_d')
vim.keymap.set('n', 'c', '"_c')
vim.keymap.set('n', 'x', '"_x')
vim.keymap.set('v', 'p', '"_dP')

-- Use emacs-compatible keymaps in insert mode
vim.keymap.set('i', '<M-f>', 'w')
vim.keymap.set('i', '<M-b>', 'b')
vim.keymap.set('i', '', '')
vim.keymap.set('i', '', 'I')
vim.keymap.set('i', '', 'A')
vim.keymap.set('i', '', 'u')
vim.keymap.set('i', '<M-BS>', '')
vim.keymap.set('i', '<C-w>', '"_dB')
vim.keymap.set('i', '<C-Right>', 'W')
vim.keymap.set('i', '<C-Left>', 'B')

-- Clear cmd messages and highlight on Esc
vim.keymap.set('n', '<Esc>', ':nohlsearch<CR>:echo ""<CR>')

-- Add nice half-page jumps inspired by the @ThePrimeagen config
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Move [U]p with centering' })
vim.keymap.set('n', '<PageUp>', '<C-u>zz', { desc = 'Move [U]p with centering' })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Move [D]own with centering' })
vim.keymap.set('n', '<PageDown>', '<C-d>zz', { desc = 'Move [D]own with centering' })

-- Improve window navigation
vim.keymap.set('n', '<C-Left>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-Right>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-Down>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-Up>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Save file wo messages, close buffer/window/tab
vim.keymap.set('n', '<leader>i', ':w<CR>:echo ""<CR>', { desc = 'Wr[i]te current file' })
vim.keymap.set('n', '<leader>d', ':bd<CR>:echo ""<CR>', { desc = '[D]elete current buffer' })
vim.keymap.set('n', '<leader>q', ':q!<CR>', { desc = '[Q]uit current window' })
vim.keymap.set('n', '<leader>x', ':tabclose<CR>', { desc = 'E[x]it current tab' })

-- Search files
vim.keymap.set('n', '<leader>o', function()
  vim.cmd('Ex | sil! /' .. vim.fn.expand('%:t'))
  vim.cmd('nohlsearch')
end, { desc = '[O]pen file tree for current buffer' })
vim.keymap.set('n', '<leader>f', ':find **/*')

-- Replace in current buffer
vim.keymap.set({'n', 'x', 'o'}, '<leader>r', '"hy:%s/<C-r>h//g<left><left>', { desc = '[R]eplace all occurences of current selection in current buffer' })

-- Buffer navigation
vim.keymap.set('n', ']q', function()
  local ok = pcall(vim.cmd, 'cnext')
  if not ok then
    vim.cmd('cfirst')
  end
end, { desc = 'Next quickfix entry (cycle)' })

vim.keymap.set('n', '[q', function()
  local ok = pcall(vim.cmd, 'cprev')
  if not ok then
    vim.cmd('clast')
  end
end, { desc = 'Previous quickfix entry (cycle)' })

local excluded_patterns = { "/site%-packages/", "%.tmp/" }
local function is_excluded(path)
  for _, pattern in ipairs(excluded_patterns) do
    if path:find(pattern) then
      return true
    end
  end
  return false
end

local function buffers_in_quickfix(opts)
  opts = opts or {}
  local hidden = opts.hidden
  local only_py = opts.only_py or false

  local current_buf = vim.api.nvim_get_current_buf()
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })

  table.sort(buffers, function(a, b)
    return a.lastused > b.lastused
  end)

  local lines = {}

  for _, buf in ipairs(buffers) do
    local name = buf.name
    local is_py = vim.endswith(name, '.py')

    if buf.bufnr ~= current_buf
        and name ~= ''
        and vim.api.nvim_buf_is_loaded(buf.bufnr)
        and (not is_excluded(name) or hidden)
        and (not only_py or is_py) then

      local filepath = vim.fn.fnamemodify(name, ':.') -- relative to CWD
      local mark = vim.api.nvim_buf_get_mark(buf.bufnr, '"')
      local line = mark[1] > 0 and mark[1] or 1
      local col = mark[2] > 0 and mark[2] or 0
      table.insert(lines, string.format('%s:%d:%d: %s', filepath, line, col + 1, filepath))
    end
  end

  if vim.tbl_isempty(lines) then
    vim.cmd('echo "No buffers"')
    vim.defer_fn(function() vim.cmd('echo ""') end, 100)
    return
  end

  vim.cmd('nos ene | setl bt=nofile bh=wipe')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.cmd('cbu')
end

vim.keymap.set('n', '<leader>n', function()
  buffers_in_quickfix({ hidden = true })
end, { desc = 'Show all buffers' })

vim.keymap.set('n', '<leader>e', function()
  buffers_in_quickfix({ hidden = false, only_py = true })
end, { desc = 'Show buffers excluding hidden' })

-- Load current file path to clipboard, execute terminal command with scratch buffer
vim.keymap.set('n', '<leader>y', function() vim.fn.setreg('+', vim.fn.expand('%:p')) vim.fn.setreg('"', vim.fn.expand('%:p')) end, { desc = 'Cop[y] to clipboard current path' })
vim.keymap.set('n', '<leader>ty', function() vim.fn.setreg('+', vim.fn.expand('%:.')) vim.fn.setreg('"', vim.fn.expand('%:p')) end, { desc = 'Cop[y] to clipboard current path' })
vim.keymap.set('n', '<leader>c', function()
  vim.ui.input({}, function(c)
    if c and c ~= "" then
      c = 'bash -i -c "source ~/.bashrc && ' .. c .. '"'
      vim.cmd('nos ene | setl bt=nofile bh=wipe')
      local output = vim.fn.systemlist(c)
      -- Filter out the bash warning lines
      local filtered_output = {}
      local skip_lines = 0
      -- Check if first two lines are the bash warnings
      if #output >= 2 and
         output[1]:match("bash: cannot set terminal process group") and
         output[2]:match("bash: no job control in this shell") then
        skip_lines = 2
      end
      -- Copy the remaining lines
      for i = skip_lines + 1, #output do
        table.insert(filtered_output, output[i])
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, false, filtered_output)
    end
  end)
end, { desc = 'Execute terminal [c]ommand and drop result to scratch buffer' })

vim.keymap.set('n', 'gd', function()
  local symbol = vim.fn.expand('<cword>')
  if symbol == '' then return end

  -- Use rg with --vimgrep and -uu to include hidden + ignored files
  local rg_cmd = string.format(
    "rg -uu --vimgrep '\\b(class|def) %s\\b' --glob '*.{py,pyi}'",
    symbol
  )

  -- Run rg and collect output
  local results = vim.fn.systemlist(rg_cmd)

  if vim.tbl_isempty(results) then
    vim.cmd('echo "No matches found"')
    vim.defer_fn(function() vim.cmd('echo ""') end, 100)
    return
  end

  if #results == 1 then
    local line = results[1]
    local file, lnum, col = line:match('^(.-):(%d+):(%d+):')
    if file and lnum and col then
      vim.cmd('edit ' .. file)
      vim.api.nvim_win_set_cursor(0, { tonumber(lnum), tonumber(col) + 1})
      vim.cmd('normal! w')
      return
    end
  end

  -- Create scratch buffer
  vim.cmd('nos ene | setl bt=nofile bh=wipe')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, results)
end, { desc = 'RG-based goto definition (Python class/def)' })

-- Improve jumping once scratchbuffer list is opened
vim.keymap.set('n', 'gf', function()
  local line = vim.fn.getline('.')
  local cursor_col = vim.fn.col('.') -- 1-based cursor column

  local matched = nil

  -- Match patterns like: filename:line:col:
  for start_col, match in line:gmatch '()([%w%./_%-]+:%d+:%d+):' do
    local file, lnum, col = match:match('^(.-):(%d+):(%d+)$')
    if file and lnum and col then
      local end_col = start_col + #match
      if cursor_col >= start_col and cursor_col <= end_col then
        matched = {
          file = file,
          lnum = tonumber(lnum),
          col = tonumber(col),
        }
        break
      end
    end
  end

  if matched then
    vim.cmd('edit ' .. matched.file)
    vim.api.nvim_win_set_cursor(0, { matched.lnum, matched.col - 1 }) -- 0-indexed column
  else
    vim.cmd('normal! gf') -- fallback
  end
end, { desc = 'Smart gf: jump to file:line:column if available' })

-- Toggle lsp messages (disabled by default)
vim.diagnostic.enable(false)
vim.keymap.set('n', '<leader>to', function()
  vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, {desc = "[To]ggle diagnostic messages and signs"})

-- Apply minimal mode settings
vim.cmd('syntax off | highlight Normal guibg=#1e1e1e guifg=#b8a583')
local minimal_group = vim.api.nvim_create_augroup("MinimalMode", { clear = true })
function recent_files_picker()
  vim.cmd("normal! '0")
  vim.cmd("1b")
  vim.cmd("bd")
end
vim.api.nvim_create_autocmd("BufEnter", {group = minimal_group, callback = function() vim.treesitter.stop() end})

-- vim: ts=2 sts=2 sw=2 et
