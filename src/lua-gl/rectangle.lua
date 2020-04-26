-- Module to add rectangle functionality in lua-gl

local coorc = require("lua-gl.CoordinateCalc")
local GUIFW = require("lua-gl.guifw")
local OBJ = require("lua-gl.objects")

local floor = math.floor

local print = print

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1 
else
	_ENV = M		-- Lua 5.2+
end

local function drawhollow(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	local x1,x2,y1,y2 = floor((x[1]-xm)/zoom),floor((x[2]-xm)/zoom),floor((y[1]-ym)/zoom),floor((y[2]-ym)/zoom)
	cnv:Rect(x1, x2, y1, y2)
    --cnv:Rect(x[1], x[2], y[1], y[2])
	return true
end

local function drawfilled(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	local x1,x2,y1,y2 = floor((x[1]-xm)/zoom),floor((x[2]-xm)/zoom),floor((y[1]-ym)/zoom),floor((y[2]-ym)/zoom)
	cnv:Box(x1, x2, y1, y2)
	--cnv:Box(x[1], x[2], y[1], y[2])
	return true
end

local function drawblockingrectangle(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	if(cnvobj.viewOptions.showBlockingRect==true) then
		local x1,x2,y1,y2 = floor((x[1]-xm)/zoom),floor((x[2]-xm)/zoom),floor((y[1]-ym)/zoom),floor((y[2]-ym)/zoom)
		cnv:Rect(x1, x2, y1, y2)
		--cnv:Rect(x[1], x[2], y[1], y[2])
	end
	return true
end

-- Function to check whether rectangle object is selectable by x,y within the given resolution res
local function checkXY(cnvobj,obj, x, y, res)
	if obj.shape ~= "RECT" and obj.shape ~= "BLOCKINGRECT" and obj.shape ~= "FILLEDRECT" then
		return nil
	end
	
	
	local x1, y1 = obj.x[1], obj.y[1]
	local x3, y3 = obj.x[2] , obj.y[2]
	local x2, y2, x4, y4 = x1, y3, x3, y1

	if obj.shape == "RECT" or obj.shape == "BLOCKINGRECT" then
		local i1 = coorc.pointNearSegment(x1,y1,x2,y2,x,y,res)
		local i2 = coorc.pointNearSegment(x2,y2,x3,y3,x,y,res)
		local i3 = coorc.pointNearSegment(x3,y3,x4,y4,x,y,res)
		local i4 = coorc.pointNearSegment(x4,y4,x1,y1,x,y,res)

		if i1 or i2 or i3 or i4 then
			return true
		end
	else
		return coorc.pointInRect(x1, y1, x2, y2, x3, y3, x4, y4, x, y)
	end
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

-- Function to return x,y arrays initialized from the starting coordinate to put in the object structure
local function initObj(x,y)
	return {x,x},{y,y}
end

-- Given the x and y coordinate arrays this function returns true if interactive drawing can end
local function endDraw(x,y)
	if #x == 2 then
		return true
	end
end

function init(cnvobj)
	GUIFW.RECT = {
		draw = drawhollow,
		visualAttr = GUIFW.getNonFilledObjAttrFunc(cnvobj.viewOptions.visualProp[1]),	-- non filled object
		vAttr = 1,
		attr = cnvobj.viewOptions.visualProp[1]
	}
	GUIFW.BLOCKINGRECT = {
		draw = drawblockingrectangle,
		visualAttr = GUIFW.getNonFilledObjAttrFunc(cnvobj.viewOptions.visualProp[2]),	-- blocking rectangle
		vAttr = 2,
		attr = cnvobj.viewOptions.visualProp[2]
	}
	GUIFW.FILLEDRECT = {
		draw = drawfilled,
		visualAttr = GUIFW.getFilledObjAttrFunc(cnvobj.viewOptions.visualProp[3]),	-- filled object
		vAttr = 3,
		attr = cnvobj.viewOptions.visualProp[3]
	}
	OBJ.RECT = {
		checkXY = checkXY,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initObj,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDraw,
		pts = 2			-- No of coordinates to define the shape drawing
	}
	OBJ.BLOCKINGRECT = {
		checkXY = checkXY,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initObj,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDraw,
		pts = 2			-- No of coordinates to define the shape drawing
	}
	OBJ.FILLEDRECT = {
		checkXY = checkXY,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initObj,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDraw,
		pts = 2			-- No of coordinates to define the shape drawing
	}
end


