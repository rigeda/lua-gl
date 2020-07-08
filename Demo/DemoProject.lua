
require("submodsearcher")
local LGL = require("lua-gl")
local tu = require("tableUtils")
local fd = require("iupcFocusDialog")

local sel = require("selection")
local unre = require("undoredo")
local comp = require("component")
local GUI = require("GUIStructures")
local netobj = require("netobj")

iup.ImageLibOpen()
iup.SetGlobal("IMAGESTOCKSIZE","32")

-------------<<<<<<<<<<< ##### LuaTerminal ##### >>>>>>>>>>>>>-------------
require("iuplua_scintilla")
local LT = require("LuaTerminal")
LT.USESCINTILLA = true

-- Create terminal
local LTdlg = iup.dialog{
	iup.vbox{
		LT.newTerm(_ENV,true)--,"testlog.txt")
	}; 
	title="LuaTerminal", 
	size="QUARTERxQUARTER",
	icon = GUI.images.appIcon
}
LTdlg:showxy(iup.RIGHT, iup.LEFT)
-------------<<<<<<<<<<< ##### LuaTerminal End ##### >>>>>>>>>>>>>-------------

--*************** Main (Part 1/2) ******************************

cnvobj = LGL.new{ 
	grid_x = 5, 
	grid_y = 5, 
	width = 900, 
	height = 600, 
	gridVisibility = true,
	snapGrid = true,
	showBlockingRect = true,
	--usecrouter = true,
}
GUI.mainArea:append(cnvobj.cnv)

-- To track interactive operations
-- op has the following keys"
-- mode - This can have values "LUAGL" and "DEMOAPP". 
--		LUAGL value means that the operation going on also involves some action of LuaGL library going on. So it the operation is aborted and has to be rolled back then undo for LuaGL will have to be called.
--		DEMOAPP means the operation consists of things being done purely above the LuaGL library.
-- finish - This is a function to end the operation in its current state
local op = {}	

-- Undo Redo module Initialize
unre.init(cnvobj,GUI.toolbar.buttons.undoButton,GUI.toolbar.buttons.redoButton)

-- Selection module initialize
sel.init(cnvobj,GUI)
-- Initialize component system
comp.init(cnvobj)

sel.resumeSelection()

-- Help text system on the status bar
local pushHelpText,popHelpText,clearHelpTextStack

