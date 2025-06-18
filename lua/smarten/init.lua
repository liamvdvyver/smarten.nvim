local M = {
  cur_list = nil,
}

-- idx for selected list
local search = 1
local quickfix = 2
local loclist = 3
local buffer = 4
local tab = 5
local tag = 6
local diagnostic = 7
local unimpaired = 8

-- idx for direction
local next = 1
local prev = 2

-- commands to run in each direction
local cmds = {}
cmds[search] = {
  "normal n",
  "normal N",
}
cmds[quickfix] = {
  "cnext",
  "cprev",
}
cmds[loclist] = {
  "lnext",
  "lprev",
}
cmds[buffer] = {
  "bnext",
  "bprevious",
}
cmds[tab] = {
  "tabnext",
  "tabprevious",
}
cmds[tag] = {
  "tnext",
  "tprevious",
}
cmds[diagnostic] = {
  "lua vim.diagnostic.goto_next()",
  "lua vim.diagnostic.goto_prev()",
}

-- Table of keys to match.
--
-- Entries must be of the form {key, typed}, where
-- each is a lua string, matching the arguments to vim.on_key.
-- That is, key is rhs, typed is lhs of mapping.
--
-- Assumed to only match in normal mode.
--
-- If smart_unimpaired, then unimpaired style mappings are not setup here
-- (they should be inferred automatically elsewhere)
local setup_keys = function(smart_unimpaired)
  local keys = {}

  local unimp_str = function(chars)
    if smart_unimpaired then
      return "[%[%]][" .. chars .. "]"
    else
      return nil
    end
  end

  keys[search] = {
    "[/?*#nN]",
    nil,
  }
  keys[quickfix] = {
    nil,
    unimp_str("qQ"),
  }
  keys[buffer] = {
    nil,
    unimp_str("bB"),
  }
  keys[tab] = {
    nil,
    nil, -- TODO: is this mapped?
  }
  keys[tag] = {
    nil,
    unimp_str("tT"),
  }
  keys[diagnostic] = {
    nil,
    unimp_str("dD"),
  }

  return keys
end

local run_cmd = function(list_idx, dir_idx)
  local cmd = "silent " .. cmds[list_idx][dir_idx]
  pcall(vim.cmd, cmd)
end

-- swap list
local set_list = function(list_idx)
  M.cur_list = list_idx
end

M.set_list = set_list

-- register autommands
local register_qf_autocmds = function()
  local callback = function(_)
    set_list(quickfix)
  end

  local callback_check = function(ev, filetype)
    local ft = vim.bo[ev.buf].filetype
    -- HACK: I can't match on pattern, so this works instead
    if ft == filetype then
      callback()
    end
  end

  vim.api.nvim_create_autocmd("BufWinEnter", {
    callback = function(ev)
      callback_check(ev, "qf")
    end,
  })

  -- On entering quickfix window
  vim.api.nvim_create_autocmd("WinEnter", {
    callback = function(ev)
      callback_check(ev, "qf")
    end,
  })
end

-- listen to keys, match search keys in normal mode only
-- then, set active list to search
local handle_onkey = function(key, typed, pattern, list_idx)
  if vim.fn.mode() == "n" then
    local match_key = pattern[1] and string.match(key, pattern[1])
    local match_typed = pattern[2] and string.match(typed, pattern[2])
    if match_key or match_typed then
      -- vim.notify("matched " .. list_idx .. " with " .. key .. ", " .. typed)
      set_list(list_idx)
    end
  end
end

-- TODO: many small listeners vs. one big listener
local register_onkey_listeners = function(keys)
  for list_idx, pattern in pairs(keys) do
    -- TODO: can I pass these args in with on_key, this is messy
    vim.on_key(function(key, typed)
      handle_onkey(key, typed, pattern, list_idx)
    end, nil, nil)
  end
end

-- Add a listener which matches typed on "[%[%]]%a",
-- and then automatically set next/prev to matching normal mode commands.
-- This way, any unimpaired style mappings are automatically supported
M.unimpaired_suffix = nil
local unimp_pat = "[%[%]](%a)"
local register_unimpaired_listener = function()
  local unimp_callback = function(_, typed)
    if vim.fn.mode() == "n" then
      local matched = string.match(typed, unimp_pat)
      if matched then
        M.unimpaired_suffix = matched
        M.cur_list = unimpaired
        cmds[unimpaired] = {
          "normal ]" .. matched,
          "normal [" .. matched,
        }
      end
    end
  end

  vim.on_key(unimp_callback, nil, nil)
end

-- public
M.setup = function(opts)
  set_list(1)

  local default_opts = {
    smart_unimpaired = true,
  }

  opts = vim.tbl_extend("force", default_opts, opts)

  local keys = setup_keys(opts.smart_unimpaired)

  register_qf_autocmds()
  register_onkey_listeners(keys)

  if opts.smart_unimpaired then
    register_unimpaired_listener()
  end

end

M.next = function()
  run_cmd(M.cur_list, next)
end

M.prev = function()
  run_cmd(M.cur_list, prev)
end

return M
