-- Module containing all graphical and user interface manipulation functions for IUP and CD library.
-- This module aims to abstract away the underlying framework of IUP and CD libraries

require("iuplua")
require("iupluaimglib")
require("cdlua")
require("iupluacd")

local iup = iup 
local cd = cd
local math = math

local RECT = require("lua-gl.rectangle")
local LINE = require("lua-gl.line")
local ELLIPSE = require("lua-gl.ellipse")
local coorc = require("lua-gl.CoordinateCalc")

local print = print

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
	--local cd_Canvas = cd.CreateCanvas(cd.IUP, cnvobj.cnv)
	local cd_bCanvas = cd.CreateCanvas(cd.IUPDBUFFER,cnvobj.cnv) --cd_Canvas)
	--cnvobj.cdCanvas = cd_Canvas
	cnvobj.cdbCanvas = cd_bCanvas
end

function unmapCB(cnvobj)
	local cd_bCanvas = cnvobj.cdbCanvas
	--local cd_Canvas = cnvobj.cdCanvas
	cd_bCanvas:Kill()
	--cd_Canvas:Kill()
end

function buttonCB(cnvobj,button,pressed,x,y, status)
	cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
	cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y,status})
end

function motionCB(cnvobj,x, y, status)
	
end

function newCanvas()
	return iup.canvas{}
end

-- to draw grid
-- One experiment was to draw the grid using a stipple but was told there is no guaranteed way to align the stipple pattern to
-- known canvas coordinates so always drawing the grid manually
local function drawGrid(cnv,cnvobj)
	--print("DRAWGRID!")
    local w,h = cnvobj.width, cnvobj.height
    local x,y
    local grid_x = cnvobj.grid.grid_x
    local grid_y = cnvobj.grid.grid_y
	
	local fColor = cnv:Foreground(cd.QUERY)
	local bColor = cnv:Background(cd.QUERY)
	if cnvobj.viewOptions.gridMode == 1 then
		local br,bg,bb = cd.DecodeColor(bColor)
		cnv:SetForeground(cd.EncodeColor(255-br,255-bg,255-bb))	-- Bitwise NOT of the background color
	else
		--cnv:SetForeground(cd.EncodeColor(192,192,192))
		cnv:SetForeground(cd.EncodeColor(255,0,0))
	end
    --first for loop to draw horizontal line
    for y=0, h, grid_y do
      cnv:Line(0,y,w,y)
    end
	if cnvobj.viewOptions.gridMode == 1 then
		cnv:SetForeground(bColor)		-- Draw with backfround color
	end		
    -- for loop used to draw vertical line
    for x=0, w, grid_x do
      cnv:Line(x,0,x,h)
    end
	if cnvobj.viewOptions.gridMode == 1 then
		cnv:WriteMode(cd.XOR)
		cnv:SetForeground(cd.EncodeColor(255,255,255))	-- XOR with White
		for y=0, h, grid_y do
		  cnv:Line(0,y,w,y)
		end
		cnv:WriteMode(cd.REPLACE)
	end		
	cnv:SetForeground(fColor)
end

function  render(cnvobj)
	local canvas = cnvobj.cnv
	local cd_bcanvas = cnvobj.cdbCanvas
	local canvas_width, canvas_height = cnvobj.width, cnvobj.height

	cd_bcanvas:Activate()
	cd_bcanvas:Background(cd.EncodeColor(255, 255, 255))
	cd_bcanvas:Clear()

	if cnvobj.viewOptions.gridVisibility then
		drawGrid(cd_bcanvas,cnvobj)
	end
	-- Now loop through the order array to draw every element in order
	local order = cnvobj.drawn.order
	for i = 1,#order do
		local item = order[i].item
		if order[i].type == "object" then
			-- This is an object
			cd_bcanvas:SetForeground(cd.EncodeColor(0, 162, 232))
			local x1,y1,x2,y2 = item.start_x,item.start_y,item.end_x,item.end_y
			--y1 = cnv:InvertYAxis(y1)
			--y2 = cnv:InvertYAxis(y2)
			y1 = cnvobj.height - y1
			y2 = cnvobj.height - y2
			
			if M[item.shape] and M[item.shape].draw then
				M[item.shape].draw(cnvobj,cd_bcanvas,item.shape,x1,y1,x2,y2)
			end
		else
			-- This is a connector
			cd_bcanvas:SetForeground(cd.EncodeColor(255, 128, 0))
			local segs = item.segments
			for j = 1,#segs do
				local s = segs[j]
				local x1,y1,x2,y2 = s.start_x,s.start_y,s.end_x,s.end_y
				--y1 = cnv:InvertYAxis(y1)
				--y2 = cnv:InvertYAxis(y2)
				y1 = cnvobj.height - y1
				y2 = cnvobj.height - y2
				LINE.draw(cnvobj,cd_bcanvas,"CONNECTOR",x1,y1,x2,y2)
			end
		end
	end
	cd_bcanvas:Flush()
end

function update(cnvobj)
	render(cnvobj)
end
