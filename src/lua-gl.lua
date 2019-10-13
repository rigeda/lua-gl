local table = table
local pairs = pairs
local print = print
local iup = iup
local cd = cd
local error = error
local pcall = pcall
local setmetatable = setmetatable
local type = type
local math = math
local snap = require("snap")
local segmentGenerator = require("segmentGenerator")
local check = require("ClickFunctions")
local tableUtils = require("tableUtils")
local CC = require("createCanvas")

local M = {}
package.loaded[...] = M
_ENV = M		-- Lua 5.2+

-- this function is used to manipulate active Element table data
local function Manipulate_activeEle(cnvobj, x, y, Table)
	if #Table > 0 then

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
		
		for i=1, #Table do	
			
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
								if segmentID and status=="ending" then
									cnvobj.connector[connectorID].segments[segmentID].end_x = Table[i].portTable[ite].x
									cnvobj.connector[connectorID].segments[segmentID].end_y = Table[i].portTable[ite].y
								end
								if segmentID and status=="starting" then
									cnvobj.connector[connectorID].segments[segmentID].start_x = Table[i].portTable[ite].x
									cnvobj.connector[connectorID].segments[segmentID].start_y = Table[i].portTable[ite].y
								end
							end
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
				if shape_id == cnvobj.drawnEle[cnvobj.group[i][j]].shapeID then
					return true, i 
				end
			end
		end
	end
	return false
end

local function cursorOnPort(cnvobj, x, y)
	for i = 1, #cnvobj.port do
		if math.abs(cnvobj.port[i].x - x) <= cnvobj.grid_x/2 then
			if math.abs(cnvobj.port[i].y - y) <= cnvobj.grid_y/2 then
				return true,cnvobj.port[i].portID
			end
		end
	end
	return false
end

