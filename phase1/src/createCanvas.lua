
--********************************** Utilities *****************************************
local module = {}

grid_y=nil
grid_x=nil
--print("grid size "..grid_x, grid_y)
str = "{"
canvas = nil
canvas = iup.canvas{}
canvas.rastersize=""

--If not any image then this function create a white image. and draw a grid on the image
function create_white_image_and_draw_grid_on_image(canvas)
  
  local w, h = string.match(canvas.rastersize,"(%d*)x(%d*)")

  local cd_canvas = canvas.cdCanvas
 
 
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
     drawGrid(grid_canvas,canvas)
     grid_canvas:Kill()
   end
   
end

 -- to draw grid
function drawGrid(cd_canvas,canvas)
 
  --local w,h = string.match(canvas.size,"(%d*)x(%d*)")
  local w,h = cd_canvas:GetSize()
  local x,y
  print(w,h)
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

  
function canvas:map_cb()
  cd_canvas = cd.CreateCanvas(cd.IUPDBUFFER, canvas)
  canvas.cdCanvas = cd_canvas
end

function canvas:unmap_cb()
  local cd_canvas = canvas.cdCanvas
  cd_canvas:Kill()
end

function cnv()
  return canvas 
end
module.cnv = cnv

function save()
  str = str.."}"
  return str
end
module.save = save

function newcanvas(grid_x_size, grid_y_size, width, height)
    grid_x = grid_x_size
    grid_y = grid_y_size
    canvas.rastersize=""..width.."x"..height..""
    create_white_image_and_draw_grid_on_image(canvas)
    return canvas
end
module.newcanvas = newcanvas

return module