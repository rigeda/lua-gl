--drawing ractangle on grid

require( "iuplua" )
require("cdlua")
require("iupluacd")


start_x=0
start_y=0
end_x=0
end_y=0

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
		 start_x=move[1]
		 start_y=move[2]
		 end_x = x 
		 end_y = y
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


function check_grid(start_x,end_x,start_y,end_y)
	if start_x%10~=0 or start_y%10~=0 then
		-- if start_x and start_y are not multiple of 10 then we have to adjust it
		-- first let start_x is not multiple of 10
		if start_x%10~=0 and start_x%10>=5 then
			start_x = start_x + (10 - start_x%10 )
		 -- if remdnder of start_x with 10 is greater then 5 then we will take upper bound     
		else
			start_x = start_x  - start_x%10 --else we will take lower bound
			--print(static_x)
		end
		-- start_y is not multiple of 10

		if start_y%10~=0 and start_y%10>=5 then
			start_y = start_y + (10 - start_y%10 )
		else
			start_y = start_y  - start_y%10 
		end
	end

	if end_x%10~=0 or end_y%10~=0 then
		if end_x%10~=0 and end_x%10>=5 then
			end_x = end_x + (10 - end_x%10 )
		else
			end_x = end_x  - end_x%10 
		end

		if end_y%10~=0 and end_y%10>=5 then
			end_y = end_y + (10 - end_y%10 )
		else
			end_y = end_y  - end_y%10 
		end
	end
	return start_x,end_x,start_y,end_y
end
--to draw rectangle
function drawRect() 
	cdbCanvas:Activate() 
	cdbCanvas:SetBackground(cd.EncodeColor(255, 255, 255))
  cdbCanvas:Clear()
  drawGrid() 
	
	cdbCanvas:Foreground(cd.EncodeColor(255, 0, 0))
	 
	 p,q,r,s= check_grid(start_x,end_x,start_y,end_y) --the set rectangle on the grid. we have to adjust initial and final mouse pointer position so rectangle can best fit a grid.
	cdbCanvas:LineWidth(2) 
	cdbCanvas:Rect(p,q,cdbCanvas:UpdateYAxis(r),cdbCanvas:UpdateYAxis(s))
	cdbCanvas:LineWidth(1)
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

