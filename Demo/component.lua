-- Module to manage file linked components in DemoProject

local setmetatable = setmetatable
local tostring = tostring
local pairs = pairs

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
	items = {}
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
local WEAKV = {__mode="v"}	-- metatable to set weak keys

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

