local math = math

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- function to calculate the area of a triangle given the vertices
local function area(x1, y1, x2, y2, x3, y3) 
    return math.abs((x1 * (y2 - y3) + x2 * (y3 - y1) +  x3 * (y1 - y2)) / 2.0) 
end

-- Function to check whether the point x,y lies in the rectangle given by the vertices. 
-- Note that x2,y2 should be diagnolly opposite x4,y4
function PointInRect(x1, y1, x2, y2, x3, y3, x4, y4, x, y) 
             
    local A = area(x1, y1, x2, y2, x3, y3) +  area(x1, y1, x4, y4, x3, y3) 
  
    local A1 = area(x, y, x1, y1, x2, y2)
  
    local A2 = area(x, y, x2, y2, x3, y3)
  
    local A3 = area(x, y, x3, y3, x4, y4) 
  
    local  A4 = area(x, y, x1, y1, x4, y4)
    return math.abs(A - (A1 + A2 + A3 + A4)) < 5 
end

-- Checks whether the point x,y lies inside the rectangle bounded by the diagnol points x1,y1 and x2,y2 with the fuzzy resolution of res
function PointOnLine(x1, y1, x2, y2, x, y, res)
    local rect = {}
    local dx = x1- x2
    local dy = y1 - y2
    local d = math.sqrt(dx * dx + dy * dy)
    dx = res * dx / d
    dy = res * dy / d
    rect[1] = {}
    rect[1].x, rect[1].y = x1 - dy, y1 + dx
    rect[2] = {}
    rect[2].x, rect[2].y = x1 + dy, y1 - dx
    rect[3] = {}
    rect[3].x, rect[3].y = x2 - dy, y2 + dx
    rect[4] = {}
    rect[4].x, rect[4].y = x2 + dy, y2 - dx

    return PointInRect(rect[1].x, rect[1].y, rect[2].x, rect[2].y, rect[4].x, rect[4].y, rect[3].x, rect[3].y, x, y)
end

-- Function to snap coordinate on X grid
snapX = function(x, grid_x)
	if x%grid_x ~= 0 then   --if x is not multiple of grid_x then we have to adjust it
		if x%grid_x >= grid_x/2 then   --upper bound 
			x = x + ( grid_x - x%grid_x )
		elseif x%grid_x < grid_x/2 then -- lower bound
			x = x - x%grid_x
		end
	end
	return x
end

-- Function to snap coordinate on Y grid
snapY = function(y, grid_y)
	if y%grid_y ~= 0 then   --if x is not multiple of grid_y then we have to adjust it
		if y%grid_y >= grid_y/2 then   --upper bound 
			y = y + ( grid_y - y%grid_y )
		elseif y%grid_y < grid_y/2 then -- lower bound
			y = y - y%grid_y
		end
	end
	return y
end


