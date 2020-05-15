-- Module to add line drawing functionality to lua-gl

local coorc = require("lua-gl.CoordinateCalc")
local GUIFW = require("lua-gl.guifw")
local OBJ = require("lua-gl.objects")

local floor = math.floor
local min = math.min
local max = math.max

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local function draw(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	local x1,x2,y1,y2 = floor((x[1]-xm)/zoom),floor((x[2]-xm)/zoom),floor((y[1]-ym)/zoom),floor((y[2]-ym)/zoom)
	cnv:Line(x1,y1,x2,y2)
	--cnv:Line(x[1],y[1],x[2],y[2])
	return true
end

local function drawConn(cnvobj,cnv,x1,y1,x2,y2,zoom,xm,ym)
	x1,x2,y1,y2 = floor((x1-xm)/zoom),floor((x2-xm)/zoom),floor((y1-ym)/zoom),floor((y2-ym)/zoom)
	cnv:Line(x1,y1,x2,y2)
	return true	
end

-- Function to check whether line object is selectable by x,y within the given resolution res
local function checkXY(cnvobj,obj, x, y,res)
	if obj.shape ~= "LINE" then
		return nil
	end
	
	local x1,y1,x2,y2
	x1 = obj.x[1]
	y1 = obj.y[1]
	x2 = obj.x[2]
	y2 = obj.y[2]

	return coorc.pointNearSegment(x1, y1, x2, y2, x, y, res)                
end

-- Function to check whether the line object lies inside or overlaps with a given rectangle coordinates
-- if full is true then returns true only if the given rectangle completely covers the object line
local function checkRectOverlap(cnvobj,obj,xr1,yr1,xr2,yr2,full)
	if obj.shape ~= "LINE" then
		return nil
	end
	
	-- Get the 2 coordinates of the line object
	local x,y = {},{}
	x[1], y[1] = obj.x[1], obj.y[1]
	x[2], y[2] = obj.x[2] , obj.y[2]
	
	-- Get the lesser and greater coordinates for the given rectangle
	local xl,xg,yl,yg
	xl = min(xr1,xr2)
	xg = max(xr1,xr2)
	yl = min(yr1,yr2)
	yg = max(yr1,yr2)
	local ci = 0	-- To count the number of coordinates inside
	for i = 1,2 do
		if x[i] >= xl and x[i] <= xg and y[i] >=yl and y[i] <=yg then
			ci = ci + 1
		end
	end
	if full then
		return ci == 2
	end
	if ci > 0 then
		return true
	end
	-- Check whether the line segment intersects with any of the line segments of the given rectangle
	if coorc.doIntersect(x[1],y[1],x[2],y[2],xl,yl,xl,yg) or coorc.doIntersect(x[1],y[1],x[2],y[2],xl,yl,xg,yl) or
	  coorc.doIntersect(x[1],y[1],x[2],y[2],xg,yg,xl,yg) or coorc.doIntersect(x[1],y[1],x[2],y[2],xg,yg,xg,yl) then
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
	GUIFW.LINE = {
		draw = draw,
		visualAttr = GUIFW.getNonFilledObjAttrFunc(cnvobj.viewOptions.visualProp[1]),	-- non filled object
		vAttr = 1,
		attr = cnvobj.viewOptions.visualProp[1]
	}
	GUIFW.CONN = {
		draw = drawConn,
		visualAttr = GUIFW.getNonFilledObjAttrFunc(cnvobj.viewOptions.visualProp[4]),	-- normal connector
		vAttr = 4,			
		attr = cnvobj.viewOptions.visualProp[4]
	}
	-- Register checkXY function
	OBJ.LINE = {
		checkXY = checkXY,
		checkRectOverlap = checkRectOverlap,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initObj,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDraw,
		pts = 2			-- No of coordinates to define the shape drawing
	}
end
