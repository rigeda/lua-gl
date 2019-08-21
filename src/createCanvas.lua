
local snap = require("snap")
local iup = iup 
local print = print
local cd = cd
local math = math

local M = {}
package.loaded[...] = M 
local _ENV = M

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

  --Used to Draw Shape
function  DrawShape(cnv, start_x, start_y, end_x, end_y, shape)
  
    cnv:Foreground(cd.EncodeColor(0, 0, 255))

    if (shape == "LINE") then
      cnv:Line(start_x, start_y, end_x, end_y)
    elseif (shape == "RECT") then
      cnv:Rect(start_x, end_x, start_y, end_y)
    elseif (shape == "FILLEDRECT") then
      cnv:Box(start_x, end_x, start_y, end_y)
    elseif (shape == "ELLIPSE") then
      cnv:Arc(math.floor((end_x + start_x) / 2), math.floor((end_y + start_y) / 2), math.abs(end_x - start_x), math.abs(end_y - start_y), 0, 360)
    elseif (shape == "FILLEDELLIPSE") then
      cnv:Sector(math.floor((end_x + start_x) / 2), math.floor((end_y + start_y) / 2), math.abs(end_x - start_x), math.abs(end_y - start_y), 0, 360)
    end
end

function  render(cnvobj)
  canvas = cnvobj.cnv
  local cd_bcanvas = cnvobj.cdbCanvas
  grid_x = cnvobj.grid_x
  grid_y = cnvobj.grid_y 
  
  local canvas_width, canvas_height = cnvobj.width, cnvobj.height
    
  cd_bcanvas:Activate()
  cd_bcanvas:Background(cd.EncodeColor(255, 255, 255))
  cd_bcanvas:Clear()
    
  if cnvobj.gridVisibility then
    drawGrid(cd_bcanvas,cnvobj)
  end
    
  if #cnvobj.drawnEle > 0 then
    for i=1, #cnvobj.drawnEle do
      DrawShape(cd_bcanvas, cnvobj.drawnEle[i].start_x, cnvobj.drawnEle[i].start_y, cnvobj.drawnEle[i].end_x, cnvobj.drawnEle[i].end_y, cnvobj.drawnEle[i].shape)
    end
  end
    
  if #cnvobj.loadedEle > 0 then
    for i=1, #cnvobj.loadedEle do
      DrawShape(cd_bcanvas, cnvobj.loadedEle[i].start_x, cnvobj.loadedEle[i].start_y, cnvobj.loadedEle[i].end_x, cnvobj.loadedEle[i].end_y, cnvobj.loadedEle[i].shape)
    end
  end
  
  if #cnvobj.activeEle > 0 then
    for i=1, #cnvobj.activeEle do
      DrawShape(cd_bcanvas, cnvobj.activeEle[i].start_x, cnvobj.activeEle[i].start_y, cnvobj.activeEle[i].end_x, cnvobj.activeEle[i].end_y, cnvobj.activeEle[i].shape)
    end
  end

  if #cnvobj.connector > 0 then
    for i = 1, #cnvobj.connector do
      DrawShape(cd_bcanvas,cnvobj.connector[i].start_x, cnvobj.connector[i].start_y, cnvobj.connector[i].end_x, cnvobj.connector[i].end_y, "LINE")
    end
  end

  if cnvobj.drawing == "START" or cnvobj.drawing == "CONNECTOR" then
    if cnvobj.motion then
      local start_x = canvas.start_x
      local start_y = canvas.start_y
      local end_x = canvas.end_x
      local end_y = canvas.end_y
      if cnvobj.snapGrid == true then  
        start_x =snap.Sx(start_x, grid_x)
        start_y = snap.Sy(start_y, grid_y)
        end_x = snap.Sx(end_x, grid_x)
        end_y = snap.Sy(end_y, grid_y)
      end
      DrawShape(cd_bcanvas, start_x, start_y, end_x, end_y, cnvobj.shape)
    end
  end
  cd_bcanvas:Flush()
end

function buttonCB(cnvobj,button, pressed, x, y)
  canvas = cnvobj.cnv
  grid_x = cnvobj.grid_x
  grid_y = cnvobj.grid_y 
  local canvas_width, canvas_height = cnvobj.width, cnvobj.height  
  --y = canvas_height - y 
  --if button is pressed then simply set start_x and start_y
  if (button) then
    if (pressed == 1) then
      canvas.start_x = x
      canvas.start_y = y
        
      -- when mouse button is release then update co.
    else
      if cnvobj.motion then         
        local start_x = canvas.start_x
        local start_y = canvas.start_y
        if cnvobj.snapGrid == true then
          start_x = snap.Sx(start_x, grid_x)
          start_y = snap.Sy(start_y, grid_y)
          x = snap.Sx(x, grid_x)
          y = snap.Sy(y, grid_y)
        end
          
        local index = #cnvobj.drawnEle
        cnvobj.drawnEle[index+1] = {}
        cnvobj.drawnEle[index+1].shapeID = index + 1
        cnvobj.drawnEle[index+1].shape = cnvobj.shape
        cnvobj.drawnEle[index+1].start_x = start_x
        cnvobj.drawnEle[index+1].start_y = start_y
        cnvobj.drawnEle[index+1].end_x = x
        cnvobj.drawnEle[index+1].end_y = y 
        cnvobj.motion = false
      end
    end
  end
end
 
function motionCB(cnvobj, x, y, status)
  canvas = cnvobj.cnv
  local canvas_width, canvas_height = cnvobj.width, cnvobj.height

  --y = canvas_height - y 
  if (iup.isbutton1(status)) then -- button1 is pressed 
    canvas.end_x = x
    canvas.end_y = y 
    canvas.shape = cnvobj.shape 
    cnvobj.motion = true
    iup.Update(canvas)
  end
end
