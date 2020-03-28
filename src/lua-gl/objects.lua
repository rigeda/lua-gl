-- Module to handle all object functions for Lua-GL

local type = type
local table = table
local pairs = pairs
local tostring = tostring

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
local next = next
local error = error


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
	x = <array>,			-- Array of integer x coordinates
	y = <array>,			-- Array of integer y coordinates
	data = <table>			-- (OPTIONAL) Any table that has number, string, table and keys and number, string, boolean and table as values. The tables can be recursive. The structure of this table will be specific to its respective object handler
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
		if M[objs[i].shape] and M[objs[i].shape].checkXY(cnvobj,objs[i],x,y,res) then
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
shiftObjList = function(grp,offx,offy,rm)
	for i = 1,#grp do
		local objx,objy = grp[i].x,grp[i].y
		for j = 1,#objx do
			objx[j] = objx[j] + offx
			objy[j] = objy[j] + offy
		end
		-- If blocking rectangle then remove from routing matrix and add the new postion
		if grp[i].shape == "BLOCKINGRECT" then
			rm:removeBlockingRectangle(grp[i])
			rm:addBlockingRectangle(grp[i],grp[i].x[1],grp[i].y[1],grp[i].x[2],grp[i].y[2])
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
	local res,attrType = utility.validateVisualAttr(attr)
	if not res then
		return res,attrType
	end
	-- attr is valid now associate it with the object
	obj.vattr = tu.copyTable(attr,{},true)	-- Perform full recursive copy of the attributes table
	-- Set the attributes function in the visual properties table
	if attrType == "FILLED" then
		cnvobj.attributes.visualAttr[obj] = {vAttr = num, visualAttr = GUIFW.getFilledObjAttrFunc(attr)}
	elseif attrType == "NONFILLED" then
		cnvobj.attributes.visualAttr[obj] = {vAttr = num, visualAttr = GUIFW.getNonFilledObjAttrFunc(attr)}
	elseif attrType == "TEXT" then
		cnvobj.attributes.visualAttr[obj] = {vAttr = num, visualAttr = GUIFW.getTextAttrFunc(attr)}
	end
	return true
end

-- Function to remove an object from all data structures
-- Removes all references of the object from everywhere:
-- * cnvobj.drawn.obj
-- * cnvobj.drawn.group
-- * cnvobj.drawn.order
-- * cnvobj.drawn.port because ports attached to the object are also removed
-- * Routing Matrix
removeObj = function(cnvobj,obj)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	-- First update the routing matrix
	if obj.shape == "BLOCKINGRECT" then
		cnvobj.rM:removeBlockingRectangle(obj)
	end
	-- Remove from the order array
	table.remove(cnvobj.drawn.order,obj.order)
	fixOrder(cnvobj)
	-- Remove the ports
	local ind
	for i = 1,#obj.port do
		-- Remove references from any connectors it connects to
		for j = 1,#obj.port[i].conn do
			ind = tu.inArray(obj.port[i].conn[j].port,obj.port[i])
			table.remove(obj.port[i].conn[j].port,ind)
		end
		-- Remove the port from the port array
		ind = tu.inArray(cnvobj.drawn.port,obj.port[i])
		table.remove(cnvobj.drawn.port,ind)
		-- Remove the port from the routing matrix
		cnvobj.rM:removePort(obj.port[i])
	end
	-- Remove references from any groups
	if obj.group then
		for i = 1,#obj.group do
			local ind = tu.inArray(obj.group[i],obj)
			table.remove(obj.group[i],ind)
		end
	end
	-- remove from object array
	ind = tu.inArray(cnvobj.drawn.obj,obj)
	table.remove(cnvobj.drawn.obj,ind)
	-- All done
	return true
end

-- Function to return a list of all objects in objList as well as objects grouped with objects in objList
function populateGroupMembers(objList)
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
	return grp
end

