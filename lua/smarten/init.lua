local M = {}

--- @alias list_val integer
--- @type table<string, list_val>
--- Enum vals for lists of which can be navigated.
local list = {
  search = 1,
  quickfix = 2,
  loclist = 3,
  buffer = 4,
  tab = 5,
  tag = 6,
  diagnostic = 7,
  -- The most recent unimpaired style mapping
  unimpaired = 8,
}

--- @alias direction_val integer
--- @type table<string, direction_val>
--- Enum vals for direction to traverse a list.
local direction = {
  next = 1,
  prev = 2,
}

--- @alias cmd_type_val integer
--- @type table<string, cmd_type_val>
--- Enum vals for method to invoke behaviour.
local cmd_type = {
  normal = 1, ---@alias cmd_type_normal 1
  ex = 2, ---@alias cmd_type_ex 2
  lua = 3, ---@alias cmd_type_lua 3
}

--- @alias cmd_entry {type: cmd_type_normal, cmd: string} | {type: cmd_type_ex, cmd: string} | {type: cmd_type_lua, cmd: function}
--- @type table<list_val, table<direction_val, cmd_entry>>
--- How to traverse lists in each direction.
local cmds = {
  [list.search] = {
    [direction.next] = { type = cmd_type.normal, cmd = "n" },
    [direction.prev] = { type = cmd_type.normal, cmd = "N" },
  },
  [list.quickfix] = {
    [direction.next] = { type = cmd_type.ex, cmd = "cnext" },
    [direction.prev] = { type = cmd_type.ex, cmd = "cprev" },
  },
  [list.loclist] = {
    [direction.next] = { type = cmd_type.ex, cmd = "lnext" },
    [direction.prev] = { type = cmd_type.ex, cmd = "lprev" },
  },
  [list.buffer] = {
    [direction.next] = { type = cmd_type.ex, cmd = "bnext" },
    [direction.prev] = { type = cmd_type.ex, cmd = "bprevious" },
  },
  [list.tab] = {
    [direction.next] = { type = cmd_type.ex, cmd = "tabnext" },
    [direction.prev] = { type = cmd_type.ex, cmd = "tabprevious" },
  },
  [list.tag] = {
    [direction.next] = { type = cmd_type.ex, cmd = "tnext" },
    [direction.prev] = { type = cmd_type.ex, cmd = "tprevious" },
  },
  [list.diagnostic] = {
    [direction.next] = { type = cmd_type.lua, cmd = vim.diagnostic.goto_next },
    [direction.prev] = { type = cmd_type.lua, cmd = vim.diagnostic.goto_prev },
  },
}

--- @param smart_unimpaired boolean infer unimpaired-style mappings
--- @alias onkey_keys { key: string, typed: string } matches vim.on_key, i.e. key is lhs, typed is rhs of mapping
--- @alias onkey_table table<list_val, onkey_keys>
--- @return onkey_table
--- Provide a table of keys to match.
local setup_keys = function(smart_unimpaired)
  local unimp_str = function(chars)
    if not smart_unimpaired then
      return "[%[%]][" .. chars .. "]"
    else
      return nil
    end
  end

  local keys = {
    [list.search] = {
      key = "[/?*#nN]",
      typed = nil,
    },
    [list.quickfix] = {
      key = nil,
      typed = unimp_str("qQ"),
    },
    [list.buffer] = {
      key = nil,
      typed = unimp_str("bB"),
    },
    [list.tab] = {
      key = nil,
      typed = nil,
    },
    [list.tag] = {
      key = nil,
      typed = unimp_str("tT"),
    },
    [list.diagnostic] = {
      key = nil,
      typed = unimp_str("dD"),
    },
  }
  return keys
end

--- @param list_idx list_val
--- @param dir_idx direction_val
--- Given index/next, dispatch correct strategy.
local run_cmd = function(list_idx, dir_idx)
  --- @type table<cmd_type_val, function>
  local do_run_cmd = {}
  do_run_cmd[cmd_type.ex] = function(cmd)
    pcall(vim.cmd, "silent " .. cmd)
  end
  do_run_cmd[cmd_type.normal] = function(cmd)
    do_run_cmd[cmd_type.ex]("normal " .. cmd)
  end
  do_run_cmd[cmd_type.lua] = function(cmd)
    cmd()
  end

  local type = cmds[list_idx][dir_idx].type
  local cmd = cmds[list_idx][dir_idx].cmd
  do_run_cmd[type](cmd)
end

--- @param list_idx list_val
--- @param dir_idx direction_val
--- @return string
--- Given list/direction idx return something mappable via:
--- `vim.keymap.set("n", key, normalise_cmd(list_idx, dir_idx))`
local normalise_cmd = function(list_idx, dir_idx)
  --- @type table<cmd_type_val, function>
  --- Given command/mode, convert it to a normal mode command
  local do_normalise_cmd = {}
  do_normalise_cmd[cmd_type.normal] = function(cmd)
    return cmd
  end
  do_normalise_cmd[cmd_type.ex] = function(cmd)
    return ":" .. cmd .. "<CR>"
  end
  do_normalise_cmd[cmd_type.lua] = function(cmd)
    return cmd
  end
  local mode = cmds[list_idx][dir_idx].type
  local cmd = cmds[list_idx][dir_idx].cmd

  return do_normalise_cmd[mode](cmd)
end

--- @param list_idx list_val
--- Swap the current list.
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

-- register autocommands
local register_qf_autocmds = function()
  local callback = function(ev)
    local wininfo = vim.fn.getwininfo(vim.fn.bufwinid(ev.buf))[1]
    if wininfo.loclist == 1 then
      set_list(list.loclist)
    elseif wininfo.quickfix == 1 then
      set_list(list.quickfix)
    end
  end

  vim.api.nvim_create_autocmd("BufWinEnter", {
    callback = callback,
  })

  -- On entering quickfix window
  vim.api.nvim_create_autocmd("WinEnter", {
    callback = callback,
  })
end

local register_tab_autocmds = function()
  vim.api.nvim_create_autocmd("TabEnter", {
    callback = function(_)
      set_list(list.tab)
    end,
  })
end

--- @param key string
--- @param typed string
--- @param pattern onkey_keys
--- @param list_idx list_val
--- Listen to keys, match search keys in normal mode only, then set active list to search>
local handle_onkey = function(key, typed, pattern, list_idx)
  if vim.fn.mode() == "n" then
    local match_key = pattern.key and string.match(key, pattern.key)
    local match_typed = pattern.typed and string.match(typed, pattern.typed)
    if match_key or match_typed then
      set_list(list_idx)
    end
  end
end

-- TODO: many small listeners vs. one big listener
--- @param keys onkey_table
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
          { type = cmd_type.ex, cmd = "normal ]" .. matched },
          { type = cmd_type.ex, cmd = "normal [" .. matched },
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
    keys = { next = "n", prev = "N" },
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
  register_tab_autocmds()
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
