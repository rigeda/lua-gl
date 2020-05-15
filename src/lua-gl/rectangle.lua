-- Module to add rectangle functionality in lua-gl

local coorc = require("lua-gl.CoordinateCalc")
local GUIFW = require("lua-gl.guifw")
local OBJ = require("lua-gl.objects")

local floor = math.floor
local min = math.min
local max = math.max

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

-- Function to check whether rectangle object is near the coordinate x,y within the given resolution res
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

-- Function to check whether the rectangle object lies inside or overlaps with a given rectangle coordinates
-- if full is true then returns true only if the given rectangle completely covers the object rectangle
local function checkRectOverlap(cnvobj,obj,xr1,yr1,xr2,yr2,full)
	if obj.shape ~= "RECT" and obj.shape ~= "BLOCKINGRECT" and obj.shape ~= "FILLEDRECT" then
		return nil
	end
	-- Get the 4 coordinates of the rectangle object
	local x,y = {},{}
	x[1], y[1] = obj.x[1], obj.y[1]
	x[3], y[3] = obj.x[2] , obj.y[2]
	x[2], y[2], x[4], y[4] = x[1], y[3], x[3], y[1]
	
	-- Get the lesser and greater coordinates for the given rectangle
	local xl,xg,yl,yg
	xl = min(xr1,xr2)
	xg = max(xr1,xr2)
	yl = min(yr1,yr2)
	yg = max(yr1,yr2)
	
	local ci = 0	-- To count the number of coordinates inside
	for i = 1,4 do
		if x[i] >= xl and x[i] <= xg and y[i] >=yl and y[i] <=yg then
			ci = ci + 1
		end
	end
	if full then
		return ci == 4
	end
	if ci > 0 then
		return true
	end
	-- Check if any coordinate of the given rectangle lies inside the object rectangle
	xl = min(x[1],x[3])
	xg = max(x[1],x[3])
	yl = min(y[1],y[3])
	yg = max(y[1],y[3])
	x[1],y[1] = xr1,yr1
	x[2],y[2] = xr1,yr2
	x[3],y[3] = xr2,yr2
	x[4],y[4] = xr2,yr1
	ci = 0	-- To count the number of coordinates inside
	for i = 1,4 do
		if x[i] >= xl and x[i] <= xg and y[i] >=yl and y[i] <=yg then
			ci = ci + 1
		end
	end
	if ci == 4 then
		return obj.shape == "FILLEDRECT"
	end
	if ci > 0 then
		return true
	end
	-- Check if any segment of the object rectangle insersects with any segment of the given rectangle
	-- Since the rectangles are aligned with the axis the intersection can only happen between horizontal and vertical segments
	if coorc.doIntersect(xr1,yr1,xr1,yr2,xl,yl,xg,yl) or coorc.doIntersect(xr1,yr1,xr1,yr2,xl,yg,xg,yg) or 
	  coorc.doIntersect(xr2,yr1,xr2,yr2,xl,yl,xg,yl) or coorc.doIntersect(xr2,yr1,xr2,yr2,xl,yg,xg,yg) or
	  coorc.doIntersect(xr1,yr1,xr2,yr1,xl,yl,xl,yg) or coorc.doIntersect(xr1,yr1,xr2,yr1,xg,yl,xg,yg) or   
	  coorc.doIntersect(xr1,yr2,xr2,yr2,xl,yl,xl,yg) or coorc.doIntersect(xr1,yr2,xr2,yr2,xg,yl,xg,yg) then
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
		checkRectOverlap = checkRectOverlap,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initObj,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDraw,
		pts = 2			-- No of coordinates to define the shape drawing
	}
	OBJ.BLOCKINGRECT = {
		checkXY = checkXY,
		checkRectOverlap = checkRectOverlap,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initObj,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDraw,
		pts = 2			-- No of coordinates to define the shape drawing
	}
	OBJ.FILLEDRECT = {
		checkXY = checkXY,
		checkRectOverlap = checkRectOverlap,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		initObj = initObj,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDraw,
		pts = 2			-- No of coordinates to define the shape drawing
	}
end


