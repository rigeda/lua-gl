-- Module in DemoProject for undo/redo handling
-- NOTE: The module does not allow for multiple independent instances to be created in the application since undo/redo stacks are 1

local table = table

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local cnvobj, hook, undoButton, redoButton 
local undo,redo = {},{}		-- The UNDO and REDO stacks
local toRedo = false
local doingRedo = false
local group = false

local function updateButtons()
	if #undo == 0 then
		undoButton.active = "NO"
	else
		undoButton.active = "YES"
	end
	if #redo == 0 then
		redoButton.active = "NO"
	else
		redoButton.active = "YES"
	end	
end

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
	updateButtons()
end

function doUndo()
	for i = #undo,1,-1 do
		if undo[i].type == "LUAGL" then
			toRedo = true
			cnvobj:undo(undo[i].obj)
			table.remove(undo,i)
			toRedo = false
			break
		elseif undo[i].type == "LUAGLGROUP" then
			toRedo = true
			group = true
			for j = #undo[i].obj,1,-1 do
				cnvobj:undo(undo[i].obj[j])
			end
			table.remove(undo,i)
			toRedo = false
			group = false
			break
		end
	end
	updateButtons()
end

function doRedo()
	for i = #redo,1,-1 do
		if redo[i].type == "LUAGL" then
			doingRedo = true
			cnvobj:undo(redo[i].obj)
			table.remove(redo,i)
			doingRedo = false
			break
		elseif redo[i].type == "LUAGLGROUP" then
			doingRedo = true
			group = true
			for j = #redo[i].obj,1,-1 do
				cnvobj:undo(redo[i].obj[j])
			end
			table.remove(redo,i)
			doingRedo = false
			group = false
			break
		end
	end	
	updateButtons()
end	

function pauseUndoRedo()
	cnvobj:removeHook(hook)
	hook = nil
end

function resumeUndoRedo()
	if not hook then
		hook = cnvobj:addHook("UNDOADDED",addUndoStack)
	end
end

function init(cnvO,ub,rb)
	cnvobj = cnvO
	undoButton = ub
	redoButton = rb
	hook = cnvobj:addHook("UNDOADDED",addUndoStack)
end
