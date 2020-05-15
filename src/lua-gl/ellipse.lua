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

-- Function to check whether the ellipse object lies inside or overlaps with a given rectangle coordinates
-- if full is true then returns true only if the given rectangle completely covers the object ellipse
local function checkRectOverlap(cnvobj,obj,xr1,yr1,xr2,yr2,full)
	if obj.shape ~= "ELLIPSE" and obj.shape ~= "FILLEDELLIPSE" and obj.shape ~= "ARC" and obj.shape ~= "FILLEDARC" then
		return nil
	end
	-- Return false for incomplete arcs
	if obj.shape == "ARC" or obj.shape == "FILLEDARC" and #obj.x < 4 then
		return false
	end
	local x1,y1,x2,y2,x3,y3,x4,y4 = obj.x[1],obj.y[1],obj.x[2],obj.y[2],obj.x[3],obj.y[3],obj.x[4],obj.y[4]
	local xc,yc	-- center coordinates
	local m1,m2	-- Slopes of the lines that define the arc
	local A,B 	-- Semi major and semi minor axis
	local xa,ya,xb,yb
	if obj.shape == "FILLEDARC" or obj.shape=="ARC" then
		xc,yc = floor((x1+x2)/2),floor((y1+y2)/2)		-- center
		m1 = (y3-yc)/(x3-xc)
		m2 = (y4-yc)/(x4-xc)
		-- Find the semi major axis and semi minor axis
		A = floor(abs(x2-x1)/2)
		B = floor(abs(y2-y1)/2)
		local tx1,tx2,y1,ty2
		-- Find xa,ya the coordinates on the ellipse that intersect with the m1 slope
		local fac = 1/sqrt(1/(A*A)+(m1*m1)/(B*B))
		tx1 = floor(xc+fac)
		tx2 = floor(xc-fac)
		ty1 = floor(yc+m1*fac)
		ty2 = floor(yc-m1*fac)
		--pick the one which is in the same direction as the x3,y3
		if x3 > xc then
			if tx1 > xc then
				xa,ya = tx1,ty1
			else
				xa,ya = tx2,ty2
			end
		else
			if tx1 < xc then
				xa,ya = tx1,ty1
			else
				xa,ya = tx2,ty2
			end
		end
		-- Find xb,yb the coordinates on the ellipse that intersect with the m2 slope
		fac = 1/sqrt(1/(A*A)+(m2*m2)/(B*B))
		tx1 = floor(xc+fac)
		tx2 = floor(xc-fac)
		ty1 = floor(yc+m2*fac)
		ty2 = floor(yc-m2*fac)
		--pick the one which is in the same direction as the x4,y4
		if x4 > xc then
			if tx1 > xc then
				xb,yb = tx1,ty1
			else
				xb,yb = tx2,ty2
			end
		else
			if tx1 < xc then
				xb,yb = tx1,ty1
			else
				xb,yb = tx2,ty2
			end
		end
	end
	if full then
		local x,y
		if obj.shape == "FILLEDARC" or obj.shape == "ARC" then
			local xa1,xa2,ya1,ya2	-- Rectangle coordinates for enclosing the arc
			if obj.shape == "ARC" then
				xa1 = min(xa,xb)
				xa2 = max(xa,xb)
				ya1 = min(ya,yb)
				ya2 = max(ya,yb)
			else
				xa1 = min(xc,xa,xb)
				xa2 = max(xc,xa,xb)
				ya1 = min(yc,ya,yb)
				ya2 = max(yc,ya,yb)
			end
			-- Check if the arc crosses the end of the major or minor axis
			
			x = {xa1,xa1,xa2,xa2}
			y = {ya1,ya2,ya2,ya1}	
		else		-- if obj.shape == "FILLEDARC" or obj.shape == "ARC" then else
			-- All 4 points of the rectangle enclosing the ellipse should be inside the given rectangle
			x = {x1,x1,x2,x2}
			y = {y1,y2,y2,y1}
		end		--if obj.shape == "FILLEDARC" or obj.shape == "ARC" then ends
		-- Get the lesser and greater coordinates for the given rectangle
		local xl,xg,yl,yg
		xl = min(xr1,xr2)
		xg = max(xr1,xr2)
		yl = min(yr1,yr2)
		yg = max(yr1,yr2)
		local ci = 0	-- To count the number of coordinates inside
		for i = 1,4 do
			if x[i] >= xl and x[i] <= xg and y[i] >=yl and y[i] >=yg then
				ci = ci + 1
			end
		end
		return ci == 4
	end		-- if full then ends here
	
	-- Not full
	if obj.shape == "ARC" then
		-- Check whether the ellipse intersects with the 
		
	else
		
	end
	
	local ox,oy = obj.x,obj.y
	
	local function checkPoint(x,y)
		local dxc,dyc = (x-xc)^2,(y-yc)^2
		if (dxc/A^2+dyc/B^2) <= 1 then
			return true
		end
		return false
	end
	
	-- Get the 4 coordinates of the given rectangle
	local x,y = {},{}
	x[1], y[1] = xr1,yr1
	x[2], y[2] = xr1,yr2
	x[3], y[3] = xr2,yr2
	x[4], y[4] = xr2,yr1
	
	
	local ci = 0	-- To count the number of coordinates inside
	for i = 1,4 do
		if checkPoint(x[i],y[i]) then
			-- Point is inside the ellipse. Check if this is a ARC or a FILLED ARC
			if obj.shape == "FILLEDARC" or obj.shape == "ARC" then
				-- Check the angle
				-- Angles of object
				local a1 = atan(oy[3]-floor((oy[2] + oy[1]) / 2),ox[3]-floor((ox[2] + ox[1]) / 2))
				local a2 = atan(oy[4]-floor((oy[2] + oy[1]) / 2),ox[4]-floor((ox[2] + ox[1]) / 2))
				-- To flip the drawing direction according to teh canvas
				-- The canvas draws anticlockwise. WHile the coordinates received in checkXY are such that the angle in the upper half starts -pi to 0 clockwise and then the lower half goes 0 to pi clockwise.
				if a2 > a1 then a2 = a2 - 2*pi end
				-- Angle of given point
				local a = atan(y-floor((oy[2] + oy[1]) / 2),x-floor((ox[2] + ox[1]) / 2))
				local inangle = a >= a2 and a <= a1
				if a1 - a2 < pi then
					-- Point should be within the angle and also not be in the triangle made by the center point and the arc ends
				elseif a1 - a2 == pi then
					if inangle then ci = ci + 1 end
				else
					-- a1 - a2 > pi
					-- Point should be within the angle or in the triangle made by the center point and the arc ends
				end
			else
				ci = ci + 1
			end
		end
	end
	
	return full and ci == 2 or ci > 0
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
	if not stat then
		return false
	end
	-- Check the angle
	-- Angles of object
	local a1 = atan(oy[3]-floor((oy[2] + oy[1]) / 2),ox[3]-floor((ox[2] + ox[1]) / 2))
	local a2 = atan(oy[4]-floor((oy[2] + oy[1]) / 2),ox[4]-floor((ox[2] + ox[1]) / 2))
	-- To flip the drawing direction according to teh canvas
	-- The canvas draws anticlockwise. WHile the coordinates received in checkXY are such that the angle in the upper half starts -pi to 0 clockwise and then the lower half goes 0 to pi clockwise.
	if a2 > a1 then a2 = a2 - 2*pi end
	-- Angle of given point
	local a = atan(y-floor((oy[2] + oy[1]) / 2),x-floor((ox[2] + ox[1]) / 2))
	if a >= a2 and a <= a1 then
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

local function validateCoordsArc(x,y)
	if #x ~= #y then
		return nil,"Arrays not equal in length"
	end
	if #x ~= 4 then
		return nil,"Only 4 coordinates needed"
	end
	if x[1] == x[2] and y[1] == y[2] then
		return nil,"0 size object not allowed."
	end
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
		initObj = initEllipse,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDrawArc,
		pts = 4
	}
	OBJ.FILLEDARC = {
		checkXY = checkXYArc,
		validateCoords = validateCoordsArc,
		initObj = initEllipse,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDrawArc,
		pts = 4
	}
	
	-- Register checkXY function
	OBJ.ELLIPSE = {
		checkXY = checkXYEllipse,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initEllipse,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDrawEllipse,
		pts = 2			-- No of coordinates to define the shape drawing
	}
	OBJ.FILLEDELLIPSE = {
		checkXY = checkXYEllipse,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initEllipse,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDrawEllipse,
		pts = 2			-- No of coordinates to define the shape drawing
	}
end