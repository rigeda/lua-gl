-- Module to manage file linked components in DemoProject

local setmetatable = setmetatable
local tostring = tostring
local pairs = pairs
local table = table

local tu = require("tableUtils")


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
Here items is a table where an entry for object structure is a weak value table having the 2 entries:
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

function getComponentFromID(id)
	local ind
	for i = 1,#components do
		if components[i].id == id then
			ind = i 
			break
		end
	end
	if not ind then
		return
	end
	-- Create a copy of the component
	return copyComponent(components[ind])
end

function getComponentFromFile(file)
	local ind
	for i = 1,#components do
		if components[i].file == file then
			ind = i
			break
		end
	end	
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
	for i = 1,#components do
		if components[i].id == id then
			table.remove(components,i)
			break
		end
	end
	return true
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
	return copyComponent(components[#components])
end

-- Function to return a table that can be saved with the current state of the drawn elements to load it with them and maintain component linkages to the files
function saveComponents()
	local tab = {}
	for i = 1,#components do
		tab[#tab + 1] = {
			id = components[i].id,
			file = components[i].file,
			items = {},
			IDMAP = tu.copyTable(components[i].IDMAP,{}),
		}
		local it = tab[#tab].items
		for j = 1,#components[i].items do
			it[#it + 1] = {
				type = components[i].items[j].type
			}			
			if it[#it].type == "object" then
				it[#it].xa = components[i].items[j].xa
				it[#it].ya = components[i].items[j].ya
				it[#it].obj = components[i].items[j].obj.id
			else
				-- connector
				it[#it].conn = components[i].items[j].conn.id
				it[#it].seg = tu.inArray(components[i].items[j].conn,components[i].items[j].seg)
			end
		end
	end
	return tab
end

-- Function to load the components given in comps into the components structure
-- THe function should be called after the file with the components is loaded in the memory using the Lua-GL load function
-- items is the list of items returned by the lua-gl load function when the loading is done
-- IDMAP is the mapping of the IDs in the loaded structure to IDs in the file. This is also returned by the Lua-gl load function
-- comps is the saved components table as returned by saveComponents function above
function loadComponents(comps,items,IDMAP)
	for i = 1,#comps do
		components.ids = components.ids + 1
		components[#components + 1] = {
				id = "CM"..tostring(components.ids),
				file = comps[i].file,
				items = {},
				IDMAP = {}
		}		
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
	end
	return true
end

