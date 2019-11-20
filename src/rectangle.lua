-- Module to add rectangle functionality in lua-gl

local coorc = require("lua-gl.CoordiateCalc")

local M = {}
package.loaded[...] = M
_ENV = M


-- Function to check whether rectangle object is selectable by x,y within the given resolution res
function checkXY(obj, x, y, res)
	if obj.shape ~= "RECT" and obj.shape ~= "BLOCKINGRECT" and obj.shape ~= "FILLEDRECT" then
		return nil
	end
	
	
	local x1, y1 = obj.start_x, obj.start_y
	local x3, y3 = obj.end_x , obj.end_y
	local x2, y2, x4, y4 = x1, y3, x3, y1

	if obj.shape == "RECT" then
		local i1 = coorc.PointOnLine(x1,y1,x2,y2,x,y,res)
		local i2 = coorc.PointOnLine(x2,y2,x3,y3,x,y,res)
		local i3 = coorc.PointOnLine(x3,y3,x4,y4,x,y,res)
		local i4 = coorc.PointOnLine(x4,y4,x1,y1,x,y,res)

		if i1 or i2 or i3 or i4 then
			return true
		end
	else
		return coorc.PointInRect(x1, y1, x2, y2, x3, y3, x4, y4, x, y)
	end
end				
