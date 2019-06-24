
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

local M = {}
package.loaded[...] = M
_ENV = M		-- Lua 5.2+

local tableUtils = require("tableUtils")
local module = require("createCanvas")


local objFuncs = {

	erase = function(cnvobj)
		
		cnvobj.drawnEle = {}
		module.create_white_image_and_draw_grid_on_image(cnvobj.cnv,cnvobj)
		iup.Update(cnvobj.cnv)

		function cnvobj.cnv:action()
			module.action(cnvobj)
		end
	end,

	drawObj = function(cnvobj,shape)
	 	if cnvobj then
			
			cnvobj.shape = shape

			function cnvobj.cnv:button_cb(button,pressed,x,y)
				if cnvobj.mode == "DRAWING" then
					--print("button")
					module.button_cb(cnvobj,button, pressed, x, y)
				end
			end
			function cnvobj.cnv:motion_cb(x, y, status)
				if cnvobj.mode == "DRAWING" then 
					--print("motion")
					module.motion_cb(cnvobj, x, y, status)
				end
			end         
		else
			--iup.Message("Error","cnvobj required")
			return false
		end
		
	end,

	save = function(cnvobj)
		cnvobj.savedEle = cnvobj.drawnEle
		local str = tableUtils.t2s(cnvobj.savedEle)
		return str
		--refresh(cnvobj)
	end,

	load = function(cnvobj)
		function cnvobj.cnv:action()
			module.action(cnvobj)
		end
		if cnvobj then
			function cnvobj.cnv:button_cb(button,pressed,x,y)
				
				if cnvobj.mode == "EDITOR" then
					local image = cnvobj.cnv.image
					if pressed == 1 then
						local temp_canvas = cd.CreateCanvas(cd.IMIMAGE, image)
						for i=1, #cnvobj.savedEle do
							module.DrawShape(temp_canvas, cnvobj.savedEle[i].start_x, cnvobj.savedEle[i].start_y, cnvobj.savedEle[i].end_x, cnvobj.savedEle[i].end_y, cnvobj.savedEle[i].shape)
						end

						temp_canvas:Kill()
						cnvobj.shape = nil
						iup.Update(cnvobj.cnv)
					end
				end
			end
		end
		
	end,

}


mapCB = function(self)
	local cd_Canvas = cd.CreateCanvas(cd.IUP, self)
	local cd_bCanvas = cd.CreateCanvas(cd.DBUFFER,cd_Canvas)
	self.cdCanvas = cd_Canvas
	self.cdbCanvas = cd_bCanvas
end
unmapCB = function(self)
	local cd_bCanvas = self.cdbCanvas
	local cd_Canvas = self.cdCanvas
	cd_bCanvas:Kill()
	cd_Canvas:Kill()
end

local function checkPara(para)
	if not para.mode or type(para.mode) ~= "string" then
		return nil,"mode not given or not a string"
	end
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
	if not para.gridVisibility or type(para.gridVisibility) ~= "boolean" then
		return nil, "gridVisibility not given or not a boolean"
	end
	
	return true
end



new = function(para)
	local cnvobj = {}
	local resp,msg = checkPara(para)
   
	if not resp then
		print(resp)
		return nil,msg
	end

	for k,v in pairs(para) do
		cnvobj[k] = v
	end

	cnvobj.cnv = module.newcanvas(cnvobj)
	cnvobj.drawnEle = {}
	cnvobj.savedEle = {}

	cnvobj.cnv.map_cb = mapCB
	cnvobj.cnv.unmap_cb = unmapCB
	
	print(cnvobj.cnv.cdCanvas)
	
	function cnvobj.cnv.action()
		--print(cnvobj.cnv.cdCanvas)
		module.action(cnvobj)
	end
	
	setmetatable(cnvobj,{__index = objFuncs})
	
	return cnvobj
end