local function addTwoTableAndRemoveDuplicate(table2,table1,table3)
	res = {}
	hash = {}
	for _,v in pairs(table2) do
		table.insert(table1, v) 
	end	
	for _,v in pairs(table3) do
		table.insert(table1, v) 
	end	
	for _,v in pairs(table1) do
		if (not hash[v]) then
			res[#res+1] = v 
			hash[v] = true
		end
	end
	return res
end

local objFuncs = {

	erase = function(cnvobj)
		cnvobj.drawnEle = {}
		cnvobj.group = {}
		cnvobj.port = {}
		cnvobj.connector = {}
		cnvobj.connectorFlag = false
		cnvobj.clickFlag = false
		cnvobj.tempflag = false

		iup.Update(cnvobj.cnv)
	end,

	drawObj = function(cnvobj,shape)
	 	if cnvobj then
			cnvobj.drawing = "START"
			cnvobj.shape = shape

			function cnvobj.cnv:button_cb(button,pressed,x,y, status)
				y = cnvobj.height - y
				if #cnvobj.hook > 0 then
					--y = cnvobj.height - y
					for i=#cnvobj.hook, 1, -1 do
						if cnvobj.hook[i].key == "MOUSECLICKPRE" then
							local func = cnvobj.hook[i].fun
							local status, val = pcall(func, button, pressed, x, y)
							if not status then
								error("error: " .. val)
							end
							--func(button, pressed, x, y)
						end
					end
				end

				if cnvobj.drawing == "START" then
					CC.buttonCB(cnvobj,button, pressed, x, y)
					if pressed == 0 then
						cnvobj.drawing = "STOP"
					end
				end

				--connectors
				if cnvobj.drawing == "CONNECTOR" then
					cnvobj.shape = "LINE"
					cnvobj.matrix = segmentGenerator.findMatrix(cnvobj)
					--[[for i=1, #cnvobj.matrix do
						str = ""
						for j=1, #cnvobj.matrix[i] do
							str = str..cnvobj.matrix[i][j].." "
						end
						print(str)
					end]]
					if pressed == 0 then
						cnvobj.connectorFlag = true
						local index = #cnvobj.connector
						cnvobj.connector[index].ID = index

						
						x = snap.Sx(x, cnvobj.grid_x)
						y = snap.Sy(y, cnvobj.grid_y)
						

						local segLen = #cnvobj.connector[index].segments
						cnvobj.connector[index].segments[segLen+1] = {}
						cnvobj.connector[index].segments[segLen+1].ID = segLen + 1
						cnvobj.connector[index].segments[segLen+1].start_x = x 
						cnvobj.connector[index].segments[segLen+1].start_y = y
						cnvobj.connector[index].segments[segLen+1].end_x = x 
						cnvobj.connector[index].segments[segLen+1].end_y = y
						
							
					end
					local isCursorOnPort, p_ID = cursorOnPort(cnvobj, x, y)

					if pressed == 1 and cnvobj.connectorFlag == false and isCursorOnPort then
						
						if not cnvobj.port[p_ID].segmentTable then
							cnvobj.port[p_ID].segmentTable = {}
						end
						local portSegTableLen = #cnvobj.port[p_ID].segmentTable
						cnvobj.port[p_ID].segmentTable[portSegTableLen+1] = {}
						cnvobj.port[p_ID].segmentTable[portSegTableLen+1].segmentID = 1 
						cnvobj.port[p_ID].segmentTable[portSegTableLen+1].connectorID = #cnvobj.connector
						cnvobj.port[p_ID].segmentTable[portSegTableLen+1].segmentStatus = "starting"

					end

					if (pressed == 1 and cnvobj.connectorFlag == true) or iup.isdouble(status) then
						
						if isCursorOnPort == true then
							local index = #cnvobj.connector
							local segLen = #cnvobj.connector[index].segments

							if not cnvobj.port[p_ID].segmentTable then
								cnvobj.port[p_ID].segmentTable = {}
							end

							local portSegTableLen = #cnvobj.port[p_ID].segmentTable
							cnvobj.port[p_ID].segmentTable[portSegTableLen+1] = {}

							cnvobj.port[p_ID].segmentTable[portSegTableLen+1].segmentID = segLen
							cnvobj.port[p_ID].segmentTable[portSegTableLen+1].connectorID = index
							cnvobj.port[p_ID].segmentTable[portSegTableLen+1].segmentStatus = "ending"
							
							--cnvobj.port[p_ID].segmentID = segLen
							--cnvobj.port[p_ID].connectorID = index
							--cnvobj.port[p_ID].segmentStatus = "ending"
							
							cnvobj.drawing = "STOP"
							cnvobj.connectorFlag = false
							
							iup.Update(cnvobj.cnv)
						end
						if iup.isdouble(status) then
							cnvobj.drawing = "STOP"
							cnvobj.connectorFlag = false
							table.remove(cnvobj.connector[#cnvobj.connector].segments,#cnvobj.connector[#cnvobj.connector].segments)
							table.remove(cnvobj.connector[#cnvobj.connector].segments,#cnvobj.connector[#cnvobj.connector].segments)
						end
					end
					
				end
				--click function
				if #cnvobj.drawnEle > 0 and cnvobj.drawing == "STOP" and pressed == 1 then
					--y = cnvobj.height - y
					local index = check.checkXY(cnvobj,x,y)
					if index ~= 0 and index then --index should not nill
						cnvobj.drawing = "CLICKED"
						local indexBelongToAnyGroup, groupID = checkIndexInGroups(cnvobj,cnvobj.drawnEle[index].shapeID)

						if indexBelongToAnyGroup then
							for j=1, #cnvobj.group[groupID] do
								local i = 1
								while #cnvobj.drawnEle >= i do
									--print(#cnvobj.group[groupID],j,groupID,i)
									if cnvobj.group[groupID][j] == cnvobj.drawnEle[i].shapeID then
										local ActiveEleLen = #cnvobj.activeEle
										--cnvobj.activeEle[ActiveEleLen+1] = {}
										cnvobj.activeEle[ActiveEleLen+1] = cnvobj.drawnEle[i]
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

										table.remove(cnvobj.drawnEle,i)
									else
										i = i + 1
									end
								end	
							end
						else
							cnvobj.activeEle[1] = cnvobj.drawnEle[index]
							cnvobj.activeEle[1].offs_x = x - cnvobj.activeEle[1].start_x
							cnvobj.activeEle[1].offs_y = y - cnvobj.activeEle[1].start_y
							cnvobj.activeEle[1].distX = cnvobj.activeEle[1].start_x - cnvobj.activeEle[1].end_x
							cnvobj.activeEle[1].distY = cnvobj.activeEle[1].start_y - cnvobj.activeEle[1].end_y

							local GridXpos = snap.Sx(cnvobj.activeEle[1].start_x, cnvobj.grid_x)
							local GridYpos = snap.Sy(cnvobj.activeEle[1].start_y, cnvobj.grid_y)
							cnvobj.activeEle[1].offsetXfromGrid = cnvobj.activeEle[1].start_x - GridXpos
							cnvobj.activeEle[1].offsetYfromGrid = cnvobj.activeEle[1].start_y - GridYpos

							table.remove(cnvobj.drawnEle, index)
						end
					end
				elseif #cnvobj.activeEle > 0 and cnvobj.drawing == "CLICKED" and pressed == 0 then
					cnvobj.drawing = "STOP"
					for i=1, #cnvobj.activeEle do
						table.insert(cnvobj.drawnEle, cnvobj.activeEle[i].shapeID, cnvobj.activeEle[i])
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
								local index = #cnvobj.drawnEle
								cnvobj.drawnEle[index+1] = cnvobj.loadedEle.drawnEle[i]
								cnvobj.drawnEle[index+1].shapeID = index + 1

								--table.insert(tempTable, index+1)
								--print(#cnvobj.port)
								if cnvobj.drawnEle[index+1].portTable then
									for ite = 1, #cnvobj.drawnEle[index+1].portTable do
										cnvobj.port[#cnvobj.port+1] = cnvobj.drawnEle[index+1].portTable[ite]

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
				
				if #cnvobj.hook > 0 then
					--y = cnvobj.height - y
					for i=#cnvobj.hook, 1, -1 do
						if cnvobj.hook[i].key == "MOUSECLICKPOST" then
							local func = cnvobj.hook[i].fun
							local status, val = pcall(func, button, pressed, x, y)
							if not status then
								--error("error: " .. val)
							end
						end
					end
				end
			
			end


			function cnvobj.cnv:motion_cb(x, y, status)
				y = cnvobj.height - y
				if cnvobj.drawing == "START" then 
					CC.motionCB(cnvobj, x, y, status)
				end
				
				--connectors
				if cnvobj.drawing == "CONNECTOR" and cnvobj.connectorFlag == true then
					local index = #cnvobj.connector
					local segLen = #cnvobj.connector[index].segments
					
					while segLen > 1 do
						table.remove(cnvobj.connector[index].segments, segLen)
						segLen = segLen - 1
					end
					
					if segLen and index then
						segmentGenerator.generateSegments(cnvobj, index, segLen, x, y)
						--cnvobj.connector[index].segments[segLen].end_x = x 
						--cnvobj.connector[index].segments[segLen].end_y = y	
					end
					iup.Update(cnvobj.cnv)
				end

				-- click fun.
				if iup.isbutton1(status) and cnvobj.drawing == "CLICKED" and #cnvobj.activeEle > 0 then
					Manipulate_activeEle(cnvobj,x,y,cnvobj.activeEle)
					iup.Update(cnvobj.cnv)
				end
				
				-- if load function is called then 
				if iup.isbutton1(status) and cnvobj.drawing == "LOAD" and move then
					Manipulate_LoadedEle(cnvobj, x, y, cnvobj.loadedEle)
					iup.Update(cnvobj.cnv)
				end

			end         
		end	
	end,

	save = function(cnvobj)
		cnvobj.drawnData.drawnEle = cnvobj.drawnEle
		cnvobj.drawnData.group = cnvobj.group
		cnvobj.drawnData.port = cnvobj.port
		cnvobj.drawnData.connector = cnvobj.connector
		
		local str = tableUtils.t2sr(cnvobj.drawnData)
		return str
	end,

	load = function(cnvobj,str)
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

    -- this function take x & y as input and return shapeID if point (x, y) is near to the shape
	whichShape = function(cnvobj,posX,posY)
		--print(posX,posY)
		local ind = check.checkXY(cnvobj,posX,posY)
		if ind ~= 0 and ind then --index should not nill
			return cnvobj.drawnEle[ind].shapeID
		end
	end,

	-- groupShapes used to group Shape using shapeList
	groupShapes = function(cnvobj,shapeList)
		if #cnvobj.drawnEle > 0 then
			local tempTable = {}
			--print("you ar in group ing with len"..#shapeList)
			local match = false
			for k=1, #shapeList, 1 do
				local i = 1
				while #cnvobj.group >= i do
					for j=1, #cnvobj.group[i] do
						if shapeList[k]==cnvobj.group[i][j] then
							tempTable = addTwoTableAndRemoveDuplicate(cnvobj.group[i],shapeList,tempTable)
							table.remove(cnvobj.group, i)
							i = i - 1
							match = true
							break
						end
						
					end
					i = i + 1
				end
			end
			if match == true then
				cnvobj.group[#cnvobj.group+1] = tempTable
			else
				cnvobj.group[#cnvobj.group+1] = shapeList
			end
			table.sort(cnvobj.group[#cnvobj.group])
		end
	end,
	
	addHook = function(cnvobj,key, fun)
		local index = #cnvobj.hook
		cnvobj.hook[index+1] = {}
		cnvobj.hook[index+1].key = key
		cnvobj.hook[index+1].fun = fun 	
	end,

	addPort = function(cnvobj,x,y,shapeID)
		local index = #cnvobj.port
		local portID = index + 1

		cnvobj.port[index + 1] = {}
		cnvobj.port[index + 1].portID = portID

		if cnvobj.snapGrid == true then
			x = snap.Sx(x, cnvobj.grid_x)
			y = snap.Sy(y, cnvobj.grid_y)
		end
		cnvobj.port[index + 1].x = x 
		cnvobj.port[index + 1].y = y
	
		if shapeID then
			if shapeID > 0 then
				--cnvobj.port[index + 1].shape = {}
				cnvobj.port[index + 1].shape = cnvobj.drawnEle[shapeID]
			
				local lenOfPortTable = #cnvobj.drawnEle[shapeID].portTable
      			--cnvobj.drawnEle[shapeID].portTable[lenOfPortTable + 1] = {}
				cnvobj.drawnEle[shapeID].portTable[lenOfPortTable + 1] = cnvobj.port[#cnvobj.port]
				return true
			end
		end
		return false
		
	end, 

	drawConnector  = function(cnvobj)
		cnvobj.connector[#cnvobj.connector + 1] = {}
		cnvobj.connector[#cnvobj.connector].segments = {}
		cnvobj.drawing = "CONNECTOR"
	end,

}

local function mapCB(cnvobj)
	local cd_Canvas = cd.CreateCanvas(cd.IUP, cnvobj.cnv)
	local cd_bCanvas = cd.CreateCanvas(cd.DBUFFER,cd_Canvas)
	cnvobj.cdCanvas = cd_Canvas
	cnvobj.cdbCanvas = cd_bCanvas
end

local function unmapCB(cnvobj)
	local cd_bCanvas = cnvobj.cdbCanvas
	local cd_Canvas = cnvobj.cdCanvas
	cd_bCanvas:Kill()
	cd_Canvas:Kill()
end

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
	if type(para.gridVisibility) ~= "boolean" then
		return nil, "gridVisibility not given or not a boolean"
	end
	
	return true
end



new = function(para)
	local cnvobj = {}
	
	local resp,msg = checkPara(para)
   
	if not resp then
		return nil,msg
	end

	for k,v in pairs(para) do
		cnvobj[k] = v
	end
	  
	cnvobj.drawnData = {}
	cnvobj.drawnEle = {}
	cnvobj.group = {}
  	cnvobj.loadedEle = {}
	cnvobj.activeEle = {}
	cnvobj.hook = {}
	cnvobj.port = {}
	cnvobj.connector = {}
	cnvobj.connectorFlag = false
	cnvobj.clickFlag = false
	cnvobj.tempflag = false
	cnvobj.showBlockingRect = false
	cnvobj.cnv = iup.canvas{}
	cnvobj.cnv.rastersize=""..cnvobj.width.."x"..cnvobj.height..""
	
	function cnvobj.cnv.map_cb()
		mapCB(cnvobj)	
	end
	
	function cnvobj.cnv.unmap_cb()
		unmapCB(cnvobj)
	end
	
	function cnvobj.cnv.action()
		CC.render(cnvobj)
	end
	
	setmetatable(cnvobj,{__index = objFuncs})
	
	return cnvobj
end
