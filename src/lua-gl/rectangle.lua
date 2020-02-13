-- Module to add rectangle functionality in lua-gl

local coorc = require("lua-gl.CoordinateCalc")
local GUIFW = require("lua-gl.guifw")
local OBJ = require("lua-gl.objects")

local print = print

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local function drawhollow(cnvobj,cnv,shape,x,y)
    cnv:Rect(x[1], x[2], y[1], y[2])
	return true
end

local function drawfilled(cnvobj,cnv,shape,x,y)
	cnv:Box(x[1], x[2], y[1], y[2])
	return true
end

local function drawblockingrectangle(cnvobj,cnv,shape,x,y)
	if(cnvobj.viewOptions.showBlockingRect==true) then
		cnv:Rect(x[1], x[2], y[1], y[2])
	end
	return true
end

-- Function to check whether rectangle object is selectable by x,y within the given resolution res
function checkXY(obj, x, y, res)
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

function init(cnvobj)
	GUIFW.RECT = {
		draw = drawhollow,
		visualAttr = cnvobj.attributes.visualAttrBank[1],	-- non filled object
		vAttr = 1
	}
	GUIFW.BLOCKINGRECT = {
		draw = drawblockingrectangle,
		visualAttr = cnvobj.attributes.visualAttrBank[2],	-- blocking rectangle
		vAttr = 2
	}
	GUIFW.FILLEDRECT = {
		draw = drawfilled,
		visualAttr = cnvobj.attributes.visualAttrBank[3],	-- filled object
		vAttr = 3
	}
	OBJ.RECT = {
		checkXY = checkXY,
	}
	OBJ.BLOCKINGRECT = {
		checkXY = checkXY,
	}
	OBJ.FILLEDRECT = {
		checkXY = checkXY,
	}
end


