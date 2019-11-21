local table = table
local pairs = pairs
local print = print
local iup = iup
local error = error
local pcall = pcall
local type = type
local math = math

local setmetatable = setmetatable
local getmetatable = getmetatable

local objects = require("lua-gl.objects")
local ports = require("lua-gl.ports")
local conn = require("lua-gl.connector")
local tu = require("tableUtils")
local CC = require("lua-gl.canvas")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

--- TASKS
--[[
1. Make connector structure store all end points. So given the endpoints the whole connector structure can be redrawn
2. Finish loading of saved structure.
3. Add tapping of connectors
4. Maintain the pathfinding matrix in cnvobj and update immediately if any blocking rectangle is added or moved. Do not generate everytime a connector path is calculated.
10. Have to make undo/redo lists - improve API by spawning from the UI interaction functions their immediate action counterparts
11. Connector labeling
12. Have to add export/print

]]


-- this function is used to manipulate active Element table data
-- cnvobj is the canvas object
-- x is the x coordinate of the mouse pointer
-- y is the y coordinate of the mouse pointer
-- Table is the active elements table
-- Structure of active elements table:
--[[
[i] = {
	portTable = {	-- table containing ports information
		[j] = {
			offsetx
			offsety
			x
			y
		}
	},
	start_x
	start_y
}

]]

local function Manipulate_LoadedEle(cnvobj, x, y, LoadedData)
	Table = LoadedData.drawnEle
	if #Table > 0 then
		local center_x , center_y = (Table[1].end_x - Table[1].start_x)/2+Table[1].start_x, (Table[1].end_y-Table[1].start_y)/2+Table[1].start_y
			
		for i=1, #Table do
			if Table[i].portTable then
				if #Table[i].portTable >= 0 then
					for ite=1 , #Table[i].portTable do   --offsetx is distance between ports x coordinate and start_x
						Table[i].portTable[ite].offsetx = Table[i].start_x - Table[i].portTable[ite].x
						Table[i].portTable[ite].offsety = Table[i].start_y - Table[i].portTable[ite].y
					end
				end
			end
		end
		--manipulating connector
		for i=1, #cnvobj.connector do
			for j=1, #cnvobj.connector[i].segments do
				LoadedData.connector[i].segments[j].start_x = math.floor(LoadedData.connector[i].segments[j].start_x + x - center_x)
				LoadedData.connector[i].segments[j].start_y = math.floor(LoadedData.connector[i].segments[j].start_y + y - center_y)
				LoadedData.connector[i].segments[j].end_x = math.floor(LoadedData.connector[i].segments[j].end_x + x - center_x)
				LoadedData.connector[i].segments[j].end_y = math.floor(LoadedData.connector[i].segments[j].end_y + y - center_y)
			end
		end
		
		for i=1, #Table do	
			
			Table[i].start_x = math.floor(Table[i].start_x + x - center_x)
			Table[i].start_y = math.floor(Table[i].start_y + y - center_y)
			
			Table[i].end_x = math.floor(Table[i].end_x + x - center_x)
			Table[i].end_y = math.floor(Table[i].end_y + y - center_y)
			
			if Table[i].portTable then
				if #Table[i].portTable >= 0 then
					for ite=1 , #Table[i].portTable do
					
						Table[i].portTable[ite].x = math.floor(Table[i].start_x - Table[i].portTable[ite].offsetx)
						Table[i].portTable[ite].y = math.floor(Table[i].start_y - Table[i].portTable[ite].offsety)

					end
				end
			end
			
			
		end
		
	end
end

-- This is the metatable that contains the API of the library that can be used by the host program

