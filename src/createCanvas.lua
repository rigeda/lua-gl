
--********************************** Utilities *****************************************

createCanvasAndDrawObj = {

  
  new = function()
    local t = {}
    for key,value in pairs(createCanvasAndDrawObj) do
      t[key]=value 
    end
    return t
  end,

  --If not any image then this function create a white image. and draw a grid on the image
  create_white_image_and_draw_grid_on_image = function(canvas, cnvobj)
  
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
    if cnvobj.gridVisibility then
      if image then
        local grid_canvas = cd.CreateCanvas(cd.IMIMAGE,image)
        createCanvasAndDrawObj.drawGrid(grid_canvas,cnvobj)
        grid_canvas:Kill()
      end
    end
  end,

  -- to draw grid
  drawGrid = function(cd_canvas,cnvobj)
    --local w,h = string.match(canvas.size,"(%d*)x(%d*)")
    local w,h = cd_canvas:GetSize()
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
  end,



  --adjust x, or x should be multiple of grid_x
  check_grid_x = function(x)
    if x%grid_x ~= 0 then   --if x is not multiple of grid_x then we have to adjust it
      if x%grid_x >= grid_x/2 then   --upper bound 
        x = x + ( grid_x - x%grid_x )
      elseif x%grid_x < grid_x/2 then -- lower bound
        x = x - x%grid_x
      end
    end
    return x
  end,

  check_grid_y = function(y)
    if y%grid_y ~= 0 then   --if x is not multiple of grid_y then we have to adjust it
      if y%grid_y >= grid_y/2 then   --upper bound 
        y = y + ( grid_y - y%grid_y )
      elseif y%grid_y < grid_y/2 then -- lower bound
        y = y - y%grid_y
      end
    end
    return y
  end,


  --Used to Draw Shape
  DrawShape = function(cnv, start_x, start_y, end_x, end_y, shapeName)
  
    cnv:Foreground(cd.EncodeColor(0, 0, 255))
    canvas.shape = shapeName
    --print(canvas.shape, cnv, start_x, start_y, end_x, end_y)
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
  end,



--********************************** End Utilities *****************************************




  action = function(cnvobj)
    canvas = cnvobj.cnv
    local image = canvas.image
    local cd_canvas = canvas.cdCanvas
  
    shapeName = cnvobj.shape
    grid_x = cnvobj.grid_x
    grid_y = cnvobj.grid_y 
    width = cnvobj.width
    height = cnvobj.height
  
    local canvas_width, canvas_height = string.match(canvas.rastersize,"(%d*)x(%d*)")
    canvas_width = tonumber(canvas_width)
    canvas_height = tonumber(canvas_height)

  
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
        
        start_x =createCanvasAndDrawObj.check_grid_x(start_x)
        start_y = createCanvasAndDrawObj.check_grid_y(start_y)
        end_x = createCanvasAndDrawObj.check_grid_x(end_x)
        end_y = createCanvasAndDrawObj.check_grid_y(end_y)
     
        createCanvasAndDrawObj.DrawShape(cd_canvas, start_x, start_y, end_x, end_y, canvas.shape)
  
      end
    end
    cd_canvas:Flush()
  end,

  map_cb = function(canvas)
    local cd_canvas = cd.CreateCanvas(cd.IUP, canvas)
    canvas.cdCanvas = cd_canvas
  end,

  unmap_cb = function(canvas)
    local cd_canvas = canvas.cdCanvas
    cd_canvas:Kill()
  end,
   
 

  button_cb = function(cnvobj,button, pressed, x, y)
    canvas = cnvobj.cnv
    local image = canvas.image
  
    shapeName = cnvobj.shape
    grid_x = cnvobj.grid_x
    grid_y = cnvobj.grid_y 
    width = cnvobj.width
    height = cnvobj.height
    --To get canvas width and height
    --print(grid_x, grid_y, width, height) 

    local canvas_width, canvas_height = string.match(canvas.rastersize,"(%d*)x(%d*)")
    canvas_width = tonumber(canvas_width)
    canvas_height = tonumber(canvas_height)
    if (image) then
    
      y = canvas_height - y 
      --if button is pressed then simply set start_x and start_y
      if (button) then
        if (pressed == 1) then
          canvas.start_x = x
          canvas.start_y = y
        
          -- when mouse button is release then draw shape from starting point to end point
        else
          if (canvas.shape) then
        
            local temp_canvas = cd.CreateCanvas(cd.IMIMAGE, image)         
            local start_x = canvas.start_x
            local start_y = canvas.start_y
            start_x = createCanvasAndDrawObj.check_grid_x(start_x)
            start_y = createCanvasAndDrawObj.check_grid_y(start_y)
            x = createCanvasAndDrawObj.check_grid_x(x)
            y = createCanvasAndDrawObj.check_grid_y(y)
          

            createCanvasAndDrawObj.DrawShape(temp_canvas, start_x, start_y, x, y,shapeName)
            --concatinate elements with str 
            local index = #cnvobj.drawnEle
            --print(createCanvasAndDrawObj.dataTableOfDrawnElement)
            cnvobj.drawnEle[index+1] = {}
            cnvobj.drawnEle[index+1].shape = shapeName
            cnvobj.drawnEle[index+1].start_x = start_x
            cnvobj.drawnEle[index+1].start_y = start_y
            cnvobj.drawnEle[index+1].end_x = x
            cnvobj.drawnEle[index+1].end_y = y 

            --createCanvasAndDrawObj.i = createCanvasAndDrawObj.i + 1
            --table.str = createCanvasAndDrawObj.dataTableOfDrawnElement
            --print(table.str)
            temp_canvas:Kill()
            canvas.shape = nil
            iup.Update(canvas)
          end
        end
      end
    end
  end,
 
  motion_cb = function(cnvobj, x, y, status)
    canvas = cnvobj.cnv
    local  image = canvas.image
  
    local canvas_width, canvas_height = string.match(canvas.rastersize,"(%d*)x(%d*)")
    canvas_width = tonumber(canvas_width)
    canvas_height = tonumber(canvas_height)

    if (image) then
      y = canvas_height - y 
      if (iup.isbutton1(status)) then -- button1 is pressed 
        canvas.end_x = x
        canvas.end_y = y 
        canvas.shape = cnvobj.shape 
      
        iup.Update(canvas)
      end
    end
  end,


  --create_white_image_and_draw_grid_on_image(canvas)

  cnv = function()
    return canvas 
  end,
  --module.cnv = cnv
  --module.save = save

  newcanvas = function(cnvobj)
    grid_x = cnvobj.grid_x
    grid_y = cnvobj.grid_y
    width = cnvobj.width
    height = cnvobj.height
    canvas = iup.canvas{}
    canvas.rastersize=""..width.."x"..height..""
    createCanvasAndDrawObj.create_white_image_and_draw_grid_on_image(canvas,cnvobj)
    return canvas
  end,
  --module.newcanvas = newcanvas
}
return createCanvasAndDrawObj