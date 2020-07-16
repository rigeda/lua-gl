-- Module in DemoProject for attaching objects to connectors

local tostring = tostring
local setmetatable = setmetatable
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
local netobjs = {ids=0}
local hook,cnvobj
local WEAKV = {__mode="v"}	-- metatable to set weak values

-- Function to backup a netobj
-- It does not point to the actual object/connector/segment structures in the Lua-GL data structures. 
-- This is helpful because undo/redo options may change the table addresses. So it is better to refer them from their values
local function backupNetObj(no)
	local n = {
		id = no.id,
		obj = no.obj and no.obj.id,
		xa = no.xa,
		ya = no.ya,
		conn = no.conn and no.conn.id,
		x1 = no.x1,
		y1 = no.y1,
		x2 = no.x2,
		y2 = no.y2,
		segTree = no.segTree
	}
	local i = tu.inArray(no.conn.segments,no.seg)
	if i then
		n.seg = i
	end
	return n
end

-- Function to restore the backed up netobj as returned by backupNetObj function
local function restoreNetObj(no)
	local n = {
			id = no.id,
			xa = no.xa,
			ya = no.ya,
			obj = no.obj and cnvobj:getObjFromID(no.obj),
			x1 = no.x1,
			x2 = no.x2,
			y1 = no.y1,
			y2 = no.y2,
			conn = no.conn and cnvobj:getConnFromID(no.conn),
			segTree = no.segTree,
			[no.segTree] = true
	}
	n.seg = no.conn and no.seg and n.conn.segments[no.seg] 
	return n
end

