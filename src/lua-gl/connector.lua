-- Module to handle connectors for lua-gl

local table = table
local type = type
local floor = math.floor
local min = math.min
local tonumber = tonumber
local error = error
local pairs = pairs
local tostring = tostring
local iup = iup

local tu = require("tableUtils")
local coorc = require("lua-gl.CoordinateCalc")
local router = require("lua-gl.router")

-- Only for debug
local print = print

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- The connector structure looks like this:
--[[
{
	id = <string>,		-- unique ID for the connector. Format is C<num> i.e. C followed by a unique number
	order = <integer>,	-- Index in the order array
	segments = {	-- Array of segment structures
		[i] = {
			start_x = <integer>,		-- starting coordinate x of the segment
			start_y = <integer>,		-- starting coordinate y of the segment
			end_x = <integer>,			-- ending coordinate x of the segment
			end_y = <integer>			-- ending coordinate y of the segment
		}
	},
	port = {		-- Array of port structures to which this connector is connected to. Needed back info to merge or delete connectors
		[i] = <port structure>,
	},
	junction = {	-- Array of junction structures
		[i] = {
			x = <integer>,		-- X coordinate of the junction
			y = <integer>		-- Y coordinate of the junction
		},
	}
}
]]
-- The connector structure is located in the array cnvobj.drawn.conn
-- Note a connector never crosses a port. If a port is placed on a connector the connector is split into 2 connectors, one on each side of the port.

-- Returns the connector structure given the connector ID
getConnFromID = function(cnvobj,connID)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	if not connID or not connID:match("C%d%d*") then
		return nil,"Need valid connector id"
	end
	local conn = cnvobj.drawn.conn
	for i = 1,#conn do
		if conn[i].id == connID then
			return conn[i]
		end
	end
	return nil,"No connector found"
end

