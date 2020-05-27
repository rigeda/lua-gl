-- Module in DemoProject for undo/redo handling
-- NOTE: The module does not allow for multiple independent instances to be created in the application since undo/redo stacks are 1

local table = table

local print = print

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
local skip = false
local group = false
local newGroup = false

function beginGroup()
	newGroup = true
	group = true
end

function endGroup()
	group = false
end

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
		print("Doing UNDO",skip)
		tab = redo 
	elseif not doingRedo then
		redo = {}	-- Redo is emptied if any action is done
	else
		print("DOING REDO",skip)
	end
	if not skip then
		if group then
			-- To group multiple luagl actions into 1 undo action of the host application
			if newGroup then
				tab[#tab + 1] = {
					type = "LUAGLGROUP",
					obj = {diff}
				}
				newGroup = false
			else
				tab[#tab].obj[#tab[#tab].obj + 1] = diff
			end
			print("Add LUAGLGROUP to stack")
		else
			tab[#tab + 1] = {
				type = "LUAGL",
				obj = diff
			}
			print("Add LUAGL to stack")
		end
	end
	updateButtons()
end

-- skipRedo if true will skip adding the action to the redo stack
function doUndo(skipRedo)
	skip = skipRedo
	for i = #undo,1,-1 do
		if undo[i].type == "LUAGL" then
			toRedo = true
			cnvobj:undo(undo[i].obj)
			table.remove(undo,i)
			toRedo = false
			break
		elseif undo[i].type == "LUAGLGROUP" then
			toRedo = true
			beginGroup()
			for j = #undo[i].obj,1,-1 do
				cnvobj:undo(undo[i].obj[j])
			end
			table.remove(undo,i)
			toRedo = false
			endGroup()
			break
		end
	end
	skip = false
	updateButtons()
end

-- skipUndo if true will skip adding the action to the undo stack
function doRedo(skipUndo)
	skip = skipUndo
	for i = #redo,1,-1 do
		if redo[i].type == "LUAGL" then
			doingRedo = true
			cnvobj:undo(redo[i].obj)
			table.remove(redo,i)
			doingRedo = false
			break
		elseif redo[i].type == "LUAGLGROUP" then
			doingRedo = true
			beginGroup()
			for j = #redo[i].obj,1,-1 do
				cnvobj:undo(redo[i].obj[j])
			end
			table.remove(redo,i)
			doingRedo = false
			endGroup()
			break
		end
	end	
	skip = false
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
	undo,redo = {},{}
	toRedo = false
	doingRedo = false
	skip = false
	group = false
	newGroup = false
	updateButtons()
	hook = cnvobj:addHook("UNDOADDED",addUndoStack)
end
