-- Module containing all graphical and user interface manipulation functions for IUP canvas

local iup = iup 
local cd = cd
local math = math

local RECT = require("lua-gl.rectangle")
local LINE = require("lua-gl.line")
local ELLIPSE = require("lua-gl.ellipse")
local coorc = require("lua-gl.CoordinateCalc")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

M.RECT = RECT
M.FILLEDRECT = RECT
M.BLOCKINGRECT = RECT
M.LINE = LINE
M.ELLIPSE = ELLIPSE
M.FILLEDELLIPSE = ELLIPSE

function mapCB(cnvobj)
	local cd_Canvas = cd.CreateCanvas(cd.IUP, cnvobj.cnv)
	local cd_bCanvas = cd.CreateCanvas(cd.DBUFFER,cd_Canvas)
	cnvobj.cdCanvas = cd_Canvas
	cnvobj.cdbCanvas = cd_bCanvas
end

function unmapCB(cnvobj)
	local cd_bCanvas = cnvobj.cdbCanvas
	local cd_Canvas = cnvobj.cdCanvas
	cd_bCanvas:Kill()
	cd_Canvas:Kill()
end

function buttonCB(cnvobj,button,pressed,x,y, status)
	cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
	cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y,status})
end

function motionCB(cnvobj,x, y, status)
	
end

function update(cnvobj)
	iup.Update(cnvobj.cnv)
end

function newCanvas()
	return iup.canvas{}
end

-- to draw grid
function drawGrid(cd_canvas,cnvobj)
    local w,h = cnvobj.width, cnvobj.height
    local x,y
    local grid_x = cnvobj.grid_x
    local grid_y = cnvobj.grid_y
    --first for loop to draw horizontal line
    cd_canvas:SetForeground(cd.EncodeColor(192,192,192))
    for y=0, h, grid_y do
      cd_canvas:Line(0,y,w,y)
    end
    -- for loop used to draw vertical line
    for x=0, w, grid_x do
      cd_canvas:Line(x,0,x,h)
    end
end

function  render(cnvobj)
	local canvas = cnvobj.cnv
	local cd_bcanvas = cnvobj.cdbCanvas
	local grid_x = cnvobj.grid_x
	local grid_y = cnvobj.grid_y 
	local canvas_width, canvas_height = cnvobj.width, cnvobj.height

	cd_bcanvas:Activate()
	cd_bcanvas:Background(cd.EncodeColor(255, 255, 255))
	cd_bcanvas:Clear()

	if cnvobj.gridVisibility then
		drawGrid(cd_bcanvas,cnvobj)
	end
	-- Now loop through the order array to draw every element in order
	local order = cnvobj.order
	for i = 1,#order do
		local item = order[i].item
		if order.type == "object" then
			-- This is an object
			canvas:Foreground(cd.EncodeColor(0, 0, 255))
			if M[item.shape] and M[item.shape].draw then
				M[item.shape].draw(cnvobj,cd_bcanvas,item.shape,item.start_x,item.start_y,item.end_x,item.end_y)
			end
		else
			-- This is a connector
			canvas:Foreground(cd.EncodeColor(0, 0, 255))
			local segs = item.segments
			for j = 1,#segs do
				LINE.draw(cnvobj,cd_bcanvas,"LINE",segs[j].start_x,segs[j].start_y,segs[j].end_x,segs[j].end_y)
			end
		end
	end
	cd_bcanvas:Flush()
end

