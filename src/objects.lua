-- Module to handle all object functions for Lua-GL

local type = type
local table = table
local math = math
local pairs = pairs
local tostring = tostring

local RECT = require("lua-gl.rectangle")
local LINE = require("lua-gl.line")
local ELLIPSE = require("lua-gl.ellipse")
local tu = require("tableUtils")
local coorc = require("lua-gl.CoordinateCalc")
local CONN = require("lua-gl.connector")


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
	id = <integer>,			-- Unique identification number for the object. Format is O<num> i.e. O followed by a unique number
	shape = <string>,		-- string indicating the type of object. Each object type has its own handler module
	start_x = <integer>,	-- starting x coordinate of the bounding rectangle
	start_y = <integer>,	-- starting y coordinate of the bounding rectangle
	end_x = <integer>,		-- ending x coordinate of the bounding rectangle
	end_y = <integer>,		-- ending y coordinate of the bounding rectange
	group = <array or nil>,			-- Pointer to the array of object structures present in the group. nil if this object not in any group
	port = <array>,			-- Array of port structures associated with the object
	order = <integer>		-- Index in the order array
}
]]
-- The object structure is located at cnvobj.drawn.obj

-- Returns the object structure given the object ID
getObjFromID = function(cnvobj,objID)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	if not objID or not objID:match("O%d%d*") then
		return nil,"Need valid object id"
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
		return nil,"Not a valid lua-gl object"
	end
	local objs = cnvobj.drawn.obj
	if #objs == 0 then
		return {}
	end
	local res = math.floor(math.min(cnvobj.grid_x,cnvobj.grid_y)/2)
	local allObjs = {}
	for i = 1,#objs do
		if M[objs[i].shape].checkXY(x,y,res) then
			allObjs[#allObjs + 1] = objs[i]
		end
	end
	return allObjs
end

-- Function to group a bunch of objects listed in objList
groupObjects = function(cnvobj,objList)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
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
	-- Sort the group elements in ascending order ranking
	table.sort(groups[#groups],function(one,two) 
			return one.order < two.order
	end)
	-- Update the obj group and collect the order number for each item in the group so they all can be grouped together in the order chain along the object with the highest order
	local order = cnvobj.drawn.order
	local grpOrder = {}
	local grp = groups[#groups]
	for i = 1,#grp do
		grp[i].group = grp
		grpOrder[i] = grp[i].order
	end
	table.sort(grpOrder)
	-- Update drawing order array
	-- All objects in the group get moved along the object with the highest order
	local pos = grpOrder[#grpOrder]-1
	for i = #grp-1,1,-1 do
		local item = order[grpOrder[i]]
		-- Move this item to just above the last one
		table.remove(order,grpOrder[i])
		table.insert(order,item,pos)
	end
	-- Update the order number for all items
	for i = 1,#order do
		order[i].item.order = i
	end
end

-- Function to move a list of objects provided as a id list with the given offset offx,offy which are added to the coordinates
-- if offx is not a number but evaluates to true then the move is done interactively
-- objList is a list of object structures of the objects to be dragged
moveObj = function(cnvobj,objList,offx,offy)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	-- Check whether this is an interactive move or not
	local interactive
	if offx and type(offx) ~= "number" then
		interactive = true
	elseif not offx or not offy or type(offx) ~= "number" or type(offy) ~= "number" then
		return nil, "Coordinates not given"
	end
	local grp = {}
	local grpsDone = {}
	
	-- Combile a list of objects by adding objects in the same group as the given objects
	for i = 1,#objList do
		local obj = objList[i]
		if obj.group then
			if not grpsDone[obj.group] then
				for j = 1,#obj.group do
					grp[#grp + 1] = obj.group[j]
				end
				grpsDone[obj.group] = true
			end
		else
			grp[#grp + 1] = obj
		end
	end
	if #grp == 0 then
		return nil,"No objects to move"
	end
	
	if not interactive then
		-- Take care of grid snapping
		local grdx,grdy = cnvobj.grid_x,cnvobj.grid_y
		if not cnvobj.snapGrid then
			grdx,grdy = 1,1
		end
		offx = coorc.snapX(offx, grdx)
		offy = coorc.snapY(offy, grdy)
		for i = 1,#grp do
			-- Move the object coordinates with their port coordinates
			grp[i].start_x = grp[i].start_x + offx
			grp[i].start_y = grp[i].start_y + offy
			grp[i].end_x = grp[i].end_x + offx
			grp[i].end_y = grp[i].end_y + offy
			for j = 1,#grp[i].port do
				grp[i].port[j].x = grp[i].port[j].x + offx
				grp[i].port[j].y = grp[i].port[j].y + offy
				-- Disconnect any connectors
				-- Connect ports to any overlapping connector on the port
				grp[i].port[j].conn = cnvobj:getConnFromXY(grp[i].port[j].x,grp[i].port[j].y)
			end
		end
		return true
	end
	-- Setup the interactive move operation here
	local oldMCB = cnvobj.cnv.motion_cb
	local oldBCB = cnvobj.cnv.button_cb
	
	local function moveEnd()
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB				
	end
	
	cnvobj.op.mode = "MOVEOBJ"	-- Set the mode to drawing object
	cnvobj.op.end = moveEnd
	
	-- button_CB to handle interactive move ending
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
		if button == iup.BUTTON1 and pressed == 1 then
			-- End the move
			moveEnd()
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,xo,yo,status})
	end
	
	function cnvobj.cnv:motion_cb(x,y,status)
		y = cnvobj.height - y
		for i = 1,#grp do
			-- Move the object coordinates with their port coordinates
		end
	end
	
	return true
end

drawObj = function(cnvobj,shape,interactive)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
	local objs = cnvobj.drawn.obj
	
	local function drawEnd()
		-- End the drawing
		objs[#objs].end_x = x
		objs[#objs].end_y = y
		objs.ids = objs.ids + 1
		-- Add the object to be drawn in the order array
		cnvobj.drawn.order[#cnvobj.drawn.order + 1] = {
			type = "object",
			item = objs[#objs]
		}
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB		
	end
	-- button_CB to handle object drawing
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
		local xo,yo = x,y
		local grdx,grdy = cnvobj.grid_x,cnvobj.grid_y
		if not cnvobj.snapGrid then
			grdx,grdy = 1,1
		end
		x = coorc.snapX(x, grdx)
		y = coorc.snapY(y, grdy)
		
		if button == iup.BUTTON1 and pressed == 1 then
			-- Start the drawing
			cnvobj.op.mode = "DRAWOBJ"	-- Set the mode to drawing object
			cnvobj.op.obj = shape
			cnvobj.op.end = drawEnd
			local t = {}
			t.id = "O"..tostring(objs.ids + 1)
			t.shape = shape
			t.start_x = x
			t.start_y = y
			t.end_x = x
			t.end_y = y 
			t.group = nil
			t.order = #cnvobj.drawn.order + 1
			t.port = {}
			objs[#objs + 1] = t
		elseif button == iup.BUTTON1 and pressed == 0 then
			drawEnd()
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,xo,yo,status})
	end
	
	function cnvobj.cnv:motion_cb(x, y, status)
		y = cnvobj.height - y
		local grdx,grdy = cnvobj.grid_x,cnvobj.grid_y
		if not cnvobj.snapGrid then
			grdx,grdy = 1,1
		end
		x = coorc.snapX(x, grdx)
		y = coorc.snapY(y, grdy)
		objs[#objs].end_x = x
		objs[#objs].end_y = y
	end    
end	-- end drawObj function

-- Function to drag objects (dragging implies connector connections are maintained 
-- objList is a list of object structures of the objects to be dragged
dragObj = function(cnvobj,objList,offx,offy)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	-- Check whether this is an interactive move or not
	local interactive
	if offx and type(offx) ~= "number" then
		interactive = true
	elseif not offx or not offy or type(offx) ~= "number" or type(offy) ~= "number" then
		return nil, "Coordinates not given"
	end
	-- Set refX,refY as the mouse coordinate on the canvas
	
	local refX,refY
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
	local grp = {}
	local grpsDone = {}
	for i = 1,#objList do
		local obj = objList[i]
		if obj.group then
			if not grpsDone[obj.group] then
				for j = 1,#obj.group do
					grp[#grp + 1] = obj.group[j]
				end
				grpsDone[obj.group] = true
			end
		else
			grp[#grp + 1] = obj
		end
	end
	if #grp == 0 then
		return nil,"No objects to drag"
	end
	-- Sort the group elements in ascending order ranking
	table.sort(grp,function(one,two) 
			return one.order < two.order
	end)
	-- Backup the orders of the elements to move and change their orders to display in the front
	local order = cnvobj.drawn.order
	local oldOrder = {}
	for i = 1,#grp do
		oldOrder[i] = grp[i].order
	end
	table.remove(cnvobj.drawn.order,grp[#grp].order)
	table.insert(cnvobj.drawn.order,grp[#grp],#cnvobj.drawn.order+1)
	for i = #grp-1,1,-1 do
		table.remove(cnvobj.drawn.order,grp[i].order)
		table.insert(cnvobj.drawn.order,grp[i],#cnvobj.drawn.order)
	end
	-- Update the order number for all items 
	for i = 1,#order do
		order[i].item.order = i
	end
	
	local function moveEnd()
		-- End the move at this point
		-- Reset the orders back
		for i = 1,#grp do
			table.remove(cnvobj.drawn.order,grp[i].order)
			table.insert(cnvobj.drawn.order,grp[i],oldOrder[i])
		end
		-- Update the order number for all items
		for i = 1,#order do
			order[i].item.order = i
		end
		-- Reset mode
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB
	end
	
	-- For all the connectors that would be affected create a list of starting points from where each connector would be routed from
	local connSrc = {}	-- To store the x,y coordinate for each connector from which rerouting has to be applied and also store the segments that need to be removed
	for i = 1,#grp do	-- For every object in the group that is moving
		local portT = grp[i].port	
		for j = 1,#portT do		-- check every port for the object
			local conn = portT[j].conn
			local enx,eny = portT[j].x,portT[j].y
			for k = 1,#conn do		-- for all connectors connected to this port of this object
				-- Find the 1st junction or if none the starting point of the connector
				local segTable = conn[k].segments
				local x,y = enx,eny
				local jT = conn[k].junction
				local found
				local checkedSegs = {}		-- Array to store index of segments already traversed to prevent traversing them again
				local checkedSegsCount = 0
				while not found do
					-- Check if a junction exists on x,y
					for l = 1,#jT do
						if jT[l].x == x and jT[l].y == y then
							found = true
							break
						end
					end
					if found then break end
					-- Find a segment whose one end is on x,y
					found = true
					for l = 1,#segTable do
						if not checkedSegs[l] then
							-- This segment is not traversed
							if segTable[l].end_x == x and segTable[l].end_y == y then
								found = false
								x,y = segTable[l].start_x,segTable[l].start_y
								checkedSegs[l] = true
								checkedSegsCount = checkedSegsCount + 1
								break
							elseif segTable[l].start_x == x and segTable[l].start_y == y then
								found = false
								x,y = segTable[l].end_x,segTable[l].end_y
								checkedSegs[l] = true
								checkedSegsCount = checkedSegsCount + 1
								break
							end
						end
					end		-- for l (segTable) ends here
				end
				connSrc[conn[k].id] = {x=x,y=y,segs=checkedSegs,segsCount = checkedSegsCount}		-- Source point to use for routing of the connector
				-- Move the traversed segments to the end of the segments array
				for l,_ in pairs(connSrc[conn[k].id].segs) do
					local item = conn[k].segments[l]
					table.remove(conn[k].segments,l)	-- Remove
					table.insert(conn[k].segments,item)	-- Insert at end
				end				
			end		-- For k (connector table) ends here
		end		-- For j (port table) ends here
	end		-- for i (group) ends here
	
		
	cnvobj.op.mode = "DRAGOBJ"
	cnvobj.op.grp = grp
	cnvobj.op.oldOrder = oldOrder
	cnvobj.op.coor1 = {x=grp[1].start_x,y=grp[1].start_y}
	cnvobj.op.end = moveEnd
	
	-- button_CB to handle object drawing
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y, status})
		if button == iup.BUTTON1 and pressed == 1 then
			moveEnd()
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y, status})
	end

	function cnvobj.cnv:motion_cb(x,y,status)
		y = cnvobj.height - y
		-- Move all items in the grp 
		--local xo,yo = x,y
		local grdx,grdy = cnvobj.grid_x,cnvobj.grid_y
		if not cnvobj.snapGrid then
			grdx,grdy = 1,1
		end
		x = coorc.snapX(x, grdx)
		y = coorc.snapY(y, grdy)
		local offx,offy = (x-refX)+cnv.op.coor1.x-grp[1].start_x,(y-refY)+cnv.op.coor1.y-grp[1].start_y
		for i = 1,#grp do
			grp[i].start_x = grp[i].start_x + offx
			grp[i].end_x = grp[i].end_x + offx
			grp[i].start_y = grp[i].start_y + offy
			grp[i].end_y = grp[i].end_y + offy
			-- Update port coordinates
			local portT = grp[i].port
			for j = 1,#portT do
				portT[j].x = portT[j].x + offx
				portT[j].y = portT[j].y + offy
			end
		end
		-- Now redo the connectors
		for i = 1,#grp do
			local portT = grp[i].port
			for j = 1,#portT do
				local conn = portT[j].conn
				for k = 1,#conn do
					local segStart = #conn[k].segments-connSrc[conn[k].id].segsCount+1
					for l = #conn[k].segments,segStart,-1 do
						table.remove(conn[k].segments,l)
					end
					-- Regenerate the connector segments here
					CONN.generateSegments(cnvobj,connSrc[conn[k].id].x,connSrc[conn[k].id].y,portT[j].x,portT[j].y,conn[k].segments)
				end
			end
		end
	end
end,
