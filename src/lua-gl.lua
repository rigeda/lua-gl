local table = table
local pairs = pairs
local print = print
local iup = iup
local cd = cd
local error = error
local pcall = pcall
local type = type
local math = math
local snap = require("snap")
local segmentGenerator = require("segmentGenerator")
local check = require("ClickFunctions")
local tableUtils = require("tableUtils")
local CC = require("createCanvas")

local setmetatable = setmetatable
local getmetatable = getmetatable

local objects = require("lua-gl.objects")
local ports = require("lua-gl.ports")
local hooks = require("lua-gl.hooks")
local conn = require("lua-gl.connector")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end


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
local function Manipulate_activeEle(cnvobj, x, y, Table)
	if #Table == 0 then
		-- Nothing to do
		return
	end
	-- Create the matrix representing the points that a connector can traverse
	cnvobj.matrix = segmentGenerator.findMatrix(cnvobj)
	
	for i=1, #Table do	
	
		-- Update all port offsets 
		if type(Table[i].portTable) == "table" and #Table[i].portTable >= 0 then
			local pT = Table[i].portTable
			for ite=1 , #pT do   --offsetx is distance between ports x coordinate and start_x
				pT[ite].offsetx = Table[i].start_x - pT[ite].x
				pT[ite].offsety = Table[i].start_y - pT[ite].y
			end
		end

		if i==1 then 
			
			Table[1].start_x = math.floor(x - Table[1].offs_x)
			Table[1].start_y = math.floor(y - Table[1].offs_y)	
			if cnvobj.snapGrid == true then
				Table[1].start_x = snap.Sx(Table[1].start_x, cnvobj.grid_x)
				Table[1].start_y = snap.Sy(Table[1].start_y, cnvobj.grid_y)

				Table[1].start_x = math.floor(Table[1].start_x + Table[1].offsetXfromGrid)
				Table[1].start_y = math.floor(Table[1].start_y + Table[1].offsetYfromGrid)
			end
			
			
			Table[1].end_x = math.floor(Table[1].start_x - Table[1].distX)
			Table[1].end_y = math.floor(Table[1].start_y - Table[1].distY)
		else
			Table[i].start_x = math.floor(Table[1].start_x - Table[i].offs_x )
			Table[i].start_y = math.floor(Table[1].start_y - Table[i].offs_y )
			Table[i].end_x = math.floor(Table[i].start_x - Table[i].distX)
			Table[i].end_y = math.floor(Table[i].start_y - Table[i].distY)
		end

		if Table[i].portTable then
			if #Table[i].portTable >= 0 then
				for ite=1 , #Table[i].portTable do
				
					Table[i].portTable[ite].x = math.floor(Table[i].start_x - Table[i].portTable[ite].offsetx)
					Table[i].portTable[ite].y = math.floor(Table[i].start_y - Table[i].portTable[ite].offsety)
					
					if Table[i].portTable[ite].segmentTable then
						for segIte = 1, #Table[i].portTable[ite].segmentTable do
							local segmentID = Table[i].portTable[ite].segmentTable[segIte].segmentID
							local connectorID = Table[i].portTable[ite].segmentTable[segIte].connectorID
							--print("connector Id = "..connectorID)
							
							local status = Table[i].portTable[ite].segmentTable[segIte].segmentStatus
							if segmentID and status=="ending" and connectorID then
								
								local endX = Table[i].portTable[ite].x
								local endY = Table[i].portTable[ite].y
								local startX = cnvobj.connector[connectorID].segments[1].start_x
								local startY = cnvobj.connector[connectorID].segments[1].start_y
								local totalSegmentInThisConnector = #cnvobj.connector[connectorID].segments
								
								if segmentID and connectorID then
									segmentGenerator.generateSegments(cnvobj, connectorID, totalSegmentInThisConnector, startX, startY, endX, endY)
								end
							end
							
							if segmentID and status=="starting" and connectorID then

								local startX = Table[i].portTable[ite].x
								local startY = Table[i].portTable[ite].y
								local totalSegmentInThisConnector = #cnvobj.connector[connectorID].segments
								
								local endX = cnvobj.connector[connectorID].segments[totalSegmentInThisConnector].end_x
								local endY = cnvobj.connector[connectorID].segments[totalSegmentInThisConnector].end_y
								
								
								if segmentID and connectorID then
									segmentGenerator.generateSegments(cnvobj, connectorID, totalSegmentInThisConnector, startX, startY, endX, endY)
								end
							end
							CC.update(cnvobj)
							
						end
					end
				end
			end
		end
		
	end
