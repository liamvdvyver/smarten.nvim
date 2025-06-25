local M = {
  cur_list = nil,
}

-- Enum vals for lists of which can be navigated
local list = {
  search = 1,
  quickfix = 2,
  loclist = 3,
  buffer = 4,
  tab = 5,
  tag = 6,
  diagnostic = 7,
  -- The most recent unimpairsed style mapping
  unimpaired = 8,
}

-- Enum vals for direction to traverse a list
local direction = {
  next = 1,
  prev = 2,
}

-- commands to run in each direction
-- Each entry should be a { next, previous } list
-- where next/previous have form:
-- { mode, command }
-- mode must be one of the locals n or c below, with the corresponding type of
-- command listen next to it
local cmds = {}

local cmd_type = {
  normal = 1, -- string
  command = 2, -- string
  lua = 3, -- callable
}
cmds[list.search] = {
  { cmd_type.normal, "n" },
  { cmd_type.normal, "N" },
}
cmds[list.quickfix] = {
  { cmd_type.command, "cnext" },
  { cmd_type.command, "cprev" },
}
cmds[list.loclist] = {
  { cmd_type.command, "lnext" },
  { cmd_type.command, "lprev" },
}
cmds[list.buffer] = {
  { cmd_type.command, "bnext" },
  { cmd_type.command, "bprevious" },
}
cmds[list.tab] = {
  { cmd_type.command, "tabnext" },
  { cmd_type.command, "tabprevious" },
}
cmds[list.tag] = {
  { cmd_type.command, "tnext" },
  { cmd_type.command, "tprevious" },
}
cmds[list.diagnostic] = {
  { cmd_type.lua, vim.diagnostic.goto_next },
  { cmd_type.lua, vim.diagnostic.goto_prev },
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
    if not smart_unimpaired then
      return "[%[%]][" .. chars .. "]"
    else
      return nil
    end
  end

  keys[list.search] = {
    "[/?*#nN]",
    nil,
  }
  keys[list.quickfix] = {
    nil,
    unimp_str("qQ"),
  }
  keys[list.buffer] = {
    nil,
    unimp_str("bB"),
  }
  keys[list.tab] = {
    nil,
    nil, -- TODO: is this mapped?
  }
  keys[list.tag] = {
    nil,
    unimp_str("tT"),
  }
  keys[list.diagnostic] = {
    nil,
    unimp_str("dD"),
  }

  return keys
end

-- do_run_cmd[mode_idx](cmd) will run the command as specified above
local do_run_cmd = {}
do_run_cmd[cmd_type.command] = function(cmd)
  pcall(vim.cmd, "silent " .. cmd)
end
do_run_cmd[cmd_type.normal] = function(cmd)
  do_run_cmd[cmd_type.command]("normal " .. cmd)
end
do_run_cmd[cmd_type.lua] = function(cmd)
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
do_normalise_cmd[cmd_type.normal] = function(cmd)
  return cmd
end
do_normalise_cmd[cmd_type.command] = function(cmd)
  return ":" .. cmd .. "<CR>"
end
do_normalise_cmd[cmd_type.lua] = function(cmd)
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
      vim.keymap.set("n", v, normalise_cmd(list_idx, direction.next))
    end
  end
  if M.prev_keys then
    for _, v in ipairs(M.prev_keys) do
      vim.keymap.set("n", v, normalise_cmd(list_idx, direction.prev))
    end
  end
end

-- register autommands
local register_qf_autocmds = function()
  local callback = function(_)
    set_list(list.quickfix)
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
        cmds[list.unimpaired] = {
          { cmd_type.command, "normal ]" .. matched },
          { cmd_type.command, "normal [" .. matched },
        }
        set_list(list.unimpaired)
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
  run_cmd(M.cur_list, direction.next)
end

M.prev = function()
  run_cmd(M.cur_list, direction.prev)
end

return M
