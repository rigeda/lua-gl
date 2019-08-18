require("imlua")
require("imlua_process")
require("iuplua")
require("iupluaimglib")
require("iupluaim")
require("cdlua")
require("iupluacd")
require("cdluaim")


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


------------<<<<<<<<<< ####### lua-gl ######## >>>>>>>>>>>----------------
LGL = require("lua-gl")
-- format LGL.new(mode, gridx, gridy, width, height, gridVisibility)
cnvobj1 = LGL.new{grid_x = 40, grid_y = 40, width = 600, height = 300, gridVisibility = true}  
cnvobj2 = LGL.new{grid_x = 15, grid_y = 15, width = 600, height = 300, gridVisibility = true}


dlg = iup.dialog{
    iup.vbox{
        iup.label{title = "----------------Canvas1---------------"},
        cnvobj1.cnv,
        iup.label{title = "----------------Canvas2---------------"},
        cnvobj2.cnv,
    },
    title="Phase1",
  
    
}
dlg:showxy(iup.CENTER, iup.CENTER)

if iup.MainLoopLevel()==0 then
    iup.MainLoop()
    iup.Close()
end
