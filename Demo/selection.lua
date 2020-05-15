-- Module in DemoProject for item selection handling
-- NOTE: The module does not allow for multiple independent instances to be created in the application since selList is just 1 

local tostring = tostring
local tonumber = tonumber
local table = table
local math = math
local setmetatable = setmetatable
local type = type

local tu = require("tableUtils")
local fd = require("iupcFocusDialog")

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
selList = {}
local oldAttr = setmetatable({},{__mode="k"})	-- Weak keys to allow the key to be garbage collected
local objSelColor
local connSelColor
local callback, selRect, opID
selModeFull = false

local function updateSelList()
	-- Remove all deleted connector segments
	for i = #selList,1,-1 do
		if not selList[i].id then
			if not selList[i].conn or not selList[i].seg then
				table.remove(selList,i)
			end
		end
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
	local c = {}
	for i = 1,#selList do
		if selList[i].id then
			c[i] = selList[i]
		else
			local segI = tu.inArray(selList[i].conn.segments,selList[i].seg)
			if segI then
				c[i] = {
					conn = selList[i].conn,
					seg = segI
				}
			end
		end
	end
	return c
end

function deselectAll()
	-- Remove all special attributes
	for i = 1,#selList do
		if selList[i].id then
			cnvobj:removeVisualAttr(selList[i])
			if oldAttr[selList[i]] then
				cnvobj:setObjVisualAttr(selList[i],oldAttr[selList[i]].attr,oldAttr[selList[i]].vAttr)
			end
		elseif selList[i].seg then
			cnvobj:removeVisualAttr(selList[i].seg)
			if oldAttr[selList[i].seg] then
				cnvobj:setSegVisualAttr(selList[i].seg,oldAttr[selList[i].seg].attr,oldAttr[selList[i].seg].vAttr)
			end
		end
	end
	GUI.statBarM.title = ""
	selList = {}		
end

