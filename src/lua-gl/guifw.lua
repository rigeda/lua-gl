-- Module containing all graphical and user interface manipulation functions for IUP and CD library.
-- This module aims to abstract away the underlying framework of IUP and CD libraries

require("iuplua")
require("iupluaimglib")
require("cdlua")
require("iupluacd")

local coorc = require("lua-gl.CoordinateCalc")

local iup = iup 
local cd = cd

local type = type
local pairs = pairs
local floor = math.floor
local abs = math.abs
local tostring = tostring

local print = print

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- Constants

-- Mouse buttons
M.BUTTON1 = iup.BUTTON1	-- Left mouse button
M.BUTTON3 = iup.BUTTON3	-- Right mouse button

-- Line style constants
M.CONTINUOUS = cd.CONTINUOUS
M.DASHED = cd.DASHED
M.DOTTED = cd.DOTTED
M.DASH_DOT = cd.DASH_DOT
M.DASH_DOT_DOT = cd.DASH_DOT_DOT
M.CUSTOM = cd.CUSTOM
-- Line Join Constants
M.MITER = cd.MITER
M.BEVEL = cd.BEVEL
M.ROUND = cd.ROUND
-- Line Cap constants
M.CAPFLAT = cd.CAPFLAT
M.CAPSQUARE = cd.CAPSQUARE
M.CAPROUND = cd.CAPROUND
-- Back Opacity
M.OPAQUE = cd.OPAQUE
M.TRANSPARENT = cd.TRANSPARENT
-- Fill style
M.SOLID = cd.SOLID
M.HOLLOW = cd.HOLLOW
M.STIPPLE = cd.STIPPLE
M.HATCH = cd.HATCH
M.PATTERN = cd.PATTERN
-- Hatch styles
M.HORIZONTAL = cd.HORIZONTAL
M.VERTICAL = cd.VERTICAL
M.FDIAGONAL = cd.FDIAGNOL
M.BDIAGONAL = cd.BDIAGNOL
M.CROSS = cd.CROSS
M.DIAGCROSS = cd.DIAGCROSS
-- Font styles
M.PLAIN = cd.PLAIN
M.BOLD = cd.BOLD
M.ITALIC = cd.ITALIC
M.UNDERLINE = cd.UNDERLINE
M.STRIKEOUT = cd.STRIKEOUT
-- Font Alignment
M.NORTH = cd.NORTH
M.SOUTH = cd.SOUTH
M.EAST = cd.EAST
M.WEST = cd.WEST
M.NORTH_EAST = cd.NORTH_EAST
M.NORTH_WEST = cd.NORTH_WEST
M.SOUTH_EAST = cd.SOUTH_EAST
M.SOUTH_WEST = cd.SOUTH_WEST
M.CENTER = cd.CENTER
M.BASE_LEFT = cd.BASE_LEFT
M.BASE_CENTER = cd.BASE_CENTER
M.BASE_RIGHT = cd.BASE_RIGHT

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
	x,y = M.sCoor2dCoor(cnvobj,x,y)
	cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
	cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y,status})
end

function motionCB(cnvobj,x, y, status)
	
end

function newCanvas()
	return iup.canvas{BORDER="NO"}
end

-- Function to return the mouse position on the canvas. The returned coordinates are the same that would have been returned on the 
-- motion_cb or button_cb callback functions
function getMouseOnCanvas(cnvobj)
	local gx,gy = iup.GetGlobal("CURSORPOS"):match("^(%d%d*)x(%d%d*)$")
	local sx,sy = cnvobj.cnv.SCREENPOSITION:match("^(%d%d*),(%d%d*)$")
	return gx-sx,gy-sy
end

-- Function to put the mouse curson on the canvas on the given coordinates.
-- The coordinates x,y should be the coordinates on the canvas equivalent to the ones returned in the motion_cb and button_cb callbacks
function setMouseOnCanvas(cnvobj,x,y)
	local sx,sy = cnvobj.cnv.SCREENPOSITION:match("^(%d%d*),(%d%d*)$")
	iup.SetGlobal("CURSORPOS",tostring(sx+x).."x"..tostring(sy+y))
	return true
end

-- Function to convert the button_cb/motion_cb returned coordinates to database coordinates
function sCoor2dCoor(cnvobj,x,y)
	y = cnvobj.cdbCanvas:UpdateYAxis(y)
	local vp = cnvobj.viewPort
	local xm = vp.xmin
	local ym = vp.ymin
	local zoom = (vp.xmax-xm+1)/(cnvobj.width)
	y = floor(y*zoom+ym)
	x = floor(x*zoom+xm)
	return x,y
end

