-- Module in DemoProject for attaching objects to connectors

local tostring = tostring
local setmetatable = setmetatable
local collectgarbage = collectgarbage
local next = next
local floor = math.floor
local sqrt = math.sqrt

local unre = require("undoredo")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local netobjs = {ids=0}
local hook,cnvobj
local WEAKV = {__mode="v"}	-- metatable to set weak values

function deleteNetObj(id)
	for i = 1,#netobjs do
		if netobjs[i].id == id then
			table.remove(netobjs,i)
			return true	-- id found and deleted
		end
	end
	return false	-- id not found
end

-- Function to update the position of all net objects
local function updateNetobjPos()
	-- Remove the hook
	cnvobj:removeHook(hook)
	-- Pause undo-redo
	unre.pauseUndoRedo()
	-- Loop through each netobj and check if any needs to be moved
	collectgarbage()	-- Clean up any segments/connectors that were deleted
	for i = 1,#netobjs do
		local no = netobjs[i]
		-- Check if the obj exists
		if not no.obj then
			deleteNetObj(no.id)
		-- Check if the segment exists
		elseif not no.seg then
			-- segment does not exist
			-- Go through the segTree to find another segment where to move the netobj
			local st = no.segTree
			-- Step through the segTree
			local found
			for j = 1,#st do
				-- CHeck if any segments exist at this step
				local k,v = next(st[j].segs)
				if k then
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
					break
				end				
			end
			if not found then
				-- Check if there are any ports that it can connect to to 
				for j = 1,#st do
					-- Check if there are any ports
					local k,v = next(st[j].ports)
					if k then
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
							break
						end
					end
				end		-- for j = 1,#st do ends
			end		-- if not found then ends
			if not found then
				-- Remove the netobj entry
				deleteNetObj(no.id)
			end
		else
			-- segment exists
			-- Check if it moved then move the netobj accordingly
			if no.seg.start_x ~= no.x1 or no.seg.start_y ~= no.y1 or no.seg.end_x ~= no.x2 or no.seg.end_y ~= no.y2 then
				-- Segment was moved so move the netobj
				local nx1,ny1,nx2,ny2 = no.seg.start_x,no.seg.start_y,no.seg.end_x,no.seg.end_y
				-- THe new anchor xb,yb are defined as:
				-- xb = sqrt(L/(m+1))+nx1
				-- yb = m(xb-nx1)+ny1
				-- Where m = (ny2-ny1)/(nx2-nx1)
				-- 		      (ny2-ny1)^2 + (nx2-nx1)^2
				--       L = --------------------------- ( (ya-y1)^2 + (xa-x1)^2 )
				--            (y2-y1)^2 + (x2-x1)^2
				local ndy = ny2-ny1
				local ndx = nx2-nx1
				local m = ndy/ndx
				local L = (ndy^2+ndx^2)*((no.ya-no.y1)^2+(no.xa-no.x1)^2)/((no.y2-no.y1)^2+(no.x2-no.x1)^2)
				local xb = floor(sqrt(L/(m+1)))+nx1
				local yb = floor(m*(xb-nx1)) + ny1
				no.xa = xb
				no.ya = yb
				no.x1 = nx1
				no.y1 = ny1
				no.x2 = nx2
				no.y2 = ny2
				no.segTree = cnvobj:getSegTree(no.conn,no.seg)
			end
		end
	end		-- for i = 1,#netobjs do ends
	-- Resume Undo Redo
	unre.resumeUndoRedo()
	hook = cnvobj:addHook("UNDOADDED",updateNetobjPos,"To update netobj positions")
end

function newNetobj(obj,cs,x,y)
	netobjs.ids = netobjs.ids + 1
	local seg = cnvobj.drawn.conn[cs.conn].segments[cs.seg]
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
		y2 = seg.end_y
		segTree = cnvobj:getSegTree(cnvobj.drawn.conn[cs.conn],seg)	-- Get the segment tree from cs to move netobj to the right segment
	},WEAKV)
	netobj[#netobjs + 1] = no
	return no
end

function init(cnvO)
	local cnvobj = cnvO
	hook = cnvobj:addHook("UNDOADDED",updateNetobjPos,"To update netobj positions")
end
