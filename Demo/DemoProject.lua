--[[
require("iuplua")
require("iupluaimglib")
require("cdlua")
require("iupluacd")
]]
LGL = require("lua-gl")
require("submodsearcher")

require("GUIStructures")


iup.ImageLibOpen()
iup.SetGlobal("IMAGESTOCKSIZE","32")

-------------<<<<<<<<<<< ##### LuaTerminal ##### >>>>>>>>>>>>>-------------
require("iuplua_scintilla")
LT = require("LuaTerminal")
LT.USESCINTILLA = true

-- Create terminal
newterm = LT.newTerm(_ENV,true,"testlog.txt")

--print("newterm: ", newterm)
LTbox = iup.vbox{newterm}

LTdlg = iup.dialog{
	LTbox; 
	title="LuaTerminal", 
	size="QUARTERxQUARTER",
	icon = GUI.images.appIcon
}
LTdlg:showxy(iup.RIGHT, iup.LEFT)
-------------<<<<<<<<<<< ##### LuaTerminal End ##### >>>>>>>>>>>>>-------------

--*************** Main (Part 1/2) ******************************

cnvobj = LGL.new{ 
	grid_x = 10, 
	grid_y = 10, 
	width = 900, 
	height = 600, 
	gridVisibility = true,
	snapGrid = true,
	showBlockingRect = true,
}
GUI.mainArea:append(cnvobj.cnv)


--********************* Callbacks *************

-- Turn ON/OFF snapping ont he grid
function GUI.toolbar.buttons.snapGridButton:action()
	if self.image == GUI.images.ongrid then
		self.image = GUI.images.offgrid
		self.tip = "Set Snapping On"
		cnvobj.grid.snapGrid = false
	else
		self.image = GUI.images.ongrid
		self.tip = "Set Snapping Off"
		cnvobj.grid.snapGrid = true
	end
end

-- Show/Hide the grid
function GUI.toolbar.buttons.showGridButton:action(v)
	if v == 1 then
		self.tip = "Turn grid off"
		cnvobj.viewOptions.gridVisibility = true
	else 
		self.tip = "Turn grid on"
		cnvobj.viewOptions.gridVisibility = false
	end
	cnvobj:refresh()
end

-- Show/Hide the Blocking Rectangles
function GUI.toolbar.buttons.showBlockingRect:action(v)
	if v == 1 then
		self.tip = "Hide Blocking Rectangles"
		self.image = GUI.images.blockingRectVisible
		cnvobj.viewOptions.showBlockingRect = true
	else 
		self.tip = "Show Blocking Rectangles"
		self.image = GUI.images.blockingRectHidden
		cnvobj.viewOptions.showBlockingRect = false
	end
	cnvobj:refresh()
end

-- Change the grid action
function GUI.toolbar.buttons.xygrid:action()
	local ret,x,y = iup.GetParam("Enter the Grid Size",nil,"X Grid%i{The grid size in X dimension}\nY Grid%i{The grid size in Y dimension}\n",cnvobj.grid.grid_x,cnvobj.grid.grid_y)
	if ret and x > 0 and y > 0 then
		cnvobj.grid.grid_x = x
		cnvobj.grid.grid_y = y
		cnvobj:refresh()
	end
end

-- Draw line object
function GUI.toolbar.buttons.lineButton:action()
	-- Non interactive line draw
	--[[cnvobj:drawObj("LINE",2,{
			{x=10,y=10},
			{x=100,y=100}
		})]]
	--cnvobj:refresh()
	cnvobj:drawObj("LINE",2)	-- interactive line drawing
end

-- Draw rectangle object
function GUI.toolbar.buttons.rectButton:action()
	cnvobj:drawObj("RECT",2)	-- interactive rectangle drawing
end

-- Draw filled rectangle object
function GUI.toolbar.buttons.fRectButton:action()
	cnvobj:drawObj("FILLEDRECT",2)	-- interactive filled rectangle drawing
end

-- Draw blocking rectangle object
function GUI.toolbar.buttons.bRectButton:action()
	cnvobj:drawObj("BLOCKINGRECT",2)	-- interactive blocking rectangle drawing
end

-- Draw ellipse object
function GUI.toolbar.buttons.elliButton:action()
	cnvobj:drawObj("ELLIPSE",2)	-- interactive ellipse drawing
end

-- Draw filled ellipse object
function GUI.toolbar.buttons.fElliButton:action()
	cnvobj:drawObj("FILLEDELLIPSE",2)	-- interactive filled ellipse drawing
end

-- Start Move operation
function GUI.toolbar.buttons.move:action()
	-- first we need to select items
	
end
--[[

function save()
  str = cnvobj:save()
end

function load()
  cnvobj:load(str)
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
end


]]
-- Set the mainDlg user size to nil so that the show uses the Natural Size
GUI.mainDlg.size = nil
GUI.mainDlg:showxy(iup.CENTER, iup.CENTER)
GUI.mainDlg.minsize = GUI.mainDlg.rastersize	-- To limit the minimum size of the dialog to the natural size
GUI.mainDlg.maxsize = GUI.mainDlg.rastersize	-- To limit the maximum size of the dialog to the natural size
GUI.mainDlg.resize = "NO"
GUI.mainDlg.maxbox = "NO"

if iup.MainLoopLevel()==0 then
    iup.MainLoop()
    iup.Close()
end