end

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

local function checkIndexInGroups(cnvobj,shape_id)
	if #cnvobj.group > 0 then
		for i=1,#cnvobj.group do
			for j=1, #cnvobj.group[i] do
				if shape_id == cnvobj.drawnObj[cnvobj.group[i][j]].shapeID then
					return true, i 
				end
			end
		end
	end
	return false
end

-- This is the metatable that contains the API of the library that can be used by the host program

local objFuncs
objFuncs = {

	save = function(cnvobj)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return
		end
		cnvobj.drawnData.drawnEle = cnvobj.drawnObj
		cnvobj.drawnData.group = cnvobj.group
		cnvobj.drawnData.port = cnvobj.port
		cnvobj.drawnData.connector = cnvobj.connector
		
		local str = tableUtils.t2sr(cnvobj.drawnData)
		return str
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
		--[[
		
	####**** WHY NOT DO ALL THESE????
	cnvobj.drawnData = {}
	cnvobj.drawnObj = {}
	cnvobj.group = {}
  	cnvobj.loadedEle = {}
	cnvobj.activeEle = {}
	cnvobj.hook = {}
	cnvobj.port = {}
	cnvobj.connector = {}
	cnvobj.connectorFlag = false
	cnvobj.clickFlag = false
	cnvobj.tempflag = false
	]]	
		cnvobj.drawnObj = {}
		cnvobj.group = {}
		cnvobj.port = {}
		cnvobj.connector = {}
		cnvobj.connectorFlag = false
		cnvobj.clickFlag = false
		cnvobj.tempflag = false
		CC.update(cnvobj)
	end,


	moveObj = function(cnvobj)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return
		end
		local oldBCB = cnvobj.cnv.button_cb
		local oldMCB = cnvobj.cnv.motion_cb
		-- button_CB to handle object drawing
		function cnvobj.cnv:button_cb(button,pressed,x,y, status)
			y = cnvobj.height - y
			-- Check if any hooks need to be processed here
			processHooks(cnvobj,"MOUSECLICKPRE")
			
			-- Process any hooks 
			processHooks(cnvobj,"MOUSECLICKPOST")
		end
	
		function cnvobj.cnv:motion_cb(x,y,status)
			
		end
	end,
		-------------------MOTION CB
			-- click fun.
			if iup.isbutton1(status) and cnvobj.drawing == "CLICKED" and #cnvobj.activeEle > 0 then
				Manipulate_activeEle(cnvobj,x,y,cnvobj.activeEle)
				CC.update(cnvobj)
			end
			
			-- if load function is called then 
			if iup.isbutton1(status) and cnvobj.drawing == "LOAD" and move then
				Manipulate_LoadedEle(cnvobj, x, y, cnvobj.loadedEle)
				CC.update(cnvobj)
			end
---------------------------		
			--click function
			if #cnvobj.drawnObj > 0 and cnvobj.drawing == "STOP" and pressed == 1 then
				--y = cnvobj.height - y
				local index = check.checkXY(cnvobj,x,y)
				if index ~= 0 and index then --index should not nill
					cnvobj.drawing = "CLICKED"
					local indexBelongToAnyGroup, groupID = checkIndexInGroups(cnvobj,cnvobj.drawnObj[index].shapeID)

					if indexBelongToAnyGroup then
						for j=1, #cnvobj.group[groupID] do
							local i = 1
							while #cnvobj.drawnObj >= i do
								--print(#cnvobj.group[groupID],j,groupID,i)
								if cnvobj.group[groupID][j] == cnvobj.drawnObj[i].shapeID then
									local ActiveEleLen = #cnvobj.activeEle
									--cnvobj.activeEle[ActiveEleLen+1] = {}
									cnvobj.activeEle[ActiveEleLen+1] = cnvobj.drawnObj[i]
									if ActiveEleLen == 1 then 
										cnvobj.activeEle[1].offs_x = x - cnvobj.activeEle[1].start_x
										cnvobj.activeEle[1].offs_y = y - cnvobj.activeEle[1].start_y
										cnvobj.activeEle[1].distX = cnvobj.activeEle[1].start_x - cnvobj.activeEle[1].end_x
										cnvobj.activeEle[1].distY = cnvobj.activeEle[1].start_y - cnvobj.activeEle[1].end_y

										local GridXpos = snap.Sx(cnvobj.activeEle[1].start_x, cnvobj.grid_x)
										local GridYpos = snap.Sy(cnvobj.activeEle[1].start_y, cnvobj.grid_y)
										cnvobj.activeEle[1].offsetXfromGrid = cnvobj.activeEle[1].start_x - GridXpos
										cnvobj.activeEle[1].offsetYfromGrid = cnvobj.activeEle[1].start_y - GridYpos
									end

									cnvobj.activeEle[ActiveEleLen+1].offs_x = cnvobj.activeEle[1].start_x - cnvobj.activeEle[ActiveEleLen+1].start_x
									cnvobj.activeEle[ActiveEleLen+1].offs_y = cnvobj.activeEle[1].start_y - cnvobj.activeEle[ActiveEleLen+1].start_y

									cnvobj.activeEle[ActiveEleLen+1].distX = cnvobj.activeEle[ActiveEleLen+1].start_x - cnvobj.activeEle[ActiveEleLen+1].end_x
									cnvobj.activeEle[ActiveEleLen+1].distY = cnvobj.activeEle[ActiveEleLen+1].start_y - cnvobj.activeEle[ActiveEleLen+1].end_y

									table.remove(cnvobj.drawnObj,i)
								else
									i = i + 1
								end
							end	
						end
					else
						cnvobj.activeEle[1] = cnvobj.drawnObj[index]
						cnvobj.activeEle[1].offs_x = x - cnvobj.activeEle[1].start_x
						cnvobj.activeEle[1].offs_y = y - cnvobj.activeEle[1].start_y
						cnvobj.activeEle[1].distX = cnvobj.activeEle[1].start_x - cnvobj.activeEle[1].end_x
						cnvobj.activeEle[1].distY = cnvobj.activeEle[1].start_y - cnvobj.activeEle[1].end_y

						local GridXpos = snap.Sx(cnvobj.activeEle[1].start_x, cnvobj.grid_x)
						local GridYpos = snap.Sy(cnvobj.activeEle[1].start_y, cnvobj.grid_y)
						cnvobj.activeEle[1].offsetXfromGrid = cnvobj.activeEle[1].start_x - GridXpos
						cnvobj.activeEle[1].offsetYfromGrid = cnvobj.activeEle[1].start_y - GridYpos

						table.remove(cnvobj.drawnObj, index)
					end
				end
			elseif #cnvobj.activeEle > 0 and cnvobj.drawing == "CLICKED" and pressed == 0 then
				cnvobj.drawing = "STOP"
				for i=1, #cnvobj.activeEle do
					table.insert(cnvobj.drawnObj, cnvobj.activeEle[i].shapeID, cnvobj.activeEle[i])
				end
				cnvobj.activeEle = {}
			end

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
	  
	cnvobj.drawn = {
		obj = {ids=0},		-- See structure in objects.lua
		group = {},			-- array of arrays containing objects intended to be grouped together
		port = {ids=0},		-- array of port structures. See structure of port in ports.lua
		conn = {ids=0},		-- array of connector structures. See structure of connector in connector.lua
	}
	cnvobj.hook = {ids=0}	-- Array of hook structure. See structure of hook in hooks.lua
	cnvobj.op = {mode="DISP"}
	
	-- Create the canvas element
	cnvobj.cnv = iup.canvas{}		-- iup canvas where all drawing will happen
	cnvobj.cnv.rastersize=""..cnvobj.width.."x"..cnvobj.height..""
	
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
		hooks.processHooks(cnvobj,"MOUSECLICKPRE")
		hooks.processHooks(cnvobj,"MOUSECLICKPOST")
	end
	
	function cnvobj.cnv:motion_cb(x, y, status)
		
	end
	
	setmetatable(cnvobj,{__index = objFuncs})
	
	return cnvobj
end
