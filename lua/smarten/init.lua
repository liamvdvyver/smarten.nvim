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
-- Each entry should be a { next, previous } list
-- where next/previous have form:
-- { mode, command }
-- mode must be one of the locals n or c below, with the corresponding type of
-- command listen next to it
local cmds = {}
local normal = 1 -- string
local command = 2 -- string
local lua = 3 -- callable
cmds[search] = {
  { normal, "n" },
  { normal, "N" },
}
cmds[quickfix] = {
  { command, "cnext" },
  { command, "cprev" },
}
cmds[loclist] = {
  { command, "lnext" },
  { command, "lprev" },
}
cmds[buffer] = {
  { command, "bnext" },
  { command, "bprevious" },
}
cmds[tab] = {
  { command, "tabnext" },
  { command, "tabprevious" },
}
cmds[tag] = {
  { command, "tnext" },
  { command, "tprevious" },
}
cmds[diagnostic] = {
  { lua, vim.diagnostic.goto_next },
  { lua, vim.diagnostic.goto_prev },
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

-- do_run_cmd[mode_idx](cmd) will run the command as specified above
local do_run_cmd = {}
do_run_cmd[command] = function(cmd)
  pcall(vim.cmd, "silent " .. cmd)
end
do_run_cmd[normal] = function(cmd)
  do_run_cmd[command]("normal " .. cmd)
end
do_run_cmd[lua] = function(cmd)
  cmd()
end

-- Given index/next, dispatch correct strategy
local run_cmd = function(list_idx, dir_idx)
  local mode = cmds[list_idx][dir_idx][1]
  local cmd = cmds[list_idx][dir_idx][2]
  do_run_cmd[mode](cmd)
end

-- Given command/mode, convert it to a normal mode command
local do_normalise_cmd = {}
do_normalise_cmd[normal] = function(cmd)
  return cmd
end
do_normalise_cmd[command] = function(cmd)
  return ":silent " .. cmd .. "<CR>"
end
do_normalise_cmd[lua] = function(cmd)
  return cmd
end

-- Given list/direction idx return something mappable via:
-- vim.keymap.set("n", key, normalise_cmd(list_idx, dir_idx))
local normalise_cmd = function(list_idx, dir_idx)
  local mode = cmds[list_idx][dir_idx][1]
  local cmd = cmds[list_idx][dir_idx][2]
  return do_normalise_cmd[mode](cmd)
end

-- swap list
local set_list = function(list_idx)
  M.cur_list = list_idx

  -- manually set managed maps
  if M.next_keys then
    for _, v in ipairs(M.next_keys) do
      -- P(normalise_cmd(list_idx, next))
      vim.keymap.set("n", v, normalise_cmd(list_idx, next))
    end
  end
  if M.prev_keys then
    for _, v in ipairs(M.prev_keys) do
      vim.keymap.set("n", v, normalise_cmd(list_idx, prev))
    end
  end
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
        cmds[unimpaired] = {
          { command, "silent normal ]" .. matched },
          { command, "silent normal [" .. matched },
        }
        M.set_list(unimpaired)
      end
    end
  end

  vim.on_key(unimp_callback, nil, nil)
end

-- public
M.setup = function(opts)
  -- default to n/N
  set_list(1)

  -- get opts
  local default_opts = {
    smart_unimpaired = true,
  }
  opts = vim.tbl_extend("force", default_opts, opts)

  -- Plugin managed keys
  if opts.keys then
    local next_keys = opts.keys.next
    local prev_keys = opts.keys.prev

    if next_keys then
      M.next_keys = vim.iter({ next_keys }):flatten():totable()
    end
    if prev_keys then
      M.prev_keys = vim.iter({ prev_keys }):flatten():totable()
    end
  end

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
