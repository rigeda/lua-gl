require("imlua")
require("imlua_process")
require("iuplua")
require("iupluaimglib")
require("iupluaim")
require("cdlua")
require("iupluacd")
require("cdluaim")

--********************************** Utilities *****************************************



function Line_button()
  newShapeIsReady = false
  shapeName="LINE"
end

function Rect_button()
  newShapeIsReady = false
  shapeName="RECT"
end

function Filled_rect_button()
  newShapeIsReady = false
  shapeName="FILLEDRECT"
end

function Ellipse_button()
  newShapeIsReady = false
  shapeName="ELLIPSE"
end

function Filled_ellipse_button()
  newShapeIsReady = false
  shapeName="FILLEDELLIPSE"
end



----------------******* Read write function ********------------------
function write_file(start_x,start_y,end_x,end_y)
  
    local ifile = io.open("/home/dsr/lua_gui/database.txt", "a")
    if (not ifile) then
      iup.Message("Error", "Can't open file: " .. "database.txt")
      return false
    end
  -- { obj="ELLIPSE", stx = 246, sty=381,enx=323,eny=217}
    local str = "{obj="..shapeName..",stx="..start_x..",sty="..start_y..",enx="..end_x..",eny="..end_y.."}\n"
    
    if (not ifile:write(str)) then
      iup.Message("Error", "Fail when writing to file: " .."database.txt")
    end
    
    ifile:close()
    return true
end

function read_file()
  local file = io.open("/home/dsr/lua_gui/database.txt", "r")
  if (not file) then
    iup.Message("Error","Can't open file:".."database.txt")
    return false
  end

  local str = file:read("*a")

  if (not str) then
    iup.Message("Error", "Fail when reading from file: " .."database.txt")
    return nil
  end
  
  file:close()
  return str
end

-----------------********* End Read Write **********---------------------------


--If not any image then this function put a white image on the canvas. and draw a grid on the canvas
function put_white_image_and_draw_grid_on_canvas(dlg)
  local canvas = dlg.canvas
  
  local cd_canvas = canvas.cdCanvas
  local w, h = cd_canvas:GetSize()
  
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
    if image then
      local grid_canvas = cd.CreateCanvas(cd.IMIMAGE,image)
      drawGrid(grid_canvas)
      grid_canvas:Kill()
    end
    
end

--this function fits the element coordinate to the grid
function check_grid(start_x,start_y,end_x,end_y)
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
	return start_x, start_y,end_x, end_y
end

function check_grid_one_argument(x)
  if x%10 ~= 0 then
    if x%10 >= 5 then
      x = x + ( 10 - x%10 )
    elseif x%10 < 5 then
      x = x - x%10
    end
  end
  return x
end

--Used to Draw Shape
function DrawShape(cnv, start_x, start_y, end_x, end_y)
  --map mouse pointer and grid
  --start_x, end_x, start_y, end_y = check_grid(s_x, e_x, s_y, e_y)
  
  cnv:Foreground(cd.EncodeColor(0, 0, 255))
  print(shapeName.." is going to draw",start_x,start_y,end_x,end_y)
  canvas.shape = shapeName
  if (canvas.shape == "LINE") then
    cnv:Line(start_x, start_y, end_x, end_y)
  elseif (canvas.shape == "RECT") then
    cnv:Rect(start_x, end_x, start_y, end_y)
  elseif (canvas.shape == "FILLEDRECT") then
    cnv:Box(start_x, end_x, start_y, end_y)
  elseif (canvas.shape == "ELLIPSE") then
    cnv:Arc(math.floor((end_x + start_x) / 2), math.floor((end_y + start_y) / 2), math.abs(end_x - start_x), math.abs(end_y - start_y), 0, 360)
  elseif (canvas.shape == "FILLEDELLIPSE") then
    cnv:Sector(math.floor((end_x + start_x) / 2), math.floor((end_y + start_y) / 2), math.abs(end_x - start_x), math.abs(end_y - start_y), 0, 360)
  end
end

