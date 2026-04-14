return {{
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  config = function()
    local dap = require 'dap'

    dap.adapters.python = function(cb, config)
      if config.request == 'attach' then
        ---@diagnostic disable-next-line: undefined-field
        local port = (config.connect or config).port
        ---@diagnostic disable-next-line: undefined-field
        local host = (config.connect or config).host or '127.0.0.1'
        cb({
          type = 'server',
          port = assert(port, '`connect.port` is required for a python `attach` configuration'),
          host = host,
          options = {
            source_filetype = 'python',
          },
        })
      end
    end
    -- A simple config to debug via attach
    -- Simply run `python -m debugpy --listen 5678 --wait-for-client`
    -- To start it
    dap.configurations.python = {
      {
        type = 'python',
        request = 'attach',
        name = 'Attach remote',
        justMyCode = false,
        connect = function()
          return {
            host = '127.0.0.1',
            port = 8016,
            justMyCode = false,
          }
        end,
      },
    }
  end,
},
{
    "miroshQa/debugmaster.nvim",
    config = function()
      local dm = require("debugmaster")
      local keys = dm.keys

      -- Remap to pdb-style keys
      -- First, move displaced keys out of the way
      keys.get("u").key = "<Tab>"  -- toggle UI (was u, freeing it for stack-up)
      keys.get("r").key = "<CR>"   -- run to cursor (was r, freeing it for step-out)

      -- Core pdb keys
      keys.get("o").key = "n"      -- step over  = pdb next
      keys.get("m").key = "s"      -- step into  = pdb step
      keys.get("q").key = "r"      -- step out   = pdb return
      keys.get("t").key = "b"      -- breakpoint = pdb break

      -- Always attach remote, skip config picker
      keys.get("c").action = function()
        local dap = require("dap")
        if dap.session() then
          dap.continue()
        else
          dap.run(dap.configurations.python[1])
        end
      end

      -- Stack navigation
      keys.get("]s").key = "u"     -- up frame   = pdb up
      keys.get("[s").key = "d"     -- down frame = pdb down

      vim.keymap.set({ "n", "v" }, "<leader>m", dm.mode.toggle, { nowait = true, desc = 'Enter debug [m]ode' })
    end
},
}
