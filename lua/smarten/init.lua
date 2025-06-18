local M = {
  cur_list = nil,
}

-- idx for selected list
local search = 1
local quickfix = 2
local loclist = 3

-- idx for direction
local next = 1
local prev = 2

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
    vim.notify("ev")
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
local handle_search_keys = function(key, typed)
  if string.match(key, "[/?*#]") then
    set_list(search)
  end
end

local register_search_onkey = function()
  vim.on_key(handle_search_keys, nil, nil)
end

-- public
M.setup = function()
  set_list(1)
  register_qf_autocmds()
  register_search_onkey()
end

M.next = function()
  run_cmd(M.cur_list, next)
end

M.prev = function()
  run_cmd(M.cur_list, prev)
end

return M
