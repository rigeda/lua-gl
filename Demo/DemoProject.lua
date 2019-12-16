require("iuplua")
require("iupluaimglib")
require("cdlua")
require("iupluacd")
require("submodsearcher")

LGL = require("lua-gl")

iup.ImageLibOpen()

-------------<<<<<<<<<<< ##### LuaTerminal ##### >>>>>>>>>>>>>-------------
require("iuplua_scintilla")
LT = require("LuaTerminal")
LT.USESCINTILLA = true

-- Create terminal
newterm = LT.newTerm(_ENV,true,"testlog.txt")

--print("newterm: ", newterm)
LTbox = iup.vbox{newterm}

LTdlg = iup.dialog{LTbox; title="LuaTerminal", size="QUARTERxQUARTER"}
LTdlg:showxy(iup.RIGHT, iup.LEFT)
-------------<<<<<<<<<<< ##### LuaTerminal End ##### >>>>>>>>>>>>>-------------

--*************** Main (Part 1/2) ******************************

cnvobj = LGL.new{ grid_x = 40, grid_y = 40, width = 900, height = 600, gridVisibility = true}

--********************* Callbacks *************
--[[

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

local shapeList = {}
function groupShapesAction()
  label.value = "select shape for grouping"
  
  cnvobj:addHook("MOUSECLICKPOST",function(button, pressed, x, y)
    shapeID = cnvobj:whichShape(x,y)
    shapeList[#shapeList + 1] = shapeID
  end)
end

function endGrouping()
  cnvobj.hook = {}
  if #shapeList > 0 then
    cnvobj:groupShapes(shapeList)
    shapeList = {}
  end
end

function addPort()
  label.value = "select coordinate on the shape where you want to add port"
  cnvobj:addHook("MOUSECLICKPOST",function(button, pressed, x, y)
    shapeID = cnvobj:whichShape(x,y)
    if pressed == 0 then
      cnvobj:addPort(x,y,shapeID)
        
      cnvobj.drawnEle[#cnvobj.drawnEle + 1] = {}
      cnvobj.drawnEle[#cnvobj.drawnEle] = {start_x = x + 3, start_y = y + 3, end_x = x-3, end_y =y-3, shape="FILLEDELLIPSE", shapeID = #cnvobj.drawnEle}
		  cnvobj.drawnEle[#cnvobj.drawnEle].Asso_port = portID
		
		  if shapeID then
			    local shapeTable = {}
      		table.insert(shapeTable,shapeID)
      		table.insert(shapeTable,#cnvobj.drawnEle)
      		cnvobj:groupShapes(shapeTable)
		  end
      iup.Update(cnvobj.cnv)
    end
  end)
end

function stopAddingport()
  print("number of port",#cnvobj.port)
  cnvobj.hook = {}
end

function clear()
  cnvobj:erase()
  cnvobj.connector = {}
end



--********************************** Main (Part 1/2) *****************************************
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
      margin = "20x20",
    },
    iup.vbox {
      label,
      iup.button{ title="Save", action = save},
      iup.button{ title="Load", action = load},
      iup.button{title = "clear" , action = clear},
      margin = "20x20",
    },
    
    iup.vbox {
      iup.label{title = "Grouping"},
      iup.button{title="groupShapes",action = groupShapesAction},
      iup.button{title="endGrouping",action = endGrouping},
      iup.label{title = "Port"},
      iup.button{title = "addPort", action  = addPort},
      iup.button{title = "stopAddingport", action = stopAddingport},
      iup.label{title = "Connector"},
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

]]
GUI.mainDlg:showxy(iup.CENTER, iup.CENTER)

if iup.MainLoopLevel()==0 then
    iup.MainLoop()
    iup.Close()
end

