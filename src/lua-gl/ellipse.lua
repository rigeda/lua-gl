-- Module to add ellipse functionality in lua-gl
-- The ellipse major and minor axis will be aligned to the X and Y axis

local coorc = require("lua-gl.CoordinateCalc")
local GUIFW = require("lua-gl.guifw")
local OBJ = require("lua-gl.objects")
local abs = math.abs
local floor = math.floor

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

function drawfilled(cnvobj,cnv,shape,x1,y1,x2,y2)
	cnv:Sector(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), 0, 360)
	return true
end

function drawhollow(cnvobj,cnv,shape,x1,y1,x2,y2)
	cnv:Arc(floor((x2 + x1) / 2), floor((y2 + y1) / 2), abs(x2 - x1), abs(y2 - y1), 0, 360)
	return true
end

-- Function to check whether ellipse object is selectable by x,y within the given resolution res
function checkXY(obj, x, y, res)
	if obj.shape ~= "ELLIPSE" and obj.shape ~= "FILLEDELLIPSE" then
		return nil
	end
	
	local x1,y1,x2,y2 = obj.start_x,obj.start_y,obj.end_x,obj.end_y
	-- Find the semi major axis and semi minor axis
	local A = floor(abs(x2-x1)/2)
	local B = floor(abs(y2-y1)/2)
	local a = A-res
	local b = B-res
	A = A + res
	B = B + res
	local xc,yc = floor((x1+x2)/2),floor((y1+y2)/2)
	local dxc,dyc = (x-xc)^2,(y-yc)^2
	if (dxc/A^2+dyc/B^2) <= 1 and (dxc/a^2+dyc/b^2) >= 1 then
		return true
	end
	return false
end

function init(cnvobj)
	-- Register drawing functions
	GUIFW.ELLIPSE = {
		draw = drawhollow,
		visualAttr = cnvobj.attributes.visualAttrBank[1],	-- non filled object
		vAttr = 3
	}
	GUIFW.FILLEDELLIPSE = {
		draw = drawfilled,
		visualAttr = cnvobj.attributes.visualAttrBank[3],	-- filled object
		vAttr = 1
	}
	-- Register checkXY function
	OBJ.ELLIPSE = {
		checkXY = checkXY
	}
	OBJ.FILLEDELLIPSE = {
		checkXY = checkXY
	}
end