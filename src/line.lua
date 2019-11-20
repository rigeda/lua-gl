-- Module to add line drawing functionality to lua-gl

local coorc = require("lua-gl.CoordiateCalc")

local M = {}
package.loaded[...] = M
_ENV = M


-- Function to check whether line object is selectable by x,y within the given resolution res
function checkXY(obj, x, y,res)
	if obj.shape ~= "LINE" then
		return nil
	end
	
	local x1,y1,x2,y2
	x1 = obj.start_x
	y1 = obj.start_y
	x2 = obj.end_x
	y2 = obj.end_y

	return coorc.PointOnLine(x1, y1, x2, y2, x, y, res)                
end