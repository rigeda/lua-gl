require"cdlua"
require"iupluacd"
require"iuplua"

--main canvas
canva = iup.canvas {size = "200x100"}

--vertical box
vbox = iup.vbox{ canva }

--main dialog
dlg = iup.dialog{vbox; title="test-1.0"}

--responsible for creating the CD canvas
function canva:map_cb()
  canvas = cd.CreateCanvas(cd.IUP, self)
  self.canvas = canvas     
end

--retrieves the CD canvas associated to IupCanvas control and destroys it
function dlg:close_cb()
  canva = canva 
  canvas = canva.canvas    
  canvas:Kill()
  self:destroy()
  return iup.IGNORE 
end

--responsible for drawing the image on canvas
function canva:action()
  canvas = self.canvas    
  canvas:Activate()
  canvas:Clear()    
  canva:button_cb(_, _, 0, 0, _)
end




--use to draw elements
function draw(self,xmin,xmax,ymin,ymax)
  canvas:Clear()
  width, height = canvas:GetSize() --use to get the size of canvas
  print("width="..width.."    height="..height)
  canvas = self.canvas
  canvas:Foreground (cd.BLUE)
  canvas:Box (xmin, xmax, ymin,ymax)  --use to draw box on canvas
  canvas:Foreground(cd.EncodeColor(255, 32, 140))
  canvas:Line(0, height, 100, height-100)  --use to draw line on canvas
end

--the function is called when a mouse button is pressed
function canva:button_cb(b, e, x, y, r)  
  print ("Button: " .. "Button="..tostring(b).." Pressed="..tostring(e).." X="..tostring(x).." Y="..tostring(y) )
  local canvas = self.canvas
  width, height = canvas:GetSize()  --use to get the size of canvas
  draw(self,x-10,x+10,height-y-10,height-y+10)
end

--call when size is change
function canva:resize_cb(w, h)
  print("Width="..w.."   Height="..h)
  draw(self,-10,10,h-10,h+10)
end

dlg:show()

if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
end
