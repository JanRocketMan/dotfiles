-- 3. [[Apply full mode settings]]

vim.cmd('syntax on')
vim.api.nvim_clear_autocmds({ group = "MinimalMode" })
local min_mode_picker = recent_files_picker
function recent_files_picker()
  vim.defer_fn(function() min_mode_picker() end, 0)
end

-- Set default colorscheme
vim.cmd.colorscheme('codeyellow')
vim.api.nvim_create_autocmd('BufWinEnter', {
  pattern = '*',
  callback = function(args)
    vim.schedule(function()
      local ok, rd = pcall(require, 'rainbow-delimiters')
      if ok and rd then
        vim.cmd('doautocmd FileType')  -- trigger highlighting again
      end
    end)
  end,
})

-- Disable autoformatting by default
vim.g.disable_autoformat = true

-- 4. [[Add plugin keymaps]]

-- Manipulate files with Vifm
vim.keymap.set('n', '<leader>o', function()
  local file = vim.fn.expand('%:p')
  local dir  = vim.fn.fnamemodify(file, ':h')
  vim.defer_fn(function() vim.cmd('echo ""') end, 100)
  vim.cmd('Vifm ' .. vim.fn.fnameescape(dir) .. ' /' .. file)
end, { desc = 'Open Vifm at current file (selected)' })

-- Save with autoformatting
vim.keymap.set('n', '<leader>ti', function()
  vim.g.disable_autoformat = false
  vim.cmd('w')
  vim.cmd('echo ""')
  vim.g.disable_autoformat = true
end, { desc = 'Save with autoformatting'})

-- Toggle diagnostic messages in current buffer in quickfix list
vim.keymap.set('n', '<leader>te', function()
  vim.diagnostic.setloclist({ open = false }) -- don't open and focus
  local window = vim.api.nvim_get_current_win()
  local qf_winid = vim.fn.getloclist(window, { winid = 0 }).winid
  if qf_winid > 0 then
    vim.cmd('lclose')
  else
    vim.diagnostic.setloclist()
  end
  vim.api.nvim_set_current_win(window) -- restore focus to current window
end, { desc = 'Toggle diagnostic [e]rror list' })

-- Jump between error messages if opened in quickfix list
vim.keymap.set('n', '[e', vim.diagnostic.goto_prev, { desc = 'Go to previous [e]rror message' })
vim.keymap.set('n', ']e', vim.diagnostic.goto_next, { desc = 'Go to next [e]rror message' })

-- Basic debugging keymaps
vim.keymap.set('n', '<leader>b', function() require('dap').toggle_breakpoint() end, { desc = 'Debug: Toggle [B]reakpoint' })
vim.keymap.set('n', '<F4>', function()
  local dap = require('dap')
  dap.toggle_breakpoint()
  require("debugmaster").mode.toggle({nowait=true})
  vim.cmd('lua vim.opt.signcolumn="yes"')
  dap.run(dap.configurations.python[1])
end, { desc = 'Start debugging' })
vim.keymap.set('n', '<F5>', function() require('dap').continue() end, { desc = 'Debug: Continue' })

-- Context navigation keymap
vim.keymap.set("n", "<leader>ts", ":Namu symbols<cr>:echo ''<cr>")
