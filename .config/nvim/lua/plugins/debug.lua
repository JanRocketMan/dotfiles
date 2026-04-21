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

    -- Inject custom torch tensor repr on first breakpoint hit (once per session)
    local repr_configured = {}
    local torch_repr = [[import sys; "torch" in sys.modules and setattr(sys.modules["torch"].Tensor, "__repr__", lambda self: f"{str(self.dtype).replace('torch.', '').replace('float32', 'fp32').replace('bfloat16', 'bf16').replace('float16', 'fp16')}{tuple(self.shape)} ∈ [{self.min().float():.2e}, {self.max().float():.2e}] @ {str(self.device)}")]]
    local torchvision_si = [[import sys; si = sys.modules["torchvision.utils"].save_image if "torchvision.utils" in sys.modules else (lambda *a, **k: print("torchvision not available"))]]

    dap.listeners.after.scopes['pytorch_repr'] = function(session)
      if repr_configured[session.id] then return end
      repr_configured[session.id] = true
      local frame_id = session.current_frame and session.current_frame.id
      if not frame_id then return end
      session:request('evaluate', { expression = torch_repr, context = 'repl', frameId = frame_id }, function(err)
        if err then
          print('torch repr: ' .. (err.message or tostring(err)))
        elseif session.current_frame then
          session:_request_scopes(session.current_frame)
        end
      end)
      session:request('evaluate', { expression = torchvision_si, context = 'repl', frameId = frame_id }, function() end)
    end

    dap.listeners.after.event_terminated['pytorch_repr'] = function(session)
      repr_configured[session.id] = nil
    end
    dap.listeners.after.event_exited['pytorch_repr'] = function(session)
      repr_configured[session.id] = nil
    end

    -- Sort variables by recency of modification (most recently changed first)
    local sort_step = 0
    local var_last_changed = {}
    local var_prev_values = {}

    dap.listeners.after.event_stopped['var_sort'] = function()
      sort_step = sort_step + 1
    end
    dap.listeners.after.event_terminated['var_sort'] = function()
      sort_step = 0
      var_last_changed = {}
      var_prev_values = {}
    end
    dap.listeners.after.event_exited['var_sort'] = function()
      sort_step = 0
      var_last_changed = {}
      var_prev_values = {}
    end

    local orig_fetch_children = entity.variable.fetch_children
    local function sorted_fetch_children(var, cb)
      orig_fetch_children(var, function(children)
        local scope_key = tostring(var.variablesReference)
        for _, child in ipairs(children) do
          local key = scope_key .. ':' .. child.name
          if var_prev_values[key] ~= child.value then
            var_last_changed[key] = sort_step
          end
          var_prev_values[key] = child.value
        end
        table.sort(children, function(a, b)
          local a_step = var_last_changed[scope_key .. ':' .. a.name] or 0
          local b_step = var_last_changed[scope_key .. ':' .. b.name] or 0
          if a_step ~= b_step then return a_step > b_step end
          local num_a = string.match(a.name, '^%[?(%d+)%]?$')
          local num_b = string.match(b.name, '^%[?(%d+)%]?$')
          if num_a and num_b then return tonumber(num_a) < tonumber(num_b) end
          return a.name < b.name
        end)
        cb(children)
      end)
    end

    entity.variable.fetch_children = sorted_fetch_children
    entity.variable.tree_spec.fetch_children = sorted_fetch_children
    entity.scope.tree_spec.fetch_children = sorted_fetch_children
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
      keys.get("t").key = "<leader>b" -- breakpoint (free up b for normal motion)

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
