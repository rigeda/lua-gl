local abs = math.abs
local max = math.max
local min = math.min
local sqrt = math.sqrt

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- function to calculate the area of a triangle given the vertices
local function area(x1, y1, x2, y2, x3, y3) 
    return abs((x1 * (y2 - y3) + x2 * (y3 - y1) +  x3 * (y1 - y2)) / 2.0) 
end

-- Function to check whether the point x,y lies in the rectangle given by the vertices. 
-- Note that x2,y2 should be diagnolly opposite x4,y4
function pointInRect(x1, y1, x2, y2, x3, y3, x4, y4, x, y) 
             
    local A = area(x1, y1, x2, y2, x3, y3) +  area(x1, y1, x4, y4, x3, y3) 
  
    local A1 = area(x, y, x1, y1, x2, y2)
  
    local A2 = area(x, y, x2, y2, x3, y3)
  
    local A3 = area(x, y, x3, y3, x4, y4) 
  
    local  A4 = area(x, y, x1, y1, x4, y4)
    return abs(A - (A1 + A2 + A3 + A4)) < 5 
end

-- Checks whether the point x,y lies inside the rectangle bounded by the midpoints of 2 opposite side at x1,y1 and x2,y2 with the fuzzy resolution of res which controls the rectangle height
function pointNearSegment(x1, y1, x2, y2, x, y, res)
    local rect = {}
    local dx = x1- x2
    local dy = y1 - y2
    local d = sqrt(dx * dx + dy * dy)
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

    return pointInRect(rect[1].x, rect[1].y, rect[2].x, rect[2].y, rect[4].x, rect[4].y, rect[3].x, rect[3].y, x, y)
end

-- Reference https://www.geeksforgeeks.org/check-if-two-given-line-segments-intersect/
-- Given three colinear points x1,y1 xc,yc and x2,y2, the function checks if 
-- point xc,yc lies on line segment 'x1,y1 y2,y2' 
local function onSegment(x1,y1, xc,yc, x2,y2) 
    if (xc <= max(x1, x2) and xc >= min(x1, x2) and
        yc <= max(y1, y2) and yc >= min(y1, y2)) then
       return true
	end
    return false
end 

-- Reference https://www.geeksforgeeks.org/check-if-two-given-line-segments-intersect/
-- To find orientation of ordered triplet (x1,y1; x2,y2; x3,y3). 
-- The function returns following values 
-- 0 --> All points are colinear 
-- 1 --> Clockwise 
-- 2 --> Counterclockwise 
local function orientation(x1,y1,x2,y2,x3,y3) 
    -- See https://www.geeksforgeeks.org/orientation-3-ordered-points/ 
    -- for details of below formula. 
    local val = (y2 - y1) * (x3 - x2) - (x2 - x1) * (y3 - y2)
  
    if val == 0 then return 0 end  -- colinear 
	return (val > 0 and 1) or 2 	-- clock or counterclock wise 
end

-- Checks whether the point x,y lies on the line segment x1,y1 x2,y2
function pointOnSegment(x1,y1,x2,y2,x,y)
    local o1 = orientation(x1,y1, x2,y2, x3,y3)
	if o1 ~= 0 then
		return false
	end
	return onSegment(x1,y1,x,y,x2,y2)
end


-- Reference https://www.geeksforgeeks.org/check-if-two-given-line-segments-intersect/
-- The main function that returns true if line segment 'p1q1' and 'p2q2' intersect. 
-- p1 = (x1,y1)
-- q1 = (x2,y2)
-- p2 = (x3,y3)
-- q2 = (x4,y4)
-- Returns 5 if they intersect
-- Returns 1 if p2 lies on p1 q1
-- Returns 2 if q2 lies on p1 q1
-- Returns 3 if p1 lies on p2 q2 
-- Returns 4 if q1 lies on p2 q2
-- Returns false if no intersection
function doIntersect(x1,y1,x2,y2,x3,y3,x4,y4) 
    -- Find the four orientations needed for general and 
    -- special cases 
    local o1 = orientation(x1,y1, x2,y2, x3,y3)
    local o2 = orientation(x1,y1, x2,y2, x4,y4) 
    local o3 = orientation(x3,y3, x4,y4, x1,y1) 
    local o4 = orientation(x3,y3, x4,y4, x2,y2) 
  
    -- Special Cases 
    -- p1, q1 and p2 are colinear and p2 lies on segment p1q1 
    if (o1 == 0 and onSegment(x1,y1, x3,y3, x2,y2)) then return 1 end
  
    -- p1, q1 and q2 are colinear and q2 lies on segment p1q1 
    if (o2 == 0 and onSegment(x1,y1, x4,y4, x2,y2)) then return 2 end 
  
    -- p2, q2 and p1 are colinear and p1 lies on segment p2q2 
    if (o3 == 0 and onSegment(x3,y3, x1,y1, x4,y4)) then return 3 end 
  
    -- p2, q2 and q1 are colinear and q1 lies on segment p2q2 
    if (o4 == 0 and onSegment(x3,y3, x2,y2, x4,y4)) then return 4 end

    -- General case 
    if (o1 ~= o2 and o3 ~= o4) then
        return 5
	end
	  
    return false	-- Doesn't fall in any of the above cases 
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


