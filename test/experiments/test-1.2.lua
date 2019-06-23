--First of all drope the image on canvas
--You can see droped image on left botton corner

require("imlua")
require("iuplua")
require("iupluaimglib")
require("iupluaim")
require("cdlua")
require("cdluaim")       
require("iupluacd")

--initial widht and height
w=0
h=0
saveVar=false
drawPath=false

-- load image using im or open image
function open_file(canvas, filename)
  local image, err = im.FileImageLoadBitmap(filename, 0)
  
  if (image) then
    local dlg = iup.GetDialog(canvas)
    local canvas = dlg.canvas
    local config = canvas.config
    canvas.image = image
    iup.Update(canvas)
  end
  
end
--set configration
config = iup.config{}
config.app_name = "test-1.1"
config:Load()

btnSave=iup.button{title="Save"}

canvas = iup.canvas{
  config = config,
  dirty = nil,
}

--responsible for drawing the image on canvas

function canvas:action()
  local image = canvas.image
  local cd_canvas = canvas.cdCanvas
  cd_canvas:Activate()
  x=100
  y=100
  x=x+5
  y=y+5
  -- draw the background 
  local r, g, b =255, 255, 255
  cd_canvas:Background(cd.EncodeColor(r, g, b))
  cd_canvas:Clear()

  --to drow the line
  cd_canvas:Foreground(cd.EncodeColor(255, 32, 140))
  cd_canvas:Line(0,610,300,410)
   
  cd_canvas:Foreground (cd.BLUE)
  
  cd_canvas:Box (x,x+1,y,y+1)  --use to draw box on canvas
  -- draw the image on the canvas 
  if (image) then
    image:cdCanvasPutImageRect(cd_canvas, w, h, 50 , 50, 0, 0, 0, 0)
  end
  
  cd_canvas:Flush()
end

function draw(self,x,y)
   
    --width, height = canvas:GetSize() --use to get the size of canvas
    --print("width="..width.."    height="..height)
    
    --canvas = self.canvas
    cd_canvas:Foreground (cd.BLUE)
    
    cd_canvas:Box (x,x+1,y,y+1)  --use to draw box on canvas
    cd_canvas:Foreground(cd.RED)
  end

--responsible for creating the CD canvas
function canvas:map_cb()
  cd_canvas = cd.CreateCanvas(cd.IUPDBUFFER, canvas)
  canvas.cdCanvas = cd_canvas
end


--retrieves the CD canvas associated to IupCanvas control and destroys it
function canvas:unmap_cb()
  local cd_canvas = canvas.cdCanvas
  cd_canvas:Kill()
end

--To change possition of image when mouse button is pressed
function canvas:button_cb(b, e, x, y, r)  
  local cd_canvas = canvas.cdCanvas
  cd_width,cd_height=cd_canvas:GetSize()
  w=x
  h=cd_height - y
  canvas:action()

end

--to save the current image
function btnSave:action() 
    local image=canvas.image
    if image then
        err = im.FileImageSave("kkr.jpeg","JPEG",image)
    end
end


--Used to open droped image
function canvas:dropfiles_cb(filename)
    open_file(canvas, filename)
end


--to check new image. if new image then put black image on canvas
function new_image(dlg)
    local canvas = dlg.canvas
    local image = canvas.image
    if (not image) then
        local config = canvas.config
        local width = config:GetVariableDef("NewImage", "Width", 640)
        local height = config:GetVariableDef("NewImage", "Height", 480)
  
        local image = im.ImageCreate(width, height, im.RGB, im.BYTE)

        local old_image = canvas.image

        canvas.image = image
  
        iup.Update(canvas)
  
        if (old_image) then
            old_image:Destroy()
        end
    end
end

vbox = iup.vbox{
  canvas,
  btnSave
}

--main dialog
dlg = iup.dialog{
  vbox,
  title = "test-1.1",
  size = "HALFxHALF",
  canvas = canvas,
  dropfiles_cb = canvas.dropfiles_cb,
}

-- show the dialog at the last position
config:DialogShow(dlg, "MainWindow")
new_image(dlg)
-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
end