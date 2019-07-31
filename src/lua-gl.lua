local table = table
local pairs = pairs
local print = print
local iup = iup
local cd = cd
local setmetatable = setmetatable
local type = type
local math = math
local snap = require("snap")

local check = require("ClickFunctions")
local tableUtils = require("tableUtils")
local CC = require("createCanvas")

local M = {}
package.loaded[...] = M
_ENV = M		-- Lua 5.2+


local function Manipulate_loaded_shape(cnvobj, x,y,Table)
	if #Table > 0 then
		local center_x , center_y = math.abs((Table[1].end_x - Table[1].start_x)/2+Table[1].start_x), math.abs((Table[1].end_y-Table[1].start_y)/2+Table[1].start_y)
		y = cnvobj.height - y			
					
		for i=1, #Table do	
			Table[i].start_x = math.floor(Table[i].start_x + x - center_x)
			Table[i].start_y = math.floor(Table[i].start_y + y - center_y)
			Table[i].end_x = math.floor(Table[i].end_x + x - center_x)
			Table[i].end_y = math.floor(Table[i].end_y + y - center_y)
			if cnvobj.snapGrid == true then
				Table[i].start_x = snap.Sx(Table[i].start_x, cnvobj.grid_x)
				Table[i].start_y = snap.Sy(Table[i].start_y, cnvobj.grid_y)
				Table[i].end_x = snap.Sx(Table[i].end_x, cnvobj.grid_x)
				Table[i].end_y = snap.Sy(Table[i].end_y, cnvobj.grid_y)
			end
		end
	end
end

--[[local function Manipulate_activeEle(cnvobj,x,y)
	if #cnvobj.activeEle > 0 then
		local center_x , center_y = math.abs((cnvobj.activeEle[1].end_x - cnvobj.activeEle[1].start_x)/2+cnvobj.activeEle[1].start_x), math.abs((cnvobj.activeEle[1].end_y-cnvobj.activeEle[1].start_y)/2+cnvobj.activeEle[1].start_y)
		y = cnvobj.height - y

		for i=1, #cnvobj.activeEle do
			cnvobj.activeEle[i].start_x = math.floor(cnvobj.activeEle[i].start_x + x - center_x)
			cnvobj.activeEle[i].start_y = math.floor(cnvobj.activeEle[i].start_y + y - center_y)
			cnvobj.activeEle[i].end_x = math.floor(cnvobj.activeEle[i].end_x + x - center_x)
			cnvobj.activeEle[i].end_y = math.floor(cnvobj.activeEle[i].end_y + y - center_y)
        
			if cnvobj.snapGrid == true then
				cnvobj.activeEle[i].start_x = snap.Sx(cnvobj.activeEle[i].start_x, cnvobj.grid_x)
				cnvobj.activeEle[i].start_y = snap.Sy(cnvobj.activeEle[i].start_y, cnvobj.grid_y)
				cnvobj.activeEle[i].end_x = snap.Sx(cnvobj.activeEle[i].end_x, cnvobj.grid_x)
				cnvobj.activeEle[i].end_y = snap.Sy(cnvobj.activeEle[i].end_y, cnvobj.grid_y)
			end
		end
	end
end]]

local function checkIndexInGroups(cnvobj,shape_id)
	for i=1,#cnvobj.group do
		for j=1, #cnvobj.group[i] do
			if shape_id == cnvobj.drawnEle[cnvobj.group[i][j]].shapeID then
				return true, i 
			end
		end
	end
end

local function findIndexAccordingToGroupId(cnvobj,groupID)
	for i = 1, #cnvobj.drawnEle do
		for j = 1, #cnvobj.group[groupID] do
			if cnvobj.group[groupID][j] == cnvobj.drawnEle[i].shapeID then
				return i
			end
		end
	end
end

