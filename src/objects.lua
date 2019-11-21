-- Module to handle all object functions for Lua-GL

local type = type
local table = table
local math = math

local RECT = require("lua-gl.rectangle")
local LINE = require("lua-gl.line")
local ELLIPSE = require("lua-gl.ellipse")
local tu = require("tableUtils")


local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

M.RECT = RECT
M.FILLEDRECT = RECT
M.BLOCKINGRECT = RECT
M.LINE = LINE
M.ELLIPSE = ELLIPSE
M.FILLEDELLIPSE = ELLIPSE

-- The object structure looks like this:
--[[
{
	id = <integer>,			-- Unique identification number for the object
	shape = <string>,		-- string indicating the type of object. Each object type has its own handler module
	start_x = <integer>,	-- starting x coordinate of the bounding rectangle
	start_y = <integer>,	-- starting y coordinate of the bounding rectangle
	end_x = <integer>,		-- ending x coordinate of the bounding rectangle
	end_y = <integer>,		-- ending y coordinate of the bounding rectange
	group = <array or nil>,			-- Pointer to the array of object structures present in the group. nil if this object not in any group
	port = <array>			-- Array of port structures associated with the object
}
]]
-- The object structure is located at cnvobj.drawn.obj

-- Returns the object structure given the object ID
getObjFromID = function(cnvobj,objID)
	if not cnvobj or type(cnvobj) ~= "table" then
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
	if not cnvobj or type(cnvobj) ~= "table" then
		return
	end
	local objs = cnvobj.drawn.obj
	if #objs == 0 then
		return nil, "No object found"
	end
	local res = math.floor(math.min(cnvobj.grid_x,cnvobj.grid_y)/2)
	for i = 1,#objs do
		if _ENV[objs[i].shape].checkXY(x,y,res) then
			return objs[i]
		end
	end
	return nil, "No object found"
end

	-- groupShapes used to group Shape using shapeList
groupObjects = function(cnvobj,objList)
	if not cnvobj or type(cnvobj) ~= "table" then
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
	if not cnvobj or type(cnvobj) ~= "table" then
		return
	end
	
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
	local objs = cnvobj.drawn.obj
	-- button_CB to handle object drawing
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
		
		
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
			t.group = nil
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
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y,status})
	end
	
	function cnvobj.cnv:motion_cb(x, y, status)
		y = cnvobj.height - y
		objs[#objs].end_x = x
		objs[#objs].end_y = y
	end    
end	-- end drawObj function

