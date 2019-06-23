local m = require("createCanvas")
local module = m.new()
local print = print
local iup = iup
local cd = cd
local im = im 


local M = {}
package.loaded[...]= M 
_ENV = M

	mode = ''
	grid_x = 10 --default value
	grid_y = 10 --default value
	width = 100
	height = 100 --default value
	cnv = nil
	drawnEle = {}  --The table which contains all the drawn elements data
	savedEle = {}
	shape = ''
	gridVisibility = true
	
    --function to create new canvas object	
	new = function(nMode, gridx, gridy, t_width, t_height, grid_visibility)
		local cnvobj = {}
		cnvobj.save = save
		cnvobj.refresh = refresh
		cnvobj.load = load
		cnvobj.drawObj = drawObj
		cnvobj.erase = erase
		cnvobj.gridVisibility = grid_visibility
		cnvobj.drawnEle = {}
		cnvobj.savedEle = {}
		cnvobj.mode = nMode
		cnvobj.grid_x = gridx
		cnvobj.grid_y = gridy
		cnvobj.width = t_width
		cnvobj.height = t_height
		
		cnvobj.cnv = module.newcanvas(cnvobj)

		function cnvobj.cnv:action()
			module.action(cnvobj)
		end
		function cnvobj.cnv:map_cb()
			module.map_cb(self)
		end
		function cnvobj.cnv:unmap_cb()
			module.unmap_cb(self)
		end
		
		return cnvobj
	end
	--function to draw shape/object on canvas
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
			iup.Message("Error","cnvobj required")
			return false
		end
		
	end
	
	save = function(cnvobj)
		cnvobj.savedEle = cnvobj.drawnEle
	end

	load = function(cnvobj)
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
						
						cnvobj.cnv.shape = nil
						iup.Update(cnvobj.cnv)
					end
				end
			end
		end
		
	end
	
	erase = function(cnvobj)
		
		cnvobj.drawnEle = {}
		module.create_white_image_and_draw_grid_on_image(cnvobj.cnv,cnvobj)
		iup.Update(cnvobj.cnv)

		function cnvobj.cnv:action()
			module.action(cnvobj)
		end
	end

	--[[erase = function(self)
		self.mode = nil
		self.grid_x = nil
		self.grid_y = nil
		self.width = nil
		self.height = nil
		self.cnv = nil 
		self.str = nil 
		self.new = nil
		self.drawObj = nil
		self.save = nil
	end]]

