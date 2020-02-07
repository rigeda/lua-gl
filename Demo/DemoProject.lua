
require("submodsearcher")
local LGL = require("lua-gl")
tu = require("tableUtils")

require("GUIStructures")


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
	grid_x = 10, 
	grid_y = 10, 
	width = 900, 
	height = 600, 
	gridVisibility = true,
	snapGrid = true,
	showBlockingRect = true,
	--usecrouter = true,
}
GUI.mainArea:append(cnvobj.cnv)

local MODE


--********************* Callbacks *************

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
	local f = io.open(fileDlg.value,"w+")
	f:write(cnvobj:save())
	f:close()
end

-- To load data from a file
function GUI.toolbar.buttons.loadButton:action()
	local fileDlg = iup.filedlg{
		dialogtype = "OPEN",
		extfilter = "Demo Files|*.dia",
		title = "Select file to save drawing...",
		extdefault = "dia"
	} 
	fileDlg:popup(iup.CENTER, iup.CENTER)
	if fileDlg.status == "-1" then
		return
	end
	f = io.open(fileDlg.value,"r")
	local s = f:read("*a")
	f:close()
	--cnvobj:load(s,nil,nil,true)	
	cnvobj:load(s,450,300)
end

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

-- If mode == 1 then add only objects
-- if mode == 2 then add only connectors/segments
-- If no mode then add both
-- If noclick is true then the given call back is called as soon as the selection list is completed otherwise an additional click is required by the mouse before the call back is called
local function getSelectionList(cb,noclick,mode)
	-- Create a dialog to show the list
	local list = iup.list{
		visiblelines = 10,
		visiblecolumns = 10
	}
	
	local ok = iup.button{title="OK",expand="HORIZONTAL"}
	local cancel = iup.button{title="Cancel",expand="HORIZONTAL"}
	local label = iup.label{
		title="Select items on \nthe canvas and they \nwill be listed below:",
		alignment = "ACENTER:ACENTER"
	}
	local label1 = iup.label{
		title="After selecting\npress OK and click \n on canvas to start.",
		alignment = "ACENTER:ACENTER"
	}
	
	local dlg = iup.dialog{
		title = "Selected Objects",
		iup.vbox{
			label,
			list,
			label1,
			iup.hbox{
				ok,
				cancel;
				homogenous = "YES",
				normalizesize = "HORIZONTAL"
			},
		},
		icon = GUI.images.appIcon
	}
	dlg:map()
	local w = list.rastersize:match("(%d%d*)x")
	label.rastersize = w.."x"
	label1.rastersize = w.."x"
	dlg.minsize = dlg.rastersize
	dlg.maxsize = dlg.rastersize
	dlg.minbox = "NO"
	dlg.maxbox = "NO"
	dlg:showxy(iup.RIGHT, iup.TOP)
	--iup.Show(iup.LayoutDialog(dlg))

	-- create hook for mouse click to add shapes to the list
	local items = {}
	local function clickToAdd(button,pressed,x,y,status)
		if button == iup.BUTTON1 and pressed == 1 then
			if mode and mode == 1 then
				-- Add any objects at x,y to items
				local i = cnvobj:getObjFromXY(x,y)
				-- Merge into items
				tu.mergeArrays(i,items,false,function(one,two) return one.id == two.id end)
			elseif mode and mode == 2 then
				-- Add any connectors at x,y to items
				local c,s = cnvobj:getConnFromXY(x,y)
				local connList = {}
				for i = 1,#s do
					for j = 1,#s[i].seg do
						connList[#connList + 1] = {
							conn = cnvobj.drawn.conn[s[i].conn],
							seg = s[i].seg[j]
						}
					end
				end
				-- Merge into items
				tu.mergeArrays(connList,items,false,function(one,two) return one.conn.id == two.conn.id and one.seg == two.seg end)
			elseif not mode then
				-- Add any objects at x,y to items
				local i = cnvobj:getObjFromXY(x,y)
				-- Merge into items
				if #i > 0 then
					tu.mergeArrays(i,items,false,function(one,two) 
						return two.id and one.id == two.id
					  end)
				end
				-- Add any connectors at x,y to items
				local c,s = cnvobj:getConnFromXY(x,y)
				local connList = {}
				for i = 1,#s do
					for j = 1,#s[i].seg do
						connList[#connList + 1] = {
							conn = cnvobj.drawn.conn[s[i].conn],
							seg = s[i].seg[j]
						}
					end
				end
				-- Merge into items
				if #connList > 0 then
					tu.mergeArrays(connList,items,false,function(one,two) 
						return two.conn and one.conn.id == two.conn.id and one.seg == two.seg 
					  end)
				end
			end
			-- Update the list item control to display the items
			list.removeitem = "ALL"
			for i = 1,#items do
				list.appenditem = items[i].id or (items[i].conn.id.."S"..tostring(items[i].seg))
			end
		end
	end
	-- set the hook
	local hook = cnvobj:addHook("MOUSECLICKPOST",clickToAdd)
	function ok:action()
		cnvobj:removeHook(hook)
		if not noclick then
			-- Now create a hook to start the move
			local function getClick(button,pressed,x,y,status)
				cnvobj:removeHook(hook)
				if #items > 0 then
					cb(items)
				end
			end
			-- Add the hook
			hook = cnvobj:addHook("MOUSECLICKPOST",getClick)
			dlg:hide()
			dlg:destroy()
		else
			dlg:hide()
			dlg:destroy()
			cb(items)
		end
		-- If there are items selected then call the callback
	end
	function cancel:action()
		cnvobj:removeHook(hook)
		dlg:hide()
		dlg:destroy()
	end
