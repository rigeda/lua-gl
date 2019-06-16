require("imlua")
require("imlua_process")
require("iuplua")
require("iupluaimglib")
require("iupluaim")
require("cdlua")
require("iupluacd")
require("cdluaim")

LGL = require("LUAgl")

cnvobj1=LGL.new("DRAWING", 30, 30, 200, 200)  
cnvobj2=LGL.new("DRAWING", 40, 40, 500, 500)
cnvobj1:erase()
--cnv1 = cnvobj1:drawObj("ELLIPSE")

cnv2 = cnvobj2:drawObj("LINE")

dlg = iup.dialog{
    iup.vbox{
        cnv2
    },
    title="Phase1",
    canvas=cnv2,
    
}

--dlg1:show()
dlg:show()

if iup.MainLoopLevel()==0 then
    iup.MainLoop()
    iup.Close()
end

st1 = cnvobj2:save()
print("string = "..st1)


