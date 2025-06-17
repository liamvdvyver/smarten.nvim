local M = {}

-- enum for selected list
local search = 1
local quickfix = 2
local loclist = 3

-- enum for direction
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

M.setup = function()
  M.cur_list = search
end

M.next = function()
  run_cmd(M.cur_list, next)
end

M.prev = function()
  run_cmd(M.cur_list, next)
end

return M
