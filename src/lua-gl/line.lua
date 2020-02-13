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

local function draw(cnvobj,cnv,shape,x,y)
	cnv:Line(x[1],y[1],x[2],y[2])
	return true
end

local function drawConn(cnvobj,cnv,shape,x1,y1,x2,y2)
	cnv:Line(x1,y1,x2,y2)
	return true	
end

-- Function to check whether line object is selectable by x,y within the given resolution res
function checkXY(obj, x, y,res)
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

function init(cnvobj)
	GUIFW.LINE = {
		draw = draw,
		visualAttr = cnvobj.attributes.visualAttrBank[1],	-- non filled object
		vAttr = 1
	}
	GUIFW.CONN = {
		draw = drawConn,
		visualAttr = cnvobj.attributes.visualAttrBank[4],	-- normal connector
		vAttr = 4				
	}
	-- Register checkXY function
	OBJ.LINE = {
		checkXY = checkXY
	}
end
