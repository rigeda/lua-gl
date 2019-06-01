--IupCanvas Example in IupLua 

require( "iuplua" )
require("cdlua")
require("iupluacd")
require("imlua")
require("iupluaim")
require("cdluaim")

cnv = iup.canvas {rastersize="600x400"}

dg = iup.dialog{
	iup.vbox{
		cnv,
	}; 
	title="IupCanvas"
}

gridx = 30
gridy = 20

boxc = {x=300,y=200}	-- current box center coordinates
boxImg = im.FileImageLoad("image.jpg")	-- The image to move
local iw,ih = boxImg:Width()*2, boxImg:Height()*2

--local Render

-- To print the mouse positions
function cnv:motion_cb(x, y, r)
  print(x, y, r)
  if move then
	-- move the box here
	cdbCanvas:PutImageRect(img, boxc.x-iw/2, cdbCanvas:UpdateYAxis(boxc.y-ih/2),0,0,0,0)
	cdbCanvas:GetImage(img, x-move[1], cdbCanvas:UpdateYAxis(y-move[2]))
	boxc.x = x-move[1]+iw/2	-- move[1] and move[2] contain the offset of the mouse pointer from the lower left corner of the box
	boxc.y = y-move[2]+ih/2	-- So set the new center coordinates on the boxc array which would be used by the rendering function to draw the box
	Render()
  end
end
-- to draw grid
function drawGrid()
  local w,h = cdbCanvas:GetSize()
  local x,y
  --first for loop to draw horizontal
  cdbCanvas:SetForeground(cd.EncodeColor(192,192,192))
  for y=h, 0, -gridy do
    cdbCanvas:Line(0,y,w,y)
  end
  -- for loop used to draw vertical line
  cdbCanvas:SetForeground(cd.EncodeColor(192,192,192))
  for x=0, w,gridx do
    cdbCanvas:Line(x,0,x,h)
  end
  
end


-- TO show key detections
function cnv:k_any(c)
  print("c              = ", c)
  print("  XkeyBase(c)  = ", iup.XkeyBase(c))
  print("  isCtrlXkey(c)= ", iup.isCtrlXkey(c))
  print("  isAltXkey(c) = ", iup.isAltXkey(c))
end

-- Draw everything needed on the canvas here
-- Maybe the buffer need not be redrawn but just the changes and then it should work. That would be faster - UNTESTED YET
function Render()
	cdbCanvas:Activate()
	cdbCanvas:SetBackground(cd.EncodeColor(255, 255, 255))
  cdbCanvas:Clear()
    drawGrid()  --used to draw grid
	
	print("IMG: ",img)
	if not img then
		-- Executing 1st time fill img with the image of area where the box will be drawn
		img = cdbCanvas:CreateImage(iw,ih)
    print("Create initial box")
    
		cdbCanvas:GetImage(img, boxc.x-iw/2, cdbCanvas:UpdateYAxis(boxc.y-ih/2))
    -- Put the image
    

      cdbCanvas:PutImImage(boxImg, boxc.x-iw/2,cdbCanvas:UpdateYAxis(boxc.y+ih/2),iw,ih)
    
		-- Draw the box
		--cdbCanvas:SetForeground(cd.EncodeColor(0, 0, 255))
		--cdbCanvas:Box(boxc.x-10,boxc.x+10,cdbCanvas:UpdateYAxis(boxc.y-10),cdbCanvas:UpdateYAxis(boxc.y+10))
	else
		print("PutImageRect")
    --cdbCanvas:PutImageRect(boxImg, boxc.x-iw/2, cdbCanvas:UpdateYAxis(boxc.y+ih/2),0,0,0,0)	-- Put the box image in the new coordinates
    --grid have 10 pixel gape
    if (boxc.x-iw/2)%gridx~=0 or (boxc.y+ih/2)%gridy~=0 then
      -- if (boxc.x-iw/2) and (boxc.y+ih/2)[x and y cordinate where we want to put image] are not multiple of 10 then we have to adjust it
      -- first let boxc.x-iw/2 is not multiple of 10
      if (boxc.x-iw/2)%gridx~=0 and (boxc.x-iw/2)%gridx>=(math.floor(gridx/2)) then
        tempx = boxc.x-iw/2 + (gridx - (boxc.x-iw/2)%gridx )  -- if remdnder of boxc.x-wh/2 with 10 is greater then 5 then we will take upper bound     
      else
        tempx = boxc.x-iw/2  - (boxc.x-iw/2)%(math.floor(gridx/2)) --else we will take lower bound
      end
      -- (boxy.c+ih/2) is not multiple of 10

      if (boxc.y+ih/2)%gridy~=0 and (boxc.y+ih/2)%gridy>=(math.floor(gridy/2)) then
        tempy = boxc.y+ih/2 + (gridy - (boxc.y+ih/2)%gridy )
      else
        tempy = boxc.y+ih/2  - (boxc.y+ih/2)%(math.floor(gridy/2))
      end

      cdbCanvas:PutImImage(boxImg, tempx,cdbCanvas:UpdateYAxis(tempy-1),iw,ih)
    end
		--cdbCanvas:PutImImage(boxImg, boxc.x-iw/2,cdbCanvas:UpdateYAxis(boxc.y+ih/2),iw,ih)
	end
	if not boxImg then
		-- Executing 1st time so get the image of the drawn box
		boxImg = cdbCanvas:CreateImage(iw,ih)
		cdbCanvas:GetImage(boxImg, boxc.x-iw/2, cdbCanvas:UpdateYAxis(boxc.y+ih/2))	-- y + 10 because that is the lower left corner of the box
	end
	
	cdbCanvas:Flush()	-- To switch the canvas to the buffer changes
end

-- Create the canvas and the buffer layer where the rendering will happen
function cnv:map_cb()
	cdCanvas = cd.CreateCanvas(cd.IUP, self)
	cdbCanvas = cd.CreateCanvas(cd.DBUFFER,cdCanvas)	-- Buffer to flush to visible canvas
end

function cnv:button_cb(button,pressed,x,y,status)
	if button == iup.BUTTON1 then
		if pressed == 1 then
			print("PRESSED COORDINATE",x,y)
			if x <= boxc.x + iw/2 and x >= boxc.x-iw/2 and y <= boxc.y+ih/2 and y >= boxc.y-ih/2 then
				print("SET MOVE")
				move = {x-boxc.x+iw/2,y-boxc.y+ih/2}
			end
		else
			print("RESET MOVE",boxc.x,boxc.y)
			move = false
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
	Render()
end


dg:showxy(iup.CENTER, iup.CENTER)
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
end
