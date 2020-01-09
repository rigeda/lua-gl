-- Module to add line drawing functionality to lua-gl

local coorc = require("lua-gl.CoordinateCalc")
local GUIFW = require("lua-gl.guifw")
local OBJ = require("lua-gl.objects")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

function draw(cnvobj,cnv,shape,x1,y1,x2,y2)
	cnv:Line(x1,y1,x2,y2)
	return true
end

-- Function to check whether line object is selectable by x,y within the given resolution res
function checkXY(obj, x, y,res)
	if obj.shape ~= "LINE" then
		return nil
	end
	
	local x1,y1,x2,y2
	x1 = obj.start_x
	y1 = obj.start_y
	x2 = obj.end_x
	y2 = obj.end_y

	return coorc.pointNearSegment(x1, y1, x2, y2, x, y, res)                
end

function init(cnvobj)
	GUIFW.LINE = {
		draw = draw,
		visualAttr = cnvobj.attributes.defaultVisualAttr[1]	-- non filled object
	}
	-- Register checkXY function
	OBJ.LINE = {
		checkXY = checkXY
	}
end
