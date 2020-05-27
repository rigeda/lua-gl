local table = table
local pairs = pairs
local print = print
local error = error
local pcall = pcall
local type = type
local assert = assert

local math = math
local setmetatable = setmetatable
local getmetatable = getmetatable
local tonumber = tonumber
local tostring = tostring

local GUIFW = require("lua-gl.guifw")
local objects = require("lua-gl.objects")
local ports = require("lua-gl.ports")
local conn = require("lua-gl.connector")
local hooks = require("lua-gl.hooks")
local tu = require("tableUtils")
local router = require("lua-gl.router")
local coorc = require("lua-gl.CoordinateCalc")
local utility = require("lua-gl.utility")

-- Add the shapes. The shape modules will register themselves to the respective modules when their init functions are called
local RECT = require("lua-gl.rectangle")
local ELLIPSE = require("lua-gl.ellipse")
local LINE = require("lua-gl.line")
local TEXT = require("lua-gl.text")


local crouter 
do
	local ret,msg = pcall(require,"luaglib.crouter")
	if ret then
		crouter = msg
	end
end

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

_VERSION = "B23.05.19"

--- TASKS
--[[
DEBUG:

TASKS:
* add copy functionality
* Add file linked data methodology to Demo and lua-gl library
* Connector labeling - object to segment grouping
* Add object resize functionality
]]

-- Initialize all the shapes
local function initShapes(cnvobj)
	-- Register the shapes
	RECT.init(cnvobj)
	LINE.init(cnvobj)
	ELLIPSE.init(cnvobj)
	TEXT.init(cnvobj)
	GUIFW.init(cnvobj)
end

-- Returns the visual attribute structure with the visual attribute function
local function getVisualAttr(cnvobj,item)
	local vattr = item.vattr	-- attribute structure stored in the item. If the item has a specific attribute it will be here
	local vattrTab = cnvobj.attributes.visualAttr[item]
	-- vattrTab is a table with the following minimum information:
	--[[
	{
		vAttr=<integer>,
		visualAttr=<function>,
		attr=<table>
	}
	vAttr integer may point to a viewOptions.visualProp index (-1 is reserved and does not point to it). The integer is used in the rendering function so decide when to change drawing attributes. If the previous item drawn had the same integer then the visualAttr function is not called.
	]]
	---if vattr is nil then the vattrTab will also be nil because there is no special attribute in that case pick the vattrTab as registered in GUIFW as the default one.
	if not vattr then	-- item did not have a specific attribute so get default from the GUIFW module
		-- pick the default one
		if item.shape then
			-- This is object
			vattr = GUIFW[item.shape].attr
			vattrTab = GUIFW[item.shape]
		else
			-- This must be a segment or connector
			vattr = GUIFW.CONN.attr
			vattrTab = GUIFW.CONN
		end
	end
	return vattr,vattrTab,cnvobj.attributes.visualAttr[item]
end

-- Function to remove the visual attribute of the item
local function removeVisualAttr(cnvobj,item)
	cnvobj.attributes.visualAttr[item] = nil
	item.vattr = nil
end

-- Function to fix the order of all the items in the order table
local function fixOrder(cnvobj)
	-- Fix the order of all the items
	for i = 1,#cnvobj.drawn.order do
		cnvobj.drawn.order[i].item.order = i
	end
	return true
end