do
	local order = {}
	local ID = 0
	local helpTextStack = {}
	function pushHelpText(text)
		if text then
			ID = ID + 1
			helpTextStack[ID] = text
			order[#order + 1] = ID
			GUI.statBarL.title = text
			return ID
		end
	end

	function popHelpText(ID)
		if not ID then
			return	-- Probably log here that popHelpText called without ID
		end
		helpTextStack[ID] = nil
		local ind = tu.inArray(order,ID)
		if ind then
			table.remove(order,ind)
			if #order == 0 then
				GUI.statBarL.title = "Ready"
			else
				GUI.statBarL.title = helpTextStack[order[#order]]
			end
			return true
		end
	end

	function clearHelpTextStack()
		helpTextStack = {}
		order = {}
		ID = 0
		GUI.statBarL.title = "Ready"
	end
end

--********************* Callbacks *************

-- Undo button action
function GUI.toolbar.buttons.undoButton:action()
	unre.doUndo()
end

-- Redo button action
function GUI.toolbar.buttons.redoButton:action()
	unre.doRedo()
end

-- TO save data to file
function GUI.toolbar.buttons.saveButton:action()
	local fileDlg = iup.filedlg{
		dialogtype = "SAVE",
		extfilter = "Demo Files|*.dia",
		title = "Select file to save drawing...",
		extdefault = "dia"
	} 
	fileDlg:popup(iup.CENTER, iup.CENTER)
	if fileDlg.status == "-1" then
		return
	end
	local lgl = cnvobj:save()
	local comps = tu.t2sr(comp.saveComponents())
	local f = io.open(fileDlg.value,"w+")
	f:write("lgl=[["..lgl.."]]\ncomps=[["..comps.."]]")
	f:close()
end

-- Turn ON/OFF snapping on the grid
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

-- Function to manage clicks for interactive functions
-- msg is the help message table
-- cb is the operation callback table
-- finish is a operation finish table
-- The function will handle n successive left clicks where n is the max of #msg-1,#cb-2
-- finish can have a max of #msg,#cb-1 number of finishers
-- If finish[1] is present it will be called if the operation finish is called before the 1st click
-- If cb[1] is present it will be called as soon as undo grouping is enabled.
-- If a cb call returns true then the mode of op entry is LUAGL otherwise it remains unchanged (it starts off with DEMOAPP). If a cb call returns "STOP" then manageClicks ends immediately (after doing its cleanup) without adding a UNDOADDED hook or waiting for any more clicks if those remain
-- All the operations that happen with Manageclicks are grouped into 1 group of Undo operation
-- The timeline is as follows:
--[[
	Callback[1] + Display Message [1] ----> Left Click [1] ----> Display Message [2] + callback[2] ----> .....
	(finish[1] is the finish function)			                 (finish[2] is the finish function)
												
												
	........... Left Click [i-1] ----> Display Message [i] + callback[i] + Setup operation end hook in UNDOADDED ----> .....
	                                  (finish[i] is the finish function)
									
	........... Cleanup + callback[i+1]
									
	NOTE: in the above time line #cb = i+1 and #msg = i so max(#msg-1,#cb-2) = i-1
									
	EXAMPLE 1:
	For Rectangle drawing it needs 2 clicks so the function is called for 1 click and 2 messages so the timeline looks as:
	Display Message [1] ----> Left Click [1] ----> Display Message [2] + callback[1] + Setup operation end hook
	                                                (finish[1] is the finish function)
													
	EXAMPLE 2: 
	For Arc drawing it needs 4 clicks so the function is called for 3 clicks and 4 messages. The timeline looks as:
	
	Display Message [1] + dummy cb[1] ----> Left Click [1] ----> Display Message [2] + callback[2] ----> Left Click [2] ----
			(dummy finish[1])										        (finish [2])
	----> Display Message [3] ----> Left Click [3] ----> Display Message [4] + Setup operation end hook
	        (finish [3])												(finish[4])
]]
local function manageClicks(msg,cb,finish)
	local hook,helpID,opptr
	local index = 1
	
	-- Function for operation end
	local function cleanup()
		popHelpText(helpID)
		cnvobj:removeHook(hook)
		sel.resumeSelection()
		if cb[index] then
			cb[index]()
		end
		unre.endGroup()
		table.remove(op,opptr)
	end
	local function doCallback(x,y,status)
		op[opptr].finish = function()
			if finish[index] then
				finish[index]()
			end
			cleanup()
		end
		local cbret
		if cb[index] then
			cbret = cb[index](x,y,status)
			if cbret and cbret ~= "STOP" then
				op[opptr].mode = "LUAGL"
			end
		end
		helpID = pushHelpText(msg[index])
		index = index + 1
		if index > #msg and index > #cb - 1 then
			cnvobj:removeHook(hook)
			-- If the last callback returned STOP i.e. the last callback did something which did not involve a Lua-GL operation then we cannot wait for the UNDOADDED hook to be triggerred so just call resumeSel immediately
			if cbret == "STOP" then
				cleanup()
			else
				hook = cnvobj:addHook("UNDOADDED",cleanup,"To cleanup manageClicks")
			end
		end
	end
	local function getClick(button,pressed,x,y,status)
		if button == cnvobj.MOUSE.BUTTON1 and pressed == 1 then
			doCallback(x,y,status)
		end
	end
	sel.pauseSelection()
	unre.beginGroup()
	-- Add the hook
	hook = cnvobj:addHook("MOUSECLICKPOST",getClick,"To get clicks for manageClicks")
	-- Setup the operation
	opptr = #op + 1
	op[opptr] = {
		mode = "DEMOAPP",
	}
	doCallback()
end

-- To load data from a file
--[[ Steps:
1. The file selection dialog is displayed
2. Load the string from the file, validate it and call LuaGL load function for interactive placement
3. After 
]]
function GUI.toolbar.buttons.loadButton:action()
	local comps,stat,msg,IDMAP
	local fileDlg = iup.filedlg{
		dialogtype = "OPEN",
		extfilter = "Demo Files|*.dia",
		title = "Select file to load drawing...",
		extdefault = "dia"
	} 
	fileDlg:popup(iup.CENTER, iup.CENTER)
	if fileDlg.status == "-1" then
		return
	end
	local f = io.open(fileDlg.value,"r")
	local s = f:read("*a")
	f:close()
	local env = {}
	local func = load(s,nil,nil,env)
	stat,msg = pcall(func)
	
	if not stat then
		print("Error loading file...")
		local dlg = iup.messagedlg{dialogtype="ERROR",title = "Error loading file...",value = "File cannot be loaded.\n"..msg}
		dlg:popup()
	else
		local lgl = env.lgl
		local cont = true
		if env.comps then
			comps = tu.s2tr(env.comps)
			if not comps then
				local dlg = iup.messagedlg{dialogtype="ERROR",title = "Error loading file...",value = "Components cannot be loaded.\n"..msg}
				dlg:popup()
				resumeSel()
				cont = false
			end
		end
		if cont then
			local function cb1()
				stat,msg,IDMAP = cnvobj:load(lgl,nil,nil,nil,nil,true)
				--local stat,msg = cnvobj:load(s,450,300)	-- Non interactive load at the given coordinate
				if not stat then
					print("Error loading file: ",msg)
					local dlg = iup.messagedlg{dialogtype="ERROR",title = "Error loading file...",value = "File cannot be loaded.\n"..msg}
					dlg:popup()
					return "STOP"
				end
				return true	-- To set op mode to LUAGL
			end
			local function cb2()
				if comps then
					local cids = comp.loadComponents(comps,msg,IDMAP)
				end				
			end
			local function finish()
				cnvobj.op[stat].finish()	-- stat is the cnvobj.op index returned by load
			end
			manageClicks({
					"Click to place the diagram"
				},{cb1,cb2},{finish}
			)	
		end
	end
end

-- To load data from a file
function GUI.toolbar.buttons.addComponentButton:action()
	local fileDlg,stat,msg,IDMAP,lgl
	fileDlg = iup.filedlg{
		dialogtype = "OPEN",
		extfilter = "Demo Files|*.dia",
		title = "Select file to load linked component...",
		extdefault = "dia"
	} 
	fileDlg:popup(iup.CENTER, iup.CENTER)
	if fileDlg.status == "-1" then
		return
	end
	local f = io.open(fileDlg.value,"r")
	local s = f:read("*a")
	f:close()
	local env = {}
	local func = load(s,nil,nil,env)
	stat,msg = pcall(func)
	
	if not stat then
		print("Error loading file...")
		local dlg = iup.messagedlg{dialogtype="ERROR",title = "Error loading file...",value = "File cannot be loaded.\n"..msg}
		dlg:popup()
	else
		lgl = env.lgl
		-- Ignore any comps inside comps since nested comps provide no advantage just more complexity
		local function cb1()
			stat,msg,IDMAP = cnvobj:load(lgl,nil,nil,nil,nil,true)
			--local stat,msg = cnvobj:load(s,450,300)	-- Non interactive load at the given coordinate
			if not stat then
				print("Error loading file: ",msg)
				local dlg = iup.messagedlg{dialogtype="ERROR",title = "Error loading file...",value = "File cannot be loaded.\n"..msg}
				dlg:popup()
				return "STOP"
			end
			return true	-- To set op mode to LUAGL
		end
		local function cb2()
			-- Add the items in the components table
			if IDMAP then
				local file = fileDlg.value
				local c = comp.newComponent(file,lgl,msg,IDMAP)	-- msg contains the list of items in load
																-- IDMAP contains the ID mapping from file data to drawn data
			end			
		end
		local function finish()
			cnvobj.op[stat].finish()	-- stat is the cnvobj.op index returned by load
		end
		manageClicks({
				"Click to place component"
			},{cb1,cb2},{finish}
		)
	end
end

-- Draw line object
function GUI.toolbar.buttons.lineButton:action()
	-- Non interactive line draw
	--[[cnvobj:drawObj("LINE",{
			{x=10,y=10},
			{x=100,y=100}
		})]]
	--cnvobj:refresh()
	local opptr
	local function cb()
		opptr = cnvobj:drawObj("LINE")	-- interactive line drawing
		return true	-- To set op mode to LUAGL
	end
	local function finish()
		cnvobj.op[opptr].finish()
	end
	local function dummy() end
	manageClicks({			-- 1 click and then operation end
			"Click starting point for line",
			"Click ending point for line"
		},{dummy,cb},{dummy,finish}
	)
end

-- Draw rectangle object
function GUI.toolbar.buttons.rectButton:action()
	local opptr
	local function cb()
		opptr = cnvobj:drawObj("RECT")	-- interactive rectangle drawing
		return true	-- To set op mode to LUAGL
	end
	local function finish()
		cnvobj.op[opptr].finish()
	end
	local function dummy() end
	manageClicks({			-- 1 click and then operation end
			"Click starting point for rectangle",
			"Click ending point for rectangle"
		},{dummy,cb},{dummy,finish}
	)
end

-- Draw filled rectangle object
function GUI.toolbar.buttons.fRectButton:action()
	local opptr
	local function cb()
		opptr = cnvobj:drawObj("FILLEDRECT")	-- interactive filled rectangle drawing
		return true	-- To set op mode to LUAGL		
	end
	local function finish()
		cnvobj.op[opptr].finish()
	end
	local function dummy() end
	manageClicks({			-- 1 click and then operation end
			"Click starting point for rectangle",
			"Click ending point for rectangle"
		},{dummy,cb},{dummy,finish}
	)
end

-- Draw blocking rectangle object
function GUI.toolbar.buttons.bRectButton:action()
	local opptr
	local function cb()
		opptr = cnvobj:drawObj("BLOCKINGRECT")	-- interactive blocking rectangle drawing
		return true	-- To set op mode to LUAGL
	end
	local function finish()
		cnvobj.op[opptr].finish()
	end
	local function dummy() end
	manageClicks({			-- 1 click and then operation end
			"Click starting point for rectangle",
			"Click ending point for rectangle"
		},{dummy,cb},{dummy,finish}
	)
end

-- Draw ellipse object
function GUI.toolbar.buttons.elliButton:action()
	local opptr
	local function cb()
		opptr = cnvobj:drawObj("ELLIPSE")	-- interactive ellipse drawing
		return true	-- To set op mode to LUAGL
	end
	local function finish()
		cnvobj.op[opptr].finish()
	end
	local function dummy() end
	manageClicks({			-- 1 click and then operation end
			"Click starting point for ellipse",
			"Click ending point for ellipse"
		},{dummy,cb},{dummy,finish}
	)
end

-- Draw filled ellipse object
function GUI.toolbar.buttons.fElliButton:action()
	local opptr
	local function cb()
		opptr = cnvobj:drawObj("FILLEDELLIPSE")	-- interactive filled ellipse drawing
		return true	-- To set op mode to LUAGL
	end
	local function finish()
		cnvobj.op[opptr].finish()
	end
	local function dummy() end
	manageClicks({			-- 1 click and then operation end
			"Click starting point for ellipse",
			"Click ending point for ellipse"
		},{dummy,cb},{dummy,finish}
	)
end

-- Draw Arc
function GUI.toolbar.buttons.arcButton:action()
	local opptr
	local function cb()
		opptr = cnvobj:drawObj("ARC")
		return true	-- To set op mode to LUAGL
	end
	local function finish()
		cnvobj.op[opptr].finish()
	end
	local function dummy() end
	manageClicks({		-- 3 clicks and then operation end
			"Click starting point for ellipse",
			"Click ending point for ellipse",
			"Click to mark starting angle of the arc",
			"Click to mark ending angle of the arc"
		},{dummy,cb},{dummy,finish,finish,finish}
	)
end

-- Draw Sector
function GUI.toolbar.buttons.filledarcButton:action()
	local opptr
	local function cb()
		opptr = cnvobj:drawObj("FILLEDARC")
		return true	-- To set op mode to LUAGL
	end
	local function finish()
		cnvobj.op[opptr].finish()
	end
	local function dummy() end
	manageClicks({		-- 3 clicks and then operation end
			"Click starting point for ellipse",
			"Click ending point for ellipse",
			"Click to mark starting angle of the arc",
			"Click to mark ending angle of the arc"
		},{dummy,cb},{dummy,finish,finish,finish}
	)
end

-- Draw text object
function GUI.toolbar.buttons.textButton:action()
	local c = cnvobj.viewOptions.constants
	local align = {
		north = c.NORTH,
		south = c.SOUTH, 
		east = c.EAST,
		west = c.WEST,
		["north east"] = c.NORTH_EAST, 
		["north west"] = c.NORTH_WEST, 
		["south east"] = c.SOUTH_EAST, 
		["south west"] = c.SOUTH_WEST, 
		["center"] = c.CENTER, 
		["base left"] = c.BASE_LEFT, 
		["base center"] = c.BASE_CENTER, 
		["base right"] = c.BASE_RIGHT
	}
	local alignList = {}
	local asi
	for k,v in pairs(align) do
		alignList[#alignList + 1] = k
		if k == "base right" then
			asi = #alignList - 1
		end
	end
	local ret, text, font, color,as,ori = iup.GetParam("Enter Text information",nil,
		"Text: %m\n"..
		"Font: %n\n"..
		"Color: %c{Color Tip}\n"..
		"Alignment: %l|"..table.concat(alignList,"|").."|\n"..
		"Orientation: %a[0,360]\n","","Courier, 12","0 0 0",asi,0)
	if ret then
		local opptrlgl
		local function cb()
			-- Create a representation of the text at the location of the mouse pointer and then start its move
			-- Set refX,refY as the mouse coordinate on the canvas
			local refX,refY = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
			local o = cnvobj:drawObj("TEXT",{{x=refX,y=refY}},{text=text})
			-- If the formatting is not the same as the default then add a formatting attribute for the text
			if color ~= "0 0 0" or font ~= "Courier, 12" or as ~= "base right" or ori ~= 0 then
				local typeface,style,size = font:match("(.-),([%a%s]*)%s*([+-]?%d+)$")
				size = cnvobj:fontPt2Pixel(tonumber(size))
				style = "" and c.PLAIN or style
				local clr = {}
				clr[1],clr[2],clr[3] = color:match("(%d%d*)%s%s*(%d%d*)%s%s*(%d%d*)")
				clr[1] = tonumber(clr[1])
				clr[2] = tonumber(clr[2])
				clr[3] = tonumber(clr[3])
				-- Also add the attribute to the object
				o.vattr = {color = clr,typeface = typeface, style = style,size=size,align=align[alignList[as+1]],orient = ori}
				cnvobj.attributes.visualAttr[o] = {
					visualAttr = cnvobj.getTextAttrFunc(o.vattr),
					vAttr = -1	-- Unique attribute not stored in the bank
				}
			end
			opptrlgl = cnvobj:moveObj({o})
			return true	-- Set operation as LUAGL
		end
		local function finish()
			cnvobj.op[opptrlgl].finish()
		end
		manageClicks({		-- No clicks just setup operation end after 1st call back
				"Click to place text"
			},{cb},{finish}
		)
	end		-- if ret ends here
end

function GUI.toolbar.buttons.printButton:action()
	local ret, mL, mR, mU,mD = iup.GetParam("Enter Print Information",nil,
	"Margin Left (mm): %i\n"..
	"Margin Right (mm): %i\n"..
	"Margin Up (mm): %i\n"..
	"Margin Down (mm): %i\n",10,10,10,10)
	if ret then
		cnvobj:doprint("Lua-GL diagram",mL,mR,mU,mD)
	end
end

-- To run code to debug
function GUI.toolbar.buttons.checkButton:action()
	local f = io.open("../test/schematic.dia")
	local s = f:read("*a")
	f:close()
	cnvobj:load(s)
end

-- Start Copy operation
function GUI.toolbar.buttons.copyButton:action()
	local hook, helpID, opptrlgl, opptr, copyStr
	local function cb()
		local x,y = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
		opptrlgl = cnvobj:load(copyStr,nil,nil,x,y,true)
		return true	-- To set op mode to LUAGL
	end
	local function finish()
		cnvobj.op[opptrlgl].finish()
	end
	local function dummy() end
	local function copycb()
		-- Remove the callback from the selection 
		sel.pauseSelection()
		sel.resumeSelection()
		popHelpText(helpID)
		if opptr then
			table.remove(op,opptr)	-- manageClicks manages its own operation table
		end
		-- Get the copy of the selected items
		sel.turnOFFVisuals()	-- Turn off the selection visuals so that when Lua-GL copies those elements they selection visual attributes do not become the default visual attributes of the copied items
		local copy = cnvobj:copy((sel.selListCopy()))
		sel.turnONVisuals()
		copyStr = tu.t2sr(copy)
		manageClicks({		-- 1 click then setup operation end
				"Click to copy",
				"Click to place"
			},{dummy,cb},{dummy,finish}
		)
	end
	-- First get items to copy
	if #sel.selListCopy() == 0 then
		-- No items so stop the selection and resume it with a callback which is called as soon as a selection is made.
		sel.pauseSelection()
		helpID = pushHelpText("Select items to copy")
		-- Setup operation entry
		opptr = #op + 1
		op[opptr] = {
			mode = "DEMOAPP",
			finish = function()
				popHelpText(helpID)
				table.remove(op,opptr)
				-- Remove the callback from the selection 
				sel.pauseSelection()
				sel.resumeSelection()
			end
		}
		sel.resumeSelection(copycb)
	else
		copycb()
	end
end

-- Start Move operation
function GUI.toolbar.buttons.moveButton:action()
	local hook, helpID, opptrlgl, opptr
	local function cb()
		opptrlgl = cnvobj:move(sel.selListCopy())
		return true	-- To set op mode to LUAGL
	end
	local function finish()
		cnvobj.op[opptrlgl].finish()
	end
	local function dummy() end
	local function movecb()
		-- Remove the callback from the selection 
		sel.pauseSelection()
		sel.resumeSelection()
		popHelpText(helpID)
		if opptr then
			table.remove(op,opptr)	-- manageClicks manages its own operation table
		end
		manageClicks({		-- 1 click then setup operation end
				"Click to start move",
				"Click to place"
			},{dummy,cb},{dummy,finish}
		)
	end
	-- First get items to move
	if #sel.selListCopy() == 0 then
		-- No items so stop the selection and resume it with a callback which is called as soon as a selection is made.
		sel.pauseSelection()
		helpID = pushHelpText("Select items to move")
		-- Setup operation entry
		opptr = #op + 1
		op[opptr] = {
			mode = "DEMOAPP",
			finish = function()
				popHelpText(helpID)
				table.remove(op,opptr)
				-- Remove the callback from the selection 
				sel.pauseSelection()
				sel.resumeSelection()
			end
		}
		sel.resumeSelection(movecb)
	else
		movecb()
	end
end

-- Drag an object to associate with a connector segment
function GUI.toolbar.buttons.attachObj:action()
	local hook, helpID, opptrlgl, opptr, msgs,callBacks,finishers,obj
	local function finish()
		cnvobj.op[opptrlgl].finish()
	end
	local function cb2(x,y,status)
		-- Check if there is a connector here
		local conn,segs = cnvobj:getConnFromXY(x,y)
		if #segs == 0 then
			-- Need to keep clicking so add callback and msg to the tables passed to manageClicks
			callBacks[#callBacks + 1] = cb2
			finishers[#finishers + 1] = finish
			msgs[#msgs + 1] = "Click connector to attach"
			opptrlgl = cnvobj:drag({obj})
			return true	-- To set op mode to LUAGL
		else
			local s = {
				conn = segs[1].conn,
				seg = segs[1].seg[1]
			}
			local function attach()
				print("Attach object "..obj.id.." to connector "..cnvobj.drawn.conn[s.conn].id.." segment "..s.seg)
				-- Attach the obj to the segment in s
				netobj.newNetobj(obj,s,x,y)
			end
			if #segs > 1 or #segs[1].seg > 1 then
				-- We need to give the option to select which segment
				local list = iup.flatlist{bgcolor=iup.GetGlobal("DLGBGCOLOR"),visiblelines = #segs,visiblecolumns=15}
				function list:k_any(c)
					return iup.CONTINUE
				end
				local doneButton = iup.flatbutton{title = "DONE",expand="HORIZONTAL"}
				local seldlg = iup.dialog{iup.vbox{list,doneButton};border="NO",resize="NO",minbox="NO",menubox="NO"}
				function seldlg:k_any(c)
					if c == iup.K_ESC then
						-- Hide the dialog
						seldlg:hide()
						unre.doUndo(true)	-- Skip Redo
						-- Undo the entire operation
						return iup.IGNORE
					end
					return iup.IGNORE
				end
				local li = 0
				for j = 1,#segs do
					for k = 1,#segs[j].seg do
						li = li + 1
						list[tostring(li)] = "Connector: "..segs[j].conn.." Segment: "..segs[j].seg[k]
					end
				end
				local done
				local function getSelected()
					if not done then
						done = true	-- To make it run only once
					else
						return
					end
					local val = list.value
					val = tonumber(val)
					if val and val ~= 0 then
						-- This is a connector segment
						local c = val
						local ci = 0
						for k = 1,#segs do
							if #segs[k].seg+ci >= c then
								s = {
									conn = segs[k].conn,
									seg = segs[k].seg[c-ci]
								}
								break
							else
								ci = ci + #segs[k].seg
							end
						end		-- for k = 1,#s do ends
					else
						unre.doUndo(true)	-- Skip Redo
					end		-- if val ~= 0 then ends
					attach()
				end		-- local function getSelected() ends
				local gx,gy = iup.GetGlobal("CURSORPOS"):match("^(-?%d%d*)x(-?%d%d*)$")
				gx,gy = tonumber(gx),tonumber(gy)
				--print("Showing selection dialog at "..gx..","..gy)
				function doneButton:flat_action()
					seldlg:hide()
					getSelected()
				end
				fd.popup(seldlg,gx,gy,getSelected)
			else
				attach()
			end
			return "STOP"	-- So that manageClicks ends
		end
	end		-- local function cb2 ends here
	local function cb1(x,y,status)
		opptrlgl = cnvobj:drag({obj})
		return true	-- To set op mode to LUAGL		
	end		-- local function cb1 ends here
	local function dragcb()
		local sList,objs,conns = sel.selListCopy()
		if #objs == 1 and #conns == 0 then
			obj = objs[1]
			popHelpText(helpID)
			if opptr then
				table.remove(op,opptr)	-- manageClicks manages its own operation table
			end
			msgs = {
				"Click to set anchor point and drag",
				"Click connector to attach"
			}
			callBacks = {cb1,cb2}
			finishers = {finish,finish}
			manageClicks(msgs,callBacks,finishers)
		else
			sel.deselectAll()
			cnvobj:refresh()
		end
	end
	-- First get the object to drag and attach
	local sList,objs,conns = sel.selListCopy()
	if not (#objs == 1 and #conns == 0)then
		sel.deselectAll()
		cnvobj:refresh()
		-- Number of items not 1 so stop the selection and resume it with a callback which is called as soon as a selection is made.
		sel.pauseSelection()
		helpID = pushHelpText("Select object to attach")
		-- Setup operation entry
		opptr = #op + 1
		op[opptr] = {
			mode = "DEMOAPP",
			finish = function()
				popHelpText(helpID)
				table.remove(op,opptr)
				-- Remove the callback from the selection 
				sel.pauseSelection()
				sel.resumeSelection()
			end
		}
		sel.resumeSelection(dragcb)
	else
		dragcb()
	end	
end

-- Start Drag operation
function GUI.toolbar.buttons.dragButton:action()
	local hook, helpID, opptrlgl, opptr
	local function cb()
		opptrlgl = cnvobj:drag(sel.selListCopy())
		return true	-- To set op mode to LUAGL
	end
	local function finish()
		cnvobj.op[opptrlgl].finish()
	end
	local function dummy() end
	local function dragcb()
		-- Remove the callback from the selection 
		sel.pauseSelection()
		sel.resumeSelection()
		popHelpText(helpID)
		if opptr then
			table.remove(op,opptr)	-- manageClicks manages its own operation table
		end
		manageClicks({		-- 1 click then setup operation end
				"Click to start drag",
				"Click to place"
			},{dummy,cb},{dummy,finish}
		)
	end
	-- First get items to drag
	if #sel.selListCopy() == 0 then
		-- No items so stop the selection and resume it with a callback which is called as soon as a selection is made.
		sel.pauseSelection()
		helpID = pushHelpText("Select items to drag")
		-- Setup operation entry
		opptr = #op + 1
		op[opptr] = {
			mode = "DEMOAPP",
			finish = function()
				popHelpText(helpID)
				table.remove(op,opptr)
				-- Remove the callback from the selection 
				sel.pauseSelection()
				sel.resumeSelection()
			end
		}
		sel.resumeSelection(dragcb)
	else
		dragcb()
	end
end

function GUI.toolbar.buttons.delButton:action()
	-- Function to delete
	local helpID, opptr
	local function delcb()
		local _,objs,conns = sel.selListCopy() 
		sel.pauseSelection()
		popHelpText(helpID)
		unre.beginGroup()		
		for i = 1,#objs do
			cnvobj:removeObj(objs[i])
		end
		cnvobj:removeSegments(conns)
		comp.updateComponents()
		unre.endGroup()
		sel.resumeSelection()
		cnvobj:refresh()
	end
	-- First get items to delete
	local _,objs,conns = sel.selListCopy() 
	if #objs == 0 and #conns == 0 then
		-- No items so stop the selection and resume it with a callback which is called as soon as a selection is made.
		sel.pauseSelection()
		helpID = pushHelpText("Select items to delete")
		-- Setup operation entry
		opptr = #op + 1
		op[opptr] = {
			mode = "DEMOAPP",
			finish = function()
				popHelpText(helpID)
				table.remove(op,opptr)
				-- Remove the callback from the selection 
				sel.pauseSelection()
				sel.resumeSelection()
			end
		}
		sel.resumeSelection(delcb)
	else
		delcb()
	end	
end

function GUI.toolbar.buttons.groupButton:action()
	-- Function to group objects together
	local helpID, opptr
	local function groupcb()
		local _,objs = sel.selListCopy() 
		if #objs < 2 then
			return
		end
		sel.pauseSelection()
		popHelpText(helpID)
		cnvobj:groupObjects(objs)
		sel.resumeSelection()
	end
	-- First get objects to group
	local _,objs = sel.selListCopy() 
	if #objs < 2 then
		-- No items so stop the selection and resume it with a callback which is called as soon as a selection is made.
		sel.pauseSelection()
		helpID = pushHelpText("Select objects to group")
		-- Setup operation entry
		opptr = #op + 1
		op[opptr] = {
			mode = "DEMOAPP",
			finish = function()
				popHelpText(helpID)
				table.remove(op,opptr)
				-- Remove the callback from the selection 
				sel.pauseSelection()
				sel.resumeSelection()
			end
		}
		sel.resumeSelection(groupcb)
	else
		groupcb()
	end	
end

do
	local MODE

	function GUI.toolbar.buttons.portButton:action()
		-- Check if port mode already on then do nothing
		if MODE == "ADDPORT" then
			return
		end
		local opptrlgl
		local function cb()
			-- Create a representation of the port at the location of the mouse pointer and then start its move
			-- Create a MOUSECLICKPOST hook to check whether the move ended on a object. If not continue the move
			-- Set refX,refY as the mouse coordinate on the canvas transformed to the database coordinates snapped
			local x,y = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
			cnvobj.grid.snapGrid = false
			local o = cnvobj:drawObj("FILLEDRECT",{{x=x-3,y=y-3},{x=x+3,y=y+3}})
			cnvobj.grid.snapGrid = true
			cnvobj:addPort(x,y,o.id)
			-- Now we need to put the mouse exactly on the center of the filled rectangle
			-- Set the cursor position to be right on the center of the object
			local rx,ry = cnvobj:setMouseOnCanvas(cnvobj:dCoor2sCoor(x,y))
			-- Start the interactive move
			MODE = "ADDPORT"
			opptrlgl = cnvobj:moveObj({o})
			return true
		end
		local function finish()
			cnvobj.op[opptrlgl].finish()
			MODE = nil
		end
		local function dummy() end
		manageClicks({		-- No clicks just setup operation end after 1st call back
				"Click to place port"
			},{cb,function() MODE=nil end},{finish}
		)
	end
end

function GUI.toolbar.buttons.refreshButton:action()
	-- First refresh all the components from their files
	-- We are just going to refresh the objects in the component items since connectors may already be used and if they are at the same place they will just be overlapped and merged when we reload the component from the file
	local coData = {}	-- To store data for all components to load
	local errs = {}
	local function getFileData(file)
		if not coData[file] then
			local f = io.open(file,"r")
			if not f then
				if not errs[file] then
					errs[file] = "Cannot open file."
				end
				return false
			else
				local fData = f:read("*a")
				f:close()
				local env = {}
				local func = load(fData,nil,nil,env)
				local stat,msg = pcall(func)
				
				if not stat then
					if not errs[file] then
						errs[file] = "Error loading file data: "..msg
					end
				else
					coData[file] = env.lgl
				end
				return true
			end
		end
		return true
	end
	local function deleteComponent(component)
		local items = component.items
		local id = component.id
		for i = 1,#items do
			if items[i].type == "object" and items[i].obj then
				cnvobj:removeObj(items[i].obj)
			end			
		end
		comp.deleteComponent(id)
		return true
	end
	unre.beginGroup()
	local compDone = {}
	-- Store the previous components in prevCo
	local prevCo = {}
	for component in comp.comps() do
		prevCo[#prevCo + 1] = component
		if not compDone[component.id] then
			-- Read the file of the component
			local file = component.file
			if getFileData(file) then
				local dData = tu.s2tr(coData[file])
				local stat,msg = cnvobj.checkData(dData)
				if not stat then
					errs[#errs + 1] = {file=file,msg = msg}
				else
					-- Get the placement point
					local idmap = component.IDMAP
					local items = component.items
					for i = 1,#items do
						if items[i].type == "object" and items[i].obj then
							local id = items[i].obj.id
							local fid = idmap[id]
							local x = items[i].obj.x[1]
							local y = items[i].obj.y[1]
							local xa,ya = items[i].xa,items[i].ya
							-- Delete the component
							deleteComponent(component)
							-- Load the file data at the right spot
							stat,msg,idmap = cnvobj:load(coData[file],x,y,xa,ya)
							-- load the component into components database
							local c = comp.newComponent(file,coData[file],msg,idmap)
							compDone[c.id] = true
							break
						end		-- if items[i].type == "object" and items[i].obj then ends
					end		-- for i = 1,#items do ends			
				end		-- if not stat then ends
			end		-- if getFileData(file) then ends
		end		-- if not compDone[component.id] then ends
	end		-- for component in comp.comps() do ends
	unre.endGroup()
	-- Now refresh the canvas
	cnvobj:refresh()
end

do 
	local mode = 0

	function GUI.toolbar.buttons.connButton:action()
		local router1,router2
		local js1,js2
		if mode == 0 then
			router1 = cnvobj.options.router[0]
			router2 = router1
			js1 = 2
			js2 = 2
		elseif mode == 1 then
			router1 = cnvobj.options.router[1]
			router2 = router1
			js1 = 0
			js2 = 0
		elseif mode == 2 then
			router1 = cnvobj.options.router[2]
			router2 = router1
			js1 = 0
			js2 = 0
		else
			router1 = cnvobj.options.router[9]
			router2 = router1
			js1 = 1
			js2 = 1
		end
		local opptr
		local function cb()
			opptr = cnvobj:drawConnector(nil,router1,js1,router2,js2)
			return true	-- To set op mode to LUAGL
		end
		local function finish()
			cnvobj.op[opptr].finish()
		end
		local function dummy() end
		manageClicks({		-- 1 click then operation end
				"Click starting point for connector",
				"Click ending point/waypoint for connector"
			},{dummy,cb},{dummy,finish}
		)
	end
	function GUI.toolbar.buttons.connModeList:action(text,item,state)
		mode = item-1
		if item == 4 then
			mode = 9
		end
	end 
end

function GUI.toolbar.buttons.newButton:action()
	cnvobj:erase()
	sel.deselectAll()
	clearHelpTextStack()
	sel.pauseSelection()
	-- Initialize undo/redo system
	unre.init(cnvobj,GUI.toolbar.buttons.undoButton,GUI.toolbar.buttons.redoButton)
	-- Initialize selection system
	sel.init(cnvobj,GUI)
	-- Initialize component system
	comp.init(cnvobj)
	sel.resumeSelection()
	cnvobj:refresh()
end

-- 90 degree rotate
local function rotateFlip(para)
	local op = cnvobj.op[#cnvobj.op]
	local mode = op.mode
	local refX,refY = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
	if mode == "DRAG" or  mode == "DRAGSEG" or mode == "DRAGOBJ" then
		-- Compile item list
		local items = {}
		if op.objList then
			for i = 1,#op.objList do
				items[#items + 1] = op.objList[i]
			end
		end
		if op.connList then
			for i = 1,#op.connList do
				items[#items + 1] = op.connList[i]
			end
		end
		-- Do the rotation 
		cnvobj:rotateFlipItems(items,refX,refY,para)
		local prx,pry = cnvobj:snap(op.ref.x,op.ref.y)
		-- Rotate/Flip the reference coordinate for the drag operation
		op.coor1.x,op.coor1.y = cnvobj:rotateFlip(op.coor1.x,op.coor1.y,prx,pry,para)
		local x,y = cnvobj:getMouseOnCanvas()
		op.motion(cnvobj.cnv,x,y)
		cnvobj:refresh()
	elseif mode == "MOVE" or mode == "MOVESEG" or mode == "MOVEOBJ" then
		-- Compile item list
		local items = {}
		if op.objList then
			for i = 1,#op.objList do
				items[#items + 1] = op.objList[i]
			end
		end
		if op.connList then
			for i = 1,#op.connList do
				local conn = op.connList[i]
				for j = 1,#conn.segments do
					items[#items + 1] = {
						conn = conn,
						seg = j
					}
				end
			end
		end
		-- Do the rotation 
		cnvobj:rotateFlipItems(items,refX,refY,para)
		local prx,pry = cnvobj:snap(op.ref.x,op.ref.y)
		op.coor1.x,op.coor1.y = cnvobj:rotateFlip(op.coor1.x,op.coor1.y,prx,pry,para)
		local x,y = cnvobj:getMouseOnCanvas()
		op.motion(cnvobj.cnv,x,y)
		cnvobj:refresh()
	else
		-- Get list of items
		local helpID, opptr
		local function rotateItems()
			local items = sel.selListCopy()
			local refX,refY = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
			-- get all group memebers for the objects selected
			local objList = {}
			local segList = {}
			for i = 1,#items do
				if items[i].id then
					-- This must be an object
					objList[#objList + 1] = items[i]
				else
					-- This must be a segment specification
					segList[#segList + 1] = items[i]
				end
			end			
			objList = cnvobj.populateGroupMembers(objList)
			items = objList
			for i = 1,#segList do
				items[#items + 1] = segList[i]
			end
			cnvobj:rotateFlipItems(items,refX,refY,para)
			cnvobj:refresh()
			return true	-- To set op mode to LUAGL
		end
		local function dummy() end
		local function startRotation()
			-- Remove the callback from the selection 
			sel.pauseSelection()
			sel.resumeSelection()
			popHelpText(helpID)
			if opptr then
				table.remove(op,opptr)
			end
			manageClicks({
					"Click at coordinate about which to rotate/flip"
				},{dummy,rotateItems},{dummy,dummy}
			)
		end
		-- first we need to select items
		if #sel.selListCopy() == 0 then
			-- No items so stop the selection and resume it with a callback which is called as soon as a selection is made.
			sel.pauseSelection()
			helpID = pushHelpText("Select items to rotate/flip")
			-- Setup operation entry
			opptr = #op + 1
			op[opptr] = {
				mode = "DEMOAPP",
				finish = function()
					popHelpText(helpID)
					table.remove(op,opptr)
					-- Remove the callback from the selection 
					sel.pauseSelection()
					sel.resumeSelection()
				end
			}
			sel.resumeSelection(startRotation)
		else
			startRotation()
		end	
	end
end

-- Key press handler
function GUI.mainDlg:k_any(c)
	--print("Key pressed MAIN DIALOG")
	if c < 255 then
		print("Pressed "..string.char(c))
		local map = {
			r = 90,
			e = 180,
			w = 270,
			h = "h",
			v = "v"
		}
		if map[string.char(c)] then
			rotateFlip(map[string.char(c)])
			return iup.IGNORE 
		end
	end
	if c == iup.K_LEFT then
		-- Change the viewport and refresh
		-- Move the viewport 10% to the left
		local vp = cnvobj.viewPort
		local dx = vp.xmax - vp.xmin + 1
		local shift = math.floor(dx/10)
		vp.xmin = vp.xmin - shift
		vp.xmax = vp.xmax - shift
		cnvobj:refresh()
		return iup.IGNORE 
	elseif c == iup.K_RIGHT then
		-- Change the viewport and refresh
		-- Move the viewport 10% to the right
		local vp = cnvobj.viewPort
		local dx = vp.xmax - vp.xmin + 1
		local shift = math.floor(dx/10)
		vp.xmin = vp.xmin + shift
		vp.xmax = vp.xmax + shift
		cnvobj:refresh()
		return iup.IGNORE 
	elseif c == iup.K_DOWN then
		-- Change the viewport and refresh
		-- Move the viewport 10% to the down
		local vp = cnvobj.viewPort
		local xm,xmax,ym,ymax,zoom = cnvobj:viewportPara(vp)
		
		local dy = ymax - ym + 1
		local shift = math.floor(dy/10)
		vp.ymin = vp.ymin - shift
		cnvobj:refresh()	
		return iup.IGNORE 
	elseif c == iup.K_UP then
		-- Change the viewport and refresh
		-- Move the viewport 10% to the up
		local vp = cnvobj.viewPort
		local xm,xmax,ym,ymax,zoom = cnvobj:viewportPara(vp)
		
		local dy = ymax - ym + 1
		local shift = math.floor(dy/10)
		vp.ymin = vp.ymin + shift
		cnvobj:refresh()				
		return iup.IGNORE 
	elseif c == iup.K_bracketleft then
		-- Zoom out with the center remaining in the center
		local zoomFac = 1.5
		local vp = cnvobj.viewPort
		local xm,xmax,ym,ymax,zoom = cnvobj:viewportPara(vp)
		local dx = math.floor(zoom/zoomFac*cnvobj.width)
		dx = math.floor((dx-(xmax-xm+1))/2)
		local dy = math.floor(zoom/zoomFac*cnvobj.height)
		dy = math.floor((dy-(ymax-ym+1))/2)
		vp.ymin = vp.ymin-dy
		vp.xmax = vp.xmax+dx
		vp.xmin = vp.xmin-dx
		
		cnvobj:refresh()				
		return iup.IGNORE 
	elseif c == iup.K_bracketright then
		-- Zoom in with the center remaining in the center
		local zoomFac = 1.5
		local vp = cnvobj.viewPort
		local xm,xmax,ym,ymax,zoom = cnvobj:viewportPara(vp)
		local dx = math.floor(zoom*zoomFac*cnvobj.width)
		dx = math.floor((xmax-xm+1-dx)/2)
		local dy = math.floor(zoom*zoomFac*cnvobj.height)
		dy = math.floor((ymax-ym+1-dy)/2)
		vp.ymin = vp.ymin+dy
		vp.xmax = vp.xmax-dx
		vp.xmin = vp.xmin+dx
		cnvobj:refresh()				
		return iup.IGNORE 
	elseif c == iup.K_ESC then
		-- Check if any operation is going on
		if #op > 0 then
			-- End the operation
			local mode = op[#op].mode
			op[#op].finish()
			if mode == "LUAGL" then
				unre.doUndo(true)	-- Skip Redo
			end
			cnvobj:refresh()				
			return iup.IGNORE 		
		end
		--print("ESCAPE pressed MAIN DIALOG")
	end
	return iup.CONTINUE
end

-- Set the mainDlg user size to nil so that the show uses the Natural Size
GUI.mainDlg.size = nil
GUI.mainDlg:showxy(iup.CENTER, iup.CENTER)
GUI.mainDlg.minsize = GUI.mainDlg.rastersize	-- To limit the minimum size of the dialog to the natural size
--GUI.mainDlg.maxsize = GUI.mainDlg.rastersize	-- To limit the maximum size of the dialog to the natural size
--GUI.mainDlg.resize = "NO"
--GUI.mainDlg.maxbox = "NO"

local timer = iup.timer{
	time = 1000,
	run = "NO"
}
function timer:action_cb()
	timer.run = "NO"
	--print("Timer ran")
	-- Update the screen coordinates
	local refX,refY = cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas())	-- mouse position on canvas coordinates
	GUI.statBarR.title = "X="..refX..", Y="..refY
	--print("X="..refX..", Y="..refY)
	timer.time = 50
	timer.run = "YES"
end

--print("Timer is ",timer)

timer.run = "YES"

if iup.MainLoopLevel()==0 then
    iup.MainLoop()
    iup.Close()
end

