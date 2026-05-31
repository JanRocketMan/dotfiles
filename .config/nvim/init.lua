-- Configuration for minimal version of frozen.nvim that doesn't use lazy or any plugins
-- You can use it as a drop-in replacement for large files with `nvim -u`

-- [1] Settings
-- Set leader keys, enable nerd font, disable highlight of current line
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true
vim.o.cursorline = false
vim.o.termguicolors = true
-- Disable swap files
vim.opt.swapfile = false
-- Disable autoformatting by default
vim.g.disable_autoformat = true
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
-- Improve search, reduce update time
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.g.cursorhold = 50
vim.opt.path:append("**")
-- Improve symbols repr
vim.opt.list = true
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

-- [2] Fixes
-- Disable global shada; create separate shadafile for each workspace
local workspace_path = vim.fn.getcwd()
local cache_dir = vim.fn.stdpath("data")
local unique_id = vim.fn.fnamemodify(workspace_path, ":t") ..
    "_" .. vim.fn.sha256(workspace_path):sub(1, 8) ---@type string
local file = cache_dir .. "/shadas/" .. unique_id .. ".shada"
vim.opt.shadafile = file
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

-- [3] Keymaps
-- Disable copy when we delete symbols in normal mode, keep last yanked when pasting
vim.keymap.set({'n', 'v'}, 'd', '"_d')
vim.keymap.set('n', 'x', '"_x')
vim.keymap.set('v', 'p', '"_dP')
-- Load current file path to clipboard, execute terminal command with scratch buffer
vim.keymap.set('n', '<leader>y', function() vim.fn.setreg('+', vim.fn.expand('%:p')) vim.fn.setreg('"', vim.fn.expand('%:p')) end, { desc = 'Cop[y] to clipboard current path' })
vim.keymap.set('n', '<leader>ty', function() vim.fn.setreg('+', vim.fn.expand('%:.')) vim.fn.setreg('"', vim.fn.expand('%:p')) end, { desc = 'Cop[y] to clipboard current path' })
-- Clear cmd messages and highlight on Esc
vim.keymap.set('n', '<Esc>', ':nohlsearch<CR>:echo ""<CR>')
-- Use emacs-compatible keymaps in insert mode
vim.keymap.set('i', '<M-f>', 'w')
vim.keymap.set('i', '<M-b>', 'b')
vim.keymap.set('i', '', '')
vim.keymap.set('i', '', 'I')
vim.keymap.set('i', '', 'A')
vim.keymap.set('i', '', 'u')
vim.keymap.set('i', '<M-BS>', '')
vim.keymap.set('i', '<C-w>', ' "_dB')
vim.keymap.set('i', '<C-Right>', ' W')
vim.keymap.set('i', '<C-Left>', ' B')
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
-- Search files
vim.keymap.set('n', '<leader>f', ':find **/*')
-- Replace in current buffer
vim.keymap.set({'n', 'x', 'o'}, '<leader>r', '"hy:%s/<C-r>h//g<left><left>', { desc = '[R]eplace all occurences of current selection in current buffer' })
-- Toggle lsp messages (disabled by default)
vim.diagnostic.enable(false)
vim.keymap.set('n', '<leader>to', function()
  vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, {desc = "[To]ggle diagnostic messages and signs"})
-- Clear cmd messages and highlight on Esc
vim.keymap.set('n', '<Esc>', ':nohlsearch<CR>:echo ""<CR>')
-- Use emacs-compatible keymaps in insert mode
vim.keymap.set('i', '<M-f>', 'w')
vim.keymap.set('i', '<M-b>', 'b')
vim.keymap.set('i', '', '')
vim.keymap.set('i', '', 'I')
vim.keymap.set('i', '', 'A')
vim.keymap.set('i', '', 'u')
vim.keymap.set('i', '<M-BS>', '')
vim.keymap.set('i', '<C-w>', ' "_dB')
vim.keymap.set('i', '<C-Right>', ' W')
vim.keymap.set('i', '<C-Left>', ' B')
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
-- Search files
vim.keymap.set('n', '<leader>f', ':find **/*')
-- Replace in current buffer
vim.keymap.set({'n', 'x', 'o'}, '<leader>r', '"hy:%s/<C-r>h//g<left><left>', { desc = '[R]eplace all occurences of current selection in current buffer' })
-- Toggle lsp messages (disabled by default)
vim.diagnostic.enable(false)
vim.keymap.set('n', '<leader>to', function()
  vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, {desc = "[To]ggle diagnostic messages and signs"})
-- Save with autoformatting
vim.keymap.set('n', '<leader>ti', function()
  vim.g.disable_autoformat = false
  vim.cmd('w')
  vim.cmd('echo ""')
  vim.g.disable_autoformat = true
end, { desc = 'Save with autoformatting'})

-- [4] Scratch buffer and quickfix lists magic
-- Global toggle for quickfix window (outside scratch buffers)
vim.keymap.set('n', '<leader>q', function()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == 'quickfix' then
      vim.cmd('cclose')
      return
    end
  end
  vim.cmd('copen')
end, { desc = 'Toggle [Q]uickfix window' })
-- Quickfix navigation with cycling
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
-- Scratch buffer keymaps: jump on <CR>, convert to quickfix on <leader>q
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'scratchcmd',
  callback = function()
    -- Jump to file:line:col on current line using native efm + cexpr
    vim.keymap.set('n', '<CR>', function()
      vim.opt_local.errorformat = '%f:%l:%c:%m'
      vim.cmd('cexpr getline(".")')
    end, { buffer = true, silent = true, desc = 'Jump to file:line:col' })

    -- Convert all buffer lines to quickfix, close scratch, jump to first match, keep cursor in file
    vim.keymap.set('n', '<leader>q', function()
      local scratch_buf = vim.api.nvim_get_current_buf()
      vim.opt_local.errorformat = '%f:%l:%c:%m'
      vim.cmd('cexpr getline(1, "$")')     -- populate qf and jump to first match
      if vim.api.nvim_buf_is_valid(scratch_buf) then
        vim.api.nvim_buf_delete(scratch_buf, { force = true })
      end
      vim.cmd('copen | wincmd p')           -- open qf at bottom, return focus to file
    end, { buffer = true, silent = true, desc = 'Convert scratch buffer to quickfix' })
  end,
})
vim.keymap.set('n', '<leader>c', function()
  vim.ui.input({}, function(c)
    if c and c ~= "" then
      vim.cmd('nos ene | setl bt=nofile bh=wipe | setl filetype=scratchcmd')
      local output = vim.fn.systemlist({ vim.o.shell, '-i', '-c', c })
      vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
    end
  end)
end, { desc = 'Execute terminal [c]ommand and drop result to scratch buffer' })

-- [5] Colorscheme
vim.cmd.colorscheme('codeyellow')

local function gh(repo) return 'https://github.com/' .. repo end
vim.pack.add { gh 'Spiegie/jj-conflict-highlight.nvim' }
require('jj_conflict_highlight').setup {}
