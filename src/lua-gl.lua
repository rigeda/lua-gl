local m = require("createCanvas")
local module = m.new()

canvasObj = {
	mode = "",
	grid_x = 10, --default value
	grid_y = 10, --default value
	width = 100,
	height = 100, --default value
	cnv = nil,
	drawnEle = {},  --The table which contains all the drawn elements data
	shape = "",
    gridVisibility = true,
    --function to create new canvas object	
	new = function(newMode, gridx, gridy, t_width, t_height, grid_visibility)
		local cnvobj = {}
		
		for k,v in pairs(canvasObj) do 
			cnvobj[k]=v 	
		end
		cnvobj.gridVisibility = grid_visibility
		cnvobj.drawnEle = {}
		cnvobj.mode = newMode
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
	end,
	--function to draw shape/object on canvas
	drawObj = function(cnvobj,shape)
		if cnvobj.mode == "DRAWING" then
			
			cnvobj.shape = shape

			function cnvobj.cnv:action()
				module.action(cnvobj)
			end
			function cnvobj.cnv:button_cb(button,pressed,x,y)
				module.button_cb(cnvobj,button, pressed, x, y)
			end
			function cnvobj.cnv:motion_cb(x, y, status)
				
				module.motion_cb(cnvobj, x, y, status)
				
			end
			function cnvobj.cnv:map_cb()
				module.map_cb(self)
			end
			function cnvobj.cnv:unmap_cb()
				module.unmap_cb(self)
			end            
		else
			iup.Message("Error","you can draw only in drawing mode")
			return false
		end
		
	end,

	erase = function(self)
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
	end
}
return canvasObj
