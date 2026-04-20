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

    -- Scopes panel: dark brown for variable names, truncate long values
    vim.api.nvim_set_hl(0, 'DapScopeVariable', { fg = '#96724e' })

    local entity = require('dap.entity')
    local orig_render_child = entity.variable.render_child
    local max_value_len = 120

    local function truncated_render_child(var, indent)
      local text, hl
      if var.value and #var.value > max_value_len then
        local saved = var.value
        var.value = saved:sub(1, max_value_len) .. '…'
        text, hl = orig_render_child(var, indent)
        var.value = saved
      else
        text, hl = orig_render_child(var, indent)
      end
      if hl then
        for _, region in ipairs(hl) do
          if region[1] == 'Identifier' then
            region[1] = 'DapScopeVariable'
          end
        end
      end
      return text, hl
    end

    entity.variable.render_child = truncated_render_child
    entity.variable.tree_spec.render_child = truncated_render_child
    entity.scope.tree_spec.render_child = truncated_render_child
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

      -- Step into the outermost function call, skipping argument evaluation
      keys.add({
        key = "f",
        desc = "Step into function call (skip arg evaluation)",
        action = function()
          local dap = require("dap")
          local session = dap.session()
          if not session then return end
          if not session.capabilities.supportsStepInTargetsRequest then
            return print("Adapter does not support step-in targets")
          end
          local frame = session.current_frame
          if not frame then return end

          session:request('stepInTargets', { frameId = frame.id }, function(err, resp)
            if err then return print("stepInTargets: " .. (err.message or "")) end
            local targets = resp.targets or {}
            if #targets == 0 then return print("No step-in targets") end
            -- Last target = outermost call (Python evaluates args before the call)
            session:_step('stepIn', { targetId = targets[#targets].id })
          end)
        end,
      })

      -- Show picker for all step-in targets (to inspect what's available)
      keys.add({
        key = "F",
        desc = "Step into target (pick from list)",
        action = function()
          require("dap").step_into({ askForTargets = true })
        end,
      })

      vim.keymap.set({ "n", "v" }, "<leader>m", dm.mode.toggle, { nowait = true, desc = 'Enter debug [m]ode' })
    end
},
}
