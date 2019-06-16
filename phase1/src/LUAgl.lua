
canvasObj = {
	mode = "",
	grid_x = 10, --default value
	grid_y = 10, --default value
	width = 100,
	height = 100, --default value
	cnv = nil,
	str = "",
	module = nil,
    --function to create new canvas object	
	new = function(mode, gridx, gridy, t_width, t_height)
		local table = {}
		
		for k,v in pairs(canvasObj) do 
			table[k]=v 	
		end
		table.mode = mode
		table.grid_x = gridx
		table.grid_y = gridy
		table.width = t_width
		table.height = t_height
		grid_x_size = gridx
		grid_y_size = gridy
		width, height = t_width, t_height
		m = require("createCanvas")
		table.cnv = m.newcanvas(gridx, gridy, t_width, t_height)
		table.module = m
		print(table.cnv)
		--print(table.module.cnv)
		return table
	end,
	--function to draw shape(object) on canvas
	drawObj = function(self,obj)
		if self.mode == "DRAWING" then
			
			shapeName = obj
			
			require("motion")
			--print(self.cnv, self.mode, self.grid_x, self.grid_y, self.width, self.height)

			return self.cnv
		else
			iup.Message("Error","you can draw only in drawing mode")
			return false
		end
		
	end,
    -- save
	save = function(self)
		--m = require("t2depen")
		self.str = self.module.save()
		return self.str 
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
		--print(self.mode, self.grid_x,self.grid_y, self.width, self.height)
	end
}
return canvasObj