-- Function to return the list of all connectors and at the vicinity measured by res. res=0 means x,y should be on the connector
-- If res is not given then it is taken as the minimum of grid_x/2 and grid_y/2
-- Returns the list of all the connectors
-- Also returns a list of tables containing more information. Each table is:
--[[
{
	conn = <integer>,	-- index of the connector in cnvobj.drawn.conn
	seg = {				-- array of indices of segments that were found on x,y for the connector
		<integer>,
		<inteher>,
		...
	}
}
]]
getConnFromXY = function(cnvobj,x,y,res)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	local conns = cnvobj.drawn.conn
	if #conns == 0 then
		return {}
	end
	res = res or floor(min(cnvobj.grid.grid_x,cnvobj.grid.grid_y)/2)
	local pS = res == 0 and coorc.pointOnSegment or coorc.pointNearSegment
	local allConns = {}
	local segInfo = {}
	for i = 1,#conns do
		local segs = conns[i].segments
		local connAdded
		for j = 1,#segs do
			if pS(segs[j].start_x, segs[j].start_y, segs[j].end_x, segs[j].end_y, x, y, res)  then
				if not connAdded then
					allConns[#allConns + 1] = conns[i]
					segInfo[#segInfo + 1] = {conn = i, seg = {j}}
					connAdded = true
				else
					segInfo[#segInfo].seg[#segInfo[#segInfo].seg + 1] = j	-- Add all segments that lie on that point
				end
			end
		end
	end
	return allConns, segInfo
end

local function equalCoordinate(v1,v2)
	return v1.x == v2.x and v1.y == v2.y
end

-- Function to fix the order of all the items in the order table
local function fixOrder(cnvobj)
	-- Fix the order of all the items
	for i = 1,#cnvobj.drawn.order do
		cnvobj.drawn.order[i].item.order = i
	end
	return true
end

-- Function to check whether 2 line segments have the same line equation or not
-- The 1st line segment is from x1,y1 to x2,y2
-- The 2nd line segment is from x3,y3 to x4,y4
local function sameeqn(x1,y1,x2,y2,x3,y3,x4,y4)
	local seqn 
	if x1==x2 and x3==x4 and x1==x3 then
		-- equation is x = c for both lines
		seqn = true
	elseif x1~=x2 and x3~=x4 then
		-- equation x = c is not true for both lines
		-- round till 0.01 resolution
		local m1 = floor((y2-y1)/(x2-x1)*100)/100
		local m2 = floor((y4-y3)/(x4-x3)*100)/100
		-- Check slopes are equal and the y-intercept are the same
		if m1 == m2 and floor((y1-x1*m1)*100) == floor((y3-x3*m2)*100) then
			seqn = true
		end
	end
	return seqn
end

-- Function to find the dangling nodes. 
-- Dangling end point is defined as one which satisfies the following:
-- * The end point does not match the end points of any other segment or
-- * The end point matches the end point of only 1 segment with the same line equation
-- AND (if chkports is true)
-- * The end point does not lie on a port
-- It returns 2 tables s,e. Segment ith has starting node dangling if s[i] == true and has ending node dangling if e[i] == true
local function findDangling(cnvobj,segs,chkports)
	local s,e = {},{}		-- Starting and ending node dangling segments indexes
	for i = 1,#segs do
		local sx,sy,ex,ey = segs[i].start_x,segs[i].start_y,segs[i].end_x,segs[i].end_y
		local founds,founde = {c = 0},{c = 0}	-- To store the last segment that connected to the coordinates of this segment and also the count of total segments
		for j = 1,#segs do
			if j ~= i then
				local sx1,sy1,ex1,ey1 = segs[j].start_x,segs[j].start_y,segs[j].end_x,segs[j].end_y
				if sx == sx1 and sy == sy1 or sx == ex1 and sy == ey1 then
					founds.c = founds.c + 1
					founds.x1 = sx1
					founds.y1 = sy1
					founds.x2 = ex1
					founds.y2 = ey1
				end
				if ex == sx1 and ey == sy1 or ex == ex1 and ey == ey1 then
					founde.c = founde.c + 1
					founde.x1 = sx1
					founde.y1 = sy1
					founde.x2 = ex1
					founde.y2 = ey1
				end
			end
		end
		if founds.c < 2 then
			-- Starting node connects to 1 or 0 segments
			local chkPorts = true
			if founds.c == 1 then
				if not sameeqn(sx,sy,ex,ey,founds.x1,founds.y1,founds.x2,founds.y2) then
					if not chkports then
						s[i] = true
					else
						chkPorts = false
					end
				end
			end
			-- Starting node is dangling check if it connects to any port
			if chkPorts and #cnvobj:getPortFromXY(sx,sy) == 0 then
				s[i] = true		-- segment i starting point is dangling
			end
		end
		if founde.c < 2 then
			-- Ending node connects to 1 or 0 segments
			local chkPorts = true
			if founde.c == 1 then
				if not sameeqn(sx,sy,ex,ey,founde.x1,founde.y1,founde.x2,founde.y2) then
					if not chkports then
						e[i] = true
					else
						chkPorts = false
					end
				end
			end
			-- Ending node is dangling, check if it connects to any port
			if chkPorts and #cnvobj:getPortFromXY(ex,ey) == 0 then
				e[i] = true		-- segment i ending point is dangling
			end
		end
	end		-- for i = 1,#segs do ends here
	return s,e
end

-- Function to check whether segments are valid and if any segments need to be split further or merged and overlaps are removed and junctions are regenerated
-- This function does not touch the ports of the connector nor check their validity
local function repairSegAndJunc(cnvobj,conn)
	
	-- First find the dangling nodes. Note that dangling segments are the ones which may merge with other segments
	-- Dangling end point is defined as one which satisfies the following:
	-- * The end point does not match the end points of any other segment or
	-- * The end point matches the end point of only 1 segment with the same line equation
	-- AND
	-- * The end point does not lie on a port
	local segs = conn.segments
	local rm = cnvobj.rM
	local s,e = findDangling(cnvobj,segs,true)	-- find dangling with port check enabled
	-- Function to create segments given the coordinate pairs
	-- Segment is only created if its length is > 0
	-- coors is an array of coordinates. Each entry has the following table:
	-- {x1,y1,x2,y2} where x1,y1 and x2,y2 represent the ends of the segment to create
	local function createSegments(coors)
		local segs = {}
		for i =1,#coors do
			if not(coors[i][1] == coors[i][3] and coors[i][2] == coors[i][4]) then	-- check if both the end points are the same coordinate
				segs[#segs + 1] = {
					start_x = coors[i][1],
					start_y = coors[i][2],
					end_x = coors[i][3],
					end_y = coors[i][4]
				}
			end
		end
		return segs
	end

	-- Now check for overlaps of the dangling segments with others
	local i = 1
	while i <= #segs do
		-- Let A = x1,y1 and B=x2,y2. So AB is 1 line segment
		local x1,y1,x2,y2 = segs[i].start_x,segs[i].start_y,segs[i].end_x,segs[i].end_y
		local adang,bdang = s[i],e[i]
		local overlap,newSegs
		local j = 1
		while j <= #segs do
			if i ~= j then
				-- Let C=x3,y3 and D=x4,y4. So CD is 2nd line segment
				local x3,y3,x4,y4 = segs[j].start_x,segs[j].start_y,segs[j].end_x,segs[j].end_y
				local cdang,ddang = s[j],e[j]
				-- Check whether the 2 line segments have the same line equation
				if sameeqn(x1,y1,x2,y2,x3,y3,x4,y4) then
					overlap = j		-- Assume they overlap
					-- There are 8 overlapping cases and 4 non overlapping cases
					--[[
					1. (no overlap)
								A-----------B
					C------D	
					2. (overlap) The merge is 3 segments CA, AD and DB. If A and D are dangling then merged is CB. If A is dangling then merged is CD, DB. If D is dangling then merged is CA, AB
						A-----------B
					C------D	
					3. (overlap) The merge is 3 segments AC CD and DB. If C and D are dangling then merged is AB. If C is dangling then merged are AD and DB. If D is dangling then merged are AC and CB
					  A-----------B
						C------D	
					4. (overlap) The merge is 3 segments AC, CB and BD. If B and C are dangling then merged is AD. If C is dangling then merged is AB, BD. If B is dangling then merged are AC and CD
					  A-----------B
							  C------D	
					5. (no overlap)
						A-----------B
										C------D	
					6. (overlap) The merge is 3 segments CA, AB and BD. If A and B are dangling then merged is CD. If A is dangling then merged are CB and BD. If B is dangling then merged are CA and AD
					  C-----------D
						A------B	
					7. (no overlap)
								A-----------B
					D------C	
					8. (overlap) The merge is 3 segments DA, AC and CB. If A and C are dangling then merged is DB. If A is dangling then merged is DC and CB. If C is dangling then merged is DA and AB
						A-----------B
					D------C	
					9. (overlap) The merge is 3 segments AC, CD and DB. If C and D are dangling then merged is AB. If D is dangling then merged are AC and CB. If C is dangling then merged are AD and DB
					  A-----------B
						D------C	
					10. (overlap) The merge is 3 segments AD, DB and BC. If B and D are dangling then merged is AC. If B is dangling then merged are AD and DC. If D is dangling then mergedf are AB and BC
					  A-----------B
							  D------C	
					11. (no overlap)
						A-----------B
										D------C
					12. (overlap) The merge is 3 segments DA, AB and BC. If A and B are dangling then merged is DC. If A is dangling then merged are DB and BC. If B is dangling then merged are DA and AC
					  D-----------C
						A------B	
					
					]]
					if coorc.pointOnSegment(x1,y1,x2,y2,x3,y3) then	
						-- C lies on AB - Cases 3,4,8,9
						if coorc.pointOnSegment(x1,y1,x2,y2,x4,y4) then
							-- D lies on AB - Cases 3 and 9
							if coorc.pointOnSegment(x1,y1,x4,y4,x3,y3) then
								-- C lies on AD - Case 3
					--[[
					3. (overlap) The merge is 3 segments AC CD and DB. If C and D are dangling then merged is AB. If C is dangling then merged are AD and DB. If D is dangling then merged are AC and CB
					  A-----------B
						C------D	]]
								if cdang and ddang then
									newSegs = {
										segs[i]		-- Only AB is the segment
									}
								elseif cdang then
									newSegs = createSegments({
											{x1,y1,x4,y4},	-- AD
											{x4,y4,x2,y2},	-- DB
										})
								elseif ddang then
									newSegs = createSegments({
											{x1,y1,x3,y3},	-- AC
											{x3,y3,x2,y2},	-- CB
										})
								else
									newSegs = createSegments({
											{x1,y1,x3,y3},	-- AC
											{x3,y3,x4,y4},	-- CD
											{x4,y4,x2,y2},	-- DB
										})
								end
							else
								-- C does not lie on AD - Case 9
					--[[
					9. (overlap) The merge is 3 segments AD, DC and CB. If C and D are dangling then merged is AB. If D is dangling then merged are AC and CB. If C is dangling then merged are AD and DB
					  A-----------B
						D------C	]]
								if cdang and ddang then
									newSegs = {
										segs[i]		-- Only AB is the segment
									}
								elseif cdang then
									newSegs = createSegments({
											{x1,y1,x4,y4},	-- AD
											{x4,y4,x2,y2},	-- DB
										})
								elseif ddang then
									newSegs = createSegments({
											{x1,y1,x3,y3},	-- AC
											{x3,y3,x2,y2},	-- CB
										})
								else
									newSegs = createSegments({
											{x1,y1,x4,y4},	-- AD
											{x4,y4,x3,y3},	-- DC
											{x3,y3,x2,y2},	-- CB
										})
								end						
							end
						else
							-- C lies on AB but not D- Cases 4 and 8
							if coorc.pointOnSegment(x1,y1,x4,y4,x2,y2) then
								-- B lies on AD - Case 4
					--[[
					4. (overlap) The merge is 3 segments AC, CB and BD. If B and C are dangling then merged is AD. If C is dangling then merged is AB, BD. If B is dangling then merged are AC and CD
					  A-----------B
							  C------D	]]
								if cdang and bdang then
									newSegs = createSegments({
											{x1,y1,x4,y4},	-- AD										
										})
								elseif cdang then
									newSegs = createSegments({
											{x1,y1,x2,y2},	-- AB
											{x2,y2,x4,y4},	-- BD
										})
								elseif bdang then
									newSegs = createSegments({
											{x1,y1,x3,y3},	-- AC
											{x3,y3,x4,y4},	-- CD
										})
								else
									newSegs = createSegments({
											{x1,y1,x3,y3},	-- AC
											{x3,y3,x2,y2},	-- CB
											{x2,y2,x4,y4},	-- BD
										})
								end						
							else
								-- B does not lie on AD - Case 8
					--[[
					8. (overlap) The merge is 3 segments DA, AC and CB. If A and C are dangling then merged is DB. If A is dangling then merged is DC and CB. If C is dangling then merged is DA and AB
						A-----------B
					D------C	]]
								if cdang and adang then
									newSegs = createSegments({
											{x4,y4,x2,y2},	-- AD										
										})
								elseif cdang then
									newSegs = createSegments({
											{x4,y4,x1,y1},	-- DA
											{x1,y1,x2,y2},	-- AB
										})
								elseif adang then
									newSegs = createSegments({
											{x4,y4,x3,y3},	-- DC
											{x3,y3,x2,y2},	-- CB
										})
								else
									newSegs = createSegments({
											{x4,y4,x1,y1},	-- DA
											{x1,y1,x3,y3},	-- AC
											{x3,y3,x2,y2},	-- CB
										})
								end						
							end		-- if B lies on AD check
						end		-- if D lies on AB check					
					else	-- if C lies on AB check
						-- C does not lie on AB - Cases 1,2,5,6,7,10,11,12
						if coorc.pointOnSegment(x1,y1,x2,y2,x4,y4) then
							-- D lies on AB - Cases 2 and 10
							if coorc.pointOnSegment(x1,y1,x3,y3,x2,y2) then
								-- B lies on AC	-- Case 10
					--[[
					10. (overlap) The merge is 3 segments AD, DB and BC. If B and D are dangling then merged is AC. If B is dangling then merged are AD and DC. If D is dangling then merged are AB and BC
					  A-----------B
							  D------C	]]
								if bdang and ddang then
									newSegs = createSegments({
											{x1,y1,x3,y3},	-- AC										
										})
								elseif bdang then
									newSegs = createSegments({
											{x1,y1,x4,y4},	-- AD
											{x4,y4,x3,y3},	-- DC
										})
								elseif ddang then
									newSegs = createSegments({
											{x1,y1,x2,y2},	-- AB
											{x2,y2,x3,y3},	-- BC
										})
								else
									newSegs = createSegments({
											{x1,y1,x4,y4},	-- AD
											{x4,y4,x2,y2},	-- DB
											{x2,y2,x3,y3},	-- BC
										})
								end						
							else
								-- B does not lie on AC	- Case 2
					--[[
					2. (overlap) The merge is 3 segments CA, AD and DB. If A and D are dangling then merged is CB. If A is dangling then merged is CD, DB. If D is dangling then merged is CA, AB
						A-----------B
					C------D	]]
								if adang and ddang then
									newSegs = createSegments({
											{x3,y3,x2,y2},	-- CB										
										})
								elseif adang then
									newSegs = createSegments({
											{x3,y3,x4,y4},	-- CD
											{x4,y4,x2,y2},	-- DB
										})
								elseif ddang then
									newSegs = createSegments({
											{x3,y3,x1,y1},	-- CA
											{x1,y1,x2,y2},	-- AB
										})
								else
									newSegs = createSegments({
											{x3,y3,x1,y1},	-- CA
											{x1,y1,x4,y4},	-- AD
											{x4,y4,x2,y2},	-- DB
										})
								end											
							end		-- if B lies on AC check
						else	-- if D lies on AB check
							-- D does not lie on AB nor does C - Cases 1,5,6,7,11,12
							if coorc.pointOnSegment(x3,y3,x4,y4,x1,y1) then
								-- A lies on CD then - Cases 6 and 12
								if coorc.pointOnSegment(x3,y3,x2,y2,x1,y1) then
									-- A lies on CB - Case 6
					--[[
					6. (overlap) The merge is 3 segments CA, AB and BD. If A and B are dangling then merged is CD. If A is dangling then merged are CB and BD. If B is dangling then merged are CA and AD
					  C-----------D
						A------B	]]
									if adang and bdang then
										newSegs = {
											segs[j]				-- CD
										}
									elseif adang then
										newSegs = createSegments({
												{x3,y3,x2,y2},	-- CB
												{x2,y2,x4,y4},	-- BD
											})
									elseif bdang then
										newSegs = createSegments({
												{x3,y3,x1,y1},	-- CA
												{x1,y1,x4,y4},	-- AD
											})
									else
										newSegs = createSegments({
												{x3,y3,x1,y1},	-- CA
												{x1,y1,x2,y2},	-- AB
												{x2,y2,x4,y4},	-- BD
											})
									end											
								else
									-- A does not lie on CB - Case 12
					--[[
					12. (overlap) The merge is 3 segments DA, AB and BC. If A and B are dangling then merged is DC. If A is dangling then merged are DB and BC. If B is dangling then merged are DA and AC
					  D-----------C
						A------B	]]
									if adang and bdang then
										newSegs = createSegments({
												{x4,y4,x3,y3},	-- DC										
											})
									elseif adang then
										newSegs = createSegments({
												{x4,y4,x2,y2},	-- DB
												{x2,y2,x3,y3},	-- BC
											})
									elseif bdang then
										newSegs = createSegments({
												{x4,y4,x1,y1},	-- DA
												{x1,y1,x3,y3},	-- AC
											})
									else
										newSegs = createSegments({
												{x4,y4,x1,y1},	-- DA
												{x1,y1,x2,y2},	-- AB
												{x2,y2,x3,y3},	-- BC
											})
									end											
								end
							else
								-- Cases 1,5,7,11 - no overlap
								overlap = false
							end
						end	-- if check D lies on AB ends
					end		-- if check C lies on AB ends
				end		-- if sameeqn then ends here
			end		-- if i ~= j then ends here
			if overlap then
				-- Handle the merge of the new segments here
				local pos
				-- Remove from routing matrix
				rm:removeSegment(segs[i])
				rm:removeSegment(segs[j])
				if i > j then
					table.remove(segs,i)
					table.remove(segs,j)
					pos = i - 1
					i = i - 1  	-- to compensate for the i increment
				else
					table.remove(segs,j)
					table.remove(segs,i)
					pos = i
				end
				-- Insert all the new segments at the pos position
				for k = #newSegs,1,-1 do
					rm:addSegment(newSegs[k],newSegs[k].start_x,newSegs[k].start_y,newSegs[k].end_x,newSegs[k].end_y)
					table.insert(segs,pos,newSegs[k])
				end
				j = 0	-- Reset j to run with all segments again
				overlap = nil
			end
			j = j + 1
		end		-- while j <= #segs ends
		i = i + 1
	end		-- for i = 1,#segs do ends
	-- Now all merging of the overlaps is done
	-- Now check if any segment needs to split up
	local donecoor = {}		-- Store coordinates of the end points of all the segments and also indicate how many segments connect there
	for i = 1,#segs do
		-- Do the starting coordinate
		local X,Y = segs[i].start_x,segs[i].start_y
		if not donecoor[X] then
			donecoor[X] = {}
		end
		if not donecoor[X][Y] then
			donecoor[X][Y] = 1
			local conns,segmts = getConnFromXY(cnvobj,X,Y,0)	-- 0 resolution check
			-- We should just have 1 connector here ideally but if not lets find the index for this connector
			local l
			for j = 1,#conns do
				if conns[j] == conn then
					l = j 
					break
				end
			end
			-- Sort the segments in ascending order
			table.sort(segmts[l].seg)
			-- Iterate over all the segments at this point
			for k = #segmts[l].seg,1,-1 do		-- Iterate from the highest segment number so that if segment is inserted then index of lower segments do not change
				local j = segmts[l].seg[k]	-- Contains the segment number where the point X,Y lies
				-- Check whether any of the end points match X,Y (allSegs[i].x,allSegs[i].y)
				if not(segs[j].start_x == X and segs[j].start_y == Y or segs[j].end_x == X and segs[j].end_y == Y) then 
					-- The point X,Y lies somewhere on this segment in between so split the segment into 2
					rm:removeSegment(segs[j])
					table.insert(segs,j+1,{
						start_x = X,
						start_y = Y,
						end_x = segs[j].end_x,
						end_y = segs[j].end_y
					})
					rm:addSegment(segs[j+1],segs[j+1].start_x,segs[j+1].start_y,segs[j+1].end_x,segs[j+1].end_y)
					segs[j].end_x = X
					segs[j].end_y = Y
					rm:addSegment(segs[j],segs[j].start_x,segs[j].start_y,segs[j].end_x,segs[j].end_y)
					donecoor[X][Y] = donecoor[X][Y] + 2		-- 2 more end points now added at this point
				end
			end
		else
			donecoor[X][Y] = donecoor[X][Y] + 1	-- Add to the number of segments connected at this point
		end
		-- Do the end coordinate
		X,Y = segs[i].end_x,segs[i].end_y
		if not donecoor[X] then
			donecoor[X] = {}
		end
		if not donecoor[X][Y] then
			donecoor[X][Y] = 1
			local conns,segmts = getConnFromXY(cnvobj,X,Y,0)	-- 0 resolution check
			-- We should just have 1 connector here ideally but if not lets find the index for this connector
			local l
			for j = 1,#conns do
				if conns[j] == conn then
					l = j 
					break
				end
			end
			-- Sort the segments in ascending order
			table.sort(segmts[l].seg)
			-- Iterate over all the segments at this point
			for k = #segmts[l].seg,1,-1 do		-- Iterate from the highest segment number so that if segment is inserted then index of lower segments do not change
				local j = segmts[l].seg[k]	-- Contains the segment number where the point X,Y lies
				-- Check whether any of the end points match X,Y (allSegs[i].x,allSegs[i].y)
				if not(segs[j].start_x == X and segs[j].start_y == Y or segs[j].end_x == X and segs[j].end_y == Y) then 
					-- The point X,Y lies somewhere on this segment in between so split the segment into 2
					rm:removeSegment(segs[j])
					table.insert(segs,j+1,{
						start_x = X,
						start_y = Y,
						end_x = segs[j].end_x,
						end_y = segs[j].end_y
					})
					rm:addSegment(segs[j+1],segs[j+1].start_x,segs[j+1].start_y,segs[j+1].end_x,segs[j+1].end_y)
					segs[j].end_x = X
					segs[j].end_y = Y
					rm:addSegment(segs[j],segs[j].start_x,segs[j].start_y,segs[j].end_x,segs[j].end_y)
					donecoor[X][Y] = donecoor[X][Y] + 2		-- 2 more end points now added at this point
				end
			end
		else
			donecoor[X][Y] = donecoor[X][Y] + 1	-- Add to the number of segments connected at this point
		end		
	end
	-- Figure out the junctions
	local j = {}
	for k,v in pairs(donecoor) do
		for n,m in pairs(v) do
			if m > 2 then
				j[#j + 1] = {x=k,y=n}
			end
		end
	end
	conn.junction = j
	return true
end		-- function repairSegAndJunc ends here

do 
	-- Function to look at the given connector conn and short an merge it with any other connector its segments end points touch
	-- All the touching connectors are merged into 1 connector and all data structures updated appropriately
	-- Order of the resulting connector will be the highest order of all the merged conectors
	-- The connector ID of the resultant connector is the highest connector ID of all the connectors
	-- Returns the final merged connector together with the list of connector ids that were merged (including the merged connector - which is at the last spot in the list)
	local shortAndMergeConnector = function(cnvobj,conn)
		local coor = {}
		-- collect all the segment end points
		for i = 1,#conn.segments do
			tu.mergeArrays({
					{
						x = conn.segments[i].start_x,
						y = conn.segments[i].start_y
					},
					{
						x = conn.segments[i].end_x,
						y = conn.segments[i].end_y
					}				
				},coor,nil,equalCoordinate)
		end
		-- Get all the connectors on the given coor
		local allSegs = {}		-- To store the list of all segs structures returned for all coordinates in coor. A segs structure is one returned by getConnFromXY as the second argument where it has 2 keys: 'conn' contains the index of the connector at X,Y in the cnvobj.drawn.conn array and 'seg' key contains the array of indexes of the segments of that connector which are at X,Y coordinate
		for i = 1,#coor do
			local allConns,segs = getConnFromXY(cnvobj,coor[i].x,coor[i].y,0)	-- 0 resolution check
			tu.mergeArrays(segs,allSegs,nil,function(one,two)
					return one.conn == two.conn
				end)	-- Just collect the unique connectors
		end		-- for i = 1,#coor ends here
		-- Now allSegs has data about all the connectors that are present at coordinates in coor and also all their segment numbers
		-- Check if more than one connector in allSegs
		if #allSegs == 1 then
			-- only 1 connector and nothing to merge
			return cnvobj.drawn.conn[allSegs[1].conn],{cnvobj.drawn.conn[allSegs[1].conn].id}
		end
		-- Sort allSegs with descending connector index so the previous index is not affected when the connector is merged and deleted
		table.sort(allSegs,function(one,two)
				return one.conn > two.conn		
			end)	-- Now we need to see whether we need to split a segment and which new junctions to create
		local connM = cnvobj.drawn.conn[allSegs[#allSegs].conn]		-- The master connector where all connectors are merged (Taken as last one in allSegs since that will have the lowest index all others with higher indexes will be removed and connM index will not be affected
		-- The destination arrays
		local segTableD = connM.segments
		local portD = connM.port
		local juncD = connM.junction
		-- All connector data structure
		local conns = cnvobj.drawn.conn
		local maxOrder = connM.order		-- To store the maximum order of all the connectors
		local orders = {maxOrder}	-- Store the orders of all the connectors since they need to be removed from the orders array and only 1 placed finally
		for i = 1,#allSegs-1 do	-- Loop through all except the master connector
			orders[#orders + 1] = conns[allSegs[i].conn].order		-- Store the order
			if conns[allSegs[i].conn].order > maxOrder then
				maxOrder = conns[allSegs[i].conn].order				-- Get the max order of all the connectors which will be used for the master connector
			end
			-- Copy the segments over
			local segTableS = conns[allSegs[i].conn].segments
			tu.mergeArrays(segTableS,segTableD,nil,function(one,two)	-- Function to check if one and two are equivalent segments
					return (one.start_x == two.start_x and one.start_y == two.start_y and
						one.end_x == two.end_x and one.end_y == two.end_y) or
						(one.start_x == two.end_x and one.start_y == two.end_y and
						one.end_x == two.start_x and one.end_y == two.start_y)
				end)
			-- Copy and update the ports
			local portS = conns[allSegs[i].conn].port
			for k = 1,#portS do
				-- Check if this port already exists
				if not tu.inArray(portD,portS[k]) then
					portD[#portD + 1] = portS[k]
					-- Update the port to refer to the connM connector
					portS[k].conn[#portS[k].conn + 1] = connM
				end
				-- Remove the conns[allSegs[i].conn] connector from the portS[i].conn array since that connector is going to go away
				for j = 1,#portS[k].conn do
					if portS[k].conn[j] == conns[allSegs[i].conn] then
						table.remove(portS[k].conn,j)
						break
					end
				end
			end
			-- Copy the junctions
			local juncS = conns[allSegs[i].conn].junction
			tu.mergeArrays(juncS,juncD,nil,equalCoordinate)
		end
		-- Create a list of connector IDs that were merged
		local mergedIDs = {}
		-- Remove all the merged connectors from the connectors array
		for i = 1,#allSegs-1 do
			mergedIDs[#mergedIDs + 1] = conns[allSegs[i].conn].id
			table.remove(conns,allSegs[i].conn)
		end
		mergedIDs[#mergedIDs + 1] = connM.id
		-- Remove all the merged connectors from the order array
		table.sort(orders)
		for i = #orders,1,-1 do
			table.remove(cnvobj.drawn.order,orders[i])
		end
		-- Set the order to the highest
		connM.order = maxOrder
		-- Put the connector at the right place in the order
		table.insert(cnvobj.drawn.order,maxOrder-#orders + 1,{type="connector",item=connM})
		-- Fix the order of all the items
		fixOrder(cnvobj)
		
		return connM,mergedIDs	-- Merging done
	end

	-- Function to short and merge a list of connectors. It calls shortAndMergeConnector repeatedly and takes care if the current connector was already merged to a previous connector then it does it again to see if the it does any more merging
	-- Returns the full merge map which shows all the merging mappings that happenned
	function shortAndMergeConnectors(cnvobj,conns)
		if not cnvobj or type(cnvobj) ~= "table" then
			return nil,"Not a valid lua-gl object"
		end
		local mergeMap = {}
		for i = 1,#conns do
			-- First check the merged map if this connector was already done
			local done
			for j = 1,#mergeMap do
				for k = 1,#mergeMap[j][2] do
					if mergeMap[j][2][k] == conns[i].id then
						done = true
						break
					end
				end
				if done then break end
			end
			if not done then
				mergeMap[#mergeMap + 1] = {shortAndMergeConnector(cnvobj,conns[i])}
				while #mergeMap[#mergeMap][2] > 1 do
					mergeMap[#mergeMap + 1] = {shortAndMergeConnector(cnvobj,mergeMap[#mergeMap][1])}
				end
			end			
		end
		-- Now run repairSegAndJunc on all the merged connectors
		for i = 1,#mergeMap do
			local found
			for j = i + 1,#mergeMap do
				for k = 1,#mergeMap[j][2] do
					if mergeMap[j][2][k] == mergeMap[i][1].id then
						found = true
						break
					end
				end
				if found then break end
			end
			if not found then
				repairSegAndJunc(cnvobj,mergeMap[i][1])
			end
		end
		return mergeMap
	end
end

-- Function to split a connector into N connectors at the given Coordinate. If the coordinate is in the middle of a segment then the segment is split first and then the connector is split
-- The result will be N (>1) connectors that are returned as an array 
-- The order of the connectors is not set nor they are put in the order array
-- The connectors are also not placed in the cnvobj.drawn.conn array nor the given connector removed from it
-- The original connector is not modified but the ports it connects to has the entry for it removed
-- The function also does not check whether the ports associated with the connector are valid nor does it look for new ports that may be touching the connector. It simply divides the ports into the new resulting connectors based on their coordinates and the coordinates of the end points of the segments
-- The id of the 1st connector in the returned list is the same as that of the given connector. If the connector could not be split there will be only 1 connector in the returned list which can directly replace the given connector in the cnvobj.drawn.conn array and the order array after initializing its order key
local function splitConnectorAtCoor(cnvobj,conn,X,Y)
	-- First check if coor is in the middle of a segment. If it is then split the segment to make coor at the end
	local allConns,sgmnts = getConnFromXY(cnvobj,X,Y,0)
	local rm = cnvobj.rM	-- routing Matrix
	local segs = conn.segments
	for j = 1,#allConns do
		if allConns[j] == conn then
			-- Sort the segments in ascending order
			table.sort(sgmnts[j].seg)
			-- Check all the segments that lie on X,Y
			for l = #sgmnts[j].seg,1,-1 do
				local k = sgmnts[j].seg[l]	-- Contains the segment number where the point X,Y lies
				-- Check whether any of the end points match X,Y
				if not(segs[k].start_x == X and segs[k].start_y == Y or segs[k].end_x == X and segs[k].end_y == Y) then 
					-- The point X,Y lies somewhere on this segment in between so split the segment into 2
					rm:removeSegment(segs[k])
					table.insert(segs,k+1,{
						start_x = X,
						start_y = Y,
						end_x = segs[k].end_x,
						end_y = segs[k].end_y
					})
					rm:addSegment(segs[k+1],segs[k+1].start_x,segs[k+1].start_y,segs[k+1].end_x,segs[k+1].end_y)
					segs[k].end_x = X
					segs[k].end_y = Y
					rm:addSegment(segs[k],segs[k].start_x,segs[k].start_y,segs[k].end_x,segs[k].end_y)
				end
			end
			break	-- The connector has only 1 entry in allConns as returned by getConnFromXY
		end
	end
	
	local connA = {}		-- Initialize the connector array where all the resulting connectors will be placed
	local segsDone = {}		-- Data structure to store segments in the path for each starting segment
	-- Function to find and return all segments connected to x,y in segs array ignoring segments already in segsDone
	local function findSegs(segs,x,y,segsDone)
		local list = {}
		for i = 1,#segs do
			if not segsDone[segs[i]] then
				if segs[i].start_x == x and segs[i].start_y == y or segs[i].end_x == x and segs[i].end_y == y then
					list[#list + 1] = segs[i]
				end
			end
		end
		return list
	end
	-- Get all the segments connected to X,Y
	local csegs = findSegs(segs,X,Y,{})	-- Get the segments connected to X,Y
	-- Now from each of the segments found check if there is a path through the segments to the ends of the other segments in csegs
	local j = 1
	while j <= #csegs do
		local segPath = {}		-- To store the path of segments taken while searching for a path to coordinates ex and ey
		local endPoints = {}		-- To collect all the endpoint coordinates of segments collected in segsDone
		segsDone[j] = {}
		segsDone[j][csegs[j]] = true	-- Add the 1st segment as traversed
		if csegs[j].start_x == X and csegs[j].start_y == Y then
			segPath[1] = {			-- 1st step in the path initialized
				x = csegs[j].end_x,
				y = csegs[j].end_y,
				i = 0		-- segment index that will be traversed
			}
		else
			segPath[1] = {			-- 1st step in the path initialized
				x = csegs[j].start_x,
				y = csegs[j].start_y,
				i = 0		-- segment index that will be traversed
			}			
		end
		if #cnvobj:getPortFromXY(segPath[1].x,segPath[1].y) == 0 then	 -- If there is a port here then path ends here for this segment
			segPath[1].segs = findSegs(segs,segPath[1].x,segPath[1].y,segsDone[j])	-- get all segments connected at this step
		else
			segPath[1].segs = {}
		end
		-- Create the segment traversal algorithm (i is the step index corresponding to the index of segPath)
		local i = 1
		while i > 0 do
			--[=[
			-- No need to remove the segment from segsDone since traversing through there did not yield the path
			if segs[segPath[i].i] then
				-- remove the last segment from the 
				segsDone[segs[segPath[i].i]] = nil
			end
			]=]
			segPath[i].i = segPath[i].i + 1
			if segPath[i].i > #segPath[i].segs then
				-- This level is exhausted. Go up a level and look at the next segment
				table.remove(segPath,i)	-- Remove this step
				i = i - 1
			else
				-- We have segments that can be traversed
				local sgmnt = segPath[i].segs[segPath[i].i]
				local nxt_x,nxt_y
				if sgmnt.start_x == segPath[i].x and sgmnt.start_y == segPath[i].y then
					nxt_x = sgmnt.end_x
					nxt_y = sgmnt.end_y
				else
					nxt_x = sgmnt.start_x
					nxt_y = sgmnt.start_y
				end
				
				-- Traverse this segment
				segsDone[j][sgmnt] = true
				-- Check whether the end point (nxt_x,nxt_y) of this segment lands on a port then this path ends here
				if #cnvobj:getPortFromXY(nxt_x,nxt_y) == 0 then	 -- If there is a port here then path ends here for this segment
					-- Check the end points of this new segment with the end points of other members in csegs
					local k = j + 1
					while k <= #csegs do	-- Loop through all the next segments in csegs
						local ex,ey		-- to store the end point other than X,Y
						if csegs[k].start_x == X and csegs[k].start_y == Y then
							ex,ey = csegs[k].end_x,csegs[k].end_y
						else
							ex,ey = csegs[k].start_x,csegs[k].start_y
						end
						if sgmnt.start_x == ex and sgmnt.start_y == ey or sgmnt.end_x == ex and sgmnt.end_y == ey then
							-- found the other point in the kth starting segment so segment j cannot split with segment k
							-- Add the kth segment to the segsDone structure 
							segsDone[j][csegs[k]] = true
							-- Merge the kth segment with the jth segment (remove it from the csegs table)
							table.remove(csegs,k)
							k = k - 1	-- To compensate for the removed segment
						end
						k = k + 1
					end		-- while k <= #csegs ends here
					-- Store the endPoints
					if not endPoints[sgmnt.end_x] then
						endPoints[sgmnt.end_x] = {}
					end
					if not endPoints[sgmnt.end_x][sgmnt.end_y] then
						endPoints[sgmnt.end_x][sgmnt.end_y] = 1
					else
						endPoints[sgmnt.end_x][sgmnt.end_y] = endPoints[sgmnt.end_x][sgmnt.end_y] + 1
					end
					if not endPoints[sgmnt.start_x] then
						endPoints[sgmnt.start_x] = {}
					end
					if not endPoints[sgmnt.start_x][sgmnt.start_y] then
						endPoints[sgmnt.start_x][sgmnt.start_y] = 1
					else
						endPoints[sgmnt.start_x][sgmnt.start_y] = endPoints[sgmnt.start_x][sgmnt.start_y] + 1
					end
					
					i = i + 1
					segPath[i] = {i = 0}
					segPath[i].x = nxt_x
					segPath[i].y = nxt_y
					segPath[i].segs = findSegs(segs,segPath[i].x,segPath[i].y,segsDone[j])
				end		-- if #cnvobj:getPortFromXY(nxt_x,nxt_y) == 0 then ends
			end
		end		-- while i > 0 ends here
		-- Now segsDone has all the segments that connect to the csegs[j] starting connector. So we can form 1 connector using these
		connA[#connA + 1] = {
			id = nil,
			order = nil,
			segments = {},
			port = {},
			junction = {}
		}
		if j == 1 then
			connA[#connA].id = conn.id
		else
			connA[#connA].id = "C"..tostring(cnvobj.drawn.conn.ids + 1)
			cnvobj.drawn.conn.ids = cnvobj.drawn.conn.ids + 1
		end
		-- Fill in the segments
		for k,v in pairs(segsDone[j]) do
			connA[#connA].segments[#connA[#connA].segments + 1] = k
		end
		-- Fill in the ports
		for i = 1,#conn.port do
			if endPoints[conn.port[i].x] and endPoints[conn.port[i].x][conn.port[i].y] then
				-- this port goes in this new connector
				connA[#connA].port[connA[#connA].port + 1] = conn.port[i]
				-- Remove conn from conn.port[i] and add connA[#connA]
				local pconn = conn.port[i].conn
				for k = 1,#pconn do
					if pconn[k] == conn then
						table.remove(pconn,k)
						break
					end
				end
				pconn[#pconn + 1] = connA[#connA]
			end
		end
		-- Now regenerate the junctions
		local jn = {}
		for x,yt in pairs(endPoints) do
			for y,num in pairs(yt) do
				if num > 2 then	-- greater than 2 segments were at this point
					jn[#jn + 1] = {x=x,y=y}
				end
			end
		end
		connA[#connA].junction = jn
		j = j + 1
	end		-- while j <= #csegs do ends
	return connA
end

-- Function to check if any ports in the drawn data port array (or, if given, in the ports array) touch the given connector 'conn'. All touching ports are connected to the connector if not already done
-- if conn is not given then all connectors are processed
-- To connect the port to the connector unless the port lies on a dangling end the connector is split at the port so that the connector never crosses the port
-- If a port in ports is already connected to the connectors processed then it is first disconnected to avoid duplicating of connectors in the port data structure as described below:
-- It is best to disconnect ports from the connector before processing. Because if there is a split in the connector it creates new connectors without any ports and then it adds the port to both the connectors. The problem is if that port was connected to the original connector the port.conn array still contains the pointer to the old connector and that is not removed.
function connectOverlapPorts(cnvobj,conn,ports)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	-- Check all the ports in the drawn structure/given ports array and see if any port lies on this connector then connect to it by splitting it
	ports = ports or cnvobj.drawn.port
	local segs,k
	local all = not conn
	local splitColl = {conn}	-- Array to store all connectors that result from the split since all of them have to be processed for every port
	for i = 1,#ports do	-- Check for every port in the list
		local X,Y = ports[i].x,ports[i].y
		local allConns,sgmnts = getConnFromXY(cnvobj,X,Y,0)
		for j = 1,#allConns do
			conn = allConns[j]
			-- Check if this connector needs to be processed
			if all or tu.inArray(splitColl,allConns[j]) then	
				-- This connector lies on the port 
				-- From this connector disconnect ports[i] if there
				k = tu.inArray(ports[i].conn,conn)
				if k then
					-- ports[i] was connected to conn so disconnected it
					table.remove(ports[i].conn,k)	-- remove conn from ports table
					k = tu.inArray(conn.port,ports[i])
					if k then
						-- port in the connector port table at index k
						table.remove(conn.port,k)	-- remove the port from the connector port table
					end
				end
				segs = conn.segments
				-- Check if the port lies on a dangling node
				-- If there are more than 1 segment on this port then it cannot be a dangling segment since the connector will have to be split
				local split
				if #sgmnts[j].seg > 1 then
					split = true
				else
					-- only 1 segment is on the port
					-- Check if it is not on the end points then we would have to split the connector
					if not(segs[sgmnts[j].seg[1]].start_x == X and segs[sgmnts[j].seg[1]].start_y == Y or segs[sgmnts[j].seg[1]].end_x == X and segs[sgmnts[j].seg[1]].end_y == Y) then 
						split = true
					end
				end
				if split then
					-- Split the connector across all the segments that lie on the port
					local splitConn = splitConnectorAtCoor(cnvobj,conn,X,Y)	-- To get the list of connectors after splitting the connector at this point					
					-- Place the connectors at the spot in cnvobj.drawn.conn where conn was
					local l = sgmnts[j].conn	-- index of the connector in cnvobj.drawn.conn
					table.remove(cnvobj.drawn.conn,l)
					-- Remove the connector reference from all its ports
					for k = 1,#conn.port do
						local m = tu.inArray(conn.port[k].conn,conn)
						table.remove(conn.port[k].conn,m)
					end
					-- Remove conn from order and place the connectors at that spot
					local ord = conn.order
					table.remove(cnvobj.drawn.order,ord)
					-- Connect the port (and ports in conn) to each of the returned connectors
					-- Note that ports[i] was already removed from conn if it was there
					-- Now conn only has ports other than ports[i]
					for k = 1,#splitConn do
						local sp = splitConn[k].port
						-- Add the port to the connector port array
						sp[#sp + 1] = ports[i]
						-- Add the connector to the port connector array
						ports[i].conn[#ports[i].conn + 1] = splitConn[k]
						-- Now do this for ports in conn
						for m = 1,#conn.port do
							conn.port[m].conn[#conn.port[m].conn + 1] = splitConn[k]
							sp[#sp + 1] = conn.port[m]
						end
						-- Place the connector at the original connector spot
						table.insert(cnvobj.drawn.conn,l,splitConn[k])
						-- Place the connectors at the order spot of the original connector
						table.insert(cnvobj.drawn.order,ord,{type="connector",item=splitConn[k]})
						-- Add the splitConn connectors to the splitColl
						table.insert(splitColl,splitConn[k])
					end
					-- Fix the indexes of other items in sgmnts
					for k = 1,#sgmnts do
						if sgmnts[k].conn > l then
							-- This will have to increase by #splitConn - 1
							sgmnts[k].conn = sgmnts[k].conn + #splitConn - 1
						end
					end
					-- Fix order of all items
					fixOrder(cnvobj)
				else
					-- Just add the port to the connector
					-- Add the connector to the port
					ports[i].conn[#ports[i].conn + 1] = conn
					-- Add the port to the connector
					conn.port[#conn.port + 1] = ports[i]
				end
			end		-- if allConns[j] == conn and not tu.inArray(conn.port,ports[i]) then ends here
		end		-- for j = 1,#allConns do ends here
	end	
	return true
end

-- Function to drag a list of segments (dragging implies connector connections are maintained)
-- segList is a list of structures like this:
--[[
{
	conn = <connector structure>,	-- Connector structure to whom this segment belongs to 
	seg = <integer>					-- segment index of the connector
}
]]
-- If offx and offy are given numbers then this will be a non interactive move
dragSegment = function(cnvobj,segList,offx,offy)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	-- Check whether this is an interactive move or not
	local interactive
	if not offx or type(offx) ~= "number" then
		interactive = true
	elseif not offy or type(offy) ~= "number" then
		return nil, "Coordinates not given"
	end
	
	-- Sort seglist by connector ID and for the same connector with descending segment index so if there are multiple segments that are being dragged for the same connector we handle them in descending order without changing the index of the next one in line
	table.sort(segList,function(one,two)
			if one.conn.id == two.conn.id then
				-- this is the same connector
				return one.seg > two.seg	-- sort with descending segment index
			else
				return one.conn.id > two.conn.id
			end
		end)
	
	if not interactive then
		-- Take care of grid snapping
		offx,offy = cnvobj:snap(offx,offy)
		
		-- Move each segment
		for i = 1,#segList do
			local seg = segList[i].conn.segments[segList[i].seg]	-- The segment that is being dragged
			-- route connector from previous end_x,end_y to the new end_x,end_y
			local newSegs = {}
			router.generateSegments(cnvobj,seg.end_x+offx,seg.end_y+offy,seg.end_x,seg.end_y,newSegs) -- generateSegments updates routing matrix
			-- Add these segments after this current segment
			for j = #newSegs,1,-1 do
				table.insert(segList[i].conn.segments,segList[i].seg+1,newSegs[j])
			end
			-- route connector from previous start_x,start_y to the new start_x,start_y
			newSegs = {}
			router.generateSegments(cnvobj,seg.start_x,seg.start_y,seg.start_x+offx,seg.start_y+offy,newSegs)	 -- generateSegments updates routing matrix
			for j = #newSegs,1,-1 do
				table.insert(segList[i].conn.segments,segList[i].seg,newSegs[j])
			end
			rm:removeSegment(seg)
			-- Move the segment
			seg.start_x = seg.start_x + offx
			seg.start_y = seg.start_y + offy
			seg.end_x = seg.end_x + offx
			seg.end_y = seg.end_y + offy
			rm:addSegment(seg,seg.start_x,seg.start_y,seg.end_x,seg.end_y)
		end
		for i = 1,#segList do
			-- Check if all segments of this connector are done
			if i == #segList or segList[i+1].conn ~= segList[i].conn then
				-- Now lets check whether there are any shorts to any other connector by this dragged segment. The shorts can be on the segment end points
				-- remove any overlaps in the final merged connector
				local mergeMap = shortAndMergeConnectors(cnvobj,{segList[i].conn})
				-- Connect overlapping ports
				connectOverlapPorts(cnvobj,mergeMap[#mergeMap][1])		-- Note shortAndMergeConnectors also runs repairSegAndJunc
			end
		end
		return true
	end
	
	-- Setup the interactive move operation here
	-- Set refX,refY as the mouse coordinate on the canvas
	local gx,gy = iup.GetGlobal("CURSORPOS"):match("^(%d%d*)x(%d%d*)$")
	local sx,sy = cnvobj.cnv.SCREENPOSITION:match("^(%d%d*),(%d%d*)$")
	local refX,refY = gx-sx,gy-sy
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
	
	local function dragEnd()
		-- Check all the ports in the drawn structure and see if any port lies on this connector then connect to it
		for i = 1,#segList do
			-- Check if all segments of this connector are done
			if i == #segList or segList[i+1].conn ~= segList[i].conn then
				-- Now lets check whether there are any shorts to any other connector by this dragged segment. The shorts can be on the segment end points
				-- remove any overlaps in the final merged connector
				local mergeMap = shortAndMergeConnectors(cnvobj,{segList[i].conn})
				-- Connect overlapping ports
				connectOverlapPorts(cnvobj,mergeMap[#mergeMap][1])		-- Note shortAndMergeConnectors also runs repairSegAndJunc
			end
		end
		
		-- Reset mode
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB
	end
		
	cnvobj.op.mode = "DRAGSEG"
	cnvobj.op.segList = segList
	cnvobj.op.coor1 = {x=segList[1].conn.segments[segList[1].seg].start_x,y=segList[1].conn.segments[segList[1].seg].start_y}
	cnvobj.op.finish = dragEnd
	cnvobj.op.offx = 0
	cnvobj.op.offy = 0
	cnvobj.op.oldSegs = {}	-- To backup old segment structures for all items in the segList
	for i = 1,#segList do
		cnvobj.op.oldSegs[i] = tu.copyTable(segList[i].conn.segments,{},true)	-- Copy the entire segments table recursively by duplicating it value by value
	end
	cnvobj.op.segsToRemove = {}	-- to store the segments generated after every motion_cb
	
	-- button_CB to handle segment dragging
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		--y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y, status})
		if button == iup.BUTTON1 and pressed == 1 then
			dragEnd()
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y, status})	
	end

	-- motion_cb to handle segment dragging
	function cnvobj.cnv:motion_cb(x,y,status)
		--y = cnvobj.height - y
		x,y = cnvobj:snap(x,y)
		local offx,offy = x-refX,y-refY
		cnvobj.op.offx = offx
		cnvobj.op.offy = offy

		-- Now shift the segments and redo the connectors
		-- Remove the old additions from routing matrix
		for i = 1,#cnvobj.op.segsToRemove do
			rm:removeSegment(cnvobj.op.segsToRemove[i])
		end
		for i = 1,#segList do
			-- First copy the old segments to the connector
			segList[i].conn.segments = 	tu.copyTable(cnvobj.op.oldSegs[i],{},true)	-- Copy the oldSegs[i] table back to the connector segments
		end
		for i = 1,#segList do
			local seg = segList[i].conn.segments[segList[i].seg]	-- The segment that is being dragged
			-- route connector from previous end_x,end_y to the new end_x,end_y
			local newSegs = {}
			router.generateSegments(cnvobj,seg.end_x+offx,seg.end_y+offy,seg.end_x,seg.end_y,newSegs)
			-- Add these segments after this current segment
			for j = #newSegs,1,-1 do
				table.insert(segList[i].conn.segments,segList[i].seg+1,newSegs[j])
			end
			cnvobj.op.segsToRemove = newSegs
			-- route connector from previous start_x,start_y to the new start_x,start_y
			newSegs = {}
			router.generateSegments(cnvobj,seg.start_x,seg.start_y,seg.start_x+offx,seg.start_y+offy,newSegs)
			for j = #newSegs,1,-1 do
				table.insert(segList[i].conn.segments,segList[i].seg,newSegs[j])
				table.insert(cnvobj.op.segsToRemove,newSegs[j])
			end
			rm:removeSegment(seg)
			-- Move the segment
			seg.start_x = seg.start_x + offx
			seg.start_y = seg.start_y + offy
			seg.end_x = seg.end_x + offx
			seg.end_y = seg.end_y + offy
			rm:addSegment(seg,seg.start_x,seg.start_y,seg.end_x,seg.end_y)
		end
	end
	
	return true
end

-- Function to draw a connector on the canvas
-- if segs is a table of segment coordinates then this will be a non interactive draw
drawConnector  = function(cnvobj,segs)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	-- Check whether this is an interactive move or not
	local interactive
	if type(segs) ~= "table" then
		interactive = true
	end
	
	print("DRAW CONNECTOR START")
	
	local rm = cnvobj.rM
	
	if not interactive then
		-- Check segs validity
		--[[
		segments = {	-- Array of segment structures
			[i] = {
				start_x = <integer>,		-- starting coordinate x of the segment
				start_y = <integer>,		-- starting coordinate y of the segment
				end_x = <integer>,			-- ending coordinate x of the segment
				end_y = <integer>			-- ending coordinate y of the segment
			}
		},
		]]
		-- Take care of grid snapping
		local conn = cnvobj.drawn.conn	-- Data structure containing all connectors
		local junc = {}			-- To store all new created junctions
		for i = 1,#segs do
			if not segs[i].start_x or type(segs[i].start_x) ~= "number" then
				return nil,"Invalid or missing coordinate."
			end
			if not segs[i].start_y or type(segs[i].start_y) ~= "number" then
				return nil,"Invalid or missing coordinate."
			end
			if not segs[i].end_x or type(segs[i].end_x) ~= "number" then
				return nil,"Invalid or missing coordinate."
			end
			if not segs[i].end_y or type(segs[i].end_y) ~= "number" then
				return nil,"Invalid or missing coordinate."
			end
			-- Do the snapping of the coordinates first
			segs[i].start_x,segs[i].start_y = cnvobj:snap(segs[i].start_x,segs[i].start_y)
			segs[i].end_x,segs[i].end_y = cnvobj:snap(segs[i].end_x,segs[i].end_y)
			local jcst,jcen=0,0	-- counters to count how many segments does the start point of the i th segment connects to (jcst) and how many segments does the end point of the i th segment connects to (jcen)
			for j = 1,#segs do
				if j ~= i then
					-- the end points of the ith segment should not lie anywhere on the jth segment except its ends
					local ep = true	-- is the jth segment connected to one of the end points of the ith segment?
					if segs[i].start_x == segs[j].start_x and segs[i].start_y == segs[j].start_y then
						jcst = jcst + 1
					elseif segs[i].start_x == segs[j].end_x and segs[i].start_y == segs[j].end_y then
						jcst = jcst + 1
					elseif segs[i].end_x == segs[j].end_x and segs[i].end_y == segs[j].end_y then
						jcen = jcen + 1
					elseif segs[i].end_x == segs[j].start_x and segs[i].end_y == segs[j].start_y then
						jcen = jcen + 1
					else
						ep = false
					end
					if not ep and (coorc.pointOnSegment(segs[j].start_x, segs[j].start_y, segs[j].end_x, segs[j].end_y, segs[i].start_x, segs[i].start_y)  
					  or coorc.pointOnSegment(segs[j].start_x, segs[j].start_y, segs[j].end_x, segs[j].end_y, segs[i].end_x, segs[i].end_y)) then
						return nil, "The end point of a segment touches a mid point of another segment."	-- This is not allowed since that segment should have been split into 2 segments
					end
				end
			end
			if jcst > 1 then
				-- More than 1 segment connects the starting point of the ith segment so the starting point is a junction and 1 is the ith segment so that makes more than 2 segments connecting at the starting point of the ith segment
				if not tu.inArray(junc,{x=segs[i].start_x,y=segs[i].start_y},equalCoordinate) then
					junc[#junc + 1] = {x=segs[i].start_x,y=segs[i].start_y}
				end
			end
			if jcen > 1 then
				if not tu.inArray(junc,{x=segs[i].end_x,y=segs[i].end_y},equalCoordinate) then
					junc[#junc + 1] = {x=segs[i].end_x,y=segs[i].end_y}
				end
			end
		end		-- for i = 1,#segs ends here
		-- Add the segments to the routing matrix
		for i = 1,#segs do
			rm:addSegment(segs[i],segs[i].start_x,segs[i].start_y,segs[i].end_x,segs[i].end_y)
		end
		-- Create a new connector using the segments
		conn[#conn + 1] = {
			segments = segs,
			id="C"..tostring(conn.ids + 1),
			order=#cnvobj.drawn.order+1,
			junction=junc,
			port={}
		}
		conn.ids = conn.ids + 1
		-- Add the connector to the order array
		cnvobj.drawn.order[#cnvobj.drawn.order + 1] = {
			type = "connector",
			item = conn[#conn]
		}
		-- Now lets check whether there are any shorts to any other connector by this dragged segment. The shorts can be on the segment end points
		-- remove any overlaps in the final merged connector
		local mergeMap = shortAndMergeConnectors(cnvobj,{conn[#conn]})
		-- Connect overlapping ports
		connectOverlapPorts(cnvobj,mergeMap[#mergeMap][1])		-- Note shortAndMergeConnectors also runs repairSegAndJunc
		return true
	end
	-- Setup interactive drawing
	
	-- Connector drawing methodology
	-- Connector drawing starts with Event 1. This event may be a mouse event or a keyboard event
	-- Connector waypoint is set with Event 2. This event may be a mouse event or a keyboard event. The waypoint freezes the connector route up till that point
	-- Connector drawing stops with Event 3. This event may be a mouse event or a keyboard event.
	-- For now the events are defined as follows:
	-- Event 1 = Mouse left click
	-- Event 2 = Mouse left click after connector start
	-- Event 3 = Mouse right click or clicking on a port or clicking on a connector
	
	-- Backup the old button_cb and motion_cb functions
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
		
	local function setWaypoint(x,y)
		cnvobj.op.startseg = #cnvobj.drawn.conn[#cnvobj.drawn.conn].segments+1
		cnvobj.op.start = {x=x,y=y}
	end
	
	local function endConnector()
		-- Check whether the new segments overlap any port
		-- Note that ports can only happen at the start and end of the whole connector
		-- This is because routing avoids ports unless it is the ending point		
		local conn = cnvobj.drawn.conn[cnvobj.op.cIndex]
		local segTable = conn.segments
		-- Add the segments to the routing matrix
		for i = 1,#segTable do
			rm:addSegment(segTable[i],segTable[i].start_x,segTable[i].start_y,segTable[i].end_x,segTable[i].end_y)
		end

		-- Now lets check whether there are any shorts to any other connector by this dragged segment. The shorts can be on the segment end points
		-- remove any overlaps in the final merged connector
		local mergeMap = shortAndMergeConnectors(cnvobj,{conn})
		-- Connect overlapping ports
		connectOverlapPorts(cnvobj,mergeMap[#mergeMap][1])		-- Note shortAndMergeConnectors also runs repairSegAndJunc
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB
	end		-- Function endConnector ends here
	
	local function startConnector(x,y)
		print("START CONNECTOR")
		local conn = cnvobj.drawn.conn
		local grdx,grdy = cnvobj.grid.snapGrid and cnvobj.grid.grid_x or 1, cnvobj.grid.snapGrid and cnvobj.grid.grid_y or 1
		local X,Y  =  coorc.snapX(x, grdx),coorc.snapY(y, grdy)
		cnvobj.op.startseg = 1		-- segment number from where to generate the segments
		-- Check if the starting point lays on another connector
		cnvobj.op.connID = "C"..tostring(cnvobj.drawn.conn.ids + 1)
		cnvobj.op.cIndex = #cnvobj.drawn.conn + 1		-- Storing this connector in a new connector structure. Will merge it with other connectors if required in endConnector
		cnvobj.op.mode = "DRAWCONN"	-- Set the mode to drawing object
		cnvobj.op.start = {x=X,y=Y}	-- snapping is done in generateSegments
		cnvobj.op.finish = endConnector
		--cnvobj.op.splitseg may also be set in the above loop
		--cnvobj.op.startseg is set
	end
	
	-- button_CB to handle connector drawing
	function cnvobj.cnv:button_cb(button,pressed,x,y,status)
		--y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
		if button == iup.BUTTON1 and pressed == 1 then
			if cnvobj.op.mode ~= "DRAWCONN" then
				print("Start connector drawing at ",x,y)
				startConnector(x,y)
			elseif #cnvobj:getPortFromXY(x, y) > 0 or #getConnFromXY(cnvobj,x,y,0) > 1 then	-- 1 is the connector being drawn right now
				endConnector()
			else
				setWaypoint(x,y)
			end
		end
		if button == iup.BUTTON3 and pressed == 1 then
			-- Event 3 (right click)
			endConnector()
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y,status})
	end
	
	function cnvobj.cnv:motion_cb(x,y,status)
		--connectors
		if cnvobj.op.mode == "DRAWCONN" then
			--y = cnvobj.height - y
			local cIndex = cnvobj.op.cIndex
			local segStart = cnvobj.op.startseg
			local startX = cnvobj.op.start.x
			local startY = cnvobj.op.start.y
			if not cnvobj.drawn.conn[cIndex] then
				-- new connector object described below:
				cnvobj.drawn.conn[cIndex] = {
					segments = {},
					id=cnvobj.op.connID,
					order=#cnvobj.drawn.order+1,
					junction={},
					port={}
				}
				-- Update the connector id counter
				cnvobj.drawn.conn.ids = cnvobj.drawn.conn.ids + 1
				-- Add the connector to be drawn in the order array
				cnvobj.drawn.order[#cnvobj.drawn.order + 1] = {
					type = "connector",
					item = cnvobj.drawn.conn[cnvobj.op.cIndex]
				}
			end
			local connector = cnvobj.drawn.conn[cIndex]
			-- Remove all the segments that need to be regenerated
			for i = #connector.segments,segStart,-1 do
				cnvobj.rM:removeSegment(connector.segments[i])
				table.remove(connector.segments,i)
			end
			print("GENERATE SEGMENTS")
			router.generateSegments(cnvobj, startX,startY,x, y,connector.segments)
			cnvobj:refresh()
		end			
	end
	
end	-- end drawConnector function