-- Function to convert the database coordinate to the canvas on screen coordinate
function dCoor2sCoor(cnvobj,x,y)
	local vp = cnvobj.viewPort
	local xm = vp.xmin
	local ym = vp.ymin
	local zoom = (vp.xmax-xm+1)/(cnvobj.width)
	x = floor((x-xm)/zoom)
	y = floor((y-ym)/zoom)
	y = cnvobj.cdbCanvas:UpdateYAxis(y)
	return x,y
end

-- Set of functions to setup attributes of something that is being drawn. Each function returns a closure (function with associated up values). The rendering loop just calls the function before drawing it
--[[
There are 6 types of items for which attributes need to be set:
		- Non filled object		(1)
		- Blocking rectangle	(2)	-- attribute set using getNonFilledObjAttrFunc function
		- Filled object			(3)
		- Normal Connector		(4)	-- attribute set using getNonFilledObjAttrFunc function
		- Jumping Connector		(5)	-- attribute set using getNonFilledObjAttrFunc function
		- Text					(6)	-- attribute set using getTextAttrFunc function
	So there are 2 functions below:
]]

-- Function to return closure for setting the attributes for text
--[[ Attributes to set are (given a table (attr) with all these keys and attributes)
* Draw color(color)	- Table with RGB e.g. {127,230,111}
* Typeface (typeface) - String containing the name of the font. If cross platform consistency is desired use "Courier", "Times" or "Helvetica".
* Style (style) - should be a combination of M.BOLD, M.ITALIC, M.PLAIN, M.UNDERLINE, M.STRIKEOUT
* Size (size) - should be a number
* Alignment (align) - should be one of M.NORTH, M.SOUTH, M.EAST, M.WEST, M.NORTH_EAST, M.NORTH_WEST, M.SOUTH_EAST, M.SOUTH_WEST, M.CENTER, M.BASE_LEFT, M.BASE_CENTER, or M.BASE_RIGHT
* Orientation (orient) - angle in degrees
]]
function getTextAttrFunc(attr)
	local typeface = attr.typeface
	local style = attr.style
	local size = attr.size
	local align = attr.align
	local orient = attr.orient
	local color = cd.EncodeColor(attr.color[1],attr.color[2],attr.color[3])
	
	return function(canvas)
		-- Set the font typeface, style and size
		canvas:Font(typeface,style,size)
		-- Set the text alignment
		canvas:TextAlignment(align)
		-- Set the text orientation
		canvas:TextOrientation(orient)
		-- Set the color of the text
		canvas:SetForeground(color)
	end	
end

