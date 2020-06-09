-- Module in DemoProject for item selection handling
-- NOTE: The module does not allow for multiple independent instances to be created in the application since selList is just 1 

local tostring = tostring
local tonumber = tonumber
local table = table
local math = math
local setmetatable = setmetatable
local type = type
local collectgarbage = collectgarbage
local rawset = rawset
local pairs = pairs

local tu = require("tableUtils")
local fd = require("iupcFocusDialog")

local unre = require("undoredo")

local iup = iup

local print = print


local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local cnvobj, GUI
local connList = {}
local selList = setmetatable({},{
		__mode="v",
		__newindex = function(t,k,v)
			if v.id then
				-- object
				rawset(t,k,v)
			else
				-- connector segment
				rawset(t,k,v)
				connList[v] = true	-- To prevent v from garbage collection since selList is weak table
			end
		end
	})
local oldAttr = setmetatable({},{__mode="k"})	-- Weak keys to allow the key to be garbage collected
local visualON = setmetatable({},{__mode="k"})	-- Table to link which items have their selection visual turned ON
local objSelColor
local connSelColor
local callback, selRect, opID
selModeFull = false		-- If true then the whole item should be inside the selecting rectangle to be selected

local function updateSelList()
	-- Remove all deleted connector segments
	for i,v in pairs(selList) do
		if not v.id then
			if not v.conn or not v.seg then
				connList[v] = nil
			end
		end
	end
	collectgarbage()
	-- Incase some other operation called the finish function then updateSelList will be called when the UNDOADDED hook is executed
	-- So the next block will clean up the selRect drawing
	if opID then
		if selRect then
			if cnvobj.op[opID] and cnvobj.drawn.obj[cnvobj.op[opID].index] == selRect then
				cnvobj.op[opID].finish()
			end
			if tu.inArray(cnvobj.drawn.obj,selRect) then
				cnvobj:removeObj(selRect)
			end
			selRect = nil
		end
		opID = nil
	end
end

function init(cvobj, gui,objSelC,connSelC)
	cnvobj = cvobj
	GUI = gui
	cnvobj:addHook("UNDOADDED",updateSelList)
	objSelColor = objSelC or {255, 162, 232}
	connSelColor = connSelC or {255, 128, 255}
end

