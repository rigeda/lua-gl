-- Module in DemoProject for attaching objects to connectors

local tostring = tostring
local collectgarbage = collectgarbage
local next = next
local floor = math.floor
local sqrt = math.sqrt
local table = table

local unre = require("undoredo")
local tu = require("tableUtils")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- netobj structure is an array of tables. Each table is a weak value table with the following elements:
--[[
{
	id = <string>,				-- ID of the net object
	obj = <luagl object>,		-- object structure
	xa = <integer>,				-- The anchor points of the obj
	ya = <integer>,				-- The anchor points of the obj
	conn = <lua-gl connector>,	-- connector structure
	seg = <lua-gl segment>,		-- segment structure
	x1 = <integer>,				-- segment startx
	y1 = <integer>,				-- segment starty
	x2 = <integer>,				-- segment endx
	y2 = <integer>				-- segment endy
	segTree = <table>			-- structure containing 
}
]]
local netobjs, PAUSE
local hook,cnvobj

-- Function to backup a netobj
-- It does not point to the actual object/connector/segment structures in the Lua-GL data structures. 
-- This is helpful because undo/redo options may change the table addresses. So it is better to refer them from their values
local function backupNetObj(no)
	local n = {
		id = no.id,
		obj = no.obj,
		xa = no.xa,
		ya = no.ya,
		conn = no.conn,
		x1 = no.x1,
		y1 = no.y1,
		x2 = no.x2,
		y2 = no.y2,
		segTree = no.segTree,
		seg = no.seg
	}
	return n
end

-- Function to restore the backed up netobj as returned by backupNetObj function
local function restoreNetObj(no)
	local n = {
		id = no.id,
		xa = no.xa,
		ya = no.ya,
		obj = no.obj,
		x1 = no.x1,
		x2 = no.x2,
		y1 = no.y1,
		y2 = no.y2,
		conn = no.conn,
		segTree = no.segTree,
		seg = no.seg
	}
	return n
end

function deleteNetObj(id)
	local index = tu.inArray(netobjs,id,function(no,id) return no.id == id end)
	if index then
		-- Setup and return the undo/redo functions
		local no,undo,redo
		undo = function()
			table.insert(netobjs,index,restoreNetObj(no))
			return redo
		end
		redo = function()
			-- Create a backup of the component structure to be used for the undo function
			no = backupNetObj(netobjs[index])
			table.remove(netobjs,index)
			return undo
		end
		redo()
		-- Add the undo function
		unre.addUndoFunction(undo)
		return true	-- id found and deleted
	end
	return false	-- id not found
end

