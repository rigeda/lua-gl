-- Module to add ellipse functionality in lua-gl

local coorc = require("lua-gl.CoordiateCalc")
local abs = math.abs
local floor = math.floor

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

function draw(cnvobj,cnv,shape,x1,y1,x2,y2)
    if (shape == "ELLIPSE") then
		cnv:Arc(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), 0, 360)
    elseif (shape == "FILLEDELLIPSE") then
		cnv:Sector(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), 0, 360)
	end
	return true
end

-- Function to check whether ellipse object is selectable by x,y within the given resolution res
function checkXY(obj, x, y, res)
	if obj.shape ~= "ELLIPSE" and obj.shape ~= "FILLEDELLIPSE" then
		return nil
	end
	
	-- four coor. of rect
	local x1, y1 = obj.start_x, obj.start_y
	local x3, y3 = obj.end_x , obj.end_y
	local x2, y2, x4, y4 = x1, y3, x3, y1
	
	local midx1,midy1,midx2,midy2,midx3,midy3,midx4,midy4
	midx1 = (x2 + x1)/2
	midy1 = (y2 + y1)/2

	midx2 = (x3 + x2)/2
	midy2 = (y3 + y2)/2

	midx3 = (x4 + x3)/2
	midy3 = (y4 + y3)/2

	midx4 = (x1 + x4)/2
	midy4 = (y1 + y4)/2
                
	--print("("..x1, y1..") ("..x2, y2..") ("..x3, y3..") ("..x4, y4..")")
	--print(midx1,midy1, midx2, midy2, midx3, midy3, midx4, midy4)
	local a = (abs(midx1 - midx3))/2
	local b = (abs(midy2 - midy4))/2
	
	local cx, cy = (x1 + x3)/2 , (y1 + y3)/2
	--print(a,b,cx,cy,x,y)
	
	local eq = ((x-cx)^2)/(a^2) + ((y-cy)^2)/(b^2)
	--print(eq)
	if obj.shape == "ELLIPSE" and eq > 0.8 and eq < 1.2 then
		return true
	elseif eq < 1.2 then
		return true
	end
	return false
end