function deleteNetObj(id)
	local index
	for i = 1,#netobjs do
		if netobjs[i].id == id then
			index = i
			break
		end
	end
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
	-- Remove the hook
	cnvobj:removeHook(hook)
	-- Add this to previous group
	local unregrp = unre.continueGroup()
	-- Loop through each netobj and check if any needs to be moved
	collectgarbage()	-- Clean up any segments/connectors that were deleted
	for i = 1,#netobjs do
		local no = netobjs[i]
		-- Check if the obj exists
		if not cnvobj:checkObj(no.obj) then
			deleteNetObj(no.id)
		-- Check if the segment exists
		elseif not cnvobj:checkSegment(no.seg) then
			local n = backupNetObj(no)
			-- segment does not exist
			-- Go through the segTree to find another segment where to move the netobj
			local st = no.segTree
			-- Step through the segTree
			local found
			for j = 1,#st do
				-- CHeck if any segments exist at this step
				local k,v = next(st[j].segs)
				if cnvobj:checkSegment(v) then
					found = true
					-- Attach the netobj to this segment (v)
					-- New anchor point
					local xn,yn = floor((v.start_x + v.end_x)/2),floor((v.start_y+v.end_y)/2)
					local offx,offy = xn-no.xa,yn-no.ya
					cnvobj:dragObj({no.obj},offx,offy)
					no.xa = xn
					no.ya = yn
					no.seg = v
					no.x1 = v.start_x
					no.y1 = v.start_y
					no.x2 = v.end_x
					no.y2 = v.end_y
					no.segTree = cnvobj:getSegTree(no.conn,v)
					no[no.segTree] = true
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
							cnvobj:dragObj({no.obj},offx,offy)
							no.xa = xn
							no.ya = yn
							no.seg = seg
							no.conn = conn
							no.x1 = seg.start_x
							no.y1 = seg.start_y
							no.x2 = seg.end_x
							no.y2 = seg.end_y
							no.segTree = cnvobj:getSegTree(conn,seg)
							no[no.segTree] = true
							break
						end
					end
				end		-- for j = 1,#st do ends
			end		-- if not found then ends
			if not found then
				-- Remove the netobj entry
				deleteNetObj(no.id)
			else
				-- Setup and return the undo/redo functions
				local undo
				undo = function()
					-- Backup the netobj
					local bac = backupNetObj(netobjs[i])
					local no = netobjs[i]
					-- Drag the object
					cnvobj:drag({no.obj},n.xa-no.xa,n.ya-no.ya)
					-- Delete the netobj
					table.remove(netobjs,i)
					-- Restore the backed up component structure
					table.insert(netobjs,i,restoreNetObj(n))
					n = bac
					return undo
				end
				-- Add the undo function
				unre.addUndoFunction(undo)
			end
		else
			-- segment exists
			-- Check if it moved then move the netobj accordingly
			if no.seg.start_x ~= no.x1 or no.seg.start_y ~= no.y1 or no.seg.end_x ~= no.x2 or no.seg.end_y ~= no.y2 then
				local n = backupNetObj(no)
				-- Segment was moved so move the netobj
				local nx1,ny1,nx2,ny2 = no.seg.start_x,no.seg.start_y,no.seg.end_x,no.seg.end_y
				-- The new anchor xb,yb are defined as:
				-- xb = +/-sqrt(A2sq/(m^2+1))+nx2		-- + when nx1 > nx2 or ny1 > ny2
				-- yb = m(xb-nx1)+ny1
				-- Where m = (ny2-ny1)/(nx2-nx1)
				-- 		      (ny2-ny1)^2 + (nx2-nx1)^2
				--       A2sq = --------------------------- ( (ya-y1)^2 + (xa-x1)^2 )
				--            (y2-y1)^2 + (x2-x1)^2
				local ndy = ny2-ny1
				local ndx = nx2-nx1
				local m = ndx==0 and 0 or ndy/ndx
				local A2sq = (ndy^2+ndx^2)*((no.ya-no.y1)^2+(no.xa-no.x1)^2)/((no.y2-no.y1)^2+(no.x2-no.x1)^2)
				local xb,yb
				if ny1 < ny2 then
					if nx1 == nx2 then
						xb = nx2
						yb = ny2 - floor(sqrt(A2sq))
					else
						xb = nx2 - floor(sqrt(A2sq/(m^2+1)))
						yb = floor(m*(xb-nx2)) + ny2
					end
				else
					if nx1 == nx2 then
						xb = nx2
						yb = ny2 + floor(sqrt(A2sq))
					else
						xb = nx2 + floor(sqrt(A2sq/(m^2+1)))
						yb = floor(m*(xb-nx2)) + ny2
					end
				end
				cnvobj:drag({no.obj},xb-no.xa,yb-no.ya)
				no.xa = xb
				no.ya = yb
				no.x1 = nx1
				no.y1 = ny1
				no.x2 = nx2
				no.y2 = ny2
				no.segTree = cnvobj:getSegTree(no.conn,no.seg)
				no[no.segTree] = true
				-- Setup and return the undo/redo functions
				local undo
				undo = function()
					-- Backup the netobj
					local bac = backupNetObj(netobjs[i])
					local no = netobjs[i]
					-- Drag the object
					cnvobj:drag({no.obj},n.xa-no.xa,n.ya-no.ya)
					-- Delete the netobj
					table.remove(netobjs,i)
					-- Restore the backed up component structure
					table.insert(netobjs,i,restoreNetObj(n))
					n = bac
					return undo
				end
				-- Add the undo function
				unre.addUndoFunction(undo)
			end
		end
	end		-- for i = 1,#netobjs do ends
	-- End the undo group
	unre.endGroup(unregrp)
	hook = cnvobj:addHook("UNDOADDED",updateNetobjPos,"To update netobj positions")
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
	local no = setmetatable({
		id = "NO"..tostring(netobjs.ids),
		obj = obj,
		xa = x,	-- The anchor points of the obj
		ya = y,	-- The anchor points of the obj
		conn = cnvobj.drawn.conn[cs.conn],
		seg = seg,
		x1 = seg.start_x,
		y1 = seg.start_y,
		x2 = seg.end_x,
		y2 = seg.end_y,
		segTree = segTree,
		[segTree] = true,	-- To prevent segTree from being garbage collected
	},WEAKV)
	netobjs[#netobjs + 1] = no
	local index = #netobjs
	-- Setup and return the undo/redo functions
	local n,undo,redo
	undo = function()
		-- Restore the backed up component structure
		table.insert(netobjs,index,restoreNetObj(n))
		return redo
	end
	redo = function()
		-- Create a backup of the component structure to be used for the undo function
		n = backupNetObj(netobjs[index])
		table.remove(netobjs,index)
		return undo
	end
	-- Add the undo function
	unre.addUndoFunction(undo)
	return no
end

function init(cnvO)
	cnvobj = cnvO
	hook = cnvobj:addHook("UNDOADDED",updateNetobjPos,"To update netobj positions")
end
