-- Module to handle all object functions for Lua-GL

local RECT = require("lua-gl.rectangle")
local LINE = require("lua-gl.line")
local ELLIPSE = require("lua-gl.ellipse")
local tu = require("tableUtils")


local M = {}
package.loaded[...] = M
_ENV = M

M.RECT = RECT
M.FILLEDRECT = RECT
M.BLOCKINGRECT = RECT
M.LINE = LINE
M.ELLIPSE = ELLIPSE
M.FILLEDELLIPSE = ELLIPSE

-- Returns the object structure given the object ID
getObjFromID = function(cnvobj,objID)
	if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
		return
	end
	if not objID or type(objID) ~= "number" then
		return nil,"Need valid shapeID"
	end
	local objs = cnvobj.drawn.obj
	for i = 1,#objs do
		if objs[i].id == objID then
			return objs[i]
		end
	end
	return nil,"No object found"
end

-- this function take x & y as input and return shapeID if point (x, y) is near to the shape
getObjFromXY = function(cnvobj,x,y)
	if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
		return
	end
	local objs = cnvobj.drawn.obj
	for i = 1,#objs do
		if _ENV[objs[i].shape].checkXY(x,y,math.floor(math.min(cnvobj.grid_x,cnvobj.grid_y)/2)) then
			return objs[i]
		end
	end
	return nil, "No object found"
end

	-- groupShapes used to group Shape using shapeList
groupObjects = function(cnvobj,objList)
	if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
		return
	end
	local objs = cnvobj.drawn.obj
	if #objs == 0 then
		return
	end
	local groups = cnvobj.drawn.group
	local tempTable = objList
	--print("you ar in group ing with len"..#shapeList)
	local match = false
	for k=1, #objList do
		for i = #groups,1,-1 do
			for j = 1,#groups[i] do
				if objList[k] == groups[i][j] then
					tempTable = tu.mergeArrays(groups[i],tempTable)
					table.remove(groups,i)
					match = true
					break
				end
			end
		end
	end
	if match == true then
		groups[#groups+1] = tempTable
	else
		groups[#groups+1] = objList
	end
	-- Update the shape group 
	for i = 1,groups[#groups] do
		groups[#groups][i].group = groups[#groups]
	end
end

drawObj = function(cnvobj,shape)
	if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
		return
	end
	
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
	local objs = cnvobj.drawn.obj
	-- button_CB to handle object drawing
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		processHooks(cnvobj,"MOUSECLICKPRE")
		
		
		if button == iup.BUTTON1 and pressed == 1 then
			cnvobj.op.mode = "DRAWOBJ"	-- Set the mode to drawing object
			cnvobj.op.obj = shape
			local t = {}
			t.id = #objs.ids + 1
			t.shape = shape
			t.start_x = x
			t.start_y = y
			t.end_x = x
			t.end_y = y 
			group = nil
			t.port = {}
			objs[#objs + 1] = t
		elseif button == iup.BUTTON1 and pressed == 0 then
			objs[#objs].end_x = x
			objs[#objs].end_y = y
			objs.ids = objs.ids + 1
			tableUtils.emptyTable(cnvobj.op)
			cnvobj.op.mode = "DISP"	-- Default display mode
			cnvobj.cnv.button_cb = oldBCB
			cnvobj.cnv.motion_cb = oldMCB
		end
		-- Process any hooks 
		processHooks(cnvobj,"MOUSECLICKPOST")
	end
	
	function cnvobj.cnv:motion_cb(x, y, status)
		y = cnvobj.height - y
		objs[#objs].end_x = x
		objs[#objs].end_y = y
	end    
end	-- end drawObj function

