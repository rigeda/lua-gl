-- Module to manage file linked components in DemoProject

local setmetatable = setmetatable
local tostring = tostring
local pairs = pairs
local table = table
local collectgarbage = collectgarbage

local tu = require("tableUtils")
local unre = require("undoredo")


local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

--[[ components structure stores the information about components linked to files i.e. they are updated when the file is updated
The components structure will be an array of the following tables:
{
	id = <number>,
	file = Path and name of file",
	items = {},
	IDMAP = {}		-- Table containing mapping of Object and Connector IDs loaded on the canvas to the Object and Connector IDs on the file
}
Here items is a table where an entry for object structure is a weak value table having the 4 entries:
{
	type = "object",
	obj = <object structure>,
	xa = 1st x coordinate of the object in the file data from where it is loaded,
	ya = 1st y coordinate of the object in the file data from where it is loaded
}
and the entry for the connector structure is a weak value table having the 3 entries
{
	type = "segment"
	conn = connector structure,
	seg = segment structure belonging to the connector
}
]]
local components = {ids = 0}
local cnvobj
local WEAKV = {__mode="v"}	-- metatable to set weak values

local function copyComponent(comp)
	local c = {
		id = comp.id,
		file = comp.file,
		items = {},
		IDMAP = tu.copyTable(comp.IDMAP,{}),
	}
	for i = 1,#comp.items do
		c.items[#c.items + 1] = setmetatable({},WEAKV)
		for k,v in pairs(comp.items[i]) do
			c.items[#c.items][k] = v
		end
	end
	return c
end

-- Function to backup a component
-- The difference between copyComponent and backupComponent is that backupComponent does not point to the actual object/connector/segment structures in the Lua-GL
-- data structures. This is helpful because undo/redo options may change the table addresses. So it is better to refer them from their values
local function backupComponent(comp)
	local c = {
		id = comp.id,
		file = comp.file,
		items = {},
		IDMAP = tu.copyTable(comp.IDMAP,{}),
	}
	for i = 1,#comp.items do
		local item = {
			type = comp.items[i].type
		}
		if item.type == "object" then
			if comp.items[i].obj then
				item.obj = comp.items[i].obj.id	-- store the object id instead of the structure table since the structure table address may change as a result of undo
				item.xa = comp.items[i].xa
				item.ya = comp.items[i].ya
			end
		else
			if comp.items[i].conn and comp.items[i].seg then
				item.conn = comp.items[i].conn.id
				item.seg = tu.inArray(comp.items[i].conn,comp.items[i].seg)
			end
		end
		c.items[#c.items + 1] = item
	end
	return c
end

-- Function to restore the component to the proper format to be stored in the component data structure
-- comp is a component structure as returned by backupComponent
local function restoreComponent(comp)
	local c = {
		id = comp.id,
		file = comp.file,
		items = {},
		IDMAP = tu.copyTable(comp.IDMAP,{}),
	}
	for i = 1,#comp.items do
		local item = {
			type = comp.items[i].type
		}
		local add	-- Only add those items whose structures are not already garbage collected
		if item.type == "object" then
			item.obj = cnvobj:getObjFromID(comp.items[i].obj)
			if item.obj then
				add = true
				item.xa = comp.items[i].xa
				item.ya = comp.items[i].ya
			end
		else	
			item.conn = cnvobj:getConnFromID(comp.items[i].conn)
			if item.conn then
				add = true
				item.seg = item.conn.segments[comp.items[i].seg]
			end
		end
		if add then
			c.items[#c.items + 1] = setmetatable(item,WEAKV)
		end
	end
	return c
end

function getComponentFromID(id)
	local ind = tu.inArray(components,id,function(one,two) return one.id == two end)
	if not ind then
		return
	end
	-- Create a copy of the component
	return copyComponent(components[ind])
end

function getComponentFromFile(file)
	local ind = tu.inArray(components,file,function(one,two) return one.file == file end)
	if not ind then
		return 
	end
	-- Create a copy of the component
	return copyComponent(components[ind])	
end

-- Components iterator factory
function comps()
	local done = {}
	return function()
			for i = 1,#components do
				if not done[components[i]] then
					done[components[i]] = true
					return copyComponent(components[i])
				end
			end
		end
end

function deleteComponent(id)
	local index
	for i = 1,#components do
		if components[i].id == id then
			index = i
			break
		end
	end
	if index then
		-- Setup and return the undo/redo functions
		local c,undo,redo
		undo = function()
			table.insert(components,index,restoreComponent(c))
			return redo
		end
		redo = function()
			-- Create a backup of the component structure to be used for the undo function
			c = backupComponent(components[index])
			table.remove(components,index)
			return undo
		end
		redo()
		-- Add the undo function
		unre.addUndoFunction(undo)
		return true
	end
	return false
end

-- Function to update the components structure by removing components who have been removed in Lua-GL
function updateComponents()
	collectgarbage()
	for i = #components,1,-1 do
		local found
		-- Check if any item is found
		for j = 1,#components[i].items do
			if components[i].items[j].type == "object" then
				found = components[i].items[j].obj and true
			else
				found = components[i].items[j].conn and components[i].items[j].seg and true
			end
			if found then break end
		end
		if not found then
			deleteComponent(components[i].id)
		end
	end
end

-- items is an array with either of the 2 things:
-- * object structure
-- * structure with the following data
--[[
	{
		conn = <connector structure>,	-- Connector structure to whom this segment belongs to 
		seg = <integer>					-- segment index of the connector
	}
]]
-- IDMAP is a mapping of IDs from the data in the loaded canvas to the id of the data in the file
--		It has only object and connector ids since ports are attached to objects
function newComponent(file,fileDat,items,IDMAP)
	components.ids = components.ids + 1
	components[#components + 1] = {
			id = "CM"..tostring(components.ids),
			file = file,
			items = {},
			IDMAP = tu.copyTable(IDMAP,{})
	}
	local index = #components
	local dData = tu.s2tr(fileDat)
	local it = components[#components].items
	for i = 1,#items do
		if items[i].id then
			-- This is a object
			it[#it + 1] = setmetatable({
					type = "object",
					obj = items[i],
				},WEAKV)
			-- Find the object in the dData to store the anchor point as the 1st coordinate of the object
			-- This is done so that if this object is used for alignment when loading the component then
			--  	xa,ya coordinate in the file will aligned to the 1st coordinate of this object on the canvas
			for j = 1,#dData.obj do
				if dData.obj[j].id == IDMAP[items[i].id] then
					it[#it].xa = dData.obj[j].x[1]
					it[#it].ya = dData.obj[j].y[1]
					break
				end
			end
		else
			-- This is a segment
			it[#it + 1] = setmetatable({
					type = "segment",
					conn = items[i].conn,
					seg = items[i].conn.segments[items[i].seg]
				},WEAKV)
		end
	end
	-- Setup and return the undo/redo functions
	local c,undo,redo
	redo = function()
		table.insert(components,index,restoreComponent(c))
		return undo
	end
	undo = function()
		-- Create a backup of the component structure to be used for the undo function
		c = backupComponent(components[index])
		table.remove(components,index)
		return redo
	end
	-- Add the undo function
	unre.addUndoFunction(undo)
	return copyComponent(components[#components])
end

-- Function to return a table that can be saved with the current state of the drawn elements to load it with them and maintain component linkages to the files
function saveComponents()
	local tab = {}
	for i = 1,#components do
		tab[#tab + 1] = backupComponent(components[i])
	end
	return tab
end

-- Function to load the components given in comps into the components structure
-- THe function should be called after the file with the components is loaded in the memory using the Lua-GL load function
-- items is the list of items returned by the lua-gl load function when the loading is done
-- IDMAP is the mapping of the IDs in the loaded structure to IDs in the file. This is also returned by the Lua-gl load function
-- comps is the saved components table as returned by saveComponents function above
function loadComponents(comps,items,IDMAP)
	local retList = {}
	local ci = {}	-- To store indexes of all the components added
	local undo,redo
	for i = 1,#comps do
		components.ids = components.ids + 1
		components[#components + 1] = {
				id = "CM"..tostring(components.ids),
				file = comps[i].file,
				items = {},
				IDMAP = {}
		}
		ci[#ci + 1] = #components
		-- Now add the items for this component
		local itd = components[#components].items
		local its = comps[i].items
		local function getLoadedID(id)
			for k,v in pairs(IDMAP) do
				if v == id then
					return k
				end
			end
		end
		local function getItemFromID(id)
			for i = 1,#items do
				if items[i].id and items[i].id == id then
					return items[i]
				elseif items[i].conn and items[i].conn.id == id then
					return items[i].conn, items[i].conn.segments[items[i].seg]
				end
			end
		end
		for j = 1,#its do
			itd[#itd + 1] = setmetatable({
				type = its[j].type
			},WEAKV)
			if its[j].type == "object" then
				itd[#itd].xa = its[j].xa
				itd[#itd].ya = its[j].ya
				itd[#itd].obj = getItemFromID(getLoadedID(its[j].obj))
			else
				local conn,seg = getItemFromID(getLoadedID(its[j].conn))
				itd[#itd].conn = conn
				itd[#itd].seg = seg
			end
		end
		local ids = comps[i].IDMAP
		local idd = components[#components].IDMAP
		for k,v in pairs(ids) do
			idd[getLoadedID(k)] = v
		end
		retList[#retList + 1] = components[#components].id
	end		-- for i = 1,#comps do ends
	table.sort(ci)
	local c
	redo = function()
		for i = #ci,1,-1 do
			table.insert(components,ci[i],restoreComponent(c[i-#c+1]))
		end
		return undo
	end
	undo = function()
		c = {}
		-- Create a backup of the component structure to be used for the undo function
		for i = #ci,1,-1 do 
			c[#c+1] = backupComponent(components[ci[i]])
			table.remove(components,ci[i])
		end
		return redo
	end
	-- Add the undo function
	unre.addUndoFunc(undo)
	return retList	
end

function init(cnvO)
	cnvobj = cnvO
end

