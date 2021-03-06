-- Module in DemoProject for undo/redo handling
-- NOTE: The module does not allow for multiple independent instances to be created in the application since undo/redo stacks are 1

local table = table
local os = os


local tostring = tostring
local print = print
local debug = debug

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local cnvobj, hook, undoButton, redoButton, PAUSE
local undo,redo = {},{}		-- The UNDO and REDO stacks
-- Each entry in the undo/redo stack is a table with the following structure:
--[[
	{	-- Array of items where each item is either of the 2 samples below:
		{
			type = "LUAGL",
			diff = <table> -- It is the diff table
		},
		{
			type = "FUNCTION",
			func = <function>,	-- function to do the undo/redo task. The function should return another function which would do the redo/undo task
		}
	}
]]

local toRedo = false
local doingRedo = false
local skip = false
local group = false
local newGroup = false

-- Behavior of addUndoStack with the above flags 1=true, 0 = false
--[[
skip		doingRedo		toRedo		group		newGroup		addUndoStack Behavior
	0			0			0				0			0			Redo stack emptied, new single undo item added  to new entry in stack
	0			0			0				0			1		*	INVALID CONFIG SINCE group=0 newgroup has no affect
	0			0			0				1			0			Redo stack emptied, new single undo item added to previous entry in the stack
	0			0			0				1			1			Redo stack emptied, new single undo item added to new entry in the stack
	0			0			1				0			0		*	INVALID CONFIG since redo stack would be emptied and then item added to it
	0			0			1				0			1		*	INVALID CONFIG since redo stack would be emptied and then item added to it
	0			0			1				1			0		*	INVALID CONFIG since redo stack would be emptied and then item added to it
	0			0			1				1			1		*	INVALID CONFIG since redo stack would be emptied and then item added to it
	0			1			0				0			0			New single redo item added to new entry in stack
	0			1			0				0			1		*	INVALID CONFIG SINCE group=0 newGroup has no affect
	0			1			0				1			0			New single redo item added to previous entry in the stack
	0			1			0				1			1			New single redo item added to new entry in the stack
	0			1			1				0			0		*	INVALID CONFIG toRedo cannot be 1 when doingRedo is 1
	0			1			1				0			1		*	INVALID CONFIG toRedo cannot be 1 when doingRedo is 1
	0			1			1				1			0		*	INVALID CONFIG toRedo cannot be 1 when doingRedo is 1
	0			1			1				1			1		*	INVALID CONFIG toRedo cannot be 1 when doingRedo is 1
	1			0			0				0			0			Nothing Done					
	1			0			0				0			1			Nothing Done
	1			0			0				1			0			Nothing Done
	1			0			0				1			1			Nothing Done
	1			0			1				0			0			Nothing Done
	1			0			1				0			1			Nothing Done
	1			0			1				1			0			Nothing Done
	1			0			1				1			1			Nothing Done
	1			1			0				0			0			Nothing Done
	1			1			0				0			1			Nothing Done
	1			1			0				1			0			Nothing Done
	1			1			0				1			1			Nothing Done
	1			1			1				0			0			Nothing Done
	1			1			1				0			1			Nothing Done
	1			1			1				1			0			Nothing Done
	1			1			1				1			1			Nothing Done


]]
do
	local groupid	-- This allows nested calls to beginGroup/continueGroup - endGroup by independent operations be inside the outermost call
	function beginGroup()
		if not groupid then
			newGroup = true
			group = true
			groupid = os.time()
			print("-------------->Setup new UNDO GROUP at stack ",#undo+1,#redo+1)
			return groupid
		end
	end

	function endGroup(gid)
		if gid == groupid then
			group = false
			groupid = nil
			print("<---------------End UNDO GROUP at stack ",#undo,#redo)
		end
	end

	function continueGroup()
		if not groupid then
			group = true
			groupid = os.time()
			print("---------------->Add more to previous GROUP at stack ",#undo,#redo,"---------------------->")
			return groupid
		end
	end

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

--[[
addUndoStack has to behave accordingly for the 4 following situations:									group		newGroup	doingRedo	toRedo
1. When a operation is happenning in a group of operations that are to be clumped as 1 operation			1			0/1			0			0
2. When a operation is happenning 																			0			X			0			0
3. When undo is happenning and a operation was done in a group of operations								1			0/1			0			1
4. When undo is happenning for a single operation 															0			X			0			1
5. When redo is happenning and a operation was done in a group of operations								1			0/1			1			0
6. When redo is happenning for a single operation															0			X			1			0

skip just disables addUndoStack to do anything
]]
local function addUndoStack(diff,func)
	if PAUSE then
		return
	end
	local tab = undo
	if toRedo then 
		tab = redo 
	end
	local trace
	if not skip then
		if not doingRedo and not toRedo then
			redo = {}	-- Redo is emptied if any action is done
		end
		local t= {}
		if not diff then	-- This is function
			t.type = "FUNCTION"
			t.func = func
			trace = debug.traceback():match(".-\n.-\n.-\n(.-)\n")
			--print(debug.traceback())
		else
			t.type = "LUAGL"
			t.diff = diff
			trace = debug.traceback():match(".-\n.-\n.-\n.-\n.-\n(.-)\n")
			--print(debug.traceback())
		end
		if group then
			-- To group multiple luagl actions into 1 undo action of the host application
			if newGroup then
				tab[#tab + 1] = {t}
				newGroup = false
				print(diff and "Add LUAGL UNDO from "..trace.." in new GROUP to stack "..tostring(#tab) or "Add UNDO function from "..trace.." in new group to stack "..tostring(#tab))
			else
				tab[#tab][#tab[#tab]+1] = t
				print(diff and "Add LUAGL UNDO from "..trace.." to group at stack "..tostring(#tab) or "Add UNDO function from "..trace.." in new group to stack at "..tostring(#tab))
			end
		else
			tab[#tab + 1] = {t}
			print(diff and "Add LUAGL UNDO from "..trace.." to stack as 1 item group at stack "..tostring(#tab) or "Add UNDO function from "..trace.." to stack as 1 item group at stack "..tostring(#tab))
		end
	end
	updateButtons()
end

function addUndoFunction(func)
	if hook then	-- Undo Redo is not paused
		addUndoStack(nil,func)
	end
end

-- skipRedo if true will skip adding the action to the redo stack
function doUndo(skipRedo)
	skip = skipRedo
	local i = #undo
	toRedo = true
	-- Disable all hooks except addUndoStack
	for i = 1,#cnvobj.hook do
		if cnvobj.hook[i].func ~= addUndoStack then
			cnvobj.hook[i].disable = true
		end
	end
	print("#################################DOING UNDO",skip)
	local unregrp = beginGroup()
	for j = #undo[i],1,-1 do
		if undo[i][j].type == "LUAGL" then
			cnvobj:undo(undo[i][j].diff)	-- redo is added automatically when addUndoStack is called as a hook for UNDOADDED
		else	-- undo[i][j].type == "FUNCTION"
			local redoFunc = undo[i][j].func()
			-- Add item to redo stack to redo
			addUndoFunction(redoFunc)
		end
	end
	table.remove(undo,i)
	endGroup(unregrp)
	toRedo = false
	skip = false
	print("#################################END UNDO",skip)
	-- Enable all hooks
	for i = 1,#cnvobj.hook do
		cnvobj.hook[i].disable = nil
	end	
	updateButtons()
end

-- skipUndo if true will skip adding the action to the undo stack
function doRedo(skipUndo)
	skip = skipUndo
	local i = #redo
	doingRedo = true
	-- Disable all hooks except addUndoStack
	for i = 1,#cnvobj.hook do
		if cnvobj.hook[i].func ~= addUndoStack then
			cnvobj.hook[i].disable = true
		end
	end
	print("#################################DOING REDO",skip)
	local unregrp = beginGroup()
	for j = #redo[i],1,-1 do
		if redo[i][j].type == "LUAGL" then
			cnvobj:undo(redo[i][j].diff)
		else	-- redo[i][j].type == "FUNCTION"
			local undoFunc = redo[i][j].func()
			addUndoFunction(undoFunc)
		end
	end	
	table.remove(redo,i)
	doingRedo = false
	endGroup(unregrp)
	skip = false
	print("#################################END REDO",skip)
	-- Enable all hooks
	for i = 1,#cnvobj.hook do
		cnvobj.hook[i].disable = nil
	end	
	updateButtons()
end	

function pauseUndoRedo()
	PAUSE = true
end

function resumeUndoRedo()
	PAUSE = nil
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
	hook = cnvobj:addHook("UNDOADDED",addUndoStack,"To add operations to the Undo Stack")
end
