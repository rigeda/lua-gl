--drawing ractangle on grid

require( "iuplua" )
require("cdlua")
require("iupluacd")
require("imlua")
require("iupluaim")
require("cdluaim")
static_x=0
static_y=0
pos_x=0
pos_y=0

cnv = iup.canvas {rastersize="600x400"}
dg = iup.dialog{
	iup.vbox{
		cnv,
	}; 
	title="DrawingRectOnGrid"
}

-- To print the mouse positions
function cnv:motion_cb(x, y, r)
  --print(x, y, r)
  if move then
		 static_x=move[1]
		 static_y=move[2]
		 pos_x = x 
		 pos_y = y
		 drawRect()
  end
end
-- to draw grid
function drawGrid()
  local w,h = cdbCanvas:GetSize()
  local x,y
  --first for loop to draw horizontal
  cdbCanvas:SetForeground(cd.EncodeColor(192,192,192))
  for y=h, 0, -10 do
    cdbCanvas:Line(0,y,w,y)
  end
  -- for loop used to draw vertical line
  cdbCanvas:SetForeground(cd.EncodeColor(192,192,192))
  for x=0, w,10 do
    cdbCanvas:Line(x,0,x,h)
  end
  
end


function check_grid(static_x,pos_x,static_y,pos_y)
	print("we are in")
	if static_x%10~=0 or static_y%10~=0 then
		-- if static_x and static_y are not multiple of 10 then we have to adjust it
		-- first let static_x is not multiple of 10
		if static_x%10~=0 and static_x%10>=5 then
			static_x = static_x + (10 - static_x%10 )
			print(static_x)  -- if remdnder of static_x with 10 is greater then 5 then we will take upper bound     
		else
			static_x = static_x  - static_x%10 --else we will take lower bound
			print(static_x)
		end
		-- static_y is not multiple of 10

		if static_y%10~=0 and static_y%10>=5 then
			static_y = static_y + (10 - static_y%10 )
		else
			static_y = static_y  - static_y%10 
		end
	end

	if pos_x%10~=0 or pos_y%10~=0 then
		if pos_x%10~=0 and pos_x%10>=5 then
			pos_x = pos_x + (10 - pos_x%10 )
		else
			pos_x = pos_x  - pos_x%10 
		end

		if pos_y%10~=0 and pos_y%10>=5 then
			pos_y = pos_y + (10 - pos_y%10 )
		else
			pos_y = pos_y  - pos_y%10 
		end
	end
	print(static_x,pos_x,static_y,pos_y)
	return static_x,pos_x,static_y,pos_y
end
--to draw rectangle
function drawRect() 
	cdbCanvas:Activate() 
	cdbCanvas:SetBackground(cd.EncodeColor(255, 255, 255))
  cdbCanvas:Clear()
  drawGrid() 
	
	cdbCanvas:Foreground(cd.EncodeColor(255, 0, 0))
	 
	 p,q,r,s= check_grid(static_x,pos_x,static_y,pos_y) --the set rectangle on the grid. we have to adjust initial and final mouse pointer position so rectangle can best fit a grid.
	  
	cdbCanvas:Rect(p,q,cdbCanvas:UpdateYAxis(r),cdbCanvas:UpdateYAxis(s))
	cdbCanvas:Flush()	
end

-- Create the canvas and the buffer layer where the rendering will happen
function cnv:map_cb()
	cdCanvas = cd.CreateCanvas(cd.IUP, self)
	cdbCanvas = cd.CreateCanvas(cd.DBUFFER,cdCanvas)	-- Buffer to flush to visible canvas
end

function cnv:button_cb(button,pressed,x,y,status)
	if button == iup.BUTTON1 then
		if pressed == 1 then
			move = {x, y} 
			print("PRESSED COORDINATE",x,y)
      
		else 
			move = false
		  --cnv.cdCanvas=cdCanvas
		end
	end
end

function cnv:unmap_cb()
	cdbCanvas:Kill()
	cdCanvas:Kill()
end

function cnv:action(posx,posy)
	cdbCanvas:Flush()	-- Dump all changes in the buffer canvas to the visible canvas
end

function cnv:resize_cb()
	drawRect()
end


dg:showxy(iup.CENTER, iup.CENTER)
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
end