local objFuncs = {

	erase = function(cnvobj)
		cnvobj.drawnEle = {}
		cnvobj.loadedEle = {}
		iup.Update(cnvobj.cnv)
	end,

	drawObj = function(cnvobj,shape)
	 	if cnvobj then
			cnvobj.drawing = "START"
			cnvobj.shape = shape

			function cnvobj.cnv:button_cb(button,pressed,x,y)
				if cnvobj.drawing == "START" then
					CC.buttonCB(cnvobj,button, pressed, x, y)
					if pressed == 0 then
						cnvobj.drawing = "STOP"
					end
				end
				--click function
				if #cnvobj.drawnEle > 0 and cnvobj.drawing == "STOP" and pressed == 1 then
					y = cnvobj.height - y
					local index = check.main(cnvobj,x,y)
					
					if index ~= 0 and index then --index should not nill
						cnvobj.drawing = "CLICKED"
						local indexBelongToAnyGroup, groupID = checkIndexInGroups(cnvobj,cnvobj.drawnEle[index].shapeID)
						--print(indexBelongToAnyGroup, groupID.." INDEX = "..index)
						if indexBelongToAnyGroup then
							for j=1, #cnvobj.group[groupID] do
								local i = 1
								while #cnvobj.drawnEle >= i do
									--print(#cnvobj.group[groupID],j,groupID,i)
									if cnvobj.group[groupID][j] == cnvobj.drawnEle[i].shapeID then
										local ActiveEleLen = #cnvobj.activeEle
										cnvobj.activeEle[ActiveEleLen+1] = {}
										cnvobj.activeEle[ActiveEleLen+1] = cnvobj.drawnEle[i]
										--print(#cnvobj.activeEle,cnvobj.activeEle[#cnvobj.activeEle].start_x)
										table.remove(cnvobj.drawnEle,i)
									else
										i = i + 1
									end
								end	
							end
						else
							cnvobj.activeEle[1] = cnvobj.drawnEle[index]
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
							Manipulate_loaded_shape(cnvobj, x,y,cnvobj.loadedEle)
							for i=1, #cnvobj.loadedEle do
								local index = #cnvobj.drawnEle
								cnvobj.drawnEle[index+1] = {}
								cnvobj.drawnEle[index+1] = cnvobj.loadedEle[i]
								cnvobj.drawnEle[index+1].shapeID = index + 1 
								--[[cnvobj.drawnEle[index+1].shape = cnvobj.loadedEle[i].shape
								cnvobj.drawnEle[index+1].start_x = cnvobj.loadedEle[i].start_x
								cnvobj.drawnEle[index+1].start_y = cnvobj.loadedEle[i].start_y
								cnvobj.drawnEle[index+1].end_x = cnvobj.loadedEle[i].end_x
								cnvobj.drawnEle[index+1].end_y = cnvobj.loadedEle[i].end_y]]
							end
								cnvobj.loadedEle = {}
							cnvobj.drawing = "STOP"
						end
					end
				end	
			
			end

			function cnvobj.cnv:motion_cb(x, y, status)
				if cnvobj.drawing == "START" then 
					CC.motionCB(cnvobj, x, y, status)
				end
				
				-- click fun.
				if iup.isbutton1(status) and cnvobj.drawing == "CLICKED" and #cnvobj.activeEle > 0 then
					Manipulate_loaded_shape(cnvobj,x,y,cnvobj.activeEle)
					iup.Update(cnvobj.cnv)
				end
				
				-- if load function is called then 
				if iup.isbutton1(status) and cnvobj.drawing == "LOAD" and move then
					Manipulate_loaded_shape(cnvobj, x, y, cnvobj.loadedEle)
					iup.Update(cnvobj.cnv)
				end

			end         
		end	
	end,

	save = function(cnvobj)
		local str = tableUtils.t2s(cnvobj.drawnEle)
		return str
	end,

	load = function(cnvobj,str)
		if cnvobj then
			cnvobj.drawing = "LOAD"
			
			move = false
			
			cnvobj.loadedEle = tableUtils.s2t(str)

			if #cnvobj.loadedEle == 0 then
				local msg = "length of string is zero"
				return msg
			end
		end	
	end,

	whichShape = function(cnvobj,posX,posY)
		local ind = check.main(cnvobj,posX,posY)
		--print(ind)
		if ind ~= 0 and ind then --index should not nill
			return cnvobj.drawnEle[ind].shapeID
		end
	end,

	groupShapes = function(cnvobj,shapeList)
		if #cnvobj.drawnEle > 0 then
			cnvobj.group[#cnvobj.group+1] = shapeList
		end
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
  	
	cnvobj.drawnEle = {}
	cnvobj.group = {}
  	cnvobj.loadedEle = {}
	cnvobj.activeEle = {}
	cnvobj.clickFlag = false
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
