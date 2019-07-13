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


local function Manipulate_loaded_shape(cnvobj,temp_canvas,x,y,buttonReleased)
	if #cnvobj.loadedEle > 0 then
		local center_x , center_y = math.abs((cnvobj.loadedEle[1].end_x - cnvobj.loadedEle[1].start_x)/2+cnvobj.loadedEle[1].start_x), math.abs((cnvobj.loadedEle[1].end_y-cnvobj.loadedEle[1].start_y)/2+cnvobj.loadedEle[1].start_y)
		y = cnvobj.height - y

    	if buttonReleased == true then
			x = snap.Sx(x,cnvobj.grid_x)
			y = snap.Sy(y,cnvobj.grid_y)
			center_x = snap.Sx(center_x, cnvobj.grid_x)
			center_y = snap.Sy(center_y, cnvobj.grid_y)
		end					
					
		for i=1, #cnvobj.loadedEle do	
			cnvobj.loadedEle[i].start_x = cnvobj.loadedEle[i].start_x + x - center_x
			cnvobj.loadedEle[i].start_y = cnvobj.loadedEle[i].start_y + y - center_y
			cnvobj.loadedEle[i].end_x = cnvobj.loadedEle[i].end_x + x - center_x
			cnvobj.loadedEle[i].end_y = cnvobj.loadedEle[i].end_y + y - center_y
	
			if buttonReleased == true then
				local index = #cnvobj.drawnEle
	 			cnvobj.drawnEle[index+1] = {}
	  			cnvobj.drawnEle[index+1].shape = cnvobj.loadedEle[i].shape
	  			cnvobj.drawnEle[index+1].start_x = cnvobj.loadedEle[i].start_x
	  			cnvobj.drawnEle[index+1].start_y = cnvobj.loadedEle[i].start_y
	  			cnvobj.drawnEle[index+1].end_x = cnvobj.loadedEle[i].end_x
	  			cnvobj.drawnEle[index+1].end_y = cnvobj.loadedEle[i].end_y
			end
		end
		if buttonReleased == true then
			cnvobj.loadedEle = {}
		end
	end
end

local function Manipulate_activeEle(cnvobj,x,y)
	if #cnvobj.activeEle > 0 then
		local center_x , center_y = math.abs((cnvobj.activeEle[1].end_x - cnvobj.activeEle[1].start_x)/2+cnvobj.activeEle[1].start_x), math.abs((cnvobj.activeEle[1].end_y-cnvobj.activeEle[1].start_y)/2+cnvobj.activeEle[1].start_y)
		y = cnvobj.height - y
		cnvobj.activeEle[1].start_x = cnvobj.activeEle[1].start_x + x - center_x
		cnvobj.activeEle[1].start_y = cnvobj.activeEle[1].start_y + y - center_y
		cnvobj.activeEle[1].end_x = cnvobj.activeEle[1].end_x + x - center_x
		cnvobj.activeEle[1].end_y = cnvobj.activeEle[1].end_y + y - center_y
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
					CC.button_cb(cnvobj,button, pressed, x, y)
					if pressed == 0 then
						cnvobj.drawing = "STOP"
					end
				end
				--click function
				if #cnvobj.drawnEle > 0 and cnvobj.drawing == "STOP" and pressed == 1 then
					local index = check.main(cnvobj,x,y)
					if index ~= 0 then
						cnvobj.drawing = "CLICKED"
					end
				elseif #cnvobj.activeEle > 0 and cnvobj.drawing == "CLICKED" then
					cnvobj.drawing = "STOP"
					cnvobj.drawnEle[#cnvobj.drawnEle + 1] = cnvobj.activeEle[1]
					cnvobj.activeEle = {}
				end

				--if load function is called
				if cnvobj.drawing == "STOP" then
					if button == iup.BUTTON1 then
						if pressed == 1 then
							move = true
						else
							move = false
							Manipulate_loaded_shape(cnvobj,cnvobj.cdbCanvas,x,y,true)
						end
					end
				end	
			
			end

			function cnvobj.cnv:motion_cb(x, y, status)
				if cnvobj.drawing == "START" then 
					CC.motion_cb(cnvobj, x, y, status)
				end
				
				-- click fun.
				if iup.isbutton1(status) and cnvobj.drawing == "CLICKED" and #cnvobj.activeEle > 0 then
					Manipulate_activeEle(cnvobj,x,y)
					cnvobj.cdbCanvas:Flush()
					iup.Update(cnvobj.cnv)
				end
				
				-- if load function is called then 
				if iup.isbutton1(status) and cnvobj.drawing == "STOP" and move then
					Manipulate_loaded_shape(cnvobj,cnvobj.cdbCanvas,x,y,false)
					cnvobj.cdbCanvas:Flush()
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
			cnvobj.drawing = "STOP"
			
			move = false
			
			cnvobj.loadedEle = tableUtils.s2t(str)

			if #cnvobj.loadedEle == 0 then
				local msg = "length of string is zero"
				return msg
			end
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
