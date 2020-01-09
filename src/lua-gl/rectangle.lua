-- Module to add rectangle functionality in lua-gl

local coorc = require("lua-gl.CoordinateCalc")
local GUIFW = require("lua-gl.guifw")

local print = print

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

function drawhollow(cnvobj,cnv,shape,x1,y1,x2,y2)
    cnv:Rect(x1, x2, y1, y2)
	return true
end

function drawfilled(cnvobj,cnv,shape,x1,y1,x2,y2)
	cnv:Box(x1, x2, y1, y2)
	return true
end

function drawblockingrectangle(cnvobj,cnv,shape,x1,y1,x2,y2)
	if(cnvobj.viewOptions.showBlockingRect==true) then
		cnv:Rect(x1, x2, y1, y2)
	end
	return true
end

function init(cnvobj)
	GUIFW.RECT = {
		draw = drawhollow,
		visualAttr = cnvobj.attributes.defaultVisualAttr[1]	-- non filled object
	}
	GUIFW.FILLEDRECT = {
		draw = drawfilled,
		visualAttr = cnvobj.attributes.defaultVisualAttr[3]	-- filled object
	}
	GUIFW.BLOCKINGRECT = {
		draw = drawblockingrectangle,
		visualAttr = cnvobj.attributes.defaultVisualAttr[2]	-- blocking rectangle
	}
end

-- Function to check whether rectangle object is selectable by x,y within the given resolution res
function checkXY(obj, x, y, res)
	if obj.shape ~= "RECT" and obj.shape ~= "BLOCKINGRECT" and obj.shape ~= "FILLEDRECT" then
		return nil
	end
	
	
	local x1, y1 = obj.start_x, obj.start_y
	local x3, y3 = obj.end_x , obj.end_y
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
