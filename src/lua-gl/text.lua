-- Module to add text drawing functionality to lua-gl

local GUIFW = require("lua-gl.guifw")
local OBJ = require("lua-gl.objects")
local coorc = require("lua-gl.CoordinateCalc")
local type = type

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local function draw(cnvobj,cnv,shape,x,y,obj)
	cnv:Text(x[1],y[1],obj.data.text)
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
	shape.visualAttr(cd_bcanvas)
	local rect = cd_bcanvas:GetTextBounds(obj.x[1],cd_bcanvas:UpdateYAxis(obj.y[1]),obj.data.text)
	
	return coorc.pointInRect(rect[1],rect[2],rect[3],rect[4],rect[5],rect[6],rect[7],rect[8],x,cd_bcanvas:UpdateYAxis(obj.y[1]))                
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
		visualAttr = cnvobj.attributes.visualAttrBank[6],	-- Text attribute
		vAttr = 6
	}
	-- Register checkXY function
	OBJ.TEXT = {
		checkXY = checkXY,
		validateCoords = validateCoords,	-- Used in non interactive and final interative step
		validateData = validateData,		-- Function to validate data
		initObj = initObj,	-- Used in the interactive mode to initialize the coordinate arrays from the starting coordinate
		endDraw = endDraw,
		pts = 1			-- No of coordinates to define the shape drawing
	}
end