-- Function to disconnect all the connectors from the list of objects given
-- Returns the list of connectors that were disconnected and the list of all ports in all the objects
disconnectAllConnectors = function(objList)
	local allConns = {}
	local allPorts = {}
	for i = 1,#objList do
		-- Object and ports move is already done in motion_cb
		-- Disconnect the connectors
		local ports = objList[i].port
		for j = 1,#ports do
			-- Disconnect any connectors
			local conns = ports[j].conn	-- table of connectors connected to this port
			for k = 1,#conns do		-- For every connector check its port table
				table.remove(conns[k].port,tu.inArray(conns[k].port,ports[j]))	-- Remove the port entry from the connector port table
				allConns[#allConns + 1] = conns[k]
			end
			ports[j].conn = {}	-- Delete all the connectors from the port
			allPorts[#allPorts + 1] = ports[j]
		end
	end
	return allConns, allPorts
end

-- Function to get the list of all ports and connectors in objList
getAllPortsAndConnectors = function(objList)
	local allPorts = {}
	local allConns = {}
	for i = 1,#objList do
		-- Object and ports move is already done in motion_cb
		-- Disconnect the connectors
		local ports = objList[i].port
		for j = 1,#ports do
			local conns = ports[j].conn	-- table of connectors connected to this port
			for k = 1,#conns do		-- For every connector check its port table
				allConns[#allConns + 1] = conns[k]
			end
			allPorts[#allPorts + 1] = ports[j]
		end
	end
	return allPorts, allConns
end

-- Function to move a list of objects provided with the given offset offx,offy which are added to the coordinates
-- if offx is not a number or not given then the move is done interactively
-- objList is a list of object structures of the objects to be moved
moveObj = function(cnvobj,objList,offx,offy)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	-- Check whether this is an interactive move or not
	--print("MOVE OBJECT BEGIN")
	local interactive
	if not offx or type(offx) ~= "number" then
		interactive = true
	elseif not offy or type(offy) ~= "number" then
		return nil, "Coordinates not given"
	end
	local rm = cnvobj.rM
	
	-- Compile a list of objects by adding objects in the same group as the given objects
	local grp = populateGroupMembers(objList)
	if #grp == 0 then
		return nil,"No objects to move"
	end
	
	-- Sort the group elements in ascending order ranking
	table.sort(grp,function(one,two) 
			return one.order < two.order
	end)

	-- Disconnect all the connectors from the objects being moved
	local allConns, allPorts = disconnectAllConnectors(grp)

	if not interactive then
		-- Take care of grid snapping
		offx,offy = cnvobj:snap(offx,offy)
		-- Shift all the objects in the list
		shiftObjList(grp,offx,offy,rm)
		-- Make all the port reconnections
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
	local refX,refY = cnvobj:sCoor2dCoor(GUIFW.getMouseOnCanvas(cnvobj))
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
	
	local opptr = #cnvobj.op + 1
	
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
		-- Make all the port reconnections here
		-- Short and Merge all the connectors that were connected to ports
		CONN.shortAndMergeConnectors(cnvobj,allConns)
		-- Connect ports to any overlapping connector on the port
		CONN.connectOverlapPorts(cnvobj,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
		-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
		PORTS.connectOverlapPorts(cnvobj,allPorts)	
		cnvobj.op[opptr] = nil
	end
	
	local op = {}
	cnvobj.op[opptr] = op
	op.mode = "MOVEOBJ"	-- Set the mode to drawing object
	op.finish = moveEnd
	op.coor1 = {x=grp[1].x[1],y=grp[1].y[1]}	-- Initial starting coordinate of the 1st object in the objList to serve as reference of the total movement
	op.ref = {x=refX,y=refY}
	op.objList = grp
	
	-- button_CB to handle interactive move ending
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		--y = cnvobj.height - y
		x,y = GUIFW.sCoor2dCoor(cnvobj,x,y)
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
		--print("BUTTON_CB execution",button,GUIFW.BUTTON1,pressed)
		if button == GUIFW.BUTTON1 and pressed == 1 then
			-- End the move
			moveEnd()
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y,status})
	end
	
	function cnvobj.cnv:motion_cb(x,y,status)
		--y = cnvobj.height - y
		x,y = GUIFW.sCoor2dCoor(cnvobj,x,y)
		-- Move all items in the grp 
		--local xo,yo = x,y
		if op.mode == "MOVEOBJ" then
			x,y = cnvobj:snap(x-refX,y-refY)
			local offx,offy = x+op.coor1.x-grp[1].x[1],y+op.coor1.y-grp[1].y[1]
			shiftObjList(grp,offx,offy,rm)
			cnvobj:refresh()
		end
	end	
	return true
end

-- Function to draw a shape on the canvas
-- shape is the shape that is being drawn
-- coords is the table containing the coordinates of the shape the number of coordinates have to be pts
-- if coords is not a table then this will be an interactive drawing
-- data is an optional parameter which is set to obj.data. This is object handler specific and should be provided as such. The object handler will validate it.
drawObj = function(cnvobj,shape,coords,data)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	if not M[shape] then
		return nil,"Shape not available"
	end
	if M[shape].validateData then
		local stat,msg = M[shape].validateData(data)
		if not stat then
			return nil,msg
		end
	end
	-- pts is the number of pts of the shape
	local pts = M[shape].pts
	-- Check whether this is an interactive move or not
	local interactive
	if type(coords) ~= "table" then
		interactive = true
	end
	
	local objs = cnvobj.drawn.obj	-- All drawn objects data structure
	local rm = cnvobj.rM
	
	if not interactive then
		-- Validate the coords table
		local x,y = {},{}
		for i = 1,pts do
			if not coords[i].x or type(coords[i].x) ~= "number" or not coords[i].y or type(coords[i].y) ~= "number" then
				return nil, "Coordinates not given"
			end
			-- Take care of coordinate snapping
			x[i],y[i] = cnvobj:snap(coords[i].x,coords[i].y)
		end
		local stat,msg = M[shape].validateCoords(x,y)
		if not stat then
			return nil,msg
		end
		-- Draw the object by adding it to the data structures
		local t = {}
		t.id = "O"..tostring(objs.ids + 1)
		t.shape = shape
		t.x = x
		t.y = y
		t.data = data
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
			rm:addBlockingRectangle(t,t.x[1],t.y[1],t.x[2],t.y[2])
		end		
		return t
	end
	-- Setup the interactive draw
	
	-- Backup the old button_cb and motion_cb functions
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
	
	local opptr
	-- Function to end the interactive drawing mode
	local function drawEnd()
		--print("drawEnd called")
		-- End the drawing
		-- Check if this is a zero dimension object then do not add anything
		local t = objs[cnvobj.op[opptr].index]
		-- Check if coordinates are valid
		local stat,msg = M[shape].validateCoords(t.x,t.y)
		if not stat then
			-- Coordinates not valid
			-- Remove object from the object and the order arrays
			table.remove(cnvobj.drawn.order,t.order)
			fixOrder(cnvobj)
			table.remove(objs,cnvobj.op[opptr].index)
		else
			-- If blocking rectangle then add to routing matrix
			if shape == "BLOCKINGRECT" then
				rm:addBlockingRectangle(t,t.x[1],t.y[1],t.x[2],t.y[2])
			end		
		end
		cnvobj.op[opptr] = nil
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB		
		cnvobj:refresh()
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
		x,y = GUIFW.sCoor2dCoor(cnvobj,x,y)
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
		local xo,yo = x,y
		x,y = cnvobj:snap(x,y)
		
		if button == GUIFW.BUTTON1 and pressed == 1 then
			if opptr and cnvobj.op[opptr].mode == "DRAWOBJ" then
				local x,y = objs[cnvobj.op[opptr].index].x,objs[cnvobj.op[opptr].index].y
				if M[shape].endDraw(x,y) then
					drawEnd()
				else
					cnvobj.op[opptr].cindex = #x + 1
				end
			else
				-- Start the drawing
				local op = {}
				cnvobj.op[#cnvobj.op + 1] = op
				opptr = #cnvobj.op
				op.mode = "DRAWOBJ"	-- Set the mode to drawing object
				op.obj = shape
				op.finish = drawEnd
				op.order = #cnvobj.drawn.order + 1
				op.index = #objs + 1
				op.cindex = 2
				local t = {}
				t.id = "O"..tostring(objs.ids + 1)
				t.shape = shape
				t.x,t.y = M[shape].initObj(x,y)
				t.group = nil
				t.data = data
				t.order = #cnvobj.drawn.order + 1
				t.port = {}
				objs[#objs + 1] = t
				objs.ids = objs.ids + 1
				-- Add the object to be drawn in the order array
				cnvobj.drawn.order[op.order] = {
					type = "object",
					item = t
				}
				if pts == 1 then
					drawEnd()
				end				
			end
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,xo,yo,status})
	end
	
	function cnvobj.cnv:motion_cb(x, y, status)
		if opptr and cnvobj.op[opptr].mode == "DRAWOBJ" then
			--y = cnvobj.height - y
			x,y = GUIFW.sCoor2dCoor(cnvobj,x,y)
			x,y = cnvobj:snap(x,y)
			local cindex = cnvobj.op[opptr].cindex
			objs[#objs].x[cindex] = x
			objs[#objs].y[cindex] = y
			cnvobj:refresh()
		end
	end    
end	-- end drawObj function

-- Function to return the list of nodes from where each connector needs to be routed to a particular port when an object is dragged. If the segment connected to the port exists in segList then that node is not added to be routed
-- segList is a list of structures like this:
--[[
{
	conn = <connector structure>,	-- Connector structure to whom this segment belongs to 
	seg = <integer>					-- segment index of the connector
}
]]
-- objList is a list of objects
generateRoutingStartNodes = function(cnvobj,objList,segList)
	-- For all the connectors that would be affected create a list of starting points from where each connector would be routed from
	segList = segList or {}
	local connSrc = {}	-- To store the x,y coordinate for each connector (for a particular port of an object) from which rerouting has to be applied and also store the segments that need to be removed
	local delSegs = {}	-- To accumulate all segments to delete stored in connSrc so that they are not duplicated
	for i = 1,#objList do	-- For every object in the group that is moving
		connSrc[objList[i]] = {}	-- New table for this object
		local portT = objList[i].port	-- The port table of the object
		for j = 1,#portT do		-- check every port for the object
			connSrc[objList[i]][portT[j]] = {}	-- Each port can have multiple connectors that may need routing
			local conn = portT[j].conn	-- Connector table of the port
			local enx,eny = portT[j].x,portT[j].y	-- This will be the end point where the segments connect to
			-- Check if there are other ports here
			local prts = PORTS.getPortFromXY(cnvobj,enx,eny)
			found = false		-- if true then all ports at this point are in the list of items to drag
			for l = 1,#prts do
				found = true
				if not tu.inArray(objList,prts[l].obj) then	-- Not all ports are in the list of items to drag so x,y can be used
					found = false
					break
				end
			end
			if #prts == 1 or (#prts > 1 and found) then
				-- Only this port here or More ports at this point and all of them are moving so we need to find the connector routing points
				for k = 1,#conn do		-- for all connectors connected to this port of this object
					-- Find the 1st junction or if none the starting point of the connector
					local segTable = conn[k].segments
					local x,y = enx,eny
					local jT = conn[k].junction
					local found,segDragging	-- segDragging if true means that the segment of conn[k] connected to portT[j] is in segList so this connector routing to the port should not be done and it is skipped from adding to connSrc
					local checkedSegs = {}		-- Array to store segments already traversed to prevent traversing them again
					local checkedSegsCount = 0
					local prex,prey
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
									-- Check if this segment exists in segList
									for m = 1,#segList do
										if segList[m].conn == conn[k] and l == segList[m].seg then
											segDragging = true
											found = true
											if checkedSegsCount > 2 then
												-- For the segment that is being dragged if it is the 1st or second then don't include the routing since the segment drag will include these segments to drag together, if it is after second segment then the routing has to be done from prex and prey since that will be used as a dragNode in the segment drag as well
												x,y = prex,prey
											end
											break
										end
									end
									prex,prey = segTable[l].end_x,segTable[l].end_y
									break
								elseif segTable[l].start_x == x and segTable[l].start_y == y then
									found = false
									x,y = segTable[l].end_x,segTable[l].end_y
									checkedSegsCount = checkedSegsCount + 1
									checkedSegs[checkedSegsCount] = segTable[l]		-- add it to the segments traversed
									-- Check if this segment exists in segList
									for m = 1,#segList do
										if segList[m].conn == conn[k] and l == segList[m].seg then
											segDragging = true
											found = true
											if checkedSegsCount > 2 then
												-- For the segment that is being dragged if it is the 1st or second then don't include the routing since the segment drag will include these segments to drag together, if it is after second segment then the routing has to be done from prex and prey since that will be used as a dragNode in the segment drag as well
												x,y = prex,prey
											end
											break
										end
									end
									prex,prey = segTable[l].start_x,segTable[l].start_y
									break
								end		-- if segTable[l].end_x == x and segTable[l].end_y == y ends here
							end		-- if not tu.inArray(checkedSegs,segTable[l]) ends here
						end		-- for l (segTable) ends here
					end		-- while not found ends here
					-- Remove the segments that are already added to delSegs
					for m = checkedSegsCount,1,-1 do
						if tu.inArray(delSegs,checkedSegs[m]) then
							table.remove(checkedSegs,m)
						else
							delSegs[#delSegs + 1] = checkedSegs[m]
						end
					end
					if not segDragging then	-- if segDragging then the segment of this connector connected to portT[j] or a subsequent segment
						-- Check if x,y is a port on another object being dragged
						local prts = PORTS.getPortFromXY(cnvobj,x,y)
						found = false		-- if true then all ports at this point are in the list of items to drag
						for l = 1,#prts do
							found = true
							if not tu.inArray(objList,prts[l].obj) then	-- Not all ports are in the list of items to drag so x,y can be used
								found = false
								break
							end
						end
						if found then
							connSrc[objList[i]][portT[j]][conn[k].id] = {coor=prts[1],segs=checkedSegs}	-- To make the routing point linked to the port
						else
							connSrc[objList[i]][portT[j]][conn[k].id] = {coor={x=x,y=y},segs=checkedSegs}		-- Source point to use for routing of the connector
						end
					else	-- if not segDragging else
						if checkedSegsCount > 2 then
							-- Remove the last 2 segments in checkedSegs
							table.remove(checkedSegs)
							table.remove(checkedSegs)
							connSrc[objList[i]][portT[j]][conn[k].id] = {coor={x=x,y=y},segs=checkedSegs}		-- Source point to use for routing of the connector
						end
					end		-- if not segDragging ends
				end		-- For k (connector table) ends here
			else	-- -- if #prts > 1 and found then else
				-- More ports here and not all of them are moving
				-- So routing point will be here for the connector connecting this port to one of the other ports
				local found
				for k = 1,#prts do
					for m = 1,#prts[k].conn do
						if tu.inArray(conn,prts[k].conn[m]) then
							connSrc[objList[i]][portT[j]][prts[k].conn[m].id] = {coor={x=enx,y=eny},segs={}}
							found = true
							break
						end
					end
					if found then break end
				end
			end		-- if #prts > 1 and found then ends
		end		-- For j (port table) ends here
	end		-- for i (group) ends here	
	return connSrc
end

-- Function to regenerate the connector to the ports after an object is moved based on the coordinates present in connSrc
-- connSrc is the data structure generated by generateRoutingStartNodes
function regenConn(cnvobj,rm,objList,connSrc,rtr,js)
	-- Now redo the connectors
	local delSegs = {}			-- To accumulate all segments to that were added to the connector so that repeated segments are not added
	--[[
	local stat,dump = utility.checkRM(cnvobj,true)
	if not stat then
		print("ROUTING MATRIX ERROR AT regenConn BEGIN: ",dump)
		error()
	end
	]]
	for i = 1,#objList do
		local portT = objList[i].port
		for j = 1,#portT do
			local conn = portT[j].conn
			for k = 1,#conn do
				delSegs[conn[k]] = delSegs[conn[k]] or {}	-- Maintain separate lists for each connector
				local cS = connSrc[objList[i]][portT[j]][conn[k].id]
				if cS then
					local segsToRemove = cS.segs
					-- Remove the previously geenrated segments
					for l = 1,#segsToRemove do
						local ind = tu.inArray(conn[k].segments,segsToRemove[l])
						rm:removeSegment(segsToRemove[l])
						table.remove(conn[k].segments,ind)
					end
					-- Regenerate the connector segments here
					-- Add the new segments into checkedSegs for this connector for next time
					local newsegs = {}
					-- Check if source and destination points already exist on the connector
					local connSegs = conn[k].segments
					local stfound,enfound
					for m = 1,#connSegs do
						if connSegs[m].start_x == cS.coor.x and connSegs[m].start_y == cS.coor.y then
							stfound = true
						end
						if connSegs[m].end_x == cS.coor.x and connSegs[m].end_y == cS.coor.y then
							stfound = true
						end
						if connSegs[m].start_x == portT[j].x and connSegs[m].start_y == portT[j].y then
							enfound = true
						end
						if connSegs[m].end_x == portT[j].x and connSegs[m].end_y == portT[j].y then
							enfound = true
						end	
						if enfound and stfound then
							break
						end
					end
					if not enfound or not stfound then
						router.generateSegments(cnvobj,cS.coor.x,cS.coor.y,portT[j].x,portT[j].y,newsegs,rtr,js)
					end
					-- Remove the segments that are already added to delSegs
					for m = #newsegs,1,-1 do
						if tu.inArray(delSegs[conn[k]],newsegs[m],function(v1,v2)
							return v1.start_x == v2.start_x and v1.start_y == v2.start_y and v1.end_x == v2.end_x and v1.end_y == v2.end_y
						  end) then
							rm:removeSegment(newsegs[m])
							table.remove(newsegs,m)
						else
							delSegs[conn[k]][#delSegs[conn[k]] + 1] = newsegs[m]
							-- Add the segment to conn[k] segments
							connSegs[#connSegs + 1] = newsegs[m]
						end
					end
					cS.segs = newsegs
				end		-- if cS then ends here
			end		-- for k = 1,#conn do ends here
		end		-- for j = 1,#portT do ends here
	end		-- for i = 1,#objList do ends here
	--[[
	stat,dump = utility.checkRM(cnvobj,true)
	if not stat then
		print("ROUTING MATRIX ERROR AT regenConn END: ",dump)
		error()
	end
	]]
	return true
end

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
	
	finalRouter = finalRouter or cnvobj.options.router[9]
	jsFinal = jsFinal or 1
	
	dragRouter = dragRouter or cnvobj.options.router[0]
	jsDrag = jsDrag or 2
	
	local rm = cnvobj.rM
	-- Collect all the objects that need to be dragged together by checking group memberships
	local grp = populateGroupMembers(objList)
	if #grp == 0 then
		return nil,"No objects to drag"
	end
	-- Sort the group elements in ascending order ranking
	table.sort(grp,function(one,two) 
			return one.order < two.order
	end)

	local p = print
	local n = next
	
	-- For all the connectors that would be affected create a list of starting points from where each connector would be routed from
	local connSrc = generateRoutingStartNodes(cnvobj,grp)
		
	if not interactive then
		-- Take care of grid snapping
		offx,offy = cnvobj:snap(offx,offy)
		shiftObjList(grp,offx,offy,rm)
		local allPorts,allConns = getAllPortsAndConnectors(grp)
		-- Regenerate the segments according to the coordinates calculated in connSrc
		regenConn(cnvobj,rm,grp,connSrc,finalRouter,jsFinal)
		-- Short and Merge all the connectors that were connected to ports
		CONN.shortAndMergeConnectors(cnvobj,allConns)
		-- Check whether after drag the ports are touching other connectors then those get connected to the port
		CONN.connectOverlapPorts(cnvobj,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
		-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
		PORTS.connectOverlapPorts(cnvobj,allPorts)
		return true
	end
	-- Setup the interactive move operation here
	-- Set refX,refY as the mouse coordinate on the canvas equivalent to database coordinates
	local refX,refY = cnvobj:sCoor2dCoor(GUIFW.getMouseOnCanvas(cnvobj))
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
	
	local opptr = #cnvobj.op + 1
		
	local function dragEnd()
		-- End the drag at this point
		-- Regenerate the segments according to the coordinates calculated in connSrc
		regenConn(cnvobj,rm,grp,connSrc,finalRouter,jsFinal)
		-- Reset the orders back
		for i = 1,#grp do
			local item = cnvobj.drawn.order[grp[i].order]
			table.remove(cnvobj.drawn.order,grp[i].order)
			table.insert(cnvobj.drawn.order,oldOrder[i],item)
		end
		-- Update the order number for all items 
		fixOrder(cnvobj)
		local stat,dump = utility.checkRM(cnvobj,true)
		if not stat then
			print("ROUTING MATRIX ERROR AT dragEnd BEGIN: ",dump)
			error()
		end
		-- Restore the previous button_cb and motion_cb
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB
		-- Get all the ports that were dragged
		local allPorts,allConns = getAllPortsAndConnectors(grp)
		-- Short and Merge all the connectors that were connected to ports
		CONN.shortAndMergeConnectors(cnvobj,allConns)
		stat,dump = utility.checkRM(cnvobj,true)
		if not stat then
			print("ROUTING MATRIX ERROR AT dragEnd after Short and Merge: ",dump)
			error()
		end
		-- Check whether after drag the ports are touching other connectors then those get connected to the port
		CONN.connectOverlapPorts(cnvobj)--,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
		stat,dump = utility.checkRM(cnvobj,true)
		if not stat then
			print("ROUTING MATRIX ERROR AT dragEnd after CONN.connectOverlapPorts: ",dump)
			error()
		end
		-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
		PORTS.connectOverlapPorts(cnvobj,allPorts)
		stat,dump = utility.checkRM(cnvobj,true)
		if not stat then
			print("ROUTING MATRIX ERROR AT dragEnd after PORTS.connectOverlapPorts: ",dump)
			error()
		end
		-- Reset mode
		cnvobj:refresh()
		cnvobj.op[opptr] = nil
	end
	
	local op = {}
	cnvobj.op[opptr] = op
	op.mode = "DRAGOBJ"
	op.grp = grp
	op.oldOrder = oldOrder
	op.coor1 = {x=grp[1].x[1],y=grp[1].y[1]}
	op.ref = {x=refX,y=refY}
	op.finish = dragEnd
	op.objList = grp
	
	-- button_CB to handle object dragging
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		--y = cnvobj.height - y
		x,y = GUIFW.sCoor2dCoor(cnvobj,x,y)
		-- Check if any hooks need to be processed here
		--print("DRAG button_Cb")
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y, status})
		if button == GUIFW.BUTTON1 and pressed == 1 then
			--print("Drag end")
			dragEnd()
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y, status})
	end
	
	-- motion_cb to handle object dragging
	function cnvobj.cnv:motion_cb(x,y,status)
		--y = cnvobj.height - y
		x,y = GUIFW.sCoor2dCoor(cnvobj,x,y)
		-- Move all items in the grp 
		--local xo,yo = x,y
		x,y = cnvobj:snap(x-refX,y-refY)
		local offx,offy = x+op.coor1.x-grp[1].x[1],y+op.coor1.y-grp[1].y[1]
		shiftObjList(grp,offx,offy,rm)
		-- Regenerate the segments according to the coordinates calculated in connSrc
		regenConn(cnvobj,rm,grp,connSrc,dragRouter,jsDrag)
		cnvobj:refresh()
	end
	return true
end