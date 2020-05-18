-- Module to add ellipse and arc functionality in lua-gl
-- The ellipse major and minor axis will be aligned to the X and Y axis

local coorc = require("lua-gl.CoordinateCalc")
local GUIFW = require("lua-gl.guifw")
local OBJ = require("lua-gl.objects")
local abs = math.abs
local floor = math.floor
local atan = math.atan
local pi = math.pi
local sqrt = math.sqrt
local min = math.min
local max = math.max
local rad2deg = 180/pi

local print = print

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local function drawfilled(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	local x1,x2,y1,y2 = floor((x[1]-xm)/zoom),floor((x[2]-xm)/zoom),floor((y[1]-ym)/zoom),floor((y[2]-ym)/zoom)
	--local x1,x2,y1,y2 = x[1],x[2],y[1],y[2]
	cnv:Sector(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), 0, 360)
	return true
end

local function drawhollow(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	local x1,x2,y1,y2 = floor((x[1]-xm)/zoom),floor((x[2]-xm)/zoom),floor((y[1]-ym)/zoom),floor((y[2]-ym)/zoom)
	--local x1,x2,y1,y2 = x[1],x[2],y[1],y[2]
	cnv:Arc(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), 0, 360)
	return true
end

local function drawhollowarc(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	if #x < 4 then
		return drawhollow(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	end
	local x1,x2,y1,y2 = floor((x[1]-xm)/zoom),floor((x[2]-xm)/zoom),floor((y[1]-ym)/zoom),floor((y[2]-ym)/zoom)
	local x3,x4,y3,y4 = floor((x[3]-xm)/zoom),floor((x[4]-xm)/zoom),floor((y[3]-ym)/zoom),floor((y[4]-ym)/zoom)
	--local x1,x2,y1,y2 = x[1],x[2],y[1],y[2]
	local a1 = atan(y3-floor((y2 + y1) / 2),x3-floor((x2 + x1) / 2))
	local a2 = atan(y4-floor((y2 + y1) / 2),x4-floor((x2 + x1) / 2))
	cnv:Arc(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), a1*rad2deg, a2*rad2deg)
	return true
end

local function drawfilledarc(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	if #x < 4 then
		return drawfilled(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	end
	local x1,x2,y1,y2 = floor((x[1]-xm)/zoom),floor((x[2]-xm)/zoom),floor((y[1]-ym)/zoom),floor((y[2]-ym)/zoom)
	local x3,x4,y3,y4 = floor((x[3]-xm)/zoom),floor((x[4]-xm)/zoom),floor((y[3]-ym)/zoom),floor((y[4]-ym)/zoom)
	--local x1,x2,y1,y2 = x[1],x[2],y[1],y[2]
	local a1 = atan(y3-floor((y2 + y1) / 2),x3-floor((x2 + x1) / 2))
	local a2 = atan(y4-floor((y2 + y1) / 2),x4-floor((x2 + x1) / 2))
	cnv:Sector(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), a1*rad2deg, a2*rad2deg)
	return true
end

local function checkXY(cnvobj,obj,x,y,res)
	local x1,y1,x2,y2 = obj.x[1],obj.y[1],obj.x[2],obj.y[2]
	-- Find the semi major axis and semi minor axis
	local A = floor(abs(x2-x1)/2)
	local B = floor(abs(y2-y1)/2)
	local a = A-res
	local b = B-res
	A = A + res
	B = B + res
	local xc,yc = floor((x1+x2)/2),floor((y1+y2)/2)		-- center
	local dxc,dyc = (x-xc)^2,(y-yc)^2
	if obj.shape:match("^FILLED") then
		if (dxc/A^2+dyc/B^2) <= 1 then
			return true
		end
	else
		if (dxc/A^2+dyc/B^2) <= 1 and (dxc/a^2+dyc/b^2) >= 1 then
			return true
		end
	end
	return false	
end

local function checkRectOverlapEllipse(cnvobj,obj,xr1,yr1,xr2,yr2,full)
	if obj.shape ~= "ELLIPSE" and obj.shape ~= "FILLEDELLIPSE" then
		return nil
	end
	-- Get the lesser and greater coordinates for the given rectangle
	local xl,xg,yl,yg
	xl = min(xr1,xr2)
	xg = max(xr1,xr2)
	yl = min(yr1,yr2)
	yg = max(yr1,yr2)
	-- Get the 4 coordinates of the rectangle enclosing the object
	local x,y = {},{}
	x[1], y[1] = obj.x[1], obj.y[1]
	x[3], y[3] = obj.x[2] , obj.y[2]
	x[2], y[2], x[4], y[4] = x[1], y[3], x[3], y[1]
	
	local ci = 0	-- To count the number of object coordinates inside the given rectangle
	for i = 1,4 do
		if x[i] >= xl and x[i] <= xg and y[i] >=yl and y[i] <=yg then
			ci = ci + 1
		end
	end
	if full then
		return ci == 4
	end
	if ci == 4 then
		return true
	end
	ci = 0
	-- count how many coordinates of the given rectangle lies inside the ellipse
	local x1,y1,x2,y2 = obj.x[1],obj.y[1],obj.x[2],obj.y[2]
	local A = floor(abs(x2-x1)/2)
	local B = floor(abs(y2-y1)/2)
	local xc,yc = floor((x1+x2)/2),floor((y1+y2)/2)		-- center
	local function checkPointInEllipse(xp,yp)
		local dxc,dyc = (xp-xc)^2,(yp-yc)^2
		return (dxc/A^2+dyc/B^2) <= 1 
	end
	if checkPointInEllipse(xr1,yr1) then
		ci = ci + 1
	end
	if checkPointInEllipse(xr1,yr2) then
		ci = ci + 1
	end
	if checkPointInEllipse(xr2,yr2) then
		ci = ci + 1
	end
	if checkPointInEllipse(xr2,yr1) then
		ci = ci + 1
	end
	if ci == 4 then
		return obj.shape == "FILLEDELLIPSE"
	end
	if ci > 0 then
		return true
	end
	-- Check if any segment of the given rectangle intersects with the ellipse
	local Bsq = B*B
	local Asq = A*A
	local function checkyeqa(a,xi,xf)
		-- First check whether the y=a line intersects the ellipse on real points
		local amycsq = (a-yc)*(a-yc)
		if Bsq < amycsq then
			return false
		end
		local alphasq = Asq*(1-amycsq/Bsq)
		local xip,xim,xfp,xfm
		-- Comparison with xi
		if xi < xc then
			xip = true
			if (xi-xc)^2 >= alphasq then
				xim = true
			end
		else
			if (xi-xc)^2 <= alphasq then
				xip = true
			end
		end
		if not xim and not xip then
			return false
		end
		-- Comparison with xf
		if xf < xc then
			if (xf-xc)^2 <= alphasq then
				xfm = true
			end
		else
			xfm = true
			if (xf-xc)^2 >= alphasq then
				xfp = true
			end
		end
		return xim and xfm or xip and xfp
	end
	
	local function checkxeqb(b,yi,yf)
		-- First check whether the y=a line intersects the ellipse on real points
		local bmxcsq = (b-xc)*(b-xc)
		if Asq < bmxcsq then
			return false
		end
		local alphasq = Bsq*(1-bmxcsq/Asq)
		local yip,yim,yfp,yfm
		-- Comparison with yi
		if yi < yc then
			yip = true
			if (yi-yc)^2 >= alphasq then
				yim = true
			end
		else
			if (yi-yc)^2 <= alphasq then
				yip = true
			end
		end
		if not yim and not yip then
			return false
		end
		-- Comparison with yf
		if yf < yc then
			if (yf-yc)^2 <= alphasq then
				yfm = true
			end
		else
			yfm = true
			if (yf-yc)^2 >= alphasq then
				yfp = true
			end
		end
		return yim and yfm or yip and yfp
	end
	-- Now check the segments
	return checkyeqa(yl,xl,xg) or checkyeqa(yg,xl,xg) or checkxeqb(xl,yl,yg) or checkxeqb(xg,yl,yg)
end

-- Function to check whether the ellipse object lies inside or overlaps with a given rectangle coordinates
-- if full is true then returns true only if the given rectangle completely covers the object ellipse
local function checkRectOverlapArc(cnvobj,obj,xr1,yr1,xr2,yr2,full)
	if obj.shape ~= "ARC" and obj.shape ~= "FILLEDARC" then
		return nil
	end
	-- Return false for incomplete arcs
	if #obj.x < 4 then
		return false
	end
	local x1,y1,x2,y2,x3,y3,x4,y4 = obj.x[1],obj.y[1],obj.x[2],obj.y[2],obj.x[3],obj.y[3],obj.x[4],obj.y[4]
	local A = floor(abs(x2-x1)/2)
	local B = floor(abs(y2-y1)/2)
	local xc,yc = floor((x1+x2)/2),floor((y1+y2)/2)		-- center
	-- Get the start and stop angles of the arc/sector
	local a1 = atan(y3-yc,x3-xc)
	local a2 = atan(y4-yc,x4-xc)
	if a2 < a1 then 
		a1 = a1-2*pi 
	end

	-- Calculate the coordinates of points where the given rectangle intersects with the ellipse whose part the arc/sector is
	local Asq,Bsq = A*A,B*B
	local function getCoordsyeqa(a,xi,xf,coords)
		local amycsq = (a-yc)^2
		if Bsq < amycsq then
			return 
		end
		local alpha = A*sqrt(1-amycsq/Bsq)
		if xc + alpha >= xi and xc + alpha <= xf then
			coords[#coords+1] = {xc+alpha,a}
		end
		if xc - alpha >= xi and xc - alpha <=xf then
			coords[#coords+1] = {xc-alpha,a}
		end
	end
	
	local function getCoordsxeqb(b,yi,yf,coords)
		local bmxcsq = (b-xc)^2
		if Asq < bmxcsq then
			return
		end
		local alpha = floor(B*sqrt(1-bmxcsq/Asq))
		if yc + alpha >= yi and yc + alpha <= yf then
			coords[#coords+1] = {b,yc+alpha}
		end
		if yc - alpha >= yi and yc - alpha <=yf then
			coords[#coords+1] = {b,yc-alpha}
		end
	end
	
	-- Get the lesser and greater coordinates for the given rectangle
	local xl,xg,yl,yg
	xl = min(xr1,xr2)
	xg = max(xr1,xr2)
	yl = min(yr1,yr2)
	yg = max(yr1,yr2)
	local function checkPointInRectangle(x,y)
		return x >= xl and x <= xg and y >=yl and y <=yg 
	end

	local coords = {}	-- To store all intersection coordinates
	getCoordsxeqb(xl,yl,yg,coords)
	getCoordsxeqb(xg,yl,yg,coords)
	getCoordsyeqa(yl,xl,xg,coords)
	getCoordsyeqa(yg,xl,xg,coords)
	
	-- Do the test for full
	-- Check if x3,y3 or x4,y4 lies inside the rectangle
	local fullSelect = true
	local intersectChecked
	if obj.shape == "FILLEDARC" then
		if not checkPointInRectangle(xc,yc) then
			fullSelect = false
		end
	end
	if fullSelect and (not checkPointInRectangle(x3,y3) and not checkPointInRectangle(x4,y4)) then
		fullSelect = false
	end
	if fullSelect and #coords > 0 then
		-- Make sure all coordinates are outside the range [a1,a2]
		intersectChecked = true
		for i = 1,#coords do
			local a = atan(coords[i][2]-yc,coords[i][1]-xc)
			while a-2*pi > a1 do
				a = a-2*pi
			end
			if a>=a1 and a<=a2 then
				fullSelect = false
				break
			end
		end
	end
	if full or fullSelect then
		return fullSelect
	end
	if intersectChecked then
		-- Intersection with ellipse coordinates were checked and one of them had to be on the arc itself
		return true
	else
		for i = 1,#coords do
			local a = atan(coords[i][2]-yc,coords[i][1]-xc)
			while a-2*pi > a1 do
				a = a-2*pi
			end
			if a>=a1 and a<=a2 then
				return true
			end
		end	
	end
	if obj.shape == "ARC" then
		return false
	end
	-- For filled ARC 2 more possibilities are if the rectangle intersects the arc ends connecting the center or if any rectangle point lies in the sector area
	local function checkPointInEllipse(xp,yp)
		local dxc,dyc = (xp-xc)^2,(yp-yc)^2
		return (dxc/A^2+dyc/B^2) <= 1 
	end
	if checkPointInEllipse(xl,yl) or checkPointInEllipse(xg,yl) or checkPointInEllipse(xg,yg) or checkPointInEllipse(xl,yg) then
		return true
	end
	
	-- Function to check whether a lies in the range [b,c] or [c,b]
	local function inbetween(a,b,c)
		if c<b then
			b,c = c,b
		end
		if a >= b and a<=c then
			return true
		end
		return false
	end
	-- Check whether the rectangle intersects the sector lines connecting to the center`
	local function checkVerticalSegmentIntersection(x,yi,yf,xa,ya,xb,yb)
		if ya == yb then
			return inbetween(x,xa,xb)
		elseif xa==xb then
			return x==xa and (inbetween(yi,ya,yb) or inbetween(yf,ya,yb) or inbetween(ya,yi,yf))
		else
			local y = (yb-ya)/(xb-xa)*(x-xa)+ya
			return inbetween(y,ya,yb)
		end
	end
	local function checkHorizontalSegmentIntersection(y,xi,xf,xa,ya,xb,yb)
		if xa == xb then
			return inbetween(y,ya,yb)
		elseif ya==yb then
			return y==ya and (inbetween(xi,xa,xb) or inbetween(xf,xa,xb) or inbetween(xa,xi,xf))
		else
			local x = (xb-xa)/(yb-ya)*(y-ya)+xa
			return inbetween(x,xa,xb)
		end		
	end
	return checkVerticalSegmentIntersection(xl,yl,yg,xc,yc,x3,y3) or checkVerticalSegmentIntersection(xl,yl,yg,xc,yc,x4,y4) or 
	  checkVerticalSegmentIntersection(xg,yl,yg,xc,yc,x3,y3) or checkVerticalSegmentIntersection(xg,yl,yg,xc,yc,x4,y4) or 
	  checkHorizontalSegmentIntersection(yl,xl,xg,xc,yc,x3,y3) or checkHorizontalSegmentIntersection(yl,xl,xg,xc,yc,x4,y4) or   
	  checkHorizontalSegmentIntersection(yg,xl,xg,xc,yc,x3,y3) or checkHorizontalSegmentIntersection(yg,xl,xg,xc,yc,x4,y4)
end


-- Function to check whether ellipse object is selectable by x,y within the given resolution res
local function checkXYEllipse(cnvobj,obj, x, y, res)
	if obj.shape ~= "ELLIPSE" and obj.shape ~= "FILLEDELLIPSE" then
		return nil
	end
	
	return checkXY(cnvobj,obj,x,y,res)
end

local function checkXYArc(cnvobj,obj,x,y,res)
	if obj.shape ~= "ARC" and obj.shape ~= "FILLEDARC" then
		return nil
	end
	local ox,oy = obj.x,obj.y
	if #ox < 4 then
		return false
	end
	local stat,msg = checkXY(cnvobj,obj,x,y,res)
	print("checkXY returned",stat)
	if not stat then
		return false
	end
	-- Check the angle
	-- Angles of object
	local a1 = atan(oy[3]-floor((oy[2] + oy[1]) / 2),ox[3]-floor((ox[2] + ox[1]) / 2))
	local a2 = atan(oy[4]-floor((oy[2] + oy[1]) / 2),ox[4]-floor((ox[2] + ox[1]) / 2))
	print("a1=",a1*rad2deg)
	print("a2=",a2*rad2deg)
	-- atan returns angle in the range -pi to +pi
	-- The arc is drawn from a1 to a2
	-- If the arc is large so that a2 becomes less than a1 then to make the range increasing reduce a1 by 2pi
	if a2 < a1 then 
		a1 = a1-2*pi 
		print("NEW a1=",a1*rad2deg)
		print("NEW a2=",a2*rad2deg)
	end
	-- Angle of given point
	local a = atan(y-floor((oy[2] + oy[1]) / 2),x-floor((ox[2] + ox[1]) / 2))
	print("a=",a*rad2deg)
	-- a should be in the 2pi range from a1
	while a-2*pi > a1 do
		a = a-2*pi
	end
	print("NEW a=",a*rad2deg)
	if a >= a1 and a <= a2 then
		return true
	end
	return false
end

-- Function to validate the coordinate arrays for the object
local function validateCoords(x,y)
	if #x ~= #y then
		return nil,"Arrays not equal in length"
	end
	if #x > 2 then
		return nil,"Only 2 coordinates needed"
	end
	if #x == 2 then
		if x[1] == x[2] and y[1] == y[2] then
			return nil,"0 size object not allowed."
		end
	end
	return true
end

local function validateCoordsArc(cnvobj,x,y)
	if #x ~= #y then
		return nil,"Arrays not equal in length"
	end
	if #x ~= 4 then
		return nil,"Only 4 coordinates needed"
	end
	if x[1] == x[2] and y[1] == y[2] then
		return nil,"0 size object not allowed."
	end
	-- Check if the start and stop angles are the same then object is 0 sized
	local a1 = atan(y[3]-floor((y[2] + y[1]) / 2),x[3]-floor((x[2] + x[1]) / 2))
	local a2 = atan(y[4]-floor((y[2] + y[1]) / 2),x[4]-floor((x[2] + x[1]) / 2))
	if a2 < a1 then 
		a1 = a1-2*pi 
	end
	-- Calculate the angle the grid spacing will project on the center from the major axis end
	local A = floor(abs(x[2]-x[1])/2)
	local B = floor(abs(y[2]-y[1])/2)
	local xc,yc = floor((x[1]+x[2])/2),floor((y[1]+y[2])/2)		-- center
	local gd1 = atan(cnvobj.grid.grid_y,A/2)
	local gd2 = atan(cnvobj.grid.grid_x,B/2)
	local gd = min(gd1,gd2)
	if a2-a1 < gd then
		return nil,"Angle too small"
	end
	-- Update x[3] and x[4] with the coordinates on the ellipse
	local function updateCoord(x,y)
		if x == xc then
			if y > yc then
				return xc,yc+B
			else
				return xc,yc-B
			end
		elseif y == yc then
			if x > xc then
				return xc+A,yc
			else
				return xc-A,yc
			end
		else
			-- Find the intersection of the line with the ellipse
			local m = (y-yc)/(x-xc)
			local del = 1/sqrt(1/(A*A)+m*m/(B*B))
			local xn,yn
			if x > xc then
				xn = xc+floor(del)
			else
				xn = xc-floor(del)
			end
			yn = yc+floor(m*(xn-xc))
			return xn,yn
		end
	end
	x[3],y[3] = updateCoord(x[3],y[3])
	x[4],y[4] = updateCoord(x[4],y[4])
	return true	
end

-- Function to return x,y arrays initialized from the starting coordinate to put in the object structure
local function initEllipse(x,y)
	return {x,x},{y,y}
end

-- Given the x and y coordinate arrays this function returns true if interactive drawing can end
local function endDrawEllipse(x,y)
	if #x == 2 then
		return true
	end
end

-- Given the x and y coordinate arrays this function returns true if interactive drawing can end
local function endDrawArc(x,y)
	if #x == 4 then
		return true
	end
end

function init(cnvobj)
	-- Register drawing functions
	GUIFW.ELLIPSE = {
		draw = drawhollow,
		visualAttr = GUIFW.getNonFilledObjAttrFunc(cnvobj.viewOptions.visualProp[1]),	-- non filled object
		vAttr = 1,
		attr = cnvobj.viewOptions.visualProp[1]
	}
	GUIFW.FILLEDELLIPSE = {
		draw = drawfilled,
		visualAttr = GUIFW.getFilledObjAttrFunc(cnvobj.viewOptions.visualProp[3]),	-- filled object
		vAttr = 3,
		attr = cnvobj.viewOptions.visualProp[3]
	}
	GUIFW.ARC = {
		draw = drawhollowarc,
		visualAttr = GUIFW.getNonFilledObjAttrFunc(cnvobj.viewOptions.visualProp[1]),	-- non filled object
		vAttr = 1,
		attr = cnvobj.viewOptions.visualProp[1]
	}
	GUIFW.FILLEDARC = {
		draw = drawfilledarc,
		visualAttr = GUIFW.getFilledObjAttrFunc(cnvobj.viewOptions.visualProp[3]),	-- filled object
		vAttr = 3,
		attr = cnvobj.viewOptions.visualProp[3]
	}
	OBJ.ARC = {
		checkXY = checkXYArc,
		validateCoords = validateCoordsArc,
		checkRectOverlap = checkRectOverlapArc,
		initObj = initEllipse,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDrawArc,
		pts = 4
	}
	OBJ.FILLEDARC = {
		checkXY = checkXYArc,
		checkRectOverlap = checkRectOverlapArc,
		validateCoords = validateCoordsArc,
		initObj = initEllipse,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDrawArc,
		pts = 4
	}
	
	-- Register checkXY function
	OBJ.ELLIPSE = {
		checkXY = checkXYEllipse,
		checkRectOverlap = checkRectOverlapEllipse,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initEllipse,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDrawEllipse,
		pts = 2			-- No of coordinates to define the shape drawing
	}
	OBJ.FILLEDELLIPSE = {
		checkXY = checkXYEllipse,
		checkRectOverlap = checkRectOverlapEllipse,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initEllipse,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDrawEllipse,
		pts = 2			-- No of coordinates to define the shape drawing
	}
end