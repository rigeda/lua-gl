require("iuplua")
require("iupluaimglib")
require("cdlua")
require("iupluacd")

LGL = require("lua-gl")

TableUtils = require("tableUtils")

function Line_button()
  cnvobj:drawObj("LINE")
end

function Rect_button()
  cnvobj:drawObj("RECT")
end

function Filled_rect_button()
  cnvobj:drawObj("FILLEDRECT")
end

function Ellipse_button()
  cnvobj:drawObj("ELLIPSE")
end

function Filled_ellipse_button()
  cnvobj:drawObj("FILLEDELLIPSE")
end

local str

function save()
  str = cnvobj:save()
end

function load()
  cnvobj:load(str)
end



cnvobj = LGL.new{ grid_x = 40, grid_y = 40, width = 700, height = 400, gridVisibility = true}

toggle1 = iup.toggle{title ="snapGrid", action = snapGrid}
toggle2 = iup.toggle{title ="gridVisibility", action = gridVisibility}


function toggle1:action(v)
  if v == 1 then
    cnvobj.snapGrid = true
  else 
    cnvobj.snapGrid = false
  end
end
function toggle2:action(v)
  if v == 1 then
    cnvobj.gridVisibility = true
  else 
    cnvobj.gridVisibility = false
  end
end

function valuechanged_cb_grid_x(self)
  local value = self.value
  cnvobj.grid_x = value
end

function valuechanged_cb_grid_y(self)
  local value = self.value
  cnvobj.grid_y = value
end

function connectorAction()
  cnvobj.drawing = "CONNECTOR"
end

function groupShapesAction(self)
  local value = self.value
  local check = string.match(value, "{.*}")
  if check then 
    local table = TableUtils.s2t(value)
    cnvobj:groupShapes(table)
    self.value = ""
  end

end


hbox = iup.hbox{
    iup.vbox {
      iup.label{ title = "Drawing"},
      iup.button{ title="Line", tip="Line", action = Line_button},
      iup.button{ title="Rect",  tip="Rectangle", action = Rect_button},
      iup.button{ title="Filled Rect",  tip="Filled Rectangle", action = Filled_rect_button},
      iup.button{ title="Ellipse", tip="Ellipse", action = Ellipse_button},
      iup.button{ title="Filled Ellipse", tip="Filled Ellipse", action = Filled_ellipse_button},
      
      margin = "20x20",
    },

    iup.vbox {
      
      toggle1,
      toggle2,
      iup.label{title="grid_x:", expand="HORIZONTAL"},
      iup.text{ expande="HORIZONTAL", value = cnvobj.grid_x, valuechanged_cb = valuechanged_cb_grid_x},

      iup.label{title="grid_y:", expand="HORIZONTAL"},
      iup.text{ expande="HORIZONTAL", value = cnvobj.grid_y, valuechanged_cb = valuechanged_cb_grid_y},


      iup.button{ title="Save", action = save},
      iup.button{ title="Load", action = load},
      margin = "20x20",
    },
    iup.vbox {
      iup.label{title="groupShapes", expand="HORIZONTAL"},
      iup.text{ expande="HORIZONTAL", value = "value must a table", valuechanged_cb = groupShapesAction},
      iup.button{ title="connector", action = connectorAction},
      margin = "20x20",
    }
}

dlg = iup.dialog{
   
    iup.vbox{
        hbox,
        iup.label{title = "----------------Canvas1---------------"},
        cnvobj.cnv,
    },
    title="lua-gl",
}
dlg:showxy(iup.CENTER, iup.CENTER)

if iup.MainLoopLevel()==0 then
    iup.MainLoop()
    iup.Close()
end