-- Function to separate the objects list and the segments list from items
-- items is an array with either of the 2 things:
-- * object structure
-- * structure with the following data
--[[
{
	conn = <connector structure>,	-- Connector structure to whom this segment belongs to 
	seg = <integer>					-- segment index of the connector
}	]]
local function separateObjSeg(items)
	local objList = {}
	local segList = {}
	for i = 1,#items do
		if items[i].id then
			-- This must be an object
			objList[#objList + 1] = items[i]
		else
			-- This must be a segment specification
			segList[#segList + 1] = items[i]
		end
	end
	return objList,segList
end


-- This is the metatable that contains the API of the library that can be used by the host program
local objFuncs
objFuncs = {
	
	-- Function to save the drawn data and return it as a string that can be passed to the load function to load it into the drawn structures.
	save = function(cnvobj)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj).__index ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		-- First check if any operation is happenning then end it
		local op = cnvobj.op
		while op[#op].finish and type(op[#op].finish) == "function" do
			op[#op].finish()
		end
		return tu.t2sr(cnvobj.drawn)
	end,
	
	-- Function to rotate/flip a coordinate
	rotateFlip = function(cnvobj,x,y,refx,refy,para)
		if para ~= 90 and para ~= 180 and para ~= 270 and para ~= "h" and para ~= "v" then
			return nil,"Not a valid rotation angle or flip direction"
		end
		
		local rot = {
			[90] = function(x,y)
				return refx+refy-y,x-refx+refy
			end,
			[180] = function(x,y)
				return 2*refx-x,2*refy-y
			end,
			[270] = function(x,y)
				return refx-refy+y,refx+refy-x
			end,
			h = function(x,y)
				return 2*refx-x,y
			end,
			v = function(x,y)
				return x,2*refy-y
			end
		}
		return rot[para](x,y)
	end,
	
	-- Function to rotate or flip the list of items around a reference point given by refx,refy
	-- para can be one of the following 90,180,270,h,v. If 90,180,270 then that rotation is applied. If h then horizontal flip otherwise vertical flip
	-- items is an array with either of the 2 things:
	-- * object structure
	-- * structure with the following data
	--[[
{
	conn = <connector structure>,	-- Connector structure to whom this segment belongs to 
	seg = <integer>					-- segment index of the connector
}	]]
	-- This is a non interactive function totally 
	-- It just transforms the coordinates of the items does not short or repair the connectors or ports etc.
	-- It also does not try to separate the segments from its connectors or disconnect the object ports from its connectors
	rotateFlipItems = function(cnvobj,items,refx,refy,para)
		if para ~= 90 and para ~= 180 and para ~= 270 and para ~= "h" and para ~= "v" then
			return nil,"Not a valid rotation angle or flip direction"
		end
		
		local rot = {
			[90] = function(x,y)
				return refx+refy-y,x-refx+refy
			end,
			[180] = function(x,y)
				return 2*refx-x,2*refy-y
			end,
			[270] = function(x,y)
				return refx-refy+y,refx+refy-x
			end,
			h = function(x,y)
				return 2*refx-x,y
			end,
			v = function(x,y)
				return x,2*refy-y
			end
		}
		
		-- Setup undo
		local key = utility.undopre(cnvobj)
		local objList,segList = separateObjSeg(items)
		-- Rotate the objects
		for i = 1,#objList do
			-- Rotate the object
			local objx,objy = objList[i].x,objList[i].y
			for j = 1,#objx do
				objx[j],objy[j] = rot[para](objx[j],objy[j])
			end
			-- Rotate the port coordinates as well
			local prts = objList[i].port
			for j = 1,#prts do
				prts[j].x,prts[j].y = rot[para](prts[j].x,prts[j].y)
			end
		end
		-- Rotate the segments
		for i = 1,#segList do
			--local seg = segList[i].conn.segments[segList[i].seg]
			local seg = segList[i].seg
			seg.start_x,seg.start_y = rot[para](seg.start_x,seg.start_y)
			seg.end_x,seg.end_y = rot[para](seg.end_x,seg.end_y)
		end
		utility.undopost(cnvobj,key)
		return true
	end,
	
	-- Function to copy the list of items
	-- It returns a structure equivalent to the cnvobj.drawn structure which can be converted to string and then loaded
	-- using the load api function
	-- items is an array with either of the 2 things:
	-- * object structure
	-- * structure with the following data
	--[[
		{
			conn = <connector structure>,	-- Connector structure to whom this segment belongs to 
			seg = <integer>					-- segment index of the connector
		}
	]]
	-- nogroup if true only the objects in the items will be moved not their associated grouped objects
	copy = function(cnvobj,items,nogroup)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj).__index ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		-- The cnvobj.drawn structure looks like this:
		--[=[
		cnvobj.drawn = {
			obj = {ids=0},		-- array of object structures. See structure in objects.lua
			group = {},			-- array of arrays containing objects intended to be grouped together
			port = {ids=0},		-- array of port structures. See structure of port in ports.lua
			conn = {ids=0},		-- array of connector structures. See structure of connector in connector.lua
			order = {},			-- array of structures containing the things to draw in order
			--[[ Order stucture looks like this:
			{
				[i] = {
					type = <string>,	-- string describing what type of item this is. Values are like "object", "connector"
					item = <table>		-- table structure of the item that is at this order position. For object it will be the object structure. For connector it will be the connector structure.
				},
			}
			]]
		}	]=]
		-- Separate the objects list and the segments list
		local objList,segList = separateObjSeg(items)
		local drawn = {
			obj = {ids = 0},
			group = {},
			port = {ids=0},
			conn = {ids=0},
			order = {}
		}
		local orderMap = {}
		local copyMap = {}
		local obj = drawn.obj
		local port = drawn.port
		local grp = drawn.group
		local conn = drawn.conn
		-- Function to copy the port structure. Connectors are not copied nor the object
		local function copyPortData(p)
			port.ids = port.ids + 1
			port[#port + 1] = {
				id = "P"..tostring(port.ids),
				conn = {},
				x = p.x,
				y = p.y
			}
			return port[#port]
		end
		-- Function to copy everything in the given object structure except group and order
		local function copyObjectData(o)
			-- Create a new id
			obj.ids = obj.ids + 1
			obj[#obj + 1] = {
				id = "O"..tostring(obj.ids),
				shape = o.shape,
				x = tu.copyTable(o.x,{}),
				y = tu.copyTable(o.y,{}),
				port = {}
			}
			if o.data then
				obj[#obj].data = tu.copyTable(o.data,{},true)
			end
			if o.vattr then
				obj[#obj].vattr = tu.copyTable(o.vattr,{},true)
			end
			-- Copy the ports
			local pc = obj[#obj].port
			for i = 1,#o.port do
				local p = copyPortData(o.port[i])
				pc[#pc+1] = p
				p.obj = obj[#obj]
			end
			orderMap[#orderMap + 1] = {order=o.order,item=obj[#obj],type="object"}
			return obj[#obj]
		end
		for i = 1,#objList do
			if not copyMap[objList[i]] then	-- still not copied
				copyMap[objList[i]] = true
				-- Copy the object
				local o = copyObjectData(objList[i])
				-- Copy the group members
				if objList[i].group and not nogroup then
					grp[#grp + 1] = {o}
					o.group = grp[#grp]
					for j = 1,#objList[i].group do
						if objList[i].group[j] ~= objList[i] then
							grp[#grp][#grp[#grp]+1] = copyObjectData(objList[i].group[j])
							grp[#grp][#grp[#grp]].group = grp[#grp]
							copyMap[objList[i].group[j]] = true
						end
					end
				end					
			end
		end
		-- Now copy over the connector segments
		for i = 1,#segList do
			if not copyMap[segList[i].conn] then
				copyMap[segList[i].conn] = true
				-- Collect all the segments for this connector
				local allSegs = {segList[i]}
				for j = 1,#segList do
					if j ~= i then
						if segList[j].conn == segList[i].conn then
							allSegs[#allSegs+1] = segList[j]
						end
					end
				end
				-- Now from allSegs create connectors of disjoined segment groups
				local conngrps = {}
				local c = allSegs[1].conn	-- The connector
				while #allSegs > 0 do
					local added
					-- Check if any segment goes into existing conngrps
					for j = #allSegs,1,-1 do
						local seg = c.segments[allSegs[j].seg]
						for k = 1,#conngrps do
							for m = 1,#conngrps[k] do
								if seg.start_x == conngrps[k][m].start_x and seg.start_y == conngrps[k][m].start_y or 
								  seg.start_x == conngrps[k][m].end_x and seg.start_y == conngrps[k][m].end_y or
								  seg.end_x == conngrps[k][m].start_x and seg.end_y == conngrps[k][m].start_y or
								  seg.end_x == conngrps[k][m].end_x and seg.end_y == conngrps[k][m].end_y then
									--this segment can be in this conngrp
									added = true
									conngrps[k][#conngrps[k]+1] = seg
									if conngrps[k].ep[seg.start_x] then
										if conngrps[k].ep[seg.start_x][seg.start_y] then
											conngrps[k].ep[seg.start_x][seg.start_y] = conngrps[k].ep[seg.start_x][seg.start_y] + 1
										else
											conngrps[k].ep[seg.start_x][seg.start_y] = 1
										end
									else
										conngrps[k].ep[seg.start_x] = {
											[seg.start_y] = 1
										}
									end
									if conngrps[k].ep[seg.end_x] then
										if conngrps[k].ep[seg.end_x][seg.end_y] then
											conngrps[k].ep[seg.end_x][seg.end_y] = conngrps[k].ep[seg.end_x][seg.end_y] + 1
										else
											conngrps[k].ep[seg.end_x][seg.end_y] = 1
										end
									else
										conngrps[k].ep[seg.end_x] = {
											[seg.end_y] = 1
										}
									end
									break
								end		-- if seg connection to end point ends here
							end	-- for m = 1,#conngrps[k] ends here
							if added then break end
						end		-- for k = 1,#conngrps ends here	
						if added then
							table.remove(allSegs,j)
						end
					end		-- for j = 1,#allSegs ends here
					if not added then
						-- Create a new connector with the 1st segment in allSegs
						local seg = c.segments[allSegs[1].seg]
						conngrps[#conngrps + 1] = {
							seg,
							ep = {
								[seg.start_x] = {
									[seg.start_y] = 1
								},
								[seg.end_x] = {
									[seg.end_y] = 1
								}
							}
						}
						table.remove(allSegs,1)
					end
				end		-- while #allSegs > 0 do ends
				-- Now take all the segment groups in conngrps and make connectors with it
				for j = 1,#conngrps do
					conn.ids = conn.ids + 1
					conn[#conn + 1] = {
						id = "C"..tostring(conn.ids),
						port = {},
						junction = {},
						vattr = c.vattr and tu.copyTable(c.vattr,{},true)
					}
					-- Fill the junctions
					local jn = conn[#conn].junction
					for x,yt in pairs(conngrps[j].ep) do
						for y,num in pairs(yt) do
							-- Check if a port exits at this coordinate
							for k = 1,#port do
								if port[k].x == x and port[k].y == y then
									conn[#conn].port[#conn[#conn].port+1] = port[k]
								end
							end
							if num > 2 then	-- greater than 2 segments were at this point
								jn[#jn + 1] = {x=x,y=y}
							end
						end						
					end
					-- Copy the segments
					local segm = {}
					for k = 1,#conngrps[j] do
						segm[#segm + 1] = tu.copyTable(conngrps[j][k],{},true)
					end
					conn[#conn].segments = segm
					orderMap[#orderMap + 1] = {order = c.order,item = conn[#conn],type="connector"}
				end		-- for j = 1,#conngrps do ends
			end		-- if not copyMap[segList[i].conn] then ends
		end		-- for i = 1,#segList do ends
		
		-- Now setup the order structure and fix the orders
		table.sort(orderMap,function(one,two)
				return one.order < two.order
			end)
		for i = 1,#orderMap do
			drawn.order[#drawn.order + 1] = {type = orderMap[i].type,item=orderMap[i].item}
		end
		for i = 1,#drawn.order do
			drawn.order[i].item.order = i
		end
		return drawn
	end,
	
	-- Function to move the list of items by moving all the items offx and offy offsets	
	-- if offx is not a number then the movement is done interactively with a mouse
	-- items is an array with either of the 2 things:
	-- * object structure
	-- * structure with the following data
	--[[
		{
			conn = <connector structure>,	-- Connector structure to whom this segment belongs to 
			seg = <integer>					-- segment index of the connector
		}
	]]
	-- nogroup if true only the objects in the items will be moved not their associated grouped objects
	move = function(cnvobj,items,offx,offy,nogroup)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj).__index ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		-- Check whether this is an interactive move or not
		local interactive
		if not offx or type(offx) ~= "number" then
			interactive = true
		elseif not offy or type(offy) ~= "number" then
			return nil, "Coordinates not given"
		end
		
		-- Separate the objects list and the segments list
		local objList,segList = separateObjSeg(items)
		-- If these are all objects or all segments then just redirect
		if #objList == 0 then
			return conn.moveSegment(cnvobj,segList,offx,offy)
		elseif #segList == 0 then
			return objects.moveObj(cnvobj,objList,offx,offy)
		end
		-- Setup undo
		local key = utility.undopre(cnvobj)
		
		-- Now we split the connectors at the segments to separate them out into connectors that need to be moved just like we did in moveSegment		
		local connM = conn.splitConnectorAtSegments(cnvobj,segList)	-- connM will get the list of connectors now that have to be moved
		
		-- Disconnect all ports in the connector
		conn.disconnectAllPorts(connM)
		
		-- Setup the objects for move
		local rm = cnvobj.rM
		
		local grp
		if nogroup then
			grp = objList
		else
			-- Compile a list of objects by adding objects in the same group as the given objects
			grp = objects.populateGroupMembers(objList)
		end
		
		-- Disconnect all the connectors from the objects being moved
		local allConns, allPorts = objects.disconnectAllConnectors(grp)
		-- Merge allConns with connM
		tu.mergeArrays(connM,allConns,false)
		
		if not interactive then
			-- Move everything in the list by offx,offy 
			-- Take care of grid snapping
			offx,offy = cnvobj:snap(offx,offy)
			-- Shift all the objects in the list
			objects.shiftObjList(grp,offx,offy,rm)
			-- Now move the connectors
			conn.shiftConnList(connM,offx,offy,rm)

			-- WRAP UP
			-- Check all the ports in the drawn structure and see if any port lies on this connector then connect to it
			conn.assimilateConnList(cnvobj,allConns)
			-- Connect ports to any overlapping connector on the port. These are the ports that were moved with the objects
			conn.connectOverlapPorts(cnvobj,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
			-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
			ports.connectOverlapPorts(cnvobj,allPorts)		
			utility.undopost(cnvobj,key)
			return true
		end
		-- Setup the interactive move operation here
		-- Set refX,refY as the mouse coordinate on the canvas
		local refX,refY = cnvobj:sCoor2dCoor(GUIFW.getMouseOnCanvas(cnvobj))
		local oldBCB = cnvobj.cnv.button_cb
		local oldMCB = cnvobj.cnv.motion_cb
		
		-- Sort the group elements in ascending order ranking
		table.sort(grp,function(one,two) 
				return one.order < two.order
		end)

		-- Sort the connector elements in ascending order ranking
		table.sort(connM,function(one,two) 
				return one.order < two.order
		end)
		
		-- Backup the orders of the elements to move and change their orders to display in the front
		local order = cnvobj.drawn.order
		local oldObjOrder = {}
		for i = 1,#grp do
			oldObjOrder[i] = grp[i].order
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
		
		-- Backup the orders of the elements to move and change their orders to display in the front
		local oldConnOrder = {}
		for i = 1,#connM do
			oldConnOrder[i] = connM[i].order
		end
		
		-- Move the last item in the list to the end. Last item because it is te one with the highest order
		item = cnvobj.drawn.order[connM[#connM].order]
		table.remove(cnvobj.drawn.order,connM[#connM].order)
		table.insert(cnvobj.drawn.order,item)
		-- Move the rest of the items on the last position
		for i = 1,#connM-1 do
			item = cnvobj.drawn.order[connM[i].order]
			table.remove(cnvobj.drawn.order,connM[i].order)
			table.insert(cnvobj.drawn.order,#cnvobj.drawn.order,item)
		end
		-- Update the order number for all items 
		fixOrder(cnvobj)
		
		local opptr = #cnvobj.op + 1
		
		local function moveEnd()
			-- Disconnect connectors connected to the ports and reconnect any connectors touching the current port positions
			-- Reset the orders back
			-- First do the connectors
			for i = 1,#connM do
				local item = cnvobj.drawn.order[connM[i].order]
				table.remove(cnvobj.drawn.order,connM[i].order)
				table.insert(cnvobj.drawn.order,oldConnOrder[i],item)
			end
			-- Update the order number for all items 
			fixOrder(cnvobj)
			-- Now do the objects
			for i = 1,#grp do
				local item = cnvobj.drawn.order[grp[i].order]
				table.remove(cnvobj.drawn.order,grp[i].order)
				table.insert(cnvobj.drawn.order,oldObjOrder[i],item)
			end
			-- Update the order number for all items 
			fixOrder(cnvobj)
			-- Restore the previous button_cb and motion_cb
			cnvobj.cnv.button_cb = oldBCB
			cnvobj.cnv.motion_cb = oldMCB	
			
			-- Check all the ports in the drawn structure and see if any port lies on this connector then connect to it
			conn.assimilateConnList(cnvobj,allConns)
			-- Connect ports to any overlapping connector on the port. These are the ports that were moved with the objects
			conn.connectOverlapPorts(cnvobj,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
			-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
			ports.connectOverlapPorts(cnvobj,allPorts)		
			cnvobj:refresh()
			cnvobj.op[opptr] = nil
			utility.undopost(cnvobj,key)
		end
		
		local op = {}
		cnvobj.op[opptr] = op
		op.mode = "MOVE"	-- Set the mode to drawing object
		op.finish = moveEnd
		op.coor1 = {x=grp[1].x[1],y=grp[1].y[1]}	-- Initial starting coordinate of the 1st object in the objList to serve as reference of the total movement
		op.ref = {x=refX,y=refY}
		op.objList = grp
		op.connList = connM
		
		-- button_CB to handle interactive move ending
		function cnvobj.cnv:button_cb(button,pressed,x,y, status)
			x,y = GUIFW.sCoor2dCoor(cnvobj,x,y)
			-- Check if any hooks need to be processed here
			cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
			if button == GUIFW.BUTTON1 and pressed == 1 then
				-- End the move
				moveEnd()
			end
			-- Process any hooks 
			cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y,status})
		end
		
		function cnvobj.cnv:motion_cb(x,y,status)
			-- Move all items in the grp 
			if op.mode == "MOVE" then
				x,y = GUIFW.sCoor2dCoor(cnvobj,x,y)
				x,y = cnvobj:snap(x-refX,y-refY)
				local offx,offy = x+op.coor1.x-grp[1].x[1],y+op.coor1.y-grp[1].y[1]
				-- Now move the objects
				objects.shiftObjList(grp,offx,offy,rm)
				-- Now move the connectors
				conn.shiftConnList(connM,offx,offy,rm)				
				cnvobj:refresh()
			end
		end	
		op.motion = cnvobj.cnv.motion_cb
		return opptr
	end,
	
	-- Function to drag a list of items by moving all the items offx and offy offsets	
	-- if offx is not a number then the movement is done interactively with a mouse
	-- items is an array with either of the 2 things:
	-- * object structure
	-- * structure with the following data
	--[[
		{
			conn = <connector structure>,	-- Connector structure to whom this segment belongs to 
			seg = <integer>					-- segment index of the connector
		}	
	]]
	-- nogroup if true only the objects in the items will be moved not their associated grouped objects	
	drag = function(cnvobj,items,offx,offy,finalRouter,jsFinal,dragRouter,jsDrag,nogroup)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj).__index ~= objFuncs then
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
		
		finalRouter = finalRouter or cnvobj.options.router[9]
		jsFinal = jsFinal or 1
		
		dragRouter = dragRouter or cnvobj.options.router[0]
		jsDrag = jsDrag or 2
		
		-- Separate the objects list and the segments list
		local objList = {}
		local segList = {}
		for i = 1,#items do
			if items[i].id then
				-- This must be an object
				objList[#objList + 1] = items[i]
			else
				-- This must be a segment specification
				segList[#segList + 1] = items[i]
			end
		end
		-- If these are all objects or all segments then just redirect
		if #objList == 0 then
			return conn.dragSegment(cnvobj,segList,offx,offy)
		elseif #segList == 0 then
			return objects.dragObj(cnvobj,objList,offx,offy)
		end
		
		-- Setup undo
		local key = utility.undopre(cnvobj)
		local grp
		if nogroup then
			grp = objList
		else
			-- Collect all the objects that need to be dragged together by checking group memberships
			grp = objects.populateGroupMembers(objList)
		end
		-- Sort the group elements in ascending order ranking
		table.sort(grp,function(one,two) 
				return one.order < two.order
		end)
		
		-- For all the connectors that would be affected create a list of starting points from where each connector would be routed from
		local connSrc = objects.generateRoutingStartNodes(cnvobj,grp,segList)
		
		local dragNodes,segsToRemove,connList = conn.generateRoutingStartNodes(cnvobj,segList,grp)
		
		-- Sort seglist by connector ID and for the same connector with descending segment index so if there are multiple segments that are being dragged for the same connector we handle them in descending order without changing the index of the next one in line
		table.sort(segList,function(one,two)
				if one.conn.id == two.conn.id then
					-- this is the same connector
					return one.seg > two.seg	-- sort with descending segment index
				else
					return one.conn.id > two.conn.id
				end
			end)
		
		-- Sort segsToRemove in descending order of segment index
		table.sort(segsToRemove,function(one,two)
				if one.conn.id == two.conn.id then
					-- this is the same connector
					return one.segI > two.segI	-- sort with descending segment index
				else
					return one.conn.id > two.conn.id
				end
			end)
		
		-- Sort the connList elements in ascending order ranking
		table.sort(connList,function(one,two) 
				return one.order < two.order
		end)
		
		--print("Number of dragnodes = ",#dragNodes)
			
		if not interactive then
			-- Take care of grid snapping
			offx,offy = cnvobj:snap(offx,offy)
			
			-- HANDLE THE SEGMENT DRAG FIRST
			-- Move each segment
			for i = 1,#segList do
				local seg = segList[i].conn.segments[segList[i].seg]	-- The segment that is being dragged
				rm:removeSegment(seg)
				-- Move the segment
				seg.start_x = seg.start_x + offx
				seg.start_y = seg.start_y + offy
				seg.end_x = seg.end_x + offx
				seg.end_y = seg.end_y + offy
				rm:addSegment(seg,seg.start_x,seg.start_y,seg.end_x,seg.end_y)
			end
			-- Remove the segments that would be rerouted from routing matrix
			for i = 1,#segsToRemove do
				rm:removeSegment(segsToRemove[i].seg)
				table.remove(segsToRemove[i].conn.segments,segsToRemove[i].segI)
			end
			-- route segments from previous dragNodes coordinates to the new ones
			for i = 1,#dragNodes do
				local newSegs = {}
				local node = dragNodes[i]
				--print("DRAG NODES: ",offx+dragNodes[i].offx,offy+dragNodes[i].offy)
				-- Remove the segments of the connector from routing matrix to allow the routing to use the space used by the connector
				for j = 1,#node.conn.segments do
					rm:removeSegment(node.conn.segments[j])
				end
				router.generateSegments(cnvobj,node.seg[node.which.."x"],node.seg[node.which.."y"],node.x,node.y,newSegs,finalRouter,jsFinal) -- generateSegments updates routing matrix. Use finalrouter 
				-- Add the segments back in again
				for j = 1,#node.conn.segments do
					local seg = node.conn.segments[j]
					rm:addSegment(seg,seg.start_x,seg.start_y,seg.end_x,seg.end_y)
				end
				-- Add these segments in the connectors segment list
				for j = #newSegs,1,-1 do
					table.insert(node.conn.segments,newSegs[j])
				end
			end
			-- Disconnect all ports
			conn.disconnectAllPorts(connList)
			-- Now assimilate all the connectors by shorting to touching ports and connectors and repairing all segments
			conn.assimilateConnList(cnvobj,connList)
			
			-- HANDLE THE OBJECT DRAG HERE
			objects.shiftObjList(grp,offx,offy,rm)
			local allPorts,allConns = objects.getAllPortsAndConnectors(grp)
			-- Regenerate the segments according to the coordinates calculated in connSrc
			objects.regenConn(cnvobj,rm,grp,connSrc,finalRouter,jsFinal)
			-- Short and Merge all the connectors that were connected to ports
			conn.shortAndMergeConnectors(cnvobj,allConns)
			-- Check whether after drag the ports are touching other connectors then those get connected to the port
			conn.connectOverlapPorts(cnvobj,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
			-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
			ports.connectOverlapPorts(cnvobj,allPorts)
			utility.undopost(cnvobj,key)
			return true
		end
		-- Setup the interactive move operation here
		
		-- Convert segList and segsToRemove into segment structure pointers rather than segment Indexes
		for i = 1,#segList do
			segList[i].seg = segList[i].conn.segments[segList[i].seg]
		end
		
		for i = 1,#segsToRemove do
			segsToRemove[i].segI = nil
		end
		
		-- Set refX,refY as the mouse coordinate on the canvas
		local refX,refY = cnvobj:sCoor2dCoor(GUIFW.getMouseOnCanvas(cnvobj))
		local oldBCB = cnvobj.cnv.button_cb
		local oldMCB = cnvobj.cnv.motion_cb
		-- Backup the orders of the elements to move and change their orders to display in the front
		local oldObjOrder = {}
		for i = 1,#grp do
			oldObjOrder[i] = grp[i].order
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
		
		-- Sort the connector elements in ascending order ranking
		table.sort(connList,function(one,two) 
				return one.order < two.order
		end)
		
		-- Backup the orders of the connectors
		local oldConnOrder = {}
		for i = 1,#connList do
			oldConnOrder[i] = connList[i].order
		end
		
		-- Move the last item in the list to the end. Last item because it is te one with the highest order
		item = cnvobj.drawn.order[connList[#connList].order]
		table.remove(cnvobj.drawn.order,connList[#connList].order)
		table.insert(cnvobj.drawn.order,item)
		-- Move the rest of the items on the last position
		for i = 1,#connList-1 do
			item = cnvobj.drawn.order[connList[i].order]
			table.remove(cnvobj.drawn.order,connList[i].order)
			table.insert(cnvobj.drawn.order,#cnvobj.drawn.order,item)
		end
		-- Update the order number for all items 
		fixOrder(cnvobj)
		
		local op = {}
		local opptr = #cnvobj.op + 1
		
		local function dragEnd()
			-- End the drag at this point
			-- Reset the orders back
			-- First do the connectors
			for i = 1,#connList do
				local item = cnvobj.drawn.order[connList[i].order]
				table.remove(cnvobj.drawn.order,connList[i].order)
				table.insert(cnvobj.drawn.order,oldConnOrder[i],item)
			end
			-- Update the order number for all items 
			fixOrder(cnvobj)
			-- Now do the objects
			for i = 1,#grp do
				local item = cnvobj.drawn.order[grp[i].order]
				table.remove(cnvobj.drawn.order,grp[i].order)
				table.insert(cnvobj.drawn.order,oldObjOrder[i],item)
			end
			-- Update the order number for all items 
			fixOrder(cnvobj)
			
			local x,y = cnvobj:sCoor2dCoor(GUIFW.getMouseOnCanvas(cnvobj))
			x,y = cnvobj:snap(x-refX,y-refY)	-- Total amount mouse has moved since drag started
			local offx,offy = x+op.coor1.x-grp[1].x[1],y+op.coor1.y-grp[1].y[1]		-- The offset to be applied now to the items being dragged

			conn.regenSegments(cnvobj,op,finalRouter,jsFinal,offx,offy)
			-- Disconnect all ports
			conn.disconnectAllPorts(connList)
			-- Assimilate the modified connectors
			conn.assimilateConnList(cnvobj,connList)
			
			-- Regenerate the segments according to the coordinates calculated in connSrc
			objects.regenConn(cnvobj,rm,grp,connSrc,finalRouter,jsFinal)
			-- Restore the previous button_cb and motion_cb
			cnvobj.cnv.button_cb = oldBCB
			cnvobj.cnv.motion_cb = oldMCB
			-- Get all the ports that were dragged
			local allPorts,allConns = objects.getAllPortsAndConnectors(grp)
			-- Short and Merge all the connectors that were connected to ports
			conn.shortAndMergeConnectors(cnvobj,allConns)
			-- Check whether after drag the ports are touching other connectors then those get connected to the port
			conn.connectOverlapPorts(cnvobj,nil,allPorts)	-- This takes care of splitting the connector segments as well if needed
			-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
			ports.connectOverlapPorts(cnvobj,allPorts)
			-- Reset mode
			cnvobj:refresh()
			cnvobj.op[opptr] = nil
			utility.undopost(cnvobj,key)
		end
		
		cnvobj.op[opptr] = op
		op.mode = "DRAG"
		op.coor1 = {x=grp[1].x[1],y=grp[1].y[1]}
		op.ref = {x=refX,y=refY}
		op.finish = dragEnd
		
		-- fill segsToRemove with the segments in segList
		op.segsToRemove = segsToRemove	-- to store the segments generated after every motion_cb
		op.dragNodes = dragNodes
		op.connList = segList
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
			-- Drag the connectors
			x,y = cnvobj:snap(x-refX,y-refY)	-- Total amount mouse has moved since drag started
			local offx,offy = x+op.coor1.x-grp[1].x[1],y+op.coor1.y-grp[1].y[1]		-- The offset to be applied now to the items being dragged
		
			conn.regenSegments(cnvobj,op,dragRouter,jsDrag,offx,offy)
			
			-- Drag the objects			
			objects.shiftObjList(grp,offx,offy,rm)
			-- Regenerate the segments according to the coordinates calculated in connSrc
			objects.regenConn(cnvobj,rm,grp,connSrc,dragRouter,jsDrag)
			cnvobj:refresh()
		end
		op.motion = cnvobj.cnv.motion_cb
		return opptr
	end,

	-- function to load the drawn structures in str and put them in the canvas 
	-- x and y are the database coordinates where the loaded structures anchor point will be placed. If x,y are not given then they default to center of the canvas. If interactive is true then x,y are ignored and set to the mouse position.
	-- xa,ya are the anchor points of the loaded structures. If not given the anchor point defaults to the center of maximum expanse of loaded structures. Note: xa and ya are database coordinates in the coordinate space of the loaded structure.
	load = function(cnvobj,str,x,y,xa,ya,interactive)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj).__index ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		
		local rm = cnvobj.rM
		
		-- Check whether the data is correct
		local tab = tu.s2tr(str)
		if not tab or (#tab.obj == 0 and #tab.conn == 0) then return nil,"No data found" end
		local stat,msg = utility.checkDrawn({drawn=tab})
		if not stat then
			return nil,"Corrupted data: "..msg
		end
		
		-- Setup undo
		local key = utility.undopre(cnvobj)
		
		-- Lets find the extreme dimensions of the data being loaded
		-- obj array copy
		local objS = tab.obj
		local connS = tab.conn
		local minX,maxX,minY,maxY 
		if #objS > 0 then
			minX,minY = objS[1].x[1],objS[1].y[1]
			maxX,maxY = minX,minY
		else
			minX,minY = connS[1].segments[1].start_x,connS[1].segments[1].start_y
			maxX,maxY = minX,minY
		end
		local function storeMaxMin(x,y)
			if x < minX then
				minX = x
			end
			if x > maxX then
				maxX = x
			end
			if y < minY then
				minY = y
			end
			if y > maxY then
				maxY = y
			end
		end
		for i = 1,#objS do
			for j = 1,#objS[i].x do
				storeMaxMin(objS[i].x[j],objS[i].y[j])
			end
		end
		for i = 1,#connS do
			for j = 1,#connS[i].segments do
				storeMaxMin(connS[i].segments[j].start_x,connS[i].segments[j].start_y)
				storeMaxMin(connS[i].segments[j].end_x,connS[i].segments[j].end_y)
			end
		end
		
		-- Get the center coordinates of the data being loaded. This will be the anchor point where the mouse will hold it or which will be placed on the center of the visible canvas
		local ctrX,ctrY = math.floor((maxX+minX)/2),math.floor((maxY+minY)/2)
		if not interactive then
			x = x or math.floor(tonumber(cnvobj.cnv.rastersize:match("(%d+)x%d+"))/2)
			y = y or math.floor(tonumber(cnvobj.cnv.rastersize:match("%d+x(%d+)"))/2)
			x,y = cnvobj:snap(cnvobj:sCoor2dCoor(x,y))
		else
			-- Mouse coordinates on the canvas snapped to the grid
			x,y = cnvobj:snap(cnvobj:sCoor2dCoor(GUIFW.getMouseOnCanvas(cnvobj))) 
		end
		-- Now append the data in tab into the cnvobj.drawn structure. The elements of the drawn structure are:
		-- * obj
		-- * port
		-- * conn
		-- * group
		-- * order
		xa,ya = xa or ctrX, ya or ctrY
		-- Offset to move each item for placement
		local offx,offy = x-xa,y-ya
		local items = {}	-- To store all objects and connector segments in case it is interactive move then we will send this to move API
		
		local objD = cnvobj.drawn.obj
		for i = 1,#objS do
			objD[#objD + 1] = objS[i]
			objD.ids = objD.ids + 1
			objS[i].id = "O"..tostring(objD.ids)
			local objx,objy = objS[i].x,objS[i].y
			for j = 1,#objx do
				objx[j] = objx[j] + offx
				objy[j] = objy[j] + offy
			end
			-- Set the obj attribute if any
			if objS[i].vattr then
				objects.setObjVisualAttr(cnvobj,objS[i],objS[i].vattr,-1)	-- -1 because it is a unique attribute
			end
			items[#items + 1] = objS[i]
			-- Add to routing matrix
			if objS[i].shape == "BLOCKINGRECT" then
				rm:addBlockingRectangle(objS[i],objS[i].x[1],objS[i].y[1],objS[i].x[2],objS[i].y[2])
			end
		end
		
		-- port array copy
		local portS = tab.port
		local portD = cnvobj.drawn.port
		for i = 1,#portS do
			portD[#portD + 1] = portS[i]
			portS[i].id = "P"..tostring(portD.ids + 1)
			portD.ids = portD.ids + 1
			portS[i].x = portS[i].x + offx
			portS[i].y = portS[i].y + offy
			-- Add to routing matrix
			rm:addPort(portS[i],portS[i].x,portS[i].y)
		end
		
		-- group array copy
		local grpS = tab.group
		local grpD = cnvobj.drawn.group
		for i = 1,#grpS do
			grpD[#grpD + 1] = grpS[i]
		end
		
		-- conn array copy
		local connD = cnvobj.drawn.conn
		for i = 1,#connS do
			connD[#connD + 1] = connS[i]
			connS[i].id = "C"..tostring(connD.ids + 1)
			connD.ids = connD.ids + 1
			-- Set the connector attribute if any
			if connS[i].vattr then
				conn.setConnVisualAttr(cnvobj,connS[i],connS[i].vattr,-1)	-- -1 because it is a unique attribute
			end
			-- update all segments
			local segs = connS[i].segments
			for j = 1,#segs do
				segs[j].start_x = segs[j].start_x + offx
				segs[j].start_y = segs[j].start_y + offy
				segs[j].end_x = segs[j].end_x + offx
				segs[j].end_y = segs[j].end_y + offy
				items[#items + 1] = {
					conn = connS[i],
					seg = j
				}
				-- Set the connector attribute if any
				if segs[j].vattr then
					conn.setSegVisualAttr(cnvobj,segs[j],segs[j].vattr,-1)	-- -1 because it is a unique attribute
				end
				-- Add to routing Matrix
				rm:addSegment(segs[j],segs[j].start_x,segs[j].start_y,segs[j].end_x,segs[j].end_y)
			end
			-- Update all junctions
			local junc = connS[i].junction
			for j = 1,#junc do
				junc[j].x = junc[j].x + offx
				junc[j].y = junc[j].y + offy
			end
		end
		
		-- Now do the order array copy
		local orderS = tab.order
		local orderD = cnvobj.drawn.order
		local curTop = #orderD
		for i = 1,#orderS do
			orderD[#orderD+1] = orderS[i]
			-- Fix the order number on the item
			orderS[i].item.order = #orderD
		end

		-- Everything is loaded now
		if not interactive then
			-- Check all the ports in the drawn structure and see if any port lies on this connector then connect to it
			conn.assimilateConnList(cnvobj,connS)
			-- Connect ports to any overlapping connector on the port. These are the ports that were moved with the objects
			conn.connectOverlapPorts(cnvobj,nil,portS)	-- This takes care of splitting the connector segments as well if needed
			-- Check whether this port now overlaps with another port then this connector is shorted to that port as well so 
			ports.connectOverlapPorts(cnvobj,portS)		
			cnvobj:refresh()
			utility.undopost(cnvobj,key)
			return true
		end
		utility.undopost(cnvobj,key)
		-- For interactive move just create the item list and send it to the Move API
		return cnvobj:move(items)
	end,

	erase = function(cnvobj)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj).__index ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		-- First check if any operation is happenning then end it
		local op = cnvobj.op
		if op and #op > 0 then
			while op[#op].finish and type(op[#op].finish) == "function" do
				op[#op].finish()
			end
		end
		cnvobj.drawn = {
			obj = {ids=0},		-- array of object structures. See structure in objects.lua
			group = {},			-- array of arrays containing objects intended to be grouped together
			port = {ids=0},		-- array of port structures. See structure of port in ports.lua
			conn = {ids=0},		-- array of connector structures. See structure of connector in connector.lua
			order = {},			-- array of structures containing the things to draw in order
			--[[ Order stucture looks like this:
			{
				[i] = {
					type = <string>,	-- string describing what type of item this is. Values are like "object", "connector"
					item = <table>		-- table structure of the item that is at this order position. For object it will be the object structure. For connector it will be the connector structure.
				},
			}
			]]
		}
		cnvobj.drawndiff = nil	-- key that holds the last action on the drawn table diff (See tableUtils [https://github.com/aryajur/tableUtils)] diffTable)
					-- drawndiff is not changed or used by lua-gl library
		cnvobj.hook = {ids=0}	-- Array of hook structure. See structure of hook in hooks.lua
		-- .op is a member table used for holding temporary data and setting up modes of operation of the canvas
		cnvobj.op = {}	-- STack to store operation temporary data
		cnvobj.op[1] = {
			mode="DISP",	-- To indicate the operation mode of the canvas. The following modes are known:
							-- * DISP = This is the normal mode where the mouse pointer is not associated with anything and it is not in the middle of any operation
							-- * DRAWCONN = A connector is being drawn in interactive mode
							-- * DRAGSEG = A segment is being dragged in interative mode
							-- * MOVEOBJ = An object is being moved in interactive mode
							-- * DRAGOBJ = An object is being dragged in interactive mode
							-- * DRAWOBJ = An object is being drawn in interactive mode
			finish = nil,	-- When set by a function calling that function will end the mode and reset the operation and the operation table back
			-- DRAWCONN
			connID = nil,	-- String containing the connector ID during interactive draw connector
			cIndex = nil,	-- index of the connector in cnvobj.drawn.conn which is being drawn
			startseg = nil,	-- index of the segment in the connector from which the segments need to be auto routed
			start = nil,	-- Table containing the X and Y coordinates marking the reference start coordinates
			fin = nil,		-- Table containing the X and Y coordinates marking the point up till where the segments have been generated
			-- DRAGSEG
			segList = nil,	-- list of segments in a structure. Every item contains 2 elemts conn pointing to the connector structure and seg pointing to the segment structure being dragged from the connector
			coor1 = nil,	-- Initial starting coordinate of the 1st segement in the segList array to serve as reference of the total movement
			segsToRemove = nil,		-- List of segments (similar structure as segList) to be removed in the next drag regenerate segment operation
			-- MOVEOBJ
			coor1 = nil,	-- Initial starting coordinate of the 1st object in the objList to serve as reference of the total movement
			-- DRAGOBJ
			segsToRemove = nil,	-- to store the segments generated after every motion_cb
			grp = nil,		-- Array of objects that are being dragged. This is already sorted in ascending order ranking
			oldOrder = nil,	-- Array containing the old order positions of the objects being dragged
			coor1 = nil,	-- Initial starting coordinate of the 1st object in the objList to serve as reference of the total drag
			-- DRAWOBJ
			obj = nil,		-- shape string of the object being drawn. The shape strings are listed at the top of the objects file when initialized in the environment
			order = nil,		-- order number where the new shape is placed once the drawing starts
			index = nil,		-- to store the index in cnvobj.drawn.obj array where the object being drawn is stored
		}
		--[[
		options = {
			usecrouter = <boolean>,	-- (OPTIONAL) if true then tries to use the crouter module. False by default
			router = <array of functions>,	-- The table containin the routing functions for different routing modes
		}
		]]
		if cnvobj.options.usecrouter and crouter then
			cnvobj.rM = crouter.newRoutingMatrix()
		else
			cnvobj.rM = router.newRoutingMatrix(cnvobj)
		end
		-- ################################################################################################################
		--[[
		cnvobj.grid = {
			grid_x = <integer>, --x direction grid distance
			grid_y = <integer>, --y direction grid distance
			snapGrid = <boolean>,		-- (OPTIONAL) if true then everything works on the grid, otherwise it behaves as if grid is 1px x 1px
		}]]
		--[[
		cnvobj.viewOptions = {
			gridVisibility = <boolean>,	-- (OPTIONAL) if true then grid is visible, default is nil
			gridMode = <integer>		-- (OPTIONAL) default = 1 (grid points), 2 (rectangular grid)
			showBlockingRect = <boolean>,-- (OPTIONAL) if true then blocking rectangles are drawn on screen
			backgroundColor = {R,G,B},	-- Array containing the background color R,G,B, default is {255,255,255}
			visualProp = <array>,		-- Array containing list of attribute tables that will set the drawing settings for each of the following items:
					- Items for which attributes need to be set:
					- Non filled object		(1)
					- Blocking rectangle	(2)
					- Filled object			(3)
					- Normal Connector		(4)
					- Jumping Connector		(5)	
					- Text					(6)
			--Junction drawing should be the same foreground color as connector. Junction shape and dx,dy should be set in view options. Set dx or dy to 0 to not draw anything on the junction. JUnction shape can be rectangle or ellipse. the coordinates for the shape from center will be x-dx,y-dx to x+dx,y+dx
			junction = {
				dx = <integer>,
				dy = <integer>,			
				shape = <string>		-- string containing one of the registered shapes
			}
		}
		]]
		cnvobj.viewOptions.gridMode = cnvobj.viewOptions.gridMode or 1
		cnvobj.viewOptions.backgroundColor = cnvobj.viewOptions.backgroundColor or {255,255,255}
		cnvobj.viewOptions.junction = cnvobj.viewOptions.junction or {
				dx = 3,
				dy = 3,
				shape = "ELLIPSE"
			}
		-- Visual properties
		local vProp = {
			{	-- For Non Filled object
				color = {0, 162, 232},
				style = GUIFW.CONTINUOUS,
				width = 2,
				join = GUIFW.MITER,
				cap = GUIFW.CAPFLAT
			},
			{	-- For blocking rectangle
				color = {255, 162, 162},
				style = GUIFW.DOTTED,
				width = 1,
				join = GUIFW.MITER,
				cap = GUIFW.CAPFLAT
			},
			{	-- For filled object
				color = {0, 162, 232},
				bopa = GUIFW.OPAQUE,
				style = GUIFW.SOLID,
			},
			{	-- For Normal connector
				color = {255, 128, 0},
				style = GUIFW.CONTINUOUS,
				width = 1,
				join = GUIFW.MITER,
				cap = GUIFW.CAPFLAT
			},
			{	-- For jumping connector
				color = {255, 128, 0},
				style = GUIFW.DASHED,
				width = 1,
				join = GUIFW.MITER,
				cap = GUIFW.CAPFLAT
			},	
			{	-- For text
				color = {0, 0, 0},
				typeface = "Courier",
				style = GUIFW.PLAIN,
				size = 16,
				align = GUIFW.BASE_RIGHT,
				orient = 0
			}
		}
		cnvobj.viewOptions.visualProp = vProp
		cnvobj.viewOptions.constants = nil		-- Filled by GUIFW init function to contain all constants that can be used to generate the attribute setting functions
		-- Setup the functions in the attributes below
		--[[
		attributes = {
			visualAttr = <table>,			-- Hash map containing mapping from the item structure to the visual attributes function
		}
		]]
		cnvobj.attributes = {
			visualAttr = setmetatable({},{__mode="k"}),	-- visualAttr is a table with weak keys to associate the visual attributes to the item. Each visual attribute is a table {vAttr=<integer>,visualAttr=<function>,attr=<table>}. The integer may point to a viewOptions.visualProp index (-1 is reserved and does not point to it). This allows registering of new visual attributes. The integer is used in the rendering function so decide when to change drawing attributes. If the previous item drawn had the same integer then the visualAttr function is not called.
		}
		
		--[[ Attributes can be set for the following structures:
		* Object
		* Connector
		* Segement
		-- Attribute when set will be in a table called 'vattr' of the object. This table is set by the API in cnvobj (below) and should not be manually set but can be read. Manually setting it will not change the display of the item.
		]]
		
		-- The viewport
		cnvobj.viewPort = {
			xmin = 0,
			ymin = 0,
			xmax = tonumber(cnvobj.cnv.rastersize:match("(%d+)x%d+"))-1
		}

		-- Attributes setting API
		cnvobj.setObjVisualAttr = objects.setObjVisualAttr
		cnvobj.getVisualAttr = getVisualAttr
		cnvobj.setConnVisualAttr = conn.setConnVisualAttr
		cnvobj.setSegVisualAttr = conn.setSegVisualAttr
		cnvobj.removeVisualAttr = removeVisualAttr
		
		--[[
			- Item Type is one of the following numbers:
					- Non filled object		(1)
					- Blocking rectangle	(2)
					- Filled object			(3)
					- Normal Connector		(4)
					- Jumping Connector		(5)
					- Text					(6)
					-1	is reserved and used by the rendeing function
		]]
		-- Function to set the default visual attributes for the given itemtype
		cnvobj.setDefVisualAttr = function(attr,itemType)
			if type(itemType) ~= "number" or math.floor(itemType) ~= itemType or itemType < 1 or 
			  itemType > #cnvobj.viewOptions.visualProp then
				return nil,"Invalid Item type"
			end
			local ret,attrType = utility.validateVisualAttr(attr)
			if not ret then
				return ret,attrType
			end
			if attrType == "FILLED" and itemType ~= 3 then
				return nil,"Attributes table is for filled object but itemType is not 3"
			elseif attrType == "TEXT" and itemType ~= 6 then
				return nil,"Attributes table is for text object but itemType is not 6"
			end
			cnvobj.viewOptions.visualProp[itemType] = attr
			-- Reinitialize the shapes to set the right attributes in the modules
			initShapes(cnvobj)
			return true
		end
		cnvobj.getDefVisualAttr = function(itemType)
			if type(itemType) ~= "number" or math.floor(itemType) ~= itemType or itemType < 1 or 
			  itemType > #cnvobj.viewOptions.visualProp then
				return nil,"Invalid Item type"
			end
			return cnvobj.viewOptions.visualProp[itemType]
		end
		
		-- Setup the callback functions
		function cnvobj.cnv.map_cb()
			GUIFW.mapCB(cnvobj)	
		end
		
		function cnvobj.cnv.unmap_cb()
			GUIFW.unmapCB(cnvobj)
		end
		
		function cnvobj.cnv:resize_cb(width,height)
			cnvobj.width = width
			cnvobj.height = height
			GUIFW.resizeCB(cnvobj,width,height)
			GUIFW.render(cnvobj)
		end
		
		function cnvobj.cnv.action()
			GUIFW.render(cnvobj)
		end
		
		function cnvobj.cnv:button_cb(button,pressed,x,y, status)
			GUIFW.buttonCB(cnvobj,button,pressed,x,y, status)
		end
		
		function cnvobj.cnv:motion_cb(x, y, status)
			GUIFW.motionCB(cnvobj,x,y, status)		
		end
		
		return true
	end,	-- erase ends
	
	refresh = GUIFW.update,


	---- CONNECTORS---------
	drawConnector = conn.drawConnector,		-- draw connector
	dragSegment = conn.dragSegment,
	moveSegment = conn.moveSegment,
	moveConn = conn.moveConn,
	removeConn = conn.removeConn,
	removeSegment = conn.removeSegment,
	getConnFromID = conn.getConnFromID,
	getConnFromXY = conn.getConnFromXY,
	getConninRect = conn.getConninRect,
	--setConnVisualAttr = conn.setConnVisualAttr,
	---- HOOKS--------------
	addHook = hooks.addHook,
	removeHook = hooks.removeHook,
	processHooks = hooks.processHooks,
	---- PORTS--------------
	addPort = ports.addPort, 				-- Add a port to a shape
	removePort = ports.removePort,			-- Remove a port given the portID
	getPortFromID = ports.getPortFromID,	-- Get the port structure from the port ID
	getPortFromXY = ports.getPortFromXY,	-- get the port structure close to x,y
	---- OBJECTS------------
	drawObj = objects.drawObj,				-- Draw object
	dragObj = objects.dragObj,				-- drag object(s)/group(s)
	moveObj = objects.moveObj,				-- move object(s)
	removeObj = objects.removeObj,
	groupObjects = objects.groupObjects,	
	getObjFromID = objects.getObjFromID,
	getObjFromXY = objects.getObjFromXY,
	getObjinRect = objects.getObjinRect,
	populateGroupMembers = objects.populateGroupMembers,
	--setObjVisualAttr = objects.setObjVisualAttr,
	-----GRAPHICS-----------
	getTextAttrFunc = GUIFW.getTextAttrFunc,
	getNonFilledObjAttrFunc = GUIFW.getNonFilledObjAttrFunc,
	getFilledObjAttrFunc = GUIFW.getFilledObjAttrFunc,
	sCoor2dCoor = GUIFW.sCoor2dCoor,
	dCoor2sCoor = GUIFW.dCoor2sCoor,
	setMouseOnCanvas = GUIFW.setMouseOnCanvas,
	getMouseOnCanvas = GUIFW.getMouseOnCanvas,
	viewportPara = GUIFW.viewportPara,
	doprint = GUIFW.doprint,
	fontPt2Pixel = GUIFW.fontPt2Pixel,
	isctrl = GUIFW.isctrl,
	isshift = GUIFW.isshift,
	isdouble = GUIFW.isdouble,
	isalt = GUIFW.isalt,
	issys = GUIFW.issys,
	-- Initialize the graphical constants here
	MOUSE = {
		BUTTON1 = GUIFW.BUTTON1,
		BUTTON2 = GUIFW.BUTTON2,
	},
	GRAPHICS = {
		-- Line style constants,
		CONTINUOUS = GUIFW.CONTINUOUS,
		DASHED = GUIFW.DASHED,
		DOTTED = GUIFW.DOTTED,
		DASH_DOT = GUIFW.DASH_DOT,
		DASH_DOT_DOT = GUIFW.DASH_DOT_DOT,
		CUSTOM = GUIFW.CUSTOM,
		-- Line Join Constants,
		MITER = GUIFW.MITER,
		BEVEL = GUIFW.BEVEL,
		ROUND = GUIFW.ROUND,
		-- Line Cap constants,
		CAPFLAT = GUIFW.CAPFLAT,
		CAPSQUARE = GUIFW.CAPSQUARE,
		CAPROUND = GUIFW.CAPROUND,
		-- Back Opacity,
		OPAQUE = GUIFW.OPAQUE,
		TRANSPARENT = GUIFW.TRANSPARENT,
		-- Fill style,
		SOLID = GUIFW.SOLID,
		HOLLOW = GUIFW.HOLLOW,
		STIPPLE = GUIFW.STIPPLE,
		HATCH = GUIFW.HATCH,
		PATTERN = GUIFW.PATTERN,
		-- Hatch styles,
		HORIZONTAL = GUIFW.HORIZONTAL,
		VERTICAL = GUIFW.VERTICAL,
		FDIAGONAL = GUIFW.FDIAGNOL,
		BDIAGONAL = GUIFW.BDIAGNOL,
		CROSS = GUIFW.CROSS,
		DIAGCROSS = GUIFW.DIAGCROSS,
		-- Font styles,
		PLAIN = GUIFW.PLAIN,
		BOLD = GUIFW.BOLD,
		ITALIC = GUIFW.ITALIC,
		UNDERLINE = GUIFW.UNDERLINE,
		STRIKEOUT = GUIFW.STRIKEOUT,
		-- Font Alignment,
		NORTH = GUIFW.NORTH,
		SOUTH = GUIFW.SOUTH,
		EAST = GUIFW.EAST,
		WEST = GUIFW.WEST,
		NORTH_EAST = GUIFW.NORTH_EAST,
		NORTH_WEST = GUIFW.NORTH_WEST,
		SOUTH_EAST = GUIFW.SOUTH_EAST,
		SOUTH_WEST = GUIFW.SOUTH_WEST,
		CENTER = GUIFW.CENTER,
		BASE_LEFT = GUIFW.BASE_LEFT,
		BASE_CENTER = GUIFW.BASE_CENTER,
		BASE_RIGHT = GUIFW.BASE_RIGHT,		
	},
	
	-----UTILITY------------
	snap = function(cnvobj,x,y)
		local grdx,grdy = cnvobj.grid.snapGrid and cnvobj.grid.grid_x or 1, cnvobj.grid.snapGrid and cnvobj.grid.grid_y or 1
		return coorc.snapX(x, grdx),coorc.snapY(y, grdy)	
	end,
	undo = utility.doundo,
}	-- objFuncs table ends here

-- cnvobj options meta table
local optMeta = {
	__index = function(t,k)
		return t.__OPTDATA[k]
	end,
	__newindex = function(t,k,v)
		if k == "usecrouter" then
			if v and crouter then
				t.__OPTDATA.usecrouter = v
				t.__OPTDATA.router[9] = crouter.BFS
			else
				t.__OPTDATA.router[9] = router.BFS
			end
		else
			t.__OPTDATA[k] = v
		end
	end
}

local function checkPara(para)

	if not para.width or type(para.width) ~= "number" then
		return nil,"Width not given or not a number"
	end
	if not para.height or type(para.height) ~= "number" then
		return nil,"height not given or not a number"
	end
	if not para.grid_x or type(para.grid_x) ~= "number" then
		return nil,"grid_x not given or not a number"
	end
	if not para.grid_y or type(para.grid_y) ~= "number" then
		return nil,"grid_y not given or not a number"
	end
	if para.backgroundColor then
		if type(para.backgroundColor) ~= "table" or #para.backgroundColor ~= 3 then
			return nil,"Background color attribute not given as a {R,G,B} table"
		end
		for i = 1,3 do
			if type(para.backgroundColor[i]) ~= "number" or math.floor(para.backgroundColor[i]) ~= para.backgroundColor[i] then
				return nil,"Background color attribute table has non integer values"
			end
			if para.backgroundColor[i]<0 or para.backgroundColor[i]>255 then
				return nil,"Background color attribute table is not in the range [0,255]"
			end
		end
	end
	return true
end


-- The parameter table contains the initialization parameters
--[[
{
	width = <integer>, 	--Width of the canvas
	height = <integer>,	--Height of the canvas
	grid_x = <integer>, --x direction grid distance
	grid_y = <integer>, --y direction grid distance
	gridVisibility = <boolean>,	-- (OPTIONAL) if true then grid is visible
	snapGrid = <boolean>,		-- (OPTIONAL) if true then everything works on the grid, otherwise it behaves as if grid is 1px x 1px
	showBlockingRect = <boolean>,-- (OPTIONAL) if true then blocking rectangles are drawn on screen
	usecrouter = <boolean>,		-- (OPTIONAL) if true then it tries to find and use the crouter module. Default is false
	backgroundColor = {R,G,B}	-- (OPTIONAL) a table with RGB values for the background color. Default is white
}

]]
new = function(para)
	local cnvobj = {
		grid = {},
		viewOptions = {},	-- this table does not need a action metatable like options since viewoptions can be made into effect by doing a refresh
		options = {},
	}		-- The lua-gl object
	
	cnvobj.options.__OPTDATA = {
--[[ ROUTING ALGORITHMS:
	* Mode 0 - Fully Manual. A single segment is made from source to destination irrespective of routing matrix
	* Mode 1 - Fully Manual orthogonal. Segments can only be vertical or horizontal. From source to destination whichever is longer of the 2 would be returned
	* Mode 2 - Manual orthogonal with routing matrix guidance?
	* Mode 9 - Auto-routing with BFS algorithm.
]]
		router = {
			[0] = router.noRoute,
			[1] = router.orthoRoute,
			[2] = router.orthoRouteRM,
			[9] = router.BFS	-- Default is the Lua implementation of the BFS algorithm for routing
		}
	}	-- table to store the actual options. This in effect is the data for the options table. This can be modified directly but the relation action or effect of setting the option may not happen
	setmetatable(cnvobj.options,optMeta)
	
	local resp,msg = checkPara(para)
   
	if not resp then
		return nil,msg
	end
	
	-- Put all parameters into the cnvobj object
	for k,v in pairs(para) do
		if k == "grid_x" or k == "grid_y" or k == "snapGrid" then
			cnvobj.grid[k] = v
		elseif k == "gridVisibility" or k == "showBlockingRect" or k == "backgroundColor" then
			cnvobj.viewOptions[k] = v
		elseif k == "usecrouter" then
			cnvobj.options[k] = v
		else
			cnvobj[k] = v
		end
	end
	
	-- Create the canvas element
	cnvobj.cnv = GUIFW.newCanvas()
	cnvobj.cnv.rastersize=""..cnvobj.width.."x"..cnvobj.height..""
	
	setmetatable(cnvobj,{__index = objFuncs})
	
	assert(objFuncs.erase(cnvobj),"Could not initialize the canvas object")
	
	initShapes(cnvobj)
	
	return cnvobj
end