-- Function to update the position of all net objects
local function updateNetobjPos()
	if PAUSE then
		return
	end
	PAUSE = true
	-- Add this to previous group
	local unregrp = unre.continueGroup()
	-- Loop through each netobj and check if any needs to be moved
	collectgarbage()	-- Clean up any segments/connectors that were deleted
	for i = 1,#netobjs do
		local no = netobjs[i]
		local obj = cnvobj:getObjFromID(no.obj)
		-- Check if the obj exists
		if not obj then
			-- Object no longer there
			-- Add this undo to previous group
			unregrp = unregrp or unre.continueGroup()
			deleteNetObj(no.id)
		-- Check if the segment exists
		else
			-- Check if the segment exists
			-- For the segment to exist the connector should exist (with the same ID) and the segment at the index should match up with the stored coordinates
			local segExist
			local c = cnvobj:getConnFromID(no.conn)
			if c then
				local seg = c.segments[no.seg]
				if seg and seg.start_x == no.x1 and seg.start_y == no.y1 and seg.end_x == no.x2 and seg.end_y == no.y2 then
					segExist = true
				end
			end
			if not segExist then
				local n = backupNetObj(no)
				-- segment does not exist
				-- Go through the segTree to find another segment where to move the netobj
				local st = no.segTree
				-- Step through the segTree
				local found
				for j = 1,#st do
					-- CHeck if any segments exist at this step
					local k,v = next(st[j].segs)
					local segI = tu.inArray(c.segments,v)
					if cnvobj:checkSegment(v) and segI then
						found = true
						-- Attach the netobj to this segment (v)
						-- New anchor point
						local xn,yn = floor((v.start_x + v.end_x)/2),floor((v.start_y+v.end_y)/2)
						local offx,offy = xn-no.xa,yn-no.ya
						-- Add this to previous group
						unregrp = unregrp or unre.continueGroup()
						cnvobj:dragObj({obj},offx,offy)
						no.xa = xn
						no.ya = yn
						no.seg = segI
						no.x1 = v.start_x
						no.y1 = v.start_y
						no.x2 = v.end_x
						no.y2 = v.end_y
						no.segTree = cnvobj:getSegTree(c,v)
						break
					end				
				end
				if not found then
					-- Check if there are any ports that it can connect to to 
					for j = 1,#st do
						-- Check if there are any ports
						local k,v = next(st[j].ports)
						if cnvobj:checkPort(v) then
							if #v.conn > 0 then
								found = true
								-- Attach to any other segment connected to the port
								local c,s = cnvobj:getConnFromXY(v.x,v.y)
								local conn = cnvobj.drawn.conn[s[1].conn]
								local seg = conn.segments[s[1].seg[1]]
								-- Attach the netobj to this segment (seg)
								-- New anchor point
								local xn,yn = floor((seg.start_x + seg.end_x)/2),floor((seg.start_y+seg.end_y)/2)
								local offx,offy = xn-no.xa,yn-no.ya
								-- Add this to previous group
								unregrp = unregrp or unre.continueGroup()
								cnvobj:dragObj({obj},offx,offy)
								no.xa = xn
								no.ya = yn
								no.seg = s[1].seg[1]
								no.conn = conn.id
								no.x1 = seg.start_x
								no.y1 = seg.start_y
								no.x2 = seg.end_x
								no.y2 = seg.end_y
								no.segTree = cnvobj:getSegTree(conn,seg)
								break
							end
						end
					end		-- for j = 1,#st do ends
				end		-- if not found then ends
				if not found then
					-- Add this to previous group
					unregrp = unregrp or unre.continueGroup()
					-- Remove the netobj entry
					deleteNetObj(no.id)
				else
					-- Setup and return the undo/redo functions
					local undo
					local index = i
					local prevno = n
					--local o = obj
					undo = function()
						-- Backup the netobj
						local bac = backupNetObj(netobjs[index])
						local no = netobjs[index]
						-- Drag the object
						--cnvobj:drag({o},prevno.xa-no.xa,prevno.ya-no.ya)
						-- Delete the netobj
						table.remove(netobjs,index)
						-- Restore the backed up component structure
						table.insert(netobjs,index,restoreNetObj(prevno))
						prevno = bac
						return undo
					end
					-- Add this to previous group
					unregrp = unregrp or unre.continueGroup()
					-- Add the undo function
					unre.addUndoFunction(undo)
				end
			end
		end		-- if not cnvobj:getObjFromID(no.obj) then else ends here
	end		-- for i = 1,#netobjs do ends
	unre.endGroup(unregrp)
	PAUSE = nil
end

-- Function to create a new netobj entry
-- cs is a table with keys:
--	* conn - index of the connector in cnvobj.drawn.conn
--  * seg - index of the segment in the connector to which the object needs to be attached
-- x,y is the anchor coordinate for the object. This coordinate would be on the segment
function newNetobj(obj,cs,x,y)
	netobjs.ids = netobjs.ids + 1
	local seg = cnvobj.drawn.conn[cs.conn].segments[cs.seg]
	local segTree = cnvobj:getSegTree(cnvobj.drawn.conn[cs.conn],seg)  -- Get the segment tree from cs to move netobj to the right segment
	local no = {
		id = "NO"..tostring(netobjs.ids),
		obj = obj.id,
		xa = x,	-- The anchor points of the obj
		ya = y,	-- The anchor points of the obj
		conn = cnvobj.drawn.conn[cs.conn].id,	-- connector id
		seg = cs.seg,		-- store the segment index
		x1 = seg.start_x,
		y1 = seg.start_y,
		x2 = seg.end_x,
		y2 = seg.end_y,
		segTree = segTree,
	}
	netobjs[#netobjs + 1] = no
	local index = #netobjs
	-- Setup and return the undo/redo functions
	local n,undo,redo
	undo = function()
		-- Create a backup of the component structure to be used for the undo function
		n = backupNetObj(netobjs[index])
		table.remove(netobjs,index)
		return redo
	end
	redo = function()
		-- Restore the backed up component structure
		table.insert(netobjs,index,restoreNetObj(n))
		return undo
	end
	-- Add the undo function
	unre.addUndoFunction(undo)
	return no
end

function init(cnvO)
	cnvobj = cnvO
	netobjs = {ids=0}
	hook = cnvobj:addHook("UNDOADDED",updateNetobjPos,"To update netobj positions")
end
