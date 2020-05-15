-- Module to add text drawing functionality to lua-gl

local GUIFW = require("lua-gl.guifw")
local OBJ = require("lua-gl.objects")
local coorc = require("lua-gl.CoordinateCalc")
local type = type
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

local function draw(cnvobj,cnv,x,y,obj,zoom,xm,ym)
	--local tf,st,sz = GUIFW.getFont(cnv)
	--cnv:Font(tf,st,floor(sz/zoom))
	local x1,y1 = floor((x[1]-xm)/zoom),floor((y[1]-ym)/zoom)
	cnv:Text(x1,y1,obj.data.text)
	--cnv:Font(tf,st,sz)
	return true
end

-- Function to check whether text object is selectable by x,y within the given resolution res (ignored for text case)
local function checkXY(cnvobj,obj, x, y,res)
	if obj.shape ~= "TEXT" then
		return nil
	end
	-- First we need to set the right attributes for the text so the bounding rectangle can be calculated
	local attr = cnvobj.attributes
	local cd_bcanvas = cnvobj.cdbCanvas
	local shape = attr.visualAttr[obj] or GUIFW.TEXT	-- validity is not checked for the registered shape structure
	shape.visualAttr(cd_bcanvas,1)
	--[[
	local rect = cd_bcanvas:GetTextBounds(obj.x[1],cd_bcanvas:UpdateYAxis(obj.y[1]),obj.data.text)
	
	return coorc.pointInRect(rect[1],rect[2],rect[3],rect[4],rect[5],rect[6],rect[7],rect[8],x,cd_bcanvas:UpdateYAxis(y))                
	]]
	local rect = cd_bcanvas:GetTextBounds(obj.x[1],obj.y[1],obj.data.text)
	
	return coorc.pointInRect(rect[1],rect[2],rect[3],rect[4],rect[5],rect[6],rect[7],rect[8],x,y)
end

-- Function to check whether the text object lies inside or overlaps with a given rectangle coordinates
-- if full is true then returns true only if the given rectangle completely covers the object text
local function checkRectOverlap(cnvobj,obj,xr1,yr1,xr2,yr2,full)
	if obj.shape ~= "TEXT" then
		return nil
	end
	
	-- Get the 4 coordinates of the text object bounding rectangle
	-- First we need to set the right attributes for the text so the bounding rectangle can be calculated
	local attr = cnvobj.attributes
	local cd_bcanvas = cnvobj.cdbCanvas
	local shape = attr.visualAttr[obj] or GUIFW.TEXT	-- validity is not checked for the registered shape structure
	shape.visualAttr(cd_bcanvas,1)
	local rect = cd_bcanvas:GetTextBounds(obj.x[1],obj.y[1],obj.data.text)
	
	local x,y = {rect[1],rect[3],rect[5],rect[7]},{rect[2],rect[4],rect[6],rect[8]}
	
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
	-- Check if any of the selection rectangle points lie in the text bounding rectangle
	ci = 0
	if coorc.pointInRect(rect[1],rect[2],rect[3],rect[4],rect[5],rect[6],rect[7],rect[8],xl,yl) then
		ci = ci + 1
	end
	if coorc.pointInRect(rect[1],rect[2],rect[3],rect[4],rect[5],rect[6],rect[7],rect[8],xl,yg) then
		ci = ci + 1
	end
	if coorc.pointInRect(rect[1],rect[2],rect[3],rect[4],rect[5],rect[6],rect[7],rect[8],xg,yg) then
		ci = ci + 1
	end
	if coorc.pointInRect(rect[1],rect[2],rect[3],rect[4],rect[5],rect[6],rect[7],rect[8],xg,yl) then
		ci = ci + 1
	end
	if ci > 0 then
		return true
	end
	-- Check if any segment of the text object bounding rectangle insersects with any segment of the given rectangle
	if coorc.doIntersect(xr1,yr1,xr1,yr2,x[1],y[1],x[2],y[2]) or coorc.doIntersect(xr1,yr1,xr1,yr2,x[2],y[2],x[3],y[3]) or 
	  coorc.doIntersect(xr1,yr1,xr1,yr2,x[3],y[3],x[4],y[4]) or coorc.doIntersect(xr1,yr1,xr1,yr2,x[4],y[4],x[1],y[1]) or 
	  coorc.doIntersect(xr1,yr2,xr2,yr2,x[1],y[1],x[2],y[2]) or coorc.doIntersect(xr1,yr2,xr2,yr2,x[2],y[2],x[3],y[3]) or 
	  coorc.doIntersect(xr1,yr2,xr2,yr2,x[3],y[3],x[4],y[4]) or coorc.doIntersect(xr1,yr2,xr2,yr2,x[4],y[4],x[1],y[1]) or 
	  coorc.doIntersect(xr2,yr2,xr2,yr1,x[1],y[1],x[2],y[2]) or coorc.doIntersect(xr2,yr2,xr2,yr1,x[2],y[2],x[3],y[3]) or 
	  coorc.doIntersect(xr2,yr2,xr2,yr1,x[3],y[3],x[4],y[4]) or coorc.doIntersect(xr2,yr2,xr2,yr1,x[4],y[4],x[1],y[1]) or 
	  coorc.doIntersect(xr2,yr1,xr1,yr1,x[1],y[1],x[2],y[2]) or coorc.doIntersect(xr2,yr1,xr1,yr1,x[2],y[2],x[3],y[3]) or 
	  coorc.doIntersect(xr2,yr1,xr1,yr1,x[3],y[3],x[4],y[4]) or coorc.doIntersect(xr2,yr1,xr1,yr1,x[4],y[4],x[1],y[1]) then
		return true
	end
	return false	
end

-- Function to validate the coordinate arrays for the object
local function validateCoords(x,y)
	if #x ~= #y then
		return nil,"Arrays not equal in length"
	end
	if #x > 1 then
		return nil,"Only 1 coordinates needed"
	end
	return true
end

-- Function to return x,y arrays initialized from the starting coordinate to put in the object structure
local function initObj(x,y)
	return {x},{y}
end

-- Given the x and y coordinate arrays this function returns true if interactive drawing can end. This can be used to determine if more points are needed
local function endDraw(x,y)
	if #x == 1 then
		return true
	end
end

local function validateData(data)
	if type(data) ~= "table" then
		return nil, "data needs to be a table"
	end
	if not data.text or type(data.text) ~= "string" then
		return nil,"data needs a text key with the text to display"
	end
	return true
end

function init(cnvobj)
	GUIFW.TEXT = {
		draw = draw,
		visualAttr = GUIFW.getTextAttrFunc(cnvobj.viewOptions.visualProp[6]),	-- Text attribute
		vAttr = 6,
		attr = cnvobj.viewOptions.visualProp[6]
	}
	-- Register checkXY function
	OBJ.TEXT = {
		checkXY = checkXY,
		checkRectOverlap = checkRectOverlap,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		validateData = validateData,		-- Function to validate data
		initObj = initObj,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDraw,
		pts = 1			-- No of coordinates to define the shape drawing
	}
end
