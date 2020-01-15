-- Module to handle all object functions for Lua-GL

local type = type
local table = table
local pairs = pairs
local tostring = tostring
local iup = iup

-- Math Library
local min = math.min
local floor = math.floor

local GUIFW = require("lua-gl.guifw")
local utility = require("lua-gl.utility")
local tu = require("tableUtils")
local coorc = require("lua-gl.CoordinateCalc")
local CONN = require("lua-gl.connector")
local PORTS = require("lua-gl.ports")
local router = require("lua-gl.router")

local print = print


local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- The object structure looks like this:
--[[
{
	id = <string>,			-- Unique identification number for the object. Format is O<num> i.e. O followed by a unique number
	shape = <string>,		-- string indicating the type of object. Each object type has its own handler module
	start_x = <integer>,	-- starting x coordinate of the bounding rectangle
	start_y = <integer>,	-- starting y coordinate of the bounding rectangle
	end_x = <integer>,		-- ending x coordinate of the bounding rectangle
	end_y = <integer>,		-- ending y coordinate of the bounding rectange
	group = <array or nil>,	-- Pointer to the array of object structures present in the group. nil if this object not in any group
	port = <array>,			-- Array of port structures associated with the object
	order = <integer>		-- Index in the order array
	vattr = <table>			-- (OPTIONAL) table containing the object visual attributes. If not present object drawn with default drawing settings
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
	local res = floor(min(cnvobj.grid.grid_x,cnvobj.grid.grid_y)/2)
	local allObjs = {}
	for i = 1,#objs do
		if M[objs[i].shape] and M[objs[i].shape].checkXY(objs[i],x,y,res) then
			allObjs[#allObjs + 1] = objs[i]
		end
	end
	return allObjs
end

-- Function to fix the order of all the items in the order table
local function fixOrder(cnvobj)
	-- Fix the order of all the items
	for i = 1,#cnvobj.drawn.order do
		cnvobj.drawn.order[i].item.order = i
	end
	return true
end

-- Function just offsets the objects (in grp array) and associated port coordinates. It does not handle the port connections which have to be updated
local shiftObjList = function(grp,offx,offy,rm)
	for i = 1,#grp do
		grp[i].start_x = grp[i].start_x + offx
		grp[i].start_y = grp[i].start_y + offy
		grp[i].end_x = grp[i].end_x and (grp[i].end_x + offx)
		grp[i].end_y = grp[i].end_y and (grp[i].end_y + offy)
		-- If blocking rectangle then remove from routing matrix and add the new postion
		if grp[i].shape == "BLOCKINGRECT" then
			rm:removeBlockingRectangle(grp[i])
			rm:addBlockingRectangle(grp[i],grp[i].start_x,grp[i].start_y,grp[i].end_x,grp[i].end_y)
		end
		-- Update port coordinates
		local portT = grp[i].port
		for j = 1,#portT do
			rm:removePort(portT[j])	-- Remove the port from the routing matrix
			portT[j].x = portT[j].x + offx
			portT[j].y = portT[j].y + offy
			-- Place the port in the routing matrix in the new position
			rm:addPort(portT[j],portT[j].x,portT[j].y)
		end
	end
	return true
end

-- Function to group a bunch of objects listed in objList
groupObjects = function(cnvobj,objList)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	local objs = cnvobj.drawn.obj	-- Data structure of all drawn objects
	if #objs == 0 then
		return
	end
	local groups = cnvobj.drawn.group	-- Data structure of all groups
	local objToGroup = tu.copyTable(objList,{})	-- Create a copy of the objList so not to modify it
	for k=1, #objList do	-- Check each object if it is a member of a group
		for i = #groups,1,-1 do		-- Iterate over all groups
			for j = 1,#groups[i] do		-- check each object in the group
				if objList[k] == groups[i][j] then
					objToGroup = tu.mergeArrays(groups[i],objToGroup)
					table.remove(groups,i)
					break
				end
			end
		end
	end
	groups[#groups+1] = objToGroup
	-- Sort the group elements in ascending order ranking
	table.sort(groups[#groups],function(one,two) 
			return one.order < two.order
	end)
	-- Update the obj group and collect the order number for each item in the group so they all can be grouped together in the order chain along the object with the highest order
	local order = cnvobj.drawn.order
	local grpOrder = {}
	local grp = objToGroup
	for i = 1,#grp do
		grp[i].group = grp		-- Set the object's group to grp
		grpOrder[i] = grp[i].order	-- record the object's order here
	end
	-- Update drawing order array
	-- All objects in the group get moved along the object with the highest order
	local pos = grpOrder[#grpOrder]-1	-- -1 because we delete the item from order before inserting it just before the highest order object
	for i = #grp-1,1,-1 do	-- grp is already sorted in ascending order number so grp[#grp] has the highest order. So start with #grp - 1
		local item = order[grpOrder[i]]
		-- Move this item to just above the last one
		table.remove(order,grpOrder[i])
		table.insert(order,pos,item)
	end
	-- Update the order number for all items
	for i = 1,#order do
		order[i].item.order = i
	end
	return true
end

-- Function to set the object Visual attributes
--[[
For non filled objects attributes to set are: (given a table (attr) with all these keys and attributes
* Draw color(color)	- Table with RGB e.g. {127,230,111}
* Line Style(style)	- number or a table. Number should be one of M.CONTINUOUS, M.DASHED, M.DOTTED, M.DASH_DOT, M.DASH_DOT_DOT. FOr table it should be array of integers specifying line length in pixels and then space length in pixels. Pattern repeats
* Line width(width) - number for width in pixels
* Line Join style(join) - should be one of the constants M.MITER, M.BEVEL, M.ROUND
* Line Cap style (cap) - should be one of the constants M.CAPFLAT, M.CAPROUND, M.CAPSQUARE
]]
--[[
For Filled objects the attributes to be set are:
* Fill Color(color)	- Table with RGB e.g. {127,230,111}
* Background Opacity (bopa) - One of the constants M.OPAQUE, M.TRANSPARENT	
* Fill interior style (style) - One of the constants M.SOLID, M.HOLLOW, M.STIPPLE, M.HATCH, M.PATTERN
* Hatch style (hatch) (OPTIONAL) - Needed if style == M.HATCH. Must be one of the constants M.HORIZONTAL, M.VERTICAL, M.FDIAGONAL, M.BDIAGONAL, M.CROSS or M.DIAGCROSS
* Stipple style (stipple) (OPTIONAL) - Needed if style = M.STIPPLE. Should be a  wxh matrix of zeros (0) and ones (1). The zeros are mapped to the background color or are transparent, according to the background opacity attribute. The ones are mapped to the foreground color.
* Pattern style (pattern) (OPTIONAL) - Needed if style = M.PATTERN. Should be a wxh color matrix of tables with RGB numbers`
]]
-- The function does not know whether the object is filled or not. It just checks the validity of the attr table and sets it for that object.
-- num is a index for the visual attribute definition and adds it to the defaults and other items can use it as well by referring to the number. It optimizes the render function as well since it does not have to reexecute the visual attributes settings if the number is the same for the next item to draw.
-- Set num to 100 to make it unique. 100 is reserved for uniqueness
function setObjVisualAttr(cnvobj,obj,attr,num)
	local res,filled = utility.validateVisualAttr(attr)
	if not res then
		return res,filled
	end
	-- attr is valid now associate it with the object
	obj.vattr = tu.copyTable(attr,{},true)	-- Perform full recursive copy of the attributes table
	-- Set the attributes function in the visual properties table
	if filled then
		cnvobj.attributes.visualAttr[obj] = {vAttr = num, visualAttr = GUIFW.getFilledObjAttrFunc(attr)}
	else
		cnvobj.attributes.visualAttr[obj] = {vAttr = num, visualAttr = GUIFW.getNonFilledObjAttrFunc(attr)}
	end
	return true
end

-- Function to move a list of objects provided with the given offset offx,offy which are added to the coordinates
-- if offx is not a number or not given then the move is done interactively
-- objList is a list of object structures of the objects to be moved
moveObj = function(cnvobj,objList,offx,offy)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	-- Check whether this is an interactive move or not
	print("MOVE OBJECT BEGIN")
	local interactive
	if not offx or type(offx) ~= "number" then
		interactive = true
	elseif not offy or type(offy) ~= "number" then
		return nil, "Coordinates not given"
	end
	local grp = {}	-- To compile the list of objects to move
	local grpsDone = {}		-- To flag which groups have been checked already
	local rm = cnvobj.rM
	
	-- Compile a list of objects by adding objects in the same group as the given objects
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
	
	-- Sort the group elements in ascending order ranking
	table.sort(grp,function(one,two) 
			return one.order < two.order
	end)
	
	if not interactive then
		-- Take care of grid snapping
		offx,offy = cnvobj:snap(offx,offy)
		local allConns = {}
		local allPorts = {}
		for i = 1,#grp do
			-- Move the object coordinates with their port coordinates
			grp[i].start_x = grp[i].start_x + offx
			grp[i].start_y = grp[i].start_y + offy
			grp[i].end_x = grp[i].end_x and (grp[i].end_x + offx)
			grp[i].end_y = grp[i].end_y and (grp[i].end_y + offy)
			-- If blocking rectangle then remove from routing matrix and add the new postion
			if grp[i].shape == "BLOCKINGRECT" then
				rm:removeBlockingRectangle(grp[i])
				rm:addBlockingRectangle(grp[i],grp[i].start_x,grp[i].start_y,grp[i].end_x,grp[i].end_y)
			end
			local ports = grp[i].port
			for j = 1,#ports do
				rm:removePort(ports[j])	-- Remove the port from the routing matrix
				ports[j].x = ports[j].x + offx
				ports[j].y = ports[j].y + offy
				-- Place the port in the routing matrix in the new position
				rm:addPort(ports[j],ports[j].x,ports[j].y)
				-- Disconnect any connectors
				local conns = ports[j].conn	-- table of connectors connected to this port
				for k = 1,#conns do		-- For every connector check its port table
					for l = #conns[k].port,1,-1 do
						-- Check which port matches ports[j] then remove it to disconnect the connector from the port
						if conns[k].port[l] == ports[j] then
							table.remove(conns[k].port,l)
							break
						end
					end
					allConns[#allConns + 1] = conns[k]
				end
				ports[j].conn = {}	-- Delete all the connectors from the port
				allPorts[#allPorts + 1] = ports[j]
			end
		end
		-- Short and Merge all the connectors that were connected to ports
		CONN.shortAndMergeConnectors(cnvobj,allConns)
		-- Connect ports to any overlapping connector on the port
		CONN.connectOverlapPorts(cnvobj,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
		-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
		PORTS.connectOverlapPorts(cnvobj,allPorts)
		return true
	end
	-- Setup the interactive move operation here
	-- Set refX,refY as the mouse coordinate on the canvas
	local gx,gy = iup.GetGlobal("CURSORPOS"):match("^(%d%d*)x(%d%d*)$")
	local sx,sy = cnvobj.cnv.SCREENPOSITION:match("^(%d%d*),(%d%d*)$")
	local refX,refY = gx-sx,gy-sy
	-- Backup the old button_cb and motion_cb
	local oldMCB = cnvobj.cnv.motion_cb
	local oldBCB = cnvobj.cnv.button_cb
	
	-- Backup the orders of the elements to move and change their orders to display in the front
	local order = cnvobj.drawn.order
	local oldOrder = {}
	for i = 1,#grp do
		oldOrder[i] = grp[i].order
	end
	-- Move the last item in the list to the end. Last item because it is te one with the highest order
	local item = cnvobj.drawn.order[grp[#grp].order]
	table.remove(cnvobj.drawn.order,grp[#grp].order)
	table.insert(cnvobj.drawn.order,item)
	-- Move the rest of the items on the last position
	for i = 1,#grp-1 do
		item = cnvobj.drawn.order[grp[i].order]
		table.remove(cnvobj.drawn.order,grp[i].order)
		table.insert(cnvobj.drawn.order,#cnvobj.drawn.order,item)
	end
	-- Update the order number for all items 
	fixOrder(cnvobj)
	
	local function moveEnd()
		-- Disconnect connectors connected to the ports and reconnect any connectors touching the current port positions
		-- Reset the orders back
		for i = 1,#grp do
			local item = cnvobj.drawn.order[grp[i].order]
			table.remove(cnvobj.drawn.order,grp[i].order)
			table.insert(cnvobj.drawn.order,oldOrder[i],item)
		end
		-- Update the order number for all items 
		fixOrder(cnvobj)
		-- Restore the previous button_cb and motion_cb
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB	
		print("Move end changed Button_CB and Motion_CB",cnvobj.op.coor1)
		local allConns = {}
		local allPorts = {}
		for i = 1,#grp do
			-- Object and ports move is already done in motion_cb
			-- Disconnect the connectors
			local ports = grp[i].port
			for j = 1,#ports do
				-- Disconnect any connectors
				local conns = ports[j].conn	-- table of connectors connected to this port
				for k = 1,#conns do		-- For every connector check its port table
					for l = #conns[k].port,1,-1 do
						-- Check which port matches ports[j] then remove it to disconnect the connector from the port
						if conns[k].port[l] == ports[j] then
							table.remove(conns[k].port,l)
							break
						end
					end
					allConns[#allConns + 1] = conns[k]
				end
				ports[j].conn = {}	-- Delete all the connectors from the port
				allPorts[#allPorts + 1] = ports[j]
			end
		end
		-- Short and Merge all the connectors that were connected to ports
		CONN.shortAndMergeConnectors(cnvobj,allConns)
		-- Connect ports to any overlapping connector on the port
		CONN.connectOverlapPorts(cnvobj,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
		-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
		PORTS.connectOverlapPorts(cnvobj,allPorts)
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
	end
	
	cnvobj.op.mode = "MOVEOBJ"	-- Set the mode to drawing object
	cnvobj.op.finish = moveEnd
	cnvobj.op.coor1 = {x=grp[1].start_x,y=grp[1].start_y}	-- Initial starting coordinate of the 1st object in the objList to serve as reference of the total movement
	
	-- button_CB to handle interactive move ending
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		--y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
		print("BUTTON_CB execution",button,iup.BUTTON1,pressed)
		if button == iup.BUTTON1 and pressed == 1 then
			-- End the move
			print("BUTTON_CB ending move",cnvobj.op.coor1)
			moveEnd()
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y,status})
	end
	
	function cnvobj.cnv:motion_cb(x,y,status)
		--y = cnvobj.height - y
		-- Move all items in the grp 
		--local xo,yo = x,y
		if cnvobj.op.mode == "MOVEOBJ" then
			x,y = cnvobj:snap(x-refX,y-refY)
			local offx,offy = x+cnvobj.op.coor1.x-grp[1].start_x,y+cnvobj.op.coor1.y-grp[1].start_y
			shiftObjList(grp,offx,offy,rm)
		end
		cnvobj:refresh()
	end	
	return true
end

-- Function to draw a shape on the canvas
-- shape is the shape that is being drawn
-- pts is the number of pts of the shape
-- coords is the table containing the coordinates of the shape the number of coordinates have to be pts
-- if coords is not a table then this will be an interactive drawing
drawObj = function(cnvobj,shape,pts,coords)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	
	-- Check whether this is an interactive move or not
	local interactive
	if type(coords) ~= "table" then
		interactive = true
	end
	
	local objs = cnvobj.drawn.obj	-- All drawn objects data structure
	local rm = cnvobj.rM
	
	if not interactive then
		-- Validate the coords table
		for i = 1,pts do
			if not coords[i].x or type(coords[i].x) ~= "number" or not coords[i].y or type(coords[i].y) ~= "number" then
				return nil, "Coordinates not given"
			end
		end
		-- Take care of coordinate snapping
		local x1,y1 = cnvobj:snap(coords[1].x,coords[1].y)
		local x2,y2
		if pts == 2 then
			x2,y2 = cnvobj:snap(coords[2].x,coords[2].y)
			if x1 == x2 and y1 == y2 then
				-- Zero dimension object not allowed
				return nil,"Zero dimension object not allowed"
			end
		end
		-- Draw the object by adding it to the data structures
		local t = {}
		t.id = "O"..tostring(objs.ids + 1)
		t.shape = shape
		t.start_x = x1
		t.start_y = y1
		t.end_x = x2
		t.end_y = y2
		t.group = nil
		t.order = #cnvobj.drawn.order + 1
		t.port = {}
		objs[#objs + 1] = t
		objs.ids = objs.ids + 1
		-- Add the object to be drawn in the order array
		cnvobj.drawn.order[#cnvobj.drawn.order + 1] = {
			type = "object",
			item = objs[#objs]
		}
		-- If blocking rectangle then add to routing matrix
		if shape == "BLOCKINGRECT" then
			rm:addBlockingRectangle(t,t.start_x,t.start_y,t.end_x,t.end_y)
		end		
		return t
	end
	-- Setup the interactive draw
	
	-- Backup the old button_cb and motion_cb functions
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
	
	-- Function to end the interactive drawing mode
	local function drawEnd()
		--print("drawEnd called")
		-- End the drawing
		-- Check if this is a zero dimension object then do not add anything
		local t = objs[cnvobj.op.index]
		if t.start_x == t.end_x and t.start_y == t.end_y then
			-- Zero dimension object not allowed
			-- Remove object from the object and the order arrays
			table.remove(cnvobj.drawn.order,t.order)
			fixOrder(cnvobj)
			table.remove(objs,cnvobj.op.index)
		else
			-- If blocking rectangle then add to routing matrix
			if shape == "BLOCKINGRECT" then
				rm:addBlockingRectangle(t,t.start_x,t.start_y,t.end_x,t.end_y)
			end		
		end
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB		
	end
	
	-- Object drawing methodology
	-- Object drawing starts (if 2 pt object) with Event 1. This event may be a mouse event or a keyboard event.
	-- Connector drawing stops with Event 2 (only for 2 pt object). This event may be a mouse event or a keyboard event.
	-- For now the events are defined as follows:
	-- Event 1 = Mouse left click
	-- Event 2 = Mouse left click after object start
	
	-- button_CB to handle object drawing
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		--y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
		local xo,yo = x,y
		x,y = cnvobj:snap(x,y)
		
		if button == iup.BUTTON1 and pressed == 1 then
			if cnvobj.op.mode == "DRAWOBJ" then
				drawEnd()
			else
				-- Start the drawing
				cnvobj.op.mode = "DRAWOBJ"	-- Set the mode to drawing object
				cnvobj.op.obj = shape
				cnvobj.op.finish = drawEnd
				cnvobj.op.order = #cnvobj.drawn.order + 1
				cnvobj.op.index = #objs + 1
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
				objs.ids = objs.ids + 1
				-- Add the object to be drawn in the order array
				cnvobj.drawn.order[cnvobj.op.order] = {
					type = "object",
					item = t
				}
				if pts == 1 then
					-- This is the end of the drawing
					t.end_x = nil
					t.end_y = nil
					
					drawEnd()
				end				
			end
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,xo,yo,status})
	end
	
	function cnvobj.cnv:motion_cb(x, y, status)
		if cnvobj.op.mode == "DRAWOBJ" then
			--y = cnvobj.height - y
			x,y = cnvobj:snap(x,y)
			objs[#objs].end_x = x
			objs[#objs].end_y = y
			cnvobj:refresh()
		end
	end    
end	-- end drawObj function

-- Function to drag objects (dragging implies connector connections are maintained)
-- objList is a list of object structures of the objects to be dragged
-- if offx is not a number or not given then the move is done interactively
-- dragRouter is the routing function to be using during dragging	-- only used if offx and offy are not given since then it will be interactive - default is cnvobj.options[0]
-- finalRouter is the routing function to be used after the drag has ended to finally route all the connectors - default is cnvobj.options.router[9]
-- jsFinal = jumpSeg parameter to be given to generateSegments functions to be used with the routing function (finalRouter) after drag has ended, default = 1
-- jsDrag = jumpSeg parameter to be given to generateSegments functions to be used with the routing function (dragRouter) durin drag operation, default = 1
-- jumpSeg parameter documentation says:
-- jumpSeg indicates whether to generate a jumping segment or not and if to set its attributes
--	= 1 generate jumping Segment and set its visual attribute to the default jumping segment visual attribute from the visualAttrBank table
-- 	= 2 generate jumping segment but don't set any special attribute
--  = false or nil then do not generate jumping segment
dragObj = function(cnvobj,objList,offx,offy,dragRouter,jsDrag,finalRouter,jsFinal)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	-- Check whether this is an interactive move or not
	local interactive
	if not offx or type(offx) ~= "number" then
		interactive = true
	elseif not offy or type(offy) ~= "number" then
		return nil, "Coordinates not given"
	end
	
	local rm = cnvobj.rM
	-- Collect all the objects that need to be dragged together by checking group memberships
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
	
	-- For all the connectors that would be affected create a list of starting points from where each connector would be routed from
	local connSrc = {}	-- To store the x,y coordinate for each connector from which rerouting has to be applied and also store the segments that need to be removed
	for i = 1,#grp do	-- For every object in the group that is moving
		connSrc[grp[i]] = {}	-- New table for this object
		local portT = grp[i].port	-- The port table of the object
		for j = 1,#portT do		-- check every port for the object
			local conn = portT[j].conn	-- Connector table of the port
			local enx,eny = portT[j].x,portT[j].y	-- This will be the end point where the segments connect to
			for k = 1,#conn do		-- for all connectors connected to this port of this object
				-- Find the 1st junction or if none the starting point of the connector
				local segTable = conn[k].segments
				local x,y = enx,eny
				local jT = conn[k].junction
				local found
				local checkedSegs = {}		-- Array to store segments already traversed to prevent traversing them again
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
					-- Find a segment whose one end is on x,y if none found this is the other end of the connector and would be the starting point for the connector routing
					found = true
					for l = 1,#segTable do
						if not tu.inArray(checkedSegs,segTable[l]) then
							-- This segment is not traversed
							if segTable[l].end_x == x and segTable[l].end_y == y then
								found = false
								x,y = segTable[l].start_x,segTable[l].start_y	-- Set x,y to the other end to traverse this segment
								checkedSegsCount = checkedSegsCount + 1
								checkedSegs[checkedSegsCount] = segTable[l]		-- add it to the segments traversed
								break
							elseif segTable[l].start_x == x and segTable[l].start_y == y then
								found = false
								x,y = segTable[l].end_x,segTable[l].end_y
								checkedSegsCount = checkedSegsCount + 1
								checkedSegs[checkedSegsCount] = segTable[l]		-- add it to the segments traversed
								break
							end
						end
					end		-- for l (segTable) ends here
				end
				-- Check if x,y is a port on another object being dragged
				local prts = PORTS.getPortFromXY(cnvobj,x,y)
				found = false		-- if true then all ports at this point are in the list of items to drag
				for l = 1,#prts do
					found = true
					if not tu.inArray(grp,prts[l].obj) then	-- Not all ports are in the list of items to drag so x,y can be used
						found = false
						break
					end
				end
				if found then
					connSrc[grp[i]][conn[k].id] = {x=enx,y=eny,segs={}}
				else
					connSrc[grp[i]][conn[k].id] = {x=x,y=y,segs=checkedSegs}		-- Source point to use for routing of the connector
				end
			end		-- For k (connector table) ends here
		end		-- For j (port table) ends here
	end		-- for i (group) ends here
		
	if not interactive then
		-- Take care of grid snapping
		offx,offy = cnvobj:snap(offx,offy)
		shiftObjList(grp,offx,offy,rm)
		local allPorts = {}
		local allConns = {}
		-- Now redo the connectors
		for i = 1,#grp do
			local portT = grp[i].port
			for j = 1,#portT do
				local conn = portT[j].conn
				for k = 1,#conn do
					-- Remove the segments that need to be rerouted
					local segsToRemove = connSrc[grp[i]][conn[k].id].segs
					for l = 1,#segsToRemove do
						local ind = tu.inArray(conn[k].segments,segsToRemove[l])
						rm:removeSegment(conn[k].segments[ind])
						table.remove(conn[k].segments,ind)
					end
					-- Regenerate the connector segments here
					router.generateSegments(cnvobj,connSrc[grp[i]][conn[k].id].x,connSrc[grp[i]][conn[k].id].y,portT[j].x,portT[j].y,conn[k].segments,cnvobj.options.router[9])
					allConns[#allConns + 1] = conn[k]
				end
				allPorts[#allPorts + 1] = portT[j]
			end
		end
		-- Short and Merge all the connectors that were connected to ports
		CONN.shortAndMergeConnectors(cnvobj,allConns)
		-- Check whether after drag the ports are touching other connectors then those get connected to the port
		CONN.connectOverlapPorts(cnvobj,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
		-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
		PORTS.connectOverlapPorts(cnvobj,allPorts)
		return true
	end
	-- Setup the interactive move operation here
	-- Set refX,refY as the mouse coordinate on the canvas
	local gx,gy = iup.GetGlobal("CURSORPOS"):match("^(%d%d*)x(%d%d*)$")
	local sx,sy = cnvobj.cnv.SCREENPOSITION:match("^(%d%d*),(%d%d*)$")
	local refX,refY = gx-sx,gy-sy
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
	-- Backup the orders of the elements to move and change their orders to display in the front
	local order = cnvobj.drawn.order
	local oldOrder = {}
	for i = 1,#grp do
		oldOrder[i] = grp[i].order
	end
	-- Move the last item in the list to the end. Last item because it is te one with the highest order
	local item = cnvobj.drawn.order[grp[#grp].order]
	table.remove(cnvobj.drawn.order,grp[#grp].order)
	table.insert(cnvobj.drawn.order,item)
	-- Move the rest of the items on the last position
	for i = 1,#grp-1 do
		item = cnvobj.drawn.order[grp[i].order]
		table.remove(cnvobj.drawn.order,grp[i].order)
		table.insert(cnvobj.drawn.order,#cnvobj.drawn.order,item)
	end
	-- Update the order number for all items 
	fixOrder(cnvobj)
	
	local function regenConn(rtr,js)
		-- Now redo the connectors
		for i = 1,#grp do
			local portT = grp[i].port
			for j = 1,#portT do
				local conn = portT[j].conn
				for k = 1,#conn do
					local segsToRemove = connSrc[grp[i]][conn[k].id].segs
					for l = 1,#segsToRemove do
						local ind = tu.inArray(conn[k].segments,segsToRemove[l])
						rm:removeSegment(segsToRemove[l])
						table.remove(conn[k].segments,ind)
					end
					-- Regenerate the connector segments here
					-- Add the new segments into checkedSegs for this connector for next time
					local ptr = connSrc[grp[i]][conn[k].id]
					ptr.segs = {}
					router.generateSegments(cnvobj,connSrc[grp[i]][conn[k].id].x,connSrc[grp[i]][conn[k].id].y,portT[j].x,portT[j].y,ptr.segs,rtr,js)
					-- Now add the new segments to connector segments
					tu.mergeArrays(ptr.segs,conn[k].segments,true)
				end
			end
		end		
	end
	
	finalRouter = finalRouter or cnvobj.options.router[9]
	jsFinal = jsFinal or 1
	local function dragEnd()
		-- End the drag at this point
		-- Regenerate the connectors
		regenConn(finalRouter,jsFinal)
		-- Reset the orders back
		for i = 1,#grp do
			local item = cnvobj.drawn.order[grp[i].order]
			table.remove(cnvobj.drawn.order,grp[i].order)
			table.insert(cnvobj.drawn.order,oldOrder[i],item)
		end
		-- Update the order number for all items 
		fixOrder(cnvobj)
		-- Restore the previous button_cb and motion_cb
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB
		-- Get all the ports that were dragged
		local allPorts = {}
		local allConns = {}
		for i = 1,#grp do
			local item = cnvobj.drawn.order[grp[i].order]
			table.remove(cnvobj.drawn.order,grp[i].order)
			table.insert(cnvobj.drawn.order,oldOrder[i],item)
			local portT = grp[i].port
			for j = 1,#portT do
				allPorts[#allPorts + 1] = portT[j]
				local conns = portT[j].conn	-- table of connectors connected to this port
				for k = 1,#conns do		-- For every connector check its port table
					allConns[#allConns + 1] = conns[k]
				end
			end			
		end
		-- Short and Merge all the connectors that were connected to ports
		CONN.shortAndMergeConnectors(cnvobj,allConns)
		-- Check whether after drag the ports are touching other connectors then those get connected to the port
		CONN.connectOverlapPorts(cnvobj,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
		-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
		PORTS.connectOverlapPorts(cnvobj,allPorts)
		-- Reset mode
		cnvobj:refresh()
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
	end
	
		
	cnvobj.op.mode = "DRAGOBJ"
	cnvobj.op.grp = grp
	cnvobj.op.oldOrder = oldOrder
	cnvobj.op.coor1 = {x=grp[1].start_x,y=grp[1].start_y}
	cnvobj.op.finish = dragEnd
	
	-- button_CB to handle object dragging
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		--y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		--print("DRAG button_Cb")
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y, status})
		if button == iup.BUTTON1 and pressed == 1 then
			--print("Drag end")
			dragEnd()
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y, status})
	end
	
	dragRouter = dragRouter or cnvobj.options.router[0]
	jsDrag = jsDrag or 2
	
	-- motion_cb to handle object dragging
	function cnvobj.cnv:motion_cb(x,y,status)
		--y = cnvobj.height - y
		-- Move all items in the grp 
		--local xo,yo = x,y
		x,y = cnvobj:snap(x-refX,y-refY)
		local offx,offy = x+cnvobj.op.coor1.x-grp[1].start_x,y+cnvobj.op.coor1.y-grp[1].start_y
		shiftObjList(grp,offx,offy,rm)
		-- Now redo the connectors
		regenConn(dragRouter,jsDrag)
		cnvobj:refresh()
	end
	return true
end