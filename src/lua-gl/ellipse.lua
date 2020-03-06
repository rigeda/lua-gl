-- Module to add ellipse and arc functionality in lua-gl
-- The ellipse major and minor axis will be aligned to the X and Y axis

local coorc = require("lua-gl.CoordinateCalc")
local GUIFW = require("lua-gl.guifw")
local OBJ = require("lua-gl.objects")
local abs = math.abs
local floor = math.floor
local atan = math.atan
local pi = math.pi
local rad2deg = 180/pi

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local function drawfilled(cnvobj,cnv,shape,x,y)
	local x1,x2,y1,y2 = x[1],x[2],y[1],y[2]
	cnv:Sector(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), 0, 360)
	return true
end

local function drawhollow(cnvobj,cnv,shape,x,y)
	local x1,x2,y1,y2 = x[1],x[2],y[1],y[2]
	cnv:Arc(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), 0, 360)
	return true
end

local function drawhollowarc(cnvobj,cnv,shape,x,y)
	if #x < 4 then
		return drawhollow(cnvobj,cnv,shape,x,y)
	end
	local x1,x2,y1,y2 = x[1],x[2],y[1],y[2]
	local a1 = atan(y[3]-floor((y2 + y1) / 2),x[3]-floor((x2 + x1) / 2))
	local a2 = atan(y[4]-floor((y2 + y1) / 2),x[4]-floor((x2 + x1) / 2))
	cnv:Arc(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), a1*rad2deg, a2*rad2deg)
	return true
end

local function drawfilledarc(cnvobj,cnv,shape,x,y)
	if #x < 4 then
		return drawfilled(cnvobj,cnv,shape,x,y)
	end
	local x1,x2,y1,y2 = x[1],x[2],y[1],y[2]
	local a1 = atan(y[3]-floor((y2 + y1) / 2),x[3]-floor((x2 + x1) / 2))
	local a2 = atan(y[4]-floor((y2 + y1) / 2),x[4]-floor((x2 + x1) / 2))
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
	local xc,yc = floor((x1+x2)/2),floor((y1+y2)/2)
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
		visualAttr = cnvobj.attributes.visualAttrBank[1],	-- non filled object
		vAttr = 1
	}
	GUIFW.FILLEDELLIPSE = {
		draw = drawfilled,
		visualAttr = cnvobj.attributes.visualAttrBank[3],	-- filled object
		vAttr = 3
	}
	GUIFW.ARC = {
		draw = drawhollowarc,
		visualAttr = cnvobj.attributes.visualAttrBank[1],	-- non filled object
		vAttr = 1
	}
	GUIFW.FILLEDARC = {
		draw = drawfilledarc,
		visualAttr = cnvobj.attributes.visualAttrBank[3],	-- filled object
		vAttr = 3
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