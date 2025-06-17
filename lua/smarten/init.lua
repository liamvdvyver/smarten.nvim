local M = {
  cur_list = nil
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
	-- local cmd = "silent " .. cmds[list_idx][dir_idx]
	local cmd = cmds[list_idx][dir_idx]
	pcall(vim.cmd, cmd)
end

-- swap list
local set_list = function(list_idx)
  M.cur_list = list_idx
end

-- register autommands
local register_qf_autocmd = function()
  vim.api.nvim_create_autocmd("QuickFixCmdPost",  {
    callback = function(_)
      set_list(quickfix)
    end
  })
end

-- listen to keys
local handle_search_keys = function(key, typed)
  if string.match(key, "[/?*#]") then
    set_list(search)
  end
end

local register_search_onkey = function()
  vim.on_key(
    handle_search_keys,
    nil,
    nil
  )
end

-- public
M.setup = function()
  set_list(1)
  register_qf_autocmd()
  register_search_onkey()
end

M.next = function()
  run_cmd(M.cur_list, next)
end

M.prev = function()
  run_cmd(M.cur_list, prev)
end

return M
