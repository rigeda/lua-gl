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
LTdlg:showxy(iup.RIGHT, iup.RIGHT)
-------------<<<<<<<<<<< ##### LuaTerminal End ##### >>>>>>>>>>>>>-------------


-------------<<<<<<<<< ##### lua-gl ##### >>>>>>>>>>----------------------
LGL = require("lua-gl")
-- format LGL.new(mode, gridx, gridy, width, height, gridVisibility)
cnvobj1 = LGL.new("DRAWING", 40, 40, 600, 300, false)  
cnvobj2 =  LGL.new("DRAWING", 15, 15, 600, 300, true)


dlg = iup.dialog{
    iup.vbox{
        iup.button{title = "----------------Canvas1---------------"},
        cnvobj1.cnv,
        iup.button{title = "----------------Canvas2---------------"},
        cnvobj2.cnv,
    },
    title="Phase1",
    canvas=cnv1,
    
}

dlg:showxy(iup.CENTER, iup.CENTER)

if iup.MainLoopLevel()==0 then
    iup.MainLoop()
    iup.Close()
end