-- Function to return closure for setting attributes for non filled objects
--[[ Attributes to set are: (given a table (attr) with all these keys and attributes)
* Draw color(color)	- Table with RGB e.g. {127,230,111}
* Line Style(style)	- number or a table. Number should be one of M.CONTINUOUS, M.DASHED, M.DOTTED, M.DASH_DOT, M.DASH_DOT_DOT. FOr table it should be array of integers specifying line length in pixels and then space length in pixels. Pattern repeats
* Line width(width) - number for width in pixels
* Line Join style(join) - should be one of the constants M.MITER, M.BEVEL, M.ROUND
* Line Cap style (cap) - should be one of the constants M.CAPFLAT, M.CAPROUND, M.CAPSQUARE
]]
function getNonFilledObjAttrFunc(attr)
	local color = cd.EncodeColor(attr.color[1],attr.color[2],attr.color[3])
	local style = attr.style
	local width = attr.width
	local join = attr.join
	local cap = attr.cap

	-- Function to set the attributes when the line style is a number
	local function nfoaNUM(canvas)
		-- Set the foreground color
		canvas:SetForeground(color)
		-- Set the line style
		canvas:LineStyle(style)
		-- Set line width
		canvas:LineWidth(width)
		-- Set Line Join
		canvas:LineJoin(join)
		-- Set Line cap
		canvas:LineCap(cap)
	end
	-- Function to set the attributes when the line style is a table
	local function nfoaTAB()
		-- Set the foreground color
		canvas:SetForeground(color)
		-- Set the line style
		canvas:LineStyleDashes(style, #style)
		-- Set line width
		canvas:LineWidth(width)
		-- Set Line Join
		canvas:LineJoin(join)
		-- Set Line cap
		canvas:LineCap(cap)	
	end
	if type(style) == "number" then
		return nfoaNUM
	else
		return nfoaTAB
	end
end

-- Function to return closure for setting attributes for non filled objects
--[[
The attributes to be set are:
* Fill Color(color)	- Table with RGB e.g. {127,230,111}
* Background Opacity (bopa) - One of the constants M.OPAQUE, M.TRANSPARENT	
* Fill interior style (style) - One of the constants M.SOLID, M.HOLLOW, M.STIPPLE, M.HATCH, M.PATTERN
* Hatch style (hatch) (OPTIONAL) - Needed if style == M.HATCH. Must be one of the constants M.HORIZONTAL, M.VERTICAL, M.FDIAGONAL, M.BDIAGONAL, M.CROSS or M.DIAGCROSS
* Stipple style (stipple) (OPTIONAL) - Needed if style = M.STIPPLE. Should be a  wxh matrix of zeros (0) and ones (1). The zeros are mapped to the background color or are transparent, according to the background opacity attribute. The ones are mapped to the foreground color.
* Pattern style (pattern) (OPTIONAL) - Needed if style = M.PATTERN. Should be a wxh color matrix of tables with RGB numbers`
]]
function getFilledObjAttrFunc(attr)
	local color = cd.EncodeColor(attr.color[1],attr.color[2],attr.color[3])
	local bopa = attr.bopa
	local style = attr.style
	local hatch = attr.hatch
	local r,c
	if attr.style == M.STIPPLE then
		r,c = #attr.stipple,#attr.stipple[1]
		local stipple = cd.CreateStipple(r,c)
		for i = 0,r do
			for j = 0,c do
				stipple[i*c+j] = attr.stipple[i+1][j+1]
			end
		end
	end
	
	if attr.style == M.PATTERN then
		r,c = #attr.pattern,#attr.pattern[1]
		local pattern = cd.CreatePattern(r,c)
		for i = 0,r do
			for j = 0,c do
				pattern[i*c+j] = cd.EncodeColor(attr.pattern[i+1][j+1][1],attr.pattern[i+1][j+1][2],attr.pattern[i+1][j+1][3])
			end
		end
	end
	
	local function foaSOHO(canvas)
		-- Set the foreground color
		canvas:SetForeground(color)
		-- Set the background opacity
		canvas:BackOpacity(bopa)
		-- Set interior style
		canvas:InteriorStyle(style)		
	end
	local function foaST(canvas)
		-- Set the foreground color
		canvas:SetForeground(color)		
		-- Set the background opacity
		canvas:BackOpacity(bopa)
		-- Set the stipple
		canvas:Stipple(stipple)		
	end
	local function foaHA(canvas)
		-- Set the foreground color
		canvas:SetForeground(color)		
		-- Set the background opacity
		canvas:BackOpacity(bopa)
		-- Set the hatch style
		canvas:Hatch(hatch)
	end
	local function foaPA(canvas)
		-- Set the foreground color
		canvas:SetForeground(color)		
		-- Set the background opacity
		canvas:BackOpacity(bopa)
		-- Set the pattern style
		canvas:Hatch(pattern)
	end
	
	if style == M.PATTERN then
		return foaPA
	elseif style == M.STIPPLE then
		return foaST
	elseif style == M.HATCH then
		return foaHA
	else
		return foaSOHO
	end
	
end

-- to draw grid
-- One experiment was to draw the grid using a stipple but was told there is no guaranteed way to align the stipple pattern to
-- known canvas coordinates so always drawing the grid manually
local function drawGrid(cnv,cnvobj,bColore,br,bg,bb,xmin,xmax,ymin,ymax,zoom)
	--print("DRAWGRID!")
    local w,h = cnvobj.width, cnvobj.height
    local x,y
    local grid_x = cnvobj.grid.grid_x
    local grid_y = cnvobj.grid.grid_y
	
	if cnvobj.viewOptions.gridMode == 1 then
		--print("Set dotted grid!")
		cnv:SetForeground(cd.EncodeColor(255-br,255-bg,255-bb))	-- Bitwise NOT of the background color
		--cnv:LineStyleDashes({1,grid_x-1},2)
		-- Set the new custom line style
		cnv:LineStyle(M.CONTINUOUS)
		cnv:LineWidth(1)
		cnv:LineJoin(M.MITER)
		cnv:LineCap(M.CAPFLAT)
		local yi,yf = floor(ymin/grid_y)*grid_y,ymax
		local yprev = floor((yi-ymin)/zoom)
		local yp
		cnv:Line(0,yprev,w,yprev)
		for y=yi+grid_y, yf, grid_y do
			yp = floor((y-ymin)/zoom)
			if abs(yp - yprev) >= 5 then
				cnv:Line(0,yp,w,yp)
				yprev = yp
			end				
		end
		-- Now draw the background rectangles
		cnv:SetForeground(bColore)
		cnv:BackOpacity(M.OPAQUE)
		cnv:InteriorStyle(M.SOLID)	
		local xi,xf = floor(xmin/grid_x)*grid_x,xmax
		local xprev = floor((xi-xmin)/zoom)
		local xp
		local fac = grid_x-xmin
		cnv:Box(xprev+1,floor((xi+fac)/zoom)-1,0,h)
		for x = xi+grid_x,xf,grid_x do
			xp = floor((x-xmin)/zoom)
			if abs(xp-xprev) >=5 then
				cnv:Box(xp+1, floor((x+fac)/zoom)-1, 0, h)
				xprev = xp
			end
		end
	else
		cnv:SetForeground(cd.EncodeColor(255-br,255-bg,255-bb))	-- Bitwise NOT of the background color
		cnv:LineStyle(M.CONTINUOUS)
		cnv:LineWidth(1)
		cnv:LineJoin(M.MITER)
		cnv:LineCap(M.CAPFLAT)
		--first for loop to draw horizontal line
		for y=0, h, grid_y do
		  cnv:Line(0,y,w,y)
		end
		-- for loop used to draw vertical line
		for x=0, w, grid_x do
		  cnv:Line(x,0,x,h)
		end		
	end
end

function  render(cnvobj)
	local canvas = cnvobj.cnv
	local cd_bcanvas = cnvobj.cdbCanvas
	local attr = cnvobj.attributes
	local vOptions = cnvobj.viewOptions
	local jdx = vOptions.junction.dx
	local jdy = vOptions.junction.dy
	local jshape = vOptions.junction.shape
	local bColor = vOptions.backgroundColor
	local bColore = cd.EncodeColor(bColor[1], bColor[2], bColor[3])

	cd_bcanvas:Activate()
	cd_bcanvas:Background(bColore)
	cd_bcanvas:Clear()

	local vp = cnvobj.viewPort
	local xm = vp.xmin
	local ym = vp.ymin
	local xmax = vp.xmax
	local zoom = (xmax-xm+1)/(cnvobj.width)
	local ymax = floor(zoom*cnvobj.height+ym-1)
	
	if cnvobj.viewOptions.gridVisibility then
		drawGrid(cd_bcanvas,cnvobj,bColore,bColor[1], bColor[2], bColor[3],xm,xmax,ym,ymax,zoom)
	end
	-- Now loop through the order array to draw every element in order
	local vAttr = 100		-- Special case number which forces the run of the next visual attributes run
	local shape,cshape
	local order = cnvobj.drawn.order
	local x1,y1,x2,y2
	local item
	local segs
	local juncs
	local s
	for i = 1,#order do
		item = order[i].item
		if order[i].type == "object" then
			-- This is an object
			--cd_bcanvas:SetForeground(cd.EncodeColor(0, 162, 232))
			-- Run the visual attributes
			shape = attr.visualAttr[item] or M[item.shape]	-- validity is not checked for the registered shape structure
			if vAttr == 100 or vAttr ~= shape.vAttr then
				vAttr = shape.vAttr
				shape.visualAttr(cd_bcanvas)
			end
			x1,y1 = item.x,item.y
			--[[
			y2 = {}
			for j = 1,#y1 do
				y2[j] = cnvobj.height - y1[j]
			end
			]]
			
			M[item.shape].draw(cnvobj,cd_bcanvas,x1,y1,item,zoom,xm,ym)
		else
			-- This is a connector
			--cd_bcanvas:SetForeground(cd.EncodeColor(255, 128, 0))
			cshape = attr.visualAttr[item] or M.CONN
			if vAttr == 100 or vAttr ~= cshape.vAttr then
				vAttr = cshape.vAttr
				cshape.visualAttr(cd_bcanvas)
			end
			segs = item.segments
			for j = 1,#segs do
				s = segs[j]
				shape = attr.visualAttr[s] or M.CONN
				if vAttr == 100 or vAttr ~= shape.vAttr then
					vAttr = shape.vAttr
					shape.visualAttr(cd_bcanvas)
				end
				x1,y1,x2,y2 = s.start_x,s.start_y,s.end_x,s.end_y
				--y1 = cnvobj.height - y1
				--y2 = cnvobj.height - y2
				M.CONN.draw(cnvobj,cd_bcanvas,x1,y1,x2,y2,zoom,xm,ym)
			end
			-- Draw the junctions
			if jdx~=0 and jdy~=0 then
				if vAttr == 100 or vAttr ~= cshape.vAttr then
					vAttr = cshape.vAttr
					cshape.visualAttr(cd_bcanvas)
				end
				cd_bcanvas:InteriorStyle(M.SOLID)	-- This doesn't effect the current vAttr because connector attribute is for non filled object		
				juncs = item.junction
				for j = 1,#juncs do
					x1,y1 = {juncs[j].x-jdx,juncs[j].x+jdx},{juncs[j].y-jdy,juncs[j].y+jdy}
					--y1[1] = cnvobj.height - y1[1]
					--y1[2] = cnvobj.height - y1[2]
					M.FILLEDELLIPSE.draw(cnvobj,cd_bcanvas,x1,y1,item,zoom,xm,ym)
				end
			end
		end
	end
	cd_bcanvas:Flush()
end

function update(cnvobj)
	render(cnvobj)
end

function init(cnvobj)
	local t = {}
	for k,v in pairs(M) do
		if type(v) ~= "function" then
			t[k] = v
		end
	end
	cnvobj.viewOptions.constants = t
end
