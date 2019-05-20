require"cdlua"
require"iupluacd"
require"iuplua"

canva = iup.canvas {size = "200x100"}

vbox = iup.vbox{ canva }

dlg = iup.dialog{vbox; title="test-1.0"}

function canva:map_cb()
  canvas = cd.CreateCanvas(cd.IUP, self)
  self.canvas = canvas     
end

function dlg:close_cb()
  canva = canva 
  canvas = canva.canvas    
  canvas:Kill()
  self:destroy()
  return iup.IGNORE 
end

function canva:action()
  canvas = self.canvas    
  canvas:Activate()
  canvas:Clear()
  canva:button_cb(_, _, 0, 0, _)
end

--initial width and height
height=210
width=350

--use to draw elements
function draw(self,xmin,xmax,ymin,ymax)
  canvas:Clear()
  canvas = self.canvas
  canvas:Foreground (cd.BLUE)
  canvas:Box (xmin, xmax, ymin,ymax)
  canvas:Foreground(cd.EncodeColor(255, 32, 140))
  canvas:Line(0, height, 100, height-100)  
end

function canva:button_cb(b, e, x, y, r)  
  draw(self,x-10,x+10,height-y-10,height-y+10)
end

function canva:resize_cb(w, h)
  print("Width="..w.."   Height="..h)
  height = h
  width = w
  draw(self,-10,10,height-10,height+10)
end

dlg:show()
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
end