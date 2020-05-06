
require("submodsearcher")
local LGL = require("lua-gl")
tu = require("tableUtils")

require("GUIStructures")

fd = require("iupcFocusDialog")

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

local undo,redo = {},{}		-- The UNDO and REDO stacks
local toRedo, doingRedo, group
local function addUndoStack(diff)
	local tab = undo
	if toRedo then 
		tab = redo 
	elseif not doingRedo then
		redo = {}	-- Redo is emptied if any action is done
	end
	if group then
		-- To group multiple luagl actions into 1 undo action of the host application
		if #tab == 0 or tab[#tab].type ~= "LUAGLGROUP" then
			tab[#tab + 1] = {
				type = "LUAGLGROUP",
				obj = {diff}
			}
		else
			tab[#tab].obj[#tab[#tab].obj + 1] = diff
		end
	else
		tab[#tab + 1] = {
			type = "LUAGL",
			obj = diff
		}
	end
end
cnvobj:addHook("UNDOADDED",addUndoStack)

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
	cnvobj:load(s,nil,nil,true)	
	--cnvobj:load(s,450,300)
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

-- Undo button action
function GUI.toolbar.buttons.undoButton:action()
	for i = #undo,1,-1 do
		if undo[i].type == "LUAGL" then
			toRedo = true
			cnvobj:undo(undo[i].obj)
			table.remove(undo,i)
			toRedo = false
			break
		elseif undo[i].type == "LUAGLGROUP" then
			toRedo = true
			group = true
			for j = #undo[i].obj,1,-1 do
				cnvobj:undo(undo[i].obj[j])
			end
			table.remove(undo,i)
			toRedo = false
			group = false
			break
		end
	end
end

-- Redo button action
function GUI.toolbar.buttons.redoButton:action()
	for i = #redo,1,-1 do
		if redo[i].type == "LUAGL" then
			doingRedo = true
			cnvobj:undo(redo[i].obj)
			table.remove(redo,i)
			doingRedo = false
			break
		elseif redo[i].type == "LUAGLGROUP" then
			doingRedo = true
			group = true
			for j = #redo[i].obj,1,-1 do
				cnvobj:undo(redo[i].obj[j])
			end
			table.remove(redo,i)
			doingRedo = false
			group = false
			break
		end
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
	--[[cnvobj:drawObj("LINE",{
			{x=10,y=10},
			{x=100,y=100}
		})]]
	--cnvobj:refresh()
	cnvobj:drawObj("LINE")	-- interactive line drawing
end

-- Draw rectangle object
function GUI.toolbar.buttons.rectButton:action()
	cnvobj:drawObj("RECT")	-- interactive rectangle drawing
end

-- Draw filled rectangle object
function GUI.toolbar.buttons.fRectButton:action()
	cnvobj:drawObj("FILLEDRECT")	-- interactive filled rectangle drawing
end

-- Draw blocking rectangle object
function GUI.toolbar.buttons.bRectButton:action()
	cnvobj:drawObj("BLOCKINGRECT")	-- interactive blocking rectangle drawing
end

-- Draw ellipse object
function GUI.toolbar.buttons.elliButton:action()
	cnvobj:drawObj("ELLIPSE")	-- interactive ellipse drawing
end

-- Draw filled ellipse object
function GUI.toolbar.buttons.fElliButton:action()
	cnvobj:drawObj("FILLEDELLIPSE")	-- interactive filled ellipse drawing
end

-- Draw Arc
function GUI.toolbar.buttons.arcButton:action()
	cnvobj:drawObj("ARC")
end

-- Draw Sector
function GUI.toolbar.buttons.filledarcButton:action()
	cnvobj:drawObj("FILLEDARC")
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
				vAttr = 100	-- Unique attribute not stored in the bank
			}
		end
		cnvobj:moveObj({o})
	end
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

selList = {}
local oldAttr = setmetatable({},{__mode="k"})	-- Weak keys to allow the item to be garbage collected
local objSelColor = {255, 162, 232}
local connSelColor = {255, 128, 255}

-- Button_CB callback to select stuff
-- If ctrl or shift is pressed then things are added to the selection list
-- Click anywhere where this is nothing to clear the list
local function selection_cb(button,pressed,x,y, status)
	
	local function deselectAll()
		-- Remove all special attributes
		for i = 1,#selList do
			if selList[i].id then
				cnvobj:removeVisualAttr(selList[i])
				if oldAttr[selList[i]] then
					cnvobj:setObjVisualAttr(selList[i],oldAttr[selList[i]].attr,oldAttr[selList[i]].vAttr)
				end
			else
				cnvobj:removeVisualAttr(selList[i].conn.segments[selList[i].seg])
				if oldAttr[selList[i].conn.segments[selList[i].seg]] then
					cnvobj:setSegVisualAttr(selList[i].conn.segments[selList[i].seg],oldAttr[selList[i].conn.segments[selList[i].seg]].attr,oldAttr[selList[i].conn.segments[selList[i].seg]].vAttr)
				end
			end
		end
		selList = {}		
	end
	
	local function setSelectedDisplay(selI)
		-- Set the selection attribute
		for i = selI + 1,#selList do
			local attr
			if selList[i].id then
				print("Added object "..selList[i].id.." to list.")
				attr,_,oldAttr[selList[i]] = cnvobj:getVisualAttr(selList[i])
				cnvobj:removeVisualAttr(selList[i])
				attr = tu.copyTable(attr,{},true)
				attr.color = objSelColor
				cnvobj:setObjVisualAttr(selList[i],attr,-1)
			else
				print("Added segment "..selList[i].seg.." from connector "..selList[i].conn.id.." to the list")
				attr,_,oldAttr[selList[i].conn.segments[selList[i].seg]] = cnvobj:getVisualAttr(selList[i].conn.segments[selList[i].seg])			
				cnvobj:removeVisualAttr(selList[i].conn.segments[selList[i].seg])
				attr = tu.copyTable(attr,{},true)
				attr.color = connSelColor
				cnvobj:setSegVisualAttr(selList[i].conn.segments[selList[i].seg],attr,-1)
			end			
		end
		cnvobj:refresh()		
	end
	
	if button == cnvobj.MOUSE.BUTTON1 and pressed == 1 then
		print("Left click done")
		-- Left click somewhere
		local multiple = cnvobj.isctrl(status) or cnvobj.isshift(status)
		-- Add any objects at x,y to items
		local i = cnvobj:getObjFromXY(x,y)
		-- Get any connector segments at x,y
		local c,s = cnvobj:getConnFromXY(x,y)
		if (#i == 0 and #s == 0) then		-- No object or segment here so deselect everything
			deselectAll()
			cnvobj:refresh()
			return true
		end
		if not multiple then
			deselectAll()
		end
		local selI = #selList
		-- Merge into items
		if #i + #s > 1 then
			-- show the selection list to get the items
			local lines = 5
			if #i + #s < lines then lines = #i + #s end
			local list = iup.flatlist{bgcolor=iup.GetGlobal("DLGBGCOLOR"),visiblelines = lines,visiblecolumns=15}
			local doneButton = iup.flatbutton{title = "DONE",expand="HORIZONTAL"}
			local selValue --= 0
			if multiple then 
				list.multiple = "YES" 
				selValue = ""
			end
			local listCount = 0
			-- Add the objects to the list
			for j = 1,#i do
				listCount = listCount + 1
				list[tostring(listCount)] = "Object: "..tu.inArray(cnvobj.drawn.obj,i[j])
				if tu.inArray(selList,i[j]) then
					if multiple then
						selValue = selValue.."+"
					else
						selValue = listCount
					end
				elseif multiple then
					selValue = selValue.."-"
				end					
			end
			for j = 1,#s do
				for k = 1,#s[j].seg do
					listCount = listCount + 1
					list[tostring(listCount)] = "Connector: "..s[j].conn.." Segment: "..s[j].seg[k]
					if tu.inArray(selList,s[j],function(one,two)
						return not(one.id) and one.conn == cnvobj.drawn.conn[two.conn] and one.seg == two.seg[k] 
					  end) then
						if multiple then
							selValue = selValue.."+"
						else
							selValue = listCount
						end
					elseif multiple then
						selValue = selValue.."-"
					end								
				end
			end
			list.value = selValue
			local seldlg = iup.dialog{iup.vbox{list,doneButton};border="NO",resize="NO",minbox="NO",menubox="NO"}
			local done
			local function getSelected()
				if not done then
					done = true
				else
					return
				end
				local val = list.value
				if multiple then
					-- Get all selected items
					local objs, connList = {},{}
					for j = 1,#val do
						if val:sub(j,j) == "+" then
							if j <= #i then
								-- This is the object
								objs[#objs + 1] = i[j]
							else
								-- This is a connector segment
								local c = j-#i
								local ci = 0
								for k = 1,#s do
									if #s[k].seg+ci >= c then
										connList[#connList + 1] = {
											conn = cnvobj.drawn.conn[s[k].conn],
											seg = s[k].seg[c-ci]
										}
										break
									else
										ci = ci + #s[k].seg
									end
								end
							end
						end
					end		-- for j = 1,#val doends
					-- Add objs and connList items to selList
					if #objs > 0 then
						tu.mergeArrays(objs,selList,false,function(one,two) 
							return two.id and one.id == two.id
						  end)
					end
					if #connList > 0 then
						tu.mergeArrays(connList,selList,false,function(one,two) 
							return two.conn and one.conn.id == two.conn.id and one.seg == two.seg 
						  end)
					end
				else	-- if multiple then else
					-- Only 1 item selected so add it to the selList
					--print("Selected:",val)
					val = tonumber(val)
					if val and val ~= 0 then
						if val <= #i then
							-- This is the object
							tu.mergeArrays({i[val]},selList,false,function(one,two) 
								return two.id and one.id == two.id
							  end)
						else
							-- This is a connector segment
							local c = val-#i
							local ci = 0
							for k = 1,#s do
								if #s[k].seg+ci > c then
									tu.mergeArrays({
											conn = cnvobj.drawn.conn[s[k].conn],
											seg = s[k].seg[c-ci]
										},selList,false,function(one,two) 
											return two.conn and one.conn.id == two.conn.id and one.seg == two.seg 
									  end)
									break
								else
									ci = ci + #s[k].seg
								end
							end		-- for k = 1,#s do ends
						end		-- if val <= #i then ends
					end		-- if val ~= 0 then ends
				end		-- if multiple then ends
				setSelectedDisplay(selI)
			end		-- local function getSelected() ends
			local gx,gy = iup.GetGlobal("CURSORPOS"):match("^(-?%d%d*)x(-?%d%d*)$")
			gx,gy = tonumber(gx),tonumber(gy)
			--print("Showing selection dialog at "..gx..","..gy)
			function doneButton:flat_action()
				seldlg:hide()
				getSelected()
			end
			fd.popup(seldlg,gx,gy,getSelected)
		else	--if #i + #s > 1 then else
			if #i > 0 then
				tu.mergeArrays(i,selList,false,function(one,two) 
					return two.id and one.id == two.id
				  end)
			else
				local connList = {}
				for j = 1,#s[1].seg do
					connList[#connList + 1] = {
						conn = cnvobj.drawn.conn[s[1].conn],
						seg = s[1].seg[j]
					}
				end
				-- Merge into items
				tu.mergeArrays(connList,selList,false,function(one,two) 
					return two.conn and one.conn.id == two.conn.id and one.seg == two.seg 
				  end)
			end		
			setSelectedDisplay(selI)
		end		-- if #i + #s > 1 then ends
	end		-- if button == cnvobj.MOUSE.BUTTON1 and pressed == 1 then ends
end

local selID = cnvobj:addHook("MOUSECLICKPOST",selection_cb)

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

function GUI.toolbar.buttons.checkButton:action()
	cnvobj:drawConnector({
			{start_x = 300,start_y=130,end_x=300,end_y=380},
			{start_x = 300,start_y=380,end_x=500,end_y=380},
			{start_x = 500,start_y=360,end_x=320,end_y=360},
			{start_x = 320,start_y=360,end_x=320,end_y=130},
		})
	cnvobj:refresh()
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
	-- Set refX,refY as the mouse coordinate on the canvas transformed to the database coordinates snapped
	group = true
	local x,y = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
	cnvobj.grid.snapGrid = false
	local o = cnvobj:drawObj("FILLEDRECT",{{x=x-3,y=y-3},{x=x+3,y=y+3}})
	cnvobj.grid.snapGrid = true
	-- Now we need to put the mouse exactly on the center of the filled rectangle
	-- Set the cursor position to be right on the center of the object
	local rx,ry = cnvobj:setMouseOnCanvas(cnvobj:dCoor2sCoor(x,y))
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
				stop = true	-- There is an object there other than the object drawn for the port visualization above
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
			group = false
		elseif cnvobj.op[#cnvobj.op].mode ~= "MOVEOBJ" then
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
	local refX,refY = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
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

