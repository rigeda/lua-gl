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

_VERSION = "B20.01.11"

--- TASKS
--[[
DEBUG:
TASKS:
* Finish moveSegment
* Finish moveConn
* Finish removeConn
* Finish removeObj
* Finish removePort
* Finish cnvobj:move
* Finish cnvobj:drag
* Finish loading of saved structure.
* Add rotate functionality
* Add object resize functionality
* Add Text functionality
* Add arc functionality
* Canvas scroll, zoom, pan and coordinate translation
* Have to make undo/redo lists - improve API by spawning from the UI interaction functions their immediate action counterparts
* Implement action cancel by ending and then undoing it.
* Connector labeling
* Have to add export/print
]]

local function getVisualAttr(cnvobj,item)
	return cnvobj.attributes.visualAttr[item]
end


-- This is the metatable that contains the API of the library that can be used by the host program
local objFuncs
objFuncs = {
	
	-- Function to move the list of items (given as a list of their IDs) by moving the all items offx and offy offsets
	-- if offx is not a number then the movement is done interactively with a mouse
	move = function(cnvobj,items,offx,offy)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		-- Check whether this is an interactive move or not
		local interactive
		if offx and type(offx) ~= "number" then
			interactive = true
		elseif not offx or not offy or type(offx) ~= "number" or type(offy) ~= "number" then
			return nil, "Coordinates not given"
		end
		if not interactive then
			-- Just do a single move
			-- Compile the list of objects from their item IDs
			local itemList = {}
			for i = 1,#items do
				local it = items[i]:match("^(.)%d*")
				if it == "O" then
					itemList[i] = cnvobj:getObjFromID(items[i])
				else
					itemList[i] = cnvobj:getConnFromID(items[i])
				end
			end
			-- sort items according to their order
			table.sort(itemList,function(one,two)
					return one.order < two.order
			end)
			for i = 1,#itemList do
				local it = itemList[i].id:match("^(.)%d*")
				if it == "O" then
					
				else
				end
			end
			
			return true
		end
		-- Setup the interactive move call backs
		
	end,
	
	drag = function(cnvobj,items,offx,offy)
		
	end,

	save = function(cnvobj)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		-- First check if any operation is happenning then end it
		if cnvobj.op.finish and type(cnvobj.op.finish) == "function" then
			cnvobj.op.finish()
		end
		return tu.t2sr(cnvobj.drawn)
	end,
	-- function to load the drawn structures in str and put them in the canvas 
	-- x and y are the coordinates where the structures will be loaded. If not given x,y will default to the center of the canvas
	-- if interactive==true then the placed elements will be moving with the mouse pointer and left click will place them
	load = function(cnvobj,str,x,y,interactive)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		local tab = tu.s2tr(str)
		if not tab then return nil,"No data found" end
		x = x or math.floor(tonumber(cnvobj.cnv.rastersize:match("(%d+)x%d+"))/2)
		y = y or math.floor(tonumber(cnvobj.cnv.rastersize:match("%d+x(%d+)"))/2)
		local grdx,grdy = cnvobj.grid.snapGrid and cnvobj.grid.grid_x or 1, cnvobj.grid.snapGrid and cnvobj.grid.grid_y or 1
		-- Now append the data in tab into the cnvobj.drawn structure
		-- obj array copy
		local objS = tab.obj
		local objD = cnvobj.drawn.obj
		local offx,offy = x-objS[1].start_x,y-objS[1].start_y
		for i = 1,#objS do
			objD[#objD + 1] = objS[i]
			objS[i].id = "O"..tostring(objD.ids + 1)
			objS[i].start_x = objS[i].start_x + offx
			objS[i].start_y = objS[i].start_y + offy
			objS[i].end_x = objS[i].end_x + offx
			objS[i].end_y = objS[i].end_y + offx
			objD.ids = objD.ids + 1
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
		end
		
		-- group array copy
		local grpS = tab.group
		local grpD = cnvobj.drawn.group
		for i = 1,#grpS do
			grpD[#grpD + 1] = grpS[i]
		end
		
		-- conn array copy
		local connS = tab.conn
		local connD = cnvobj.drawn.conn
		for i = 1,#connS do
			connD[#connD + 1] = connS[i]
			connS[i].id = "C"..tostring(connD.ids + 1)
			connD.ids = connD.ids + 1
			-- update all segments
			local segs = connS[i].segments
			for j = 1,#segs do
				segs[j].start_x = segs[j].start_x + offx
				segs[j].start_y = segs[j].start_y + offy
				segs[j].end_x = segs[j].end_x + offx
				segs[j].end_y = segs[j].end_y + offy
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
			return true
		end
		-- Setup the interactive movement here
	end,

	erase = function(cnvobj)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj).__index ~= objFuncs then
			return nil,"Not a valid lua-gl object"
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
		cnvobj.hook = {ids=0}	-- Array of hook structure. See structure of hook in hooks.lua
		-- .op is a member table used for holding temporary data and setting up modes of operation of the canvas
		cnvobj.op = {
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
			segList = nil,	-- list of segments in a structure described in the dragSegment functon documentation
			coor1 = nil,	-- Initial starting coordinate of the 1st segement in the segList array to serve as reference of the total movement
			offx = nil,		-- To store the last x offset applied to the segments being moved
			offy = nil,		-- To store the last y offset applied to the segments being moved
			oldSegs = nil,	-- To store the old segments table for the all the connectors whose segments are being dragged i.e. in the segList
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
		----############## THIS NEEDS TO BE EVALUATED WHEN DOING ZOOM AND PAN #############################################
		cnvobj.size = nil	-- when set should be in the form {width=<integer>,height=<integer>} and that will fix the size of the drawing area to that. Note that this is not the canvas size which is always referred from cnvobj.cnv.rastersize
		--[[
		cnvobj.size = {}	
		cnvobj.size.width = cnvobj.cnv.rastersize:match("(%d%d*)x%d*")
		cnvobj.size.height = cnvobj.cnv.rastersize:match("%d%d*x(%d%d*)")
		
		width = <integer>, 	--Width of the canvas	-- The width at the time of creation
		height = <integer>,	--Height of the canvas	-- The height at the time of creation
		]]
		-- ################################################################################################################
		--[[
		grid = {
			grid_x = <integer>, --x direction grid distance
			grid_y = <integer>, --y direction grid distance
			snapGrid = <boolean>,		-- (OPTIONAL) if true then everything works on the grid, otherwise it behaves as if grid is 1px x 1px
		}]]
		--[[
		viewOptions = {
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
		}
		cnvobj.viewOptions.visualProp = vProp
		-- Setup the functions in the attributes below
		--[[
		attributes = {
			visualAttr = <table>,			-- Hash map containing mapping from the item structure to the visual attributes function
			defaulVisualAttr = <array>,		-- Array containing list of functions that will set the drawing settings for each of the following items:
					- Items for which attributes need to be set:
					- Non filled object		(1)
					- Blocking rectangle	(2)
					- Filled object			(3)
					- Normal Connector		(4)
					- Jumping Connector		(5)
					100	is reserved and used by the rendeing function
		}
		]]
		cnvobj.attributes = {
			visualAttr = setmetatable({},{__mode="k"}),	-- attr is a table with weak keys to associate the visual attributes to the item. Each visual attribute is a table {<integer>,<function>}. The integer points to a visualAttrBank index. This allows registering of new visual attributes in the visualAttrBank table defined below and helps optimize the render function by not executing same attributes
			visualAttrBank = {
				GUIFW.getNonFilledObjAttrFunc(vProp[1]),	-- For Non Filled object
				GUIFW.getNonFilledObjAttrFunc(vProp[2]),	-- For blocking rectangle
				GUIFW.getFilledObjAttrFunc(vProp[3]),		-- For filled object
				GUIFW.getNonFilledObjAttrFunc(vProp[4]),	-- For Normal connector
				GUIFW.getNonFilledObjAttrFunc(vProp[5]),	-- For jumping connector
			}
		}
		
		--[[ Attributes can be set for the following structures:
		* Object
		* Connector
		* Segement
		-- Attribute when set will be in a table called 'vattr' of the object. This table is set by the API in cnvobj (below) and should not be manually set but can be read. Manually setting it will not change the display of the item.
		]]

		-- Attributes setting API
		cnvobj.setObjVisualAttr = objects.setObjVisualAttr
		cnvobj.getObjVisualAttr = getVisualAttr
		cnvobj.setConnVisualAttr = conn.setConnVisualAttr
		cnvobj.getConnVisualAttr = getVisualAttr
		cnvobj.setSegVisualAttr = conn.setSegVisualAttr
		cnvobj.getSegVisualAttr = getVisualAttr
		
		--[[
			- Item Type is one of the following numbers:
					- Non filled object		(1)
					- Blocking rectangle	(2)
					- Filled object			(3)
					- Normal Connector		(4)
					- Jumping Connector		(5)
					100	is reserved and used by the rendeing function
		]]
		cnvobj.setDefVisualAttr = function(itemType,attr)
			if type(itemType) ~= "number" or math.floor(itemType) ~= itemType or itemType < 1 or itemType > 5 then
				return nil,"Invalid Item type"
			end
			local ret,filled = utility.validateVisualAttr(attr)
			if not ret then
				return ret,filled
			end
			if filled and itemType ~= 3 then
				return nil,"attributes table is for filled object but itemType is not 3"
			end
			cnvobj.viewOptions.visualProp[itemType] = attr
			if filled then
				cnvobj.attributes.visualAttrBank[itemType] = GUIFW.getFilledObjAttrFunc(attr)
			else
				cnvobj.attributes.visualAttrBank[itemType] = GUIFW.getNonFilledObjAttrFunc(attr)
			end
			if itemType == 4 then
				-- Register the new default in the GUIFW
				GUIFW.CONN = {
					visualAttr = cnvobj.attributes.visualAttrBank[4],	-- normal connector
					vAttr = 4				
				}
			end
			return true
		end
		cnvobj.getDefVisualAttr = function(itemType)
			if type(itemType) ~= "number" or math.floor(itemType) ~= itemType or itemType < 1 or itemType > 5 then
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
		
		function cnvobj.cnv.resize_cb()
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
	end,
	
	refresh = GUIFW.update,


	---- CONNECTORS---------
	drawConnector = conn.drawConnector,		-- draw connector
	dragSegment = conn.dragSegment,
	moveSegment = conn.moveSegment,
	moveConn = conn.moveConn,
	getConnFromID = conn.getConnFromID,
	getConnFromXY = conn.getConnFromXY,
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
	groupObjects = objects.groupObjects,	
	getObjFromID = objects.getObjFromID,
	getObjFromXY = objects.getObjFromXY,
	-----UTILITY------------
	snap = function(cnvobj,x,y)
		local grdx,grdy = cnvobj.grid.snapGrid and cnvobj.grid.grid_x or 1, cnvobj.grid.snapGrid and cnvobj.grid.grid_y or 1
		return coorc.snapX(x, grdx),coorc.snapY(y, grdy)	
	end
}

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
	
	-- Register the shapes
	RECT.init(cnvobj)
	LINE.init(cnvobj)
	ELLIPSE.init(cnvobj)
	
	return cnvobj
end