local objFuncs
objFuncs = {

	save = function(cnvobj)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return
		end
		-- First check if any operation is happenning then end it
		if cnvobj.op.end and type(cnvobj.op.end) == "function" then
			cnvobj.op.end()
		end
		return tu.t2sr(cnvobj.drawn)
	end,
	
	load = function(cnvobj,str)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return
		end
		if cnvobj then
			cnvobj.drawing = "LOAD"
			
			move = false
			

			cnvobj.loadedEle = tableUtils.s2tr(str)

			if not cnvobj.loadedEle then
				local msg = "length of string is zero"
				return msg
			end
		end	
	end,

	erase = function(cnvobj)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return
		end
		cnvobj.drawn = {
			obj = {ids=0},		-- See structure in objects.lua
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
		cnvobj.op = {mode="DISP"}
		
		if cnvobj.cnv then
			function cnvobj.cnv:button_cb(button,pressed,x,y, status)
				CC.buttonCB(cnvobj,button,pressed,x,y, status)
			end
			
			function cnvobj.cnv:motion_cb(x, y, status)
				CC.motionCB(cnvobj,x,y, status)		
			end
		end
	end,


	-------------------MOTION CB
			-- if load function is called then 
			if iup.isbutton1(status) and cnvobj.drawing == "LOAD" and move then
				Manipulate_LoadedEle(cnvobj, x, y, cnvobj.loadedEle)
				CC.update(cnvobj)
			end
---------------------------		

			--if load function is called
			if cnvobj.drawing == "LOAD" then
				if button == iup.BUTTON1 then
					if pressed == 1 then
						move = true
					else
						move = false
						
						--group previously grouped shapes
						local total_shapes = #cnvobj.loadedEle.drawnEle
						
						for g_i = 1, #cnvobj.loadedEle.group do
							cnvobj.group[#cnvobj.group + 1] = {}
							for g_j = 1, #cnvobj.loadedEle.group[g_i] do 
								cnvobj.group[#cnvobj.group][g_j] = total_shapes + cnvobj.loadedEle.group[g_i][g_j]
							end
						end

						--load the connectors
						local no_of_connector = #cnvobj.loadedEle.connector
						for i=1, no_of_connector do 
							cnvobj.connector[#cnvobj.connector+1] = cnvobj.loadedEle.connector[i]
							cnvobj.connector[#cnvobj.connector].ID = no_of_connector + i
						end
						
					
						--load all the drawn shapes and port 
						for i=1, #cnvobj.loadedEle.drawnEle do
							local index = #cnvobj.drawnObj
							cnvobj.drawnObj[index+1] = cnvobj.loadedEle.drawnEle[i]
							cnvobj.drawnObj[index+1].shapeID = index + 1

							--table.insert(tempTable, index+1)
							--print(#cnvobj.port)
							if cnvobj.drawnObj[index+1].portTable then
								for ite = 1, #cnvobj.drawnObj[index+1].portTable do
									cnvobj.port[#cnvobj.port+1] = cnvobj.drawnObj[index+1].portTable[ite]

									cnvobj.port[#cnvobj.port].portID = #cnvobj.port

									for p_j=1, #cnvobj.port[#cnvobj.port].segmentTable do
										cnvobj.port[#cnvobj.port].segmentTable[p_j].connectorID = no_of_connector + cnvobj.port[#cnvobj.port].segmentTable[p_j].connectorID
									end
									--cnvobj.port[p_ID].segmentTable[portSegTableLen+1].connectorID = #cnvobj.connector

									--cnvobj.port[#cnvobj.port].segmentTable = 
								end
							end
						end

						--cnvobj:groupShapes(tempTable)
						cnvobj.loadedEle = {}
						cnvobj.drawing = "STOP"
					end
				end
			end	
			
	---- CONNECTORS---------
	drawConnector = conn.drawConnector,
	---- HOOKS--------------
	addHook = hooks.addHook,
	removeHook = hooks.removeHook,
	processHooks = hooks.processHooks,
	---- PORTS--------------
	addPort = ports.addPort, 	-- Add a port to a shape
	removePort = ports.removePort,	-- Remove a port given the portID
	getPortFromID = ports.getPortFromID,	-- Get the port structure from the port ID
	getPortFromXY = ports.getPortFromXY,	-- get the port structure close to x,y
	---- OBJECTS------------
	drawObj = objects.drawObj,
	moveObj = objects.moveObj,
	groupObjects = objects.groupObjects,
	getObjFromID = objects.getObjFromID,
	getObjFromXY = objects.getObjFromXY,
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
}

]]
new = function(para)
	local cnvobj = {}	-- The canvas object for lua-gl
	
	local resp,msg = checkPara(para)
   
	if not resp then
		return nil,msg
	end
	
	-- Put all parameters into the cnvobj object
	for k,v in pairs(para) do
		cnvobj[k] = v
	end
	  
	objFuncs.erase(cnvobj)
	-- Create the canvas element
	cnvobj.cnv = iup.canvas{}		-- iup canvas where all drawing will happen
	cnvobj.cnv.rastersize=""..cnvobj.width.."x"..cnvobj.height..""
	
	-- Setup the callback functions
	function cnvobj.cnv.map_cb()
		CC.mapCB(cnvobj)	
	end
	
	function cnvobj.cnv.unmap_cb()
		CC.unmapCB(cnvobj)
	end
	
	function cnvobj.cnv.action()
		CC.render(cnvobj)
	end
	
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		CC.buttonCB(cnvobj,button,pressed,x,y, status)
	end
	
	function cnvobj.cnv:motion_cb(x, y, status)
		CC.motionCB(cnvobj,x,y, status)		
	end
	
	setmetatable(cnvobj,{__index = objFuncs})
	
	return cnvobj
end