end

-- Start Move operation
function GUI.toolbar.buttons.moveButton:action()
	-- function to handle the move
	local function moveitems(items)
		cnvobj:move(items)
		--cnvobj:moveSegment(items)
	end
	-- first we need to select items
	getSelectionList(moveitems,false)	-- Need a click 
end

-- Start drag operation
function GUI.toolbar.buttons.dragButton:action()
	-- function to handle drag
	local function dragitems(items)
		--print("callback dragitems")
		--cnvobj:dragObj(items)
		cnvobj:drag(items)
	end
	-- Get the list of items
	getSelectionList(dragitems,false)
end

function GUI.toolbar.buttons.groupButton:action()
	-- Function to group objects together
	local function groupObjects(items)
		local it = {}
		-- Pick only objects from the selection
		for i = 1,#items do
			if items[i].id:match("^O%d%d*$") then
				it[#it + 1] = items[i]
			end
		end
		if #it > 0 then
			cnvobj:groupObjects(it)
		end		
	end
	-- Get the list of items
	getSelectionList(groupObjects,true,1)
end

function GUI.toolbar.buttons.portButton:action()
	-- Check if port mode already on then do nothing
	if MODE == "ADDPORT" then
		return
	end
	-- Create a representation of the port at the location of the mouse pointer and then start its move
	-- Create a MOUSECLICKPOST hook to check whether the move ended on a object. If not continue the move
	-- Set refX,refY as the mouse coordinate on the canvas
	local gx,gy = iup.GetGlobal("CURSORPOS"):match("^(%d%d*)x(%d%d*)$")
	local sx,sy = cnvobj.cnv.SCREENPOSITION:match("^(%d%d*),(%d%d*)$")
	local refX,refY = cnvobj:snap(gx-sx,gy-sy)
	cnvobj.grid.snapGrid = false
	local o = cnvobj:drawObj("FILLEDRECT",2,{{x=refX-3,y=refY-3},{x=refX+3,y=refY+3}})
	cnvobj.grid.snapGrid = true
	-- Set the cursor position to be right on the center of the object
	iup.SetGlobal("CURSORPOS",tostring(sx+refX).."x"..tostring(sy+refY))
	-- Create the hook
	local hook
	local function getClick(button,pressed,x,y,status)
		print("Run Hook getClick")
		x,y = cnvobj:snap(x,y)
		-- Check if there is an object here
		local allObjs = cnvobj:getObjFromXY(x,y)
		local stop
		for i = 1,#allObjs do
			if allObjs[i] ~= o then
				stop = true
				break
			end
		end
		if stop then
			cnvobj:removeHook(hook)
			-- group o with the 1st object
			cnvobj:groupObjects({allObjs[1],o})
			-- Create a port
			print("Create the port at ",x,y)
			cnvobj:addPort(x,y,allObjs[1].id)
			MODE = nil
		elseif cnvobj.op.mode ~= "MOVEOBJ" then
			print("Continuing Move",#allObjs)
			-- Continue the move only if it is out of the move mode
			cnvobj:moveObj({o})
		end
		print("End Hook execution getClick")
	end
	-- Add the hook
	hook = cnvobj:addHook("MOUSECLICKPOST",getClick)
	-- Start the interactive move
	MODE = "ADDPORT"
	cnvobj:moveObj({o})
end

function GUI.toolbar.buttons.refreshButton:action()
	cnvobj:refresh()
end

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
	cnvobj:drawConnector(nil,router1,js1,router2,js2)
end

function GUI.toolbar.buttons.connModeList:action(text,item,state)
	mode = item-1
	if item == 4 then
		mode = 9
	end
end 

function GUI.toolbar.buttons.newButton:action()
	cnvobj:erase()
	cnvobj:refresh()
end

-- 90 degree rotate
function rotateFlip(para)
	local op = cnvobj.op[#cnvobj.op]
	local mode = op.mode
	local gx,gy = iup.GetGlobal("CURSORPOS"):match("^(%d%d*)x(%d%d*)$")
	local sx,sy = cnvobj.cnv.SCREENPOSITION:match("^(%d%d*),(%d%d*)$")
	local refX,refY = cnvobj:snap(gx-sx,gy-sy)
	if mode == "DRAG" or  mode == "DRAGSEG" or mode == "DRAGOBJ" then
		-- Compile item list
		local items = {}
		for i = 1,#op.objList do
			items[#items + 1] = op.objList[i]
		end
		if op.segList then
			for i = 1,#op.segList do
				items[#items + 1] = op.segList[i]
			end
		end
		-- Do the rotation 
		cnvobj.rotateFlipItems(items,refX,refY,para)
		local prx,pry = cnvobj:snap(op.ref.x,op.ref.y)
		op.coor1.x,op.coor1.y = cnvobj.rotateFlip(op.coor1.x,op.coor1.y,prx,pry,para)
		cnvobj:refresh()
	elseif mode == "MOVE" or mode == "MOVESEG" or mode == "MOVEOBJ" then
		-- Compile item list
		local items = {}
		for i = 1,#op.objList do
			items[#items + 1] = op.objList[i]
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
		cnvobj.rotateFlipItems(items,refX,refY,para)
		local prx,pry = cnvobj:snap(op.ref.x,op.ref.y)
		op.coor1.x,op.coor1.y = cnvobj.rotateFlip(op.coor1.x,op.coor1.y,prx,pry,para)
		cnvobj:refresh()
	else
		-- Get list of items
		local function rotateItems(items)
			local gx,gy = iup.GetGlobal("CURSORPOS"):match("^(%d%d*)x(%d%d*)$")
			local sx,sy = cnvobj.cnv.SCREENPOSITION:match("^(%d%d*),(%d%d*)$")
			local refX,refY = cnvobj:snap(gx-sx,gy-sy)
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
			cnvobj.rotateFlipItems(items,refX,refY,para)
			cnvobj:refresh()
		end
		-- first we need to select items
		getSelectionList(rotateItems,false)	-- Need a click 
	end
end

function GUI.mainDlg:k_any(c)
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
	return iup.CONTINUE
end

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

