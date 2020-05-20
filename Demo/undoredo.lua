-- Module in DemoProject for undo/redo handling
-- NOTE: The module does not allow for multiple independent instances to be created in the application since undo/redo stacks are 1


local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local cnvobj
undo,redo = {},{}		-- The UNDO and REDO stacks
toRedo = false
doingRedo = false
group = false
local function addUndoStack(diff)
	local tab = undo
	if toRedo then 
		tab = redo 
	elseif not doingRedo then
		redo = {}	-- Redo is emptied if any action is done
	end
	if group then
		-- To group multiple luagl actions into 1 undo action of the host application
		if #tab == 0 or tab[#tab].type ~= "LUAGLGROUP" then
			tab[#tab + 1] = {
				type = "LUAGLGROUP",
				obj = {diff}
			}
		else
			tab[#tab].obj[#tab[#tab].obj + 1] = diff
		end
	else
		tab[#tab + 1] = {
			type = "LUAGL",
			obj = diff
		}
	end
end

function init(cnvO)
	cnvobj = cnvO
	cnvobj:addHook("UNDOADDED",addUndoStack)
end
