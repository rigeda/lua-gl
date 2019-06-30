local test_str  
local require = require
local pairs = pairs
local print = print
local iup = iup
local cd = cd
local im = im 
local tonumber = tonumber 
local string = string 
local setmetatable = setmetatable
local type = type
local math = math
local snap = require("snap")
local M = {}
package.loaded[...] = M
_ENV = M		-- Lua 5.2+

local tableUtils = require("tableUtils")
local CC = require("createCanvas")

--[[this function is used to draw the loaded shape it takes 4 arguments 
	the first cnvobj which used for snaping, second a CD Canvas where we have to draw a loaded shape, 
	third and forth x & y where we have to place the loaded shape on the CD Canvas
	
	this function simply calculates the center of the first element of shape according to the center place all the elements of shape on CD canvas.
	]]

local function draw_loaded_shape(cnvobj,temp_canvas,x,y,IsSnap)
	local center_x , center_y = math.abs((cnvobj.loadedEle[1].end_x - cnvobj.loadedEle[1].start_x)/2+cnvobj.loadedEle[1].start_x), math.abs((cnvobj.loadedEle[1].end_y-cnvobj.loadedEle[1].start_y)/2+cnvobj.loadedEle[1].start_y)
		y = cnvobj.height - y

    if IsSnap == true then
			x = snap.Sx(x,cnvobj.grid_x)
			y = snap.Sy(y,cnvobj.grid_y)
			center_x = snap.Sx(center_x, cnvobj.grid_x)
			center_y = snap.Sy(center_y, cnvobj.grid_y)
		end					
					
		for i=1, #cnvobj.loadedEle do
		start_x = cnvobj.loadedEle[i].start_x
		start_y = cnvobj.loadedEle[i].start_y
		end_x = cnvobj.loadedEle[i].end_x
		end_y = cnvobj.loadedEle[i].end_y

		start_x = start_x + x - center_x
    start_y = start_y + y - center_y
    end_x = end_x + x - center_x
		end_y = end_y + y - center_y

		CC.DrawShape(temp_canvas, start_x, start_y, end_x, end_y, cnvobj.loadedEle[i].shape)
	end
end


local objFuncs = {

	erase = function(cnvobj)
		cnvobj.drawnEle = {}
		CC.create_white_image_and_draw_grid_on_image(cnvobj)
		iup.Update(cnvobj.cnv)
	end,

	drawObj = function(cnvobj,shape)
	 	if cnvobj then
			
			cnvobj.shape = shape

			function cnvobj.cnv:button_cb(button,pressed,x,y)
				if cnvobj.drawing == "START" then
					CC.button_cb(cnvobj,button, pressed, x, y)
				end
			end

			function cnvobj.cnv:motion_cb(x, y, status)
				if cnvobj.drawing == "START" then 
				
					CC.motion_cb(cnvobj, x, y, status)
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
			cnvobj.shape = nil
			move = false
    
			cnvobj.loadedEle = tableUtils.s2t(str)

			if #cnvobj.loadedEle == 0 then
				local msg = "loadedEle table is empty"
				return msg
			end

			
			function cnvobj.cnv:button_cb(button,pressed,x,y)
				if cnvobj.drawing == "STOP" then
					
					if button == iup.BUTTON1 then
						if pressed == 1 then
							move = true
						else
							move = false

							local image = cnvobj.cnv.image
							local temp_canvas = cd.CreateCanvas(cd.IMIMAGE, image)

		          draw_loaded_shape(cnvobj,temp_canvas,x,y,true)

							temp_canvas:Kill()
							iup.Update(cnvobj.cnv)
						end
					end
				end	
			
			end

			function cnvobj.cnv:motion_cb(x, y, status)
				if move then
				  if cnvobj.drawing == "STOP" and iup.isbutton1(status) then
					 
						draw_loaded_shape(cnvobj,cnvobj.cdbCanvas,x,y,false)

						cnvobj.cdbCanvas:Flush()
						iup.Update(cnvobj.cnv)
					end
				end
			end
		end	
	end,

}

mapCB = function(cnvobj)
	local cd_Canvas = cd.CreateCanvas(cd.IUP, cnvobj.cnv)
	local cd_bCanvas = cd.CreateCanvas(cd.DBUFFER,cd_Canvas)
	cnvobj.cdCanvas = cd_Canvas
	cnvobj.cdbCanvas = cd_bCanvas
end
unmapCB = function(cnvobj)
	local cd_bCanvas = cnvobj.cdbCanvas
	local cd_Canvas = cnvobj.cdCanvas
	cd_bCanvas:Kill()
	cd_Canvas:Kill()
end

local function checkPara(para)
	--[[if not para.drawing or type(para.drawing) ~= "string" then
		return nil,"drawing not given or not a string"
	end]]
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
  
	cnvobj.drawing = "START"
	
	cnvobj.drawnEle = {}
  cnvobj.loadedEle = {}
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

	CC.create_white_image_and_draw_grid_on_image(cnvobj)
	
	setmetatable(cnvobj,{__index = objFuncs})
	
	return cnvobj
end


	
	