local function setSelectedDisplay(selI)
	-- Set the selection attribute
	for i = #selList,selI + 1,-1 do
		local attr
		if selList[i].id then
			print("Added object "..selList[i].id.." to list.")
			attr,_,oldAttr[selList[i]] = cnvobj:getVisualAttr(selList[i])
			cnvobj:removeVisualAttr(selList[i])
			attr = tu.copyTable(attr,{},true)
			attr.color = objSelColor
			cnvobj:setObjVisualAttr(selList[i],attr,-1)
		else
			if selList[i].seg then
				print("Added segment "..tu.inArray(selList[i].conn.segments,selList[i].seg).." from connector "..selList[i].conn.id.." to the list")
				attr,_,oldAttr[selList[i].seg] = cnvobj:getVisualAttr(selList[i].seg)			
				cnvobj:removeVisualAttr(selList[i].seg)
				attr = tu.copyTable(attr,{},true)
				attr.color = connSelColor
				cnvobj:setSegVisualAttr(selList[i].seg,attr,-1)
			else
				table.remove(selList,i)
			end
		end			
	end
	GUI.statBarM.title = tostring(#selList).." selected"
	cnvobj:refresh()	
	if callback and type(callback) == "function" and #selList > 0 then
		callback()
	end
end

-- Button_CB callback to select stuff. Set as a hook in MOUSECLICKPOST event
-- If ctrl or shift is pressed then things are added to the selection list
-- Click anywhere where this is nothing to clear the list
local function selection_cb(button,pressed,x,y, status)
	if button == cnvobj.MOUSE.BUTTON1 and pressed == 1 then 
		-- Button was released
		-- The highest index in cnvobj.op should contain the object information since we won't reach here if any other operation is stacked since selection is disabled when any action is started
	-- put it in the rectangle drawing mode
		cnvobj:drawObj("RECT",nil,nil,{	-- Selection rectangle attribute
					color = {0, 0, 0},
					style = cnvobj.GRAPHICS.DOTTED,
					width = 2,
					join = cnvobj.GRAPHICS.MITER,
					cap = cnvobj.GRAPHICS.CAPFLAT
				},-1)	-- interactive rectangle drawing
		opID = #cnvobj.op
		selRect = cnvobj.drawn.obj[cnvobj.op[opID].index]
	end		-- if button == cnvobj.MOUSE.BUTTON1 and pressed == 0 then  

	if button == cnvobj.MOUSE.BUTTON1 and pressed == 0 then
		print("Left click done")
		local x1,x2,y1,y2
		local mode	-- selection mode
		-- Check if the selRect has anything and if the drawn rectangle needs to be considered a rectangle
		if selRect then
			x1,x2,y1,y2 = selRect.x[1],selRect.x[2],selRect.y[1],selRect.y[2]
			cnvobj.op[opID].finish()
			if cnvobj.drawn.order[selRect.order] and cnvobj.drawn.order[selRect.order].item == selRect then
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
		if mode == "POINT" then
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
			updateSelList()
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
							return not(one.id) and one.conn == cnvobj.drawn.conn[two.conn] and one.seg == cnvobj.drawn.conn[two.conn].segments[two.seg[k]]
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
							tu.mergeArrays(objs,selList,false,function(one,two) 
								return two.id and one.id == two.id
							  end)
						end
						if #connList > 0 then
							tu.mergeArrays(connList,selList,false,function(one,two) 
								return two.conn and one.conn == two.conn and one.seg == two.seg
							  end)
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
								tu.mergeArrays(obj,selList,false,function(one,two) 
									return two.id and one.id == two.id
								  end)
							else
								-- This is a connector segment
								local c = val-#i
								local ci = 0
								for k = 1,#s do
									if #s[k].seg+ci >= c then
										tu.mergeArrays({setmetatable({
												conn = cnvobj.drawn.conn[s[k].conn],
												seg = cnvobj.drawn.conn[s[k].conn].segments[s[k].seg[c-ci]]
											},{__mode="v"})},selList,false,function(one,two) 
												return two.conn and one.conn == two.conn and one.seg == two.seg 
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
					local obj 
					if cnvobj.isshift(status) then
						obj = cnvobj.populateGroupMembers(i)
					else
						obj = i
					end
					tu.mergeArrays(obj,selList,false,function(one,two) 
						return two.id and one.id == two.id
					  end)
				else
					local connList = {}
					for j = 1,#s[1].seg do
						connList[#connList + 1] = setmetatable({
							conn = cnvobj.drawn.conn[s[1].conn],
							seg = cnvobj.drawn.conn[s[1].conn].segments[s[1].seg[j]]
						},{__mode="v"})
					end
					-- Merge into items
					tu.mergeArrays(connList,selList,false,function(one,two) 
						return two.conn and one.conn == two.conn and one.seg == two.seg 
					  end)
				end		
				setSelectedDisplay(selI)
			end		-- if #i + #s > 1 then ends
		else	-- if mode == "POINT" then else
			if not multiple then
				deselectAll()
			end
			updateSelList()
			local i = cnvobj:getObjinRect(x1,y1,x2,y2,selModeFull)
			local selI = #selList
			if #i > 0 then
				local obj 
				if cnvobj.isshift(status) then
					obj = cnvobj.populateGroupMembers(i)
				else
					obj = i
				end
				tu.mergeArrays(obj,selList,false,function(one,two) 
					return two.id and one.id == two.id
				  end)
			end
			local c,s = cnvobj:getConninRect(x1,y1,x2,y2,selModeFull)
			if #s > 0 then
				local connList = {}
				for j = 1,#s[1].seg do
					connList[#connList + 1] = setmetatable({
						conn = cnvobj.drawn.conn[s[1].conn],
						seg = cnvobj.drawn.conn[s[1].conn].segments[s[1].seg[j]]
					},{__mode="v"})
				end
				-- Merge into items
				tu.mergeArrays(connList,selList,false,function(one,two) 
					return two.conn and one.conn == two.conn and one.seg == two.seg 
				  end)
			end		
			
			setSelectedDisplay(selI)
		end		-- -- if mode == "POINT" then ends
	end		-- if button == cnvobj.MOUSE.BUTTON1 and pressed == 1 then ends
end

local selID
function resumeSelection(cb)
	callback = cb
	if selID then
		cnvobj:removeHook(selID)
	end
	selID = cnvobj:addHook("MOUSECLICKPOST",selection_cb)	
end

function pauseSelection()
	cnvobj:removeHook(selID)
	
	selID = nil
end