-- to draw grid
function drawGrid(cd_canvas)
  local w,h = cd_canvas:GetSize()
  local x,y
  --first for loop to draw horizontal line
  cd_canvas:SetForeground(cd.EncodeColor(192,192,192))
  for y=h-2, 0, -10 do
    cd_canvas:Line(0,y,w,y)
  end
  -- for loop used to draw vertical line
  cd_canvas:SetForeground(cd.EncodeColor(192,192,192))
  for x=0, w,10 do
    cd_canvas:Line(x,0,x,h)
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
      if newShapeIsReady then 
         --if the new shape is ready then no need to draw an element we have to draw a new shape
      else
        start_x, start_y, end_x, end_y = check_grid(start_x, start_y, end_x, end_y)
        DrawShape(cd_canvas, start_x, start_y, end_x, end_y)
      end
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
        
          if (canvas.shape) then
            
            local temp_canvas = cd.CreateCanvas(cd.IMIMAGE, image)

            if newShapeIsReady then
              --read the data from the database.txt file
              local str=read_file()

              local center_x,center_y
              center = true
              
              --retrieve data from the database.txt file
              for word in string.gmatch(str, "{.-}") do 
                shapeName, start_x, start_y, end_x, end_y = string.match(word,"{%a*=(%a*),%a*=(%d*).?.?,%a*=(%d*).?.?,%a*=(%d*).?.?,%a*=(%d*).?.?}*")                
                --calculate center_x, center_y which will use to adjust start_x, start_y, end_x, end_y according to the mouse pointer(cursor)                if center == true then
                if center == true then
                  center_x , center_y = math.abs((end_x - start_x)/2+start_x), math.abs((end_y-start_y)/2+start_y)
                  center = false 
                end
                x = check_grid_one_argument(x)
                y = check_grid_one_argument(y)
                --adjust start_x, start_y, end_x, end_y according to the mouse pointer(cursor)
                start_x = start_x + x - center_x
                start_y = start_y + y - center_y
                end_x = end_x + x - center_x
                end_y = end_y + y - center_y
                
                DrawShape(temp_canvas,start_x, start_y,end_x,end_y) 
              end
              print("\n function end \n")
            else
              local start_x = canvas.start_x
              local start_y = canvas.start_y
              start_x, start_y, x, y = check_grid(start_x, start_y, x, y)
              DrawShape(temp_canvas, start_x, start_y, x, y)
              --write elements in the database.txt file
              write_file(start_x,start_y,x,y)  
              
            end
            temp_canvas:Kill()

            canvas.shape = nil
            iup.Update(canvas)
          end
        --end
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

        self.end_x = x
        self.end_y = y 
        self.shape = shapeName
        iup.Update(self)

    end
 end
end








-----------------------------************ NewDialog ************------------------------------

--create new dialog when save button is pressed, a dialog contains a button for a new shape 

function dialog_which_contain_created_shape()
  newShapeBox=iup.hbox{
    iup.button{title = "new shape", action = new_shape},
    margin = "20x20",
  }

  created_shape = iup.dialog{
    newShapeBox,
    title = "Dialog for new Shapes",
    cursor = "HAND",
  }
  created_shape.parentdialog = dlg
  created_shape:showxy(iup.RIGHT,iup.RIGHT)
end

--when new_shape button pressed it will clear the canvas.it will put a white image and draw the grid on the canvas. 
--this button set newShapeIsReady = true
function new_shape()
  
  local str = read_file()
  
  put_white_image_and_draw_grid_on_canvas(dlg)
  iup.Update(canvas)
  newShapeIsReady = true
  
end
----------------------************** End Newdialog **************--------------------


--********************************** Main *****************************************

hbox = iup.hbox{
  iup.vbox {
  iup.button{ title="Line", tip="Line", action = Line_button},
  iup.button{ title="Rect",  tip="Rectangle", action = Rect_button},
  iup.button{ title="Filled Rect",  tip="Filled Rectangle", action = Filled_rect_button},
  iup.button{ title="Ellipse", tip="Ellipse", action = Ellipse_button},
  iup.button{ title="Filled Ellipse", tip="Filled Ellipse", action = Filled_ellipse_button},
  iup.button{ title="Save", action = dialog_which_contain_created_shape},
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

--to delete all data of database.txt file
function dlg:close_cb()
  local file = io.open("/home/dsr/lua_gui/database.txt","w")
  file:close()
end




dlg:showxy(iup.CENTER, iup.CENTER)
ElementBox:showxy(iup.RIGHT, iup.LEFT)


put_white_image_and_draw_grid_on_canvas(dlg)


if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
end
