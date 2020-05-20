-- Module to handle hooks
local pcall = pcall
local type = type
local table = table
local tostring = tostring
local error = error

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- The hook structure looks like this:
--[[
{
	key = <string>,			-- string which tells when the hook has to be executed
	func = <function>,		-- function code for the hook that is executed
	id = <integer>			-- Unique ID for the hook. Format is H<num> i.e. H followed by a unique number
}
]]
-- Hooks are located at cnvobj.hook

--[[ DEFINED HOOKS IN lua-gl
MOUSECLICKPRE
MOUSECLICKPOST
UNDOADDED
RESIZED
]]
function processHooks(cnvobj, key, params)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	if #cnvobj.hook == 0 then
		return
	end
	params = params or {}
	for i=#cnvobj.hook, 1, -1 do
		if cnvobj.hook[i].key == key then
			local status, val = pcall(cnvobj.hook[i].func, table.unpack(params))
			if not status then
				error("error: " .. val)
			end
		end
	end
end

addHook = function(cnvobj,key,func)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	if type(func) ~= "function" then
		return nil,"Need a function to add as a hook"
	end
	local hook = {
		key = key,
		func = func,
		id = "H"..tostring(cnvobj.hook.ids + 1)
	}
	local index = #cnvobj.hook
	cnvobj.hook[index+1] = hook
	cnvobj.hook.ids = cnvobj.hook.ids + 1
	return hook.id
end

removeHook = function(cnvobj,id)
	if not cnvobj or type(cnvobj) ~= "table" or not id then
		return
	end
	for i = 1,#cnvobj.hook do
		if cnvobj.hook[i].id == id then
			table.remove(cnvobj.hook,i)
			break
		end
	end
end