-- Function to create a copy of the selList array. It also converts the seg structure pointer to the seg structure integer number of the connector segment. This is how the move/drag/etc. API of Lua-GL takes it
function selListCopy()
	local item = {}
	local objs = {}
	local conns = {}
	for i,v in pairs(selList) do
		if v.id then
			item[i] = v
			objs[#objs + 1] = v
		else
			local segI = tu.inArray(v.conn.segments,v.seg)
			if segI then
				item[i] = {
					conn = v.conn,
					seg = segI
				}
				conns[#conns + 1] = item[i]
			end
		end
	end
	return item,objs,conns
end

local function inselList(item)
	for i,v in pairs(selList) do
		if item.id then
			if v == item then
				return i
			end
		else
			if v.conn and v.conn == item.conn and v.seg == item.seg then
				return i
			end
		end
	end	
end

local function addInselList(item)
	local len = #selListCopy()
	local index, found
	for i = len,1,-1 do
		if selList[i] == nil then
			index = i
		elseif not selList[i].id and (not selList[i].conn or not selList[i].seg) then
			-- Connector selection entry but connector/segment no longer there. 
			-- Do some garbage collection
			connList[selList[i]] = nil
			selList[i] = nil
			index = i
		end
		if item.id then
			if selList[i] == item then
				found = true
				break
			end
		elseif selList[i].conn and selList[i].conn == item.conn and selList[i].seg == item.seg then
			found = true
			break
		end
	end
	if not found then
		if not index then
			index = len + 1
		end
		selList[index] = item
	end
	return true
end

local function removeSelListItem(index)
	if visualON[selList[index]] then
		visualON[selList[index]] = nil
		if selList[index].id then
			cnvobj:removeVisualAttr(selList[index])
			if oldAttr[selList[index]] then
				cnvobj:setObjVisualAttr(selList[index],oldAttr[selList[index]].attr,oldAttr[selList[index]].vAttr)
				oldAttr[selList[index]] = nil
			end
			selList[index] = nil
		elseif selList[index].seg then
			cnvobj:removeVisualAttr(selList[index].seg)
			if oldAttr[selList[index].seg] then
				cnvobj:setSegVisualAttr(selList[index].seg,oldAttr[selList[index].seg].attr,oldAttr[selList[index].seg].vAttr)
				oldAttr[selList[index].seg] = nil
			end
			connList[selList[index]] = nil
		end
	end
	collectgarbage()
end

function deselectAll()
	-- Remove all special attributes
	for i,v in pairs(selList) do
		removeSelListItem(i)
	end
	GUI.statBarM.title = ""
end

local function setSelectedDisplay()
	-- Set the selection attribute
	for i,v in pairs(selList) do
		local attr
		if not visualON[v] then
			visualON[v] = true
			if v.id then
				print("Added object "..v.id.." to list.")
				attr,_,oldAttr[v] = cnvobj:getVisualAttr(v)
				cnvobj:removeVisualAttr(v)
				attr = tu.copyTable(attr,{},true)
				attr.color = objSelColor
				cnvobj:setObjVisualAttr(v,attr,-1)
			else
				if v.seg then
					print("Added segment "..tu.inArray(v.conn.segments,v.seg).." from connector "..v.conn.id.." to the list")
					attr,_,oldAttr[v.seg] = cnvobj:getVisualAttr(v.seg)			
					cnvobj:removeVisualAttr(v.seg)
					attr = tu.copyTable(attr,{},true)
					attr.color = connSelColor
					cnvobj:setSegVisualAttr(v.seg,attr,-1)
				else
					connList[v] = nil
					selList[i] = nil
				end
			end	
		end
	end
	GUI.statBarM.title = tostring(#selListCopy()).." selected"
	cnvobj:refresh()	
	if callback and type(callback) == "function" and #selListCopy() > 0 then
		callback()
	end
end

-- Function to turn OFF the visual indications of the element being selected
function turnOFFVisuals()
	for i,v in pairs(selList) do
		if visualON[v] then
			visualON[v] = nil
			if v.id then
				cnvobj:removeVisualAttr(v)
				if oldAttr[v] then
					cnvobj:setObjVisualAttr(v,oldAttr[v].attr,oldAttr[v].vAttr)
					oldAttr[v] = nil
				end
			elseif v.seg then
				cnvobj:removeVisualAttr(v.seg)
				if oldAttr[v.seg] then
					cnvobj:setSegVisualAttr(v.seg,oldAttr[v.seg].attr,oldAttr[v.seg].vAttr)
					oldAttr[v.seg] = nil
				end
			end
		end
	end
end

-- Function to turn ON the visual indications of the element being selected
function turnONVisuals()
	setSelectedDisplay(0)
end

-- Button_CB callback to select stuff. Set as a hook in MOUSECLICKPOST event
-- If ctrl or shift is pressed then things are added to the selection list
-- Click anywhere where this is nothing to clear the list
local function selection_cb(button,pressed,x,y, status)
	if button == cnvobj.MOUSE.BUTTON1 and pressed == 1 then 
		-- Button was released
		-- The highest index in cnvobj.op should contain the object information since we won't reach here if any other operation is stacked since selection is disabled when any action is started
	-- put it in the rectangle drawing mode
		unre.pauseUndoRedo()
		print("Start selection rectangle")
		opID = cnvobj:drawObj("RECT",nil,nil,{	-- Selection rectangle attribute
					color = {0, 0, 0},
					style = cnvobj.GRAPHICS.DOTTED,
					width = 2,
					join = cnvobj.GRAPHICS.MITER,
					cap = cnvobj.GRAPHICS.CAPFLAT
				},-1)	-- interactive rectangle drawing
		selRect = cnvobj.drawn.obj[cnvobj.op[opID].index]
		
	end		-- if button == cnvobj.MOUSE.BUTTON1 and pressed == 0 then  

	if button == cnvobj.MOUSE.BUTTON1 and pressed == 0 then
		print("Left click done")
		local x1,x2,y1,y2
		local mode	-- selection mode
		-- Check if the selRect has anything and if the drawn rectangle needs to be considered a rectangle
		if selRect then
			x1,x2,y1,y2 = selRect.x[1],selRect.x[2],selRect.y[1],selRect.y[2]
			if not cnvobj.op[opID] or cnvobj.drawn.obj[cnvobj.op[opID].index] ~= selRect then
				return
			end
			cnvobj.op[opID].finish()
			if selRect and tu.inArray(cnvobj.drawn.obj,selRect) then
				cnvobj:removeObj(selRect)
			end
			local res = math.floor(math.min(cnvobj.grid.grid_x/2,cnvobj.grid.grid_y/2))
			if math.abs(x1-x2) > res and math.abs(y1-y2) > res then
				mode = "RECT"
			else
				mode = "POINT"
			end
			selRect = nil
		end
		-- Left click somewhere
		local multiple = cnvobj.isctrl(status) or cnvobj.isshift(status)
		local deselect = cnvobj.isalt(status)	-- Alt pressed for deselection mode
		if mode == "POINT" then
			-- Add any objects at x,y to items
			local i = cnvobj:getObjFromXY(x,y)
			-- Get any connector segments at x,y
			local c,s = cnvobj:getConnFromXY(x,y)
			if (#i == 0 and #s == 0) then		-- No object or segment here so deselect everything
				deselectAll()
				cnvobj:refresh()
				unre.resumeUndoRedo()
				return true
			end
			if not multiple and not deselect then
				deselectAll()
			end
			updateSelList()
			-- Merge into selList or remove from selList
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
					if inselList(i[j]) then
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
						if inselList({conn=cnvobj.drawn.conn[two.conn],seg=cnvobj.drawn.conn[two.conn].segments[two.seg[k]]}) then
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
						done = true	-- To make it run only once
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
									local obj 
									if cnvobj.isshift(status) then
										obj = cnvobj.populateGroupMembers({i[j]})
									else
										obj = {i[j]}
									end
									for m = 1,#obj do
										objs[#objs + 1] = obj[m]
									end
								else
									-- This is a connector segment
									local c = j-#i
									local ci = 0
									for k = 1,#s do
										if #s[k].seg+ci >= c then
											connList[#connList + 1] = setmetatable({
												conn = cnvobj.drawn.conn[s[k].conn],
												seg = cnvobj.drawn.conn[s[k].conn].segments[s[k].seg[c-ci]]
											},{__mode="v"})
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
							if not deselect then
								for k = 1,#objs do
									addInselList(objs[k])
								end
							else
								-- Remove elements from selList that are in objs
								for i = 1,#objs do
									local ind = inselList(objs[i])
									if ind then
										removeSelListItem(ind)
									end
								end
							end
						end
						if #connList > 0 then
							if not deselect then
								for k = 1,#connList do
									addInselList(connList[k])
								end
							else
								-- Remove elements from selList that are in connList
								for i = 1,#connList do
									local ind = inselList(connList[i])
									if ind then
										removeSelListItem(ind)
									end
								end
							end
						end
					else	-- if multiple then else
						-- Only 1 item selected so add it to the selList
						--print("Selected:",val)
						val = tonumber(val)
						if val and val ~= 0 then
							if val <= #i then
								-- This is the object
								local obj 
								if cnvobj.isshift(status) then
									obj = cnvobj.populateGroupMembers({i[val]})
								else
									obj = {i[val]}
								end
								if not deselect then
									for k = 1,#obj do
										addInselList(obj[k])
									end
								else
									-- Remove elements from selList that are in obj
									for i = 1,#obj do
										local ind = inselList(obj[i])
										if ind then
											removeSelListItem(ind)
										end
									end
								end
							else
								-- This is a connector segment
								local c = val-#i
								local ci = 0
								for k = 1,#s do
									if #s[k].seg+ci >= c then
										if not deselect then
											addInselList(setmetatable({
													conn = cnvobj.drawn.conn[s[k].conn],
													seg = cnvobj.drawn.conn[s[k].conn].segments[s[k].seg[c-ci]]
												},{__mode="v"}))
										else
											-- Remove elements from selList that are in connList
											local ind = inselList({
													conn = cnvobj.drawn.conn[s[k].conn],
													seg = cnvobj.drawn.conn[s[k].conn].segments[s[k].seg[c-ci]]
												})
											if ind then
												removeSelListItem(ind)
											end
										end
										break
									else
										ci = ci + #s[k].seg
									end
								end		-- for k = 1,#s do ends
							end		-- if val <= #i then ends
						end		-- if val ~= 0 then ends
					end		-- if multiple then ends
					setSelectedDisplay()
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
					local obj 
					if cnvobj.isshift(status) then
						obj = cnvobj.populateGroupMembers(i)
					else
						obj = i
					end
					if not deselect then
						for k = 1,#obj do
							addInselList(obj[k])
						end
					else
						-- Remove elements from selList that are in obj
						for i = 1,#obj do
							local ind = inselList(obj[i])
							if ind then
								removeSelListItem(ind)
							end
						end
					end
				else
					local connList = {}
					for j = 1,#s[1].seg do
						connList[#connList + 1] = setmetatable({
							conn = cnvobj.drawn.conn[s[1].conn],
							seg = cnvobj.drawn.conn[s[1].conn].segments[s[1].seg[j]]
						},{__mode="v"})
					end
					-- Merge into items
					if not deselect then
						for k = 1,#connList do
							addInselList(connList[k])
						end
					else
						-- Remove elements from selList that are in connList
						for i = 1,#connList do
							local ind = inselList(connList[i])
							if ind then
								removeSelListItem(ind)
							end
						end
					end
				end		
				setSelectedDisplay()
			end		-- if #i + #s > 1 then ends
		elseif mode == "RECT" then	-- if mode == "POINT" then else
			if not multiple then
				deselectAll()
			end
			updateSelList()
			local i = cnvobj:getObjinRect(x1,y1,x2,y2,selModeFull)
			if #i > 0 then
				local obj 
				if cnvobj.isshift(status) then
					obj = cnvobj.populateGroupMembers(i)
				else
					obj = i
				end
				if not delselect then
					for k = 1,#obj do
						addInselList(obj[k])
					end
				else
					-- Remove elements from selList that are in obj
					for i = 1,#obj do
						local ind = inselList(obj[i])
						if ind then
							removeSelListItem(ind)
						end
					end
				end
			end
			local c,s = cnvobj:getConninRect(x1,y1,x2,y2,selModeFull)
			if #s > 0 then
				local connList = {}
				for k = 1,#s do
					for j = 1,#s[k].seg do
						connList[#connList + 1] = setmetatable({
							conn = cnvobj.drawn.conn[s[k].conn],
							seg = cnvobj.drawn.conn[s[k].conn].segments[s[k].seg[j]]
						},{__mode="v"})
					end
				end
				-- Merge into items
				if not deselect then
					for k = 1,#connList do
						addInselList(connList[k])
					end
				else
					-- Remove elements from selList that are in connList
					for i = 1,#connList do
						local ind = inselList(connList[i])
						if ind then
							removeSelListItem(ind)
						end
					end
				end
			end		
			setSelectedDisplay()
		end		-- -- if mode == "POINT" then ends
		unre.resumeUndoRedo()
	end		-- if button == cnvobj.MOUSE.BUTTON1 and pressed == 0 then ends
end

local selID
function resumeSelection(cb)
	callback = cb
	if selID then
		cnvobj:removeHook(selID)
	end
	selID = cnvobj:addHook("MOUSECLICKPRE",selection_cb)	
end

function pauseSelection()
	cnvobj:removeHook(selID)
	selID = nil
end
