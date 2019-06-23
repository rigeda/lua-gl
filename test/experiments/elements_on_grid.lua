require("imlua")
require("imlua_process")
require("iuplua")
require("iupluaimglib")
require("iupluaim")
require("cdlua")
require("iupluacd")
require("cdluaim")

--********************************** Utilities *****************************************

shapeNo = 0

function Line_button()
  shapeNo=1
end

function Rect_button()
  shapeNo=2
end

function Filled_rect_button()
  shapeNo=3
end

function Ellipse_button()
  shapeNo=4
end

function Filled_ellipse_button()
  shapeNo=5
end

--If not any image then this function put white image on canvas
function check_image(dlg)
  local canvas = dlg.canvas
  local image = canvas.image
  local cd_canvas = canvas.cdCanvas
  local w, h = cd_canvas:GetSize()
  if (not image) then
    --create imimage
    local image = im.ImageCreate(w, h, im.RGB, im.BYTE)
    
    --fill new image with white color
    local i, j
    local r = image[0]
    local g = image[1]
    local b = image[2]
    for i = 0, image:Height()-1 do
      for j = 0, image:Width()-1 do
        r[i][j] = 255
        g[i][j] = 255
        b[i][j] = 255
      end
    end
    canvas.image = image

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

--Used to Draw Shape
function DrawShape(cnv, s_x, s_y, e_x, e_y)
  --map mouse pointer and grid
  start_x, end_x, start_y, end_y = check_grid(s_x, e_x, s_y, e_y)
  
  cnv:Foreground(cd.EncodeColor(0, 0, 255))


  if (canvas.shape == "LINE") then
    cnv:Line(start_x, start_y, end_x, end_y)
  elseif (canvas.shape == "RECT") then
    cnv:Rect(start_x, end_x, start_y, end_y)
  elseif (canvas.shape == "FILLED_RECT") then
    cnv:Box(start_x, end_x, start_y, end_y)
  elseif (canvas.shape == "ELLIPSE") then
    cnv:Arc(math.floor((end_x + start_x) / 2), math.floor((end_y + start_y) / 2), math.abs(end_x - start_x), math.abs(end_y - start_y), 0, 360)
  elseif (canvas.shape == "FILLED_ELLIPSE") then
    cnv:Sector(math.floor((end_x + start_x) / 2), math.floor((end_y + start_y) / 2), math.abs(end_x - start_x), math.abs(end_y - start_y), 0, 360)
  end
end

-- to draw grid
function drawGrid(cd_canvas)
  local w,h = cd_canvas:GetSize()
  local x,y
  --first for loop to draw horizontal line
  cd_canvas:SetForeground(cd.EncodeColor(192,192,192))
  for y=h, 0, -10 do
    cd_canvas:Line(0,y,w,y)
  end
  -- for loop used to draw vertical line
  cd_canvas:SetForeground(cd.EncodeColor(192,192,192))
  for x=0, w,10 do
    cd_canvas:Line(x,0,x,h)
  end
end

-- this function call only one time. it draw grid on canvas
function NotGrid() 
  image = canvas.image
  if image then
    local grid_canvas = cd.CreateCanvas(cd.IMIMAGE,image)
    drawGrid(grid_canvas)
    grid_canvas:Kill()
  end
end
--********************************** End Utilities *****************************************


canvas = iup.canvas{ }


function canvas:action()
  local image = canvas.image
  local cd_canvas = canvas.cdCanvas
  local canvas_width, canvas_height = cd_canvas:GetSize()
  
  cd_canvas:Activate()
  cd_canvas:Background(cd.EncodeColor(255, 255, 255))
  cd_canvas:Clear()

  if (image) then
    cd_canvas:PutImImage(image, 0, 0, canvas_width, canvas_height)  
    if (canvas.shape) then
      local start_x = canvas.start_x
      local start_y = canvas.start_y
      local end_x = canvas.end_x
      local end_y = canvas.end_y
      DrawShape(cd_canvas, start_x, start_y, end_x, end_y)
    end
  end
  cd_canvas:Flush()
end

function canvas:map_cb()
  cd_canvas = cd.CreateCanvas(cd.IUPDBUFFER, canvas)
  canvas.cdCanvas = cd_canvas
end

function canvas:unmap_cb()
  local cd_canvas = canvas.cdCanvas
  cd_canvas:Kill()
end



function canvas:button_cb(button, pressed, x, y)
  local image = self.image
  --To get canvas width and height
  local cd_canvas = canvas.cdCanvas
  local canvas_width, canvas_height = cd_canvas:GetSize()

  if (image) then
    y = canvas_height - y 
    --if button is pressed then simply set start_x and start_y
    if (button == iup.BUTTON1) then
      if (pressed == 1) then
        canvas.start_x = x
        canvas.start_y = y
      -- when mouse button is release then draw shape from starting point to end point
      else
        if (shapeNo >= 1 and shapeNo <= 6) then -- Shapes
          if (canvas.shape) then
            local start_x = canvas.start_x
            local start_y = canvas.start_y
            local temp_canvas = cd.CreateCanvas(cd.IMIMAGE, image)
            DrawShape(temp_canvas, start_x, start_y, x, y)
              
            temp_canvas:Kill()

            canvas.shape = nil
            iup.Update(canvas)
          end
        end
      end
    end
  end
  --return iup.DEFAULT
end

function canvas:motion_cb(x, y, status)
  local image = self.image
  --to get size of canvas
  local cd_canvas= canvas.cdCanvas
  local canvas_width, canvas_height = cd_canvas:GetSize()
  
  if (image) then
    y = canvas_height - y 
    if (iup.isbutton1(status)) then -- button1 is pressed          
      if (shapeNo >= 1 and shapeNo <= 5) then -- Shapes
        local shapes = {"LINE", "RECT", "FILLED_RECT", "ELLIPSE", "FILLED_ELLIPSE"}
        self.end_x = x
        self.end_y = y 
        self.shape = shapes[shapeNo]
        iup.Update(self)
      end
    end
  end
end



--********************************** Main *****************************************

hbox = iup.hbox{
  iup.vbox {
  iup.button{ title="Line", tip="Line", action = Line_button},
  iup.button{ title="Rect",  tip="Rectangle", action = Rect_button},
  iup.button{ title="Filled Rect",  tip="Filled Rectangle", action = Filled_rect_button},
  iup.button{ title="Ellipse", tip="Ellipse", action = Ellipse_button},
  iup.button{ title="Filled Ellipse", tip="Filled Ellipse", action = Filled_ellipse_button},
  
  margin = "20x20",
  }
}
--element box
ElementBox = iup.dialog{
  hbox,
  title = "Elements",
  cursor="HAND" 
}

vbox = iup.vbox{
  canvas,
}

dlg = iup.dialog{
  vbox,
  title = "Draw elements on grid",
  size = "FULLxFULL",
  canvas = canvas,
}

ElementBox.parentdialog = dlg

dlg:showxy(iup.CENTER, iup.CENTER)
ElementBox:showxy(iup.RIGHT, iup.LEFT)

check_image(dlg)
NotGrid()
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
end
