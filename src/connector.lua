-- Module to handle connectors for lua-gl

local table = table
local type = type
local math = math
local tonumber = tonumber
local error = error
local pairs = pairs
local tostring = tostring

local print = print

local tu = require("tableUtils")
local coorc = require("lua-gl.CoordinateCalc")


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

getConnFromXY = function(cnvobj,x,y,res)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	local conns = cnvobj.drawn.conn
	if #conns == 0 then
		return {}
	end
	res = res or math.floor(math.min(cnvobj.grid_x,cnvobj.grid_y)/2)
	local allConns = {}
	local segs = {}
	for i = 1,#conns do
		local segs = conns[i].segments
		local connAdded
		for j = 1,#segs do
			if coorc.PointOnLine(segs[j].start_x, segs[j].start_y, segs[j].end_x, segs[j].end_y, x, y, res)  then
				if not connAdded then
					allConns[#allConns + 1] = conns[i]
					segs[#segs + 1] = {conn = i, seg = {j}}
					connAdded = true
				else
					segs[#segs].seg[#segs[#segs].seg + 1] = j	-- Add all segments that lie on that point
				end
			end
		end
	end
	return allConns, segs
end


-- BFS algorithm implementation
local BFS
do
	local Point = {}

	local queueNode  = {}
	local matrix_width, matrix_height = 0, 0

	local function isValid(row, col) 
		if (row > 0) and (row <= matrix_width) and (col > 0) and (col <= matrix_height) then
			return true
		end
	end 
	  
	-- These arrays are used to get row and column 
	-- numbers of 4 neighbours of a given cell 
	local rowNum = {-1, 0, 0, 1}; 
	local colNum = {0, -1, 1, 0}; 
	  
	-- function to find the shortest path and string between 
	-- a given source cell to a destination cell. 
	function BFS(mat, srcX,srcY,destX, destY, mWidth, mHeight) 
	   
		-- check source and destination cell 
		-- of the matrix have value 1 
		matrix_width, matrix_height = mWidth, mHeight
		if not isValid(srcX,srcY) or not isValid(destX, destY) or mat[srcX][srcY]==0 or mat[destX][destY]==0 then 
			return
		end

		local visited = {}
		for i=1, matrix_width do 
			visited[i] = {}
			for j=1, matrix_height do 
				visited[i][j] = false
			end
		end
		  
		-- Mark the source cell as visited 
		visited[srcX][srcY] = true; 
	  
		-- Create a queue for BFS 
		local q = {}

		-- Distance of source cell is 0 
		str = ""
	   
		s = {srcX, srcY, 0, str}
		table.insert(q,s)  -- Enqueue source cell 
	  
		-- Do a BFS starting from source cell 
		while #q > 0 do 
			
			-- If we have reached the destination cell, 
			-- we are done 
			if (q[1][1] == destX and q[1][2] == destY) then
				return q[1][3], q[1][4]; 
			end
			-- Otherwise dequeue the front cell in the queue 
			-- and enqueue its adjacent cells 

			local pt = tu.copyTable(q[1],{})
			
			table.remove(q,1); 
			
			for i=1, 4 do
			   
				srcX = pt[1] + rowNum[i]
				srcY = pt[2] + colNum[i]
			   
				-- if adjacent cell is valid, has path and 
				-- not visited yet, enqueue it. 
			   
				
				if isValid(srcX, srcY)==1 and mat[srcX][srcY]==1 and not visited[srcX][srcY] then
					-- mark cell as visited and enqueue it 
					visited[srcX][srcY] = true
					if i==1 then
						str = pt[4].."U"
					elseif i==2 then
						str = pt[4].."L"
					elseif i==3 then
						str = pt[4].."R"
					elseif i==4 then
						str = pt[4].."D"
					end
					
					local Adjcell = { srcX, srcY, pt[3] + 1, str}; 
				  
					table.insert(q, Adjcell)
				end
			end
		end 
	  
		-- Return -1 if destination cannot be reached 
		return -1; 
	end
	  
	-- Driver program to test above function 

	--[[mat =  { 
			{ 1, 0, 1, 1, 1, 1, 0, 1, 1, 1 }, 
			{ 1, 0, 0, 0, 1, 1, 1, 0, 1, 1 }, 
			{ 1, 1, 1, 1, 1, 1, 0, 1, 0, 1 }, 
			{ 0, 0, 1, 0, 1, 0, 0, 0, 0, 1 }, 
			{ 1, 1, 1, 0, 1, 1, 1, 0, 1, 0 }, 
			{ 1, 0, 1, 1, 1, 1, 0, 1, 0, 0 }, 
			{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 1 }, 
			{ 1, 0, 1, 1, 1, 1, 0, 1, 1, 1 }, 
			{ 1, 1, 0, 0, 0, 0, 1, 0, 0, 1 } } 
	  
		
		sourceX , sourceY = 1, 1 
		destX, destY= 6, 5
	  
		dist, strin= BFS(mat, sourceX, sourceY, destX, destY, 9, 10); 
	  
		if (dist ~= INT_MAX) then
			print("Shortest Path is ", dist, strin) 
		else
			print("Shortest Path doesn't exist") 
		end
	]]
	  
	
end

-- Function to represent the canvas area as a matrix of obstacles to use for BFS path searching
local function findMatrix(cnvobj)
	local grdx, grdy = cnvobj.grid_x,cnvobj.grid_y
	if not cnvobj.snapGrid then
		grdx,grdy = 1,1
	end
	
    local matrix = {}
	
	-- Shortlist all blocking rectangles
	local br = {}
	local objs = cnvobj.drawn.obj
	for i = 1,#objs do
		if objs[i].shape == "BLOCKINGRECT" then
			br[#br + 1] =objs[i]
		end
	end
	
    local matrix_width = math.floor(cnvobj.width/grdx) + 1
    local matrix_height = math.floor(cnvobj.height/grdy) + 1
    for i=1, matrix_width  do
        matrix[i] = {}
        for j=1, matrix_height do 
            local x = (i-1)*grdx
            local y = (j-1)*grdy
			matrix[i][j]=1	-- 1 where the connector can route
			-- Check if x,y lies in any blocking rectangle
			for k = 1,#br do
				local x1, y1 = br[k].start_x, br[k].start_y
				local x3, y3 = br[k].end_x , br[k].end_y
				local x2, y2, x4, y4 = x1, y3, x3, y1

				if coorc.PointInRect(x1, y1, x2, y2, x3, y3, x4, y4, x, y) then
					matrix[i][j]=0	-- 0 where the connector cannot route
					break
				end
			end
        end
    end
    return matrix
end

-- Function to generate connector segment coordinates given the starting X, Y and the ending x,y coordinates
-- The new segments are added to the end of the segments array passed to it
function generateSegments(cnvobj, startX,startY,x, y,segments)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	local grdx, grdy = cnvobj.grid_x,cnvobj.grid_y
	if not cnvobj.snapGrid then
		grdx,grdy = 1,1
	end
    local matrix_width = math.floor(cnvobj.width/grdx) + 1
    local matrix_height = math.floor(cnvobj.height/grdy) + 1
    
    --srcX is sourceX in binary matrix and startX is exact start point of connector on canvas
    --destX is destinationX in binrary matrix and x is exact end point of connector on canvas
    local srcX  =  coorc.snapX(startX, grdx)/grdx + 1
    local srcY  =  coorc.snapY(startY, grdy)/grdy + 1
    local destX =  coorc.snapX(x, grdx)/grdx + 1
    local destY =  coorc.snapY(y, grdy)/grdy + 1
	
	if srcX == destX and srcY == destY then
		-- No distance yet so no segments should be generated
		return true
	end
   
    local shortestPathLen, shortestPathString = BFS(findMatrix(cnvobj), srcX, srcY, destX, destY, matrix_width, matrix_height)
    
	if not shortestPathLen then
        return 
    end
	
    local shortestpathTable = {}
    for i=1, #shortestPathString do
		local c = str:sub(i,i)
        if c:upper() == "U" then
            shortestpathTable[i] = 1
        elseif c:upper() == "L" then
            shortestpathTable[i] = 2
        elseif c:upper() == "R" then
            shortestpathTable[i] = 3
        else
            shortestpathTable[i] = 4
        end
    end
	
    --[[str = ""
    for k,v in pairs(shortestpathTable) do
        str = str..v.." "
    end
    print(str)]]

    local rowNum = {-1, 0, 0, 1}; 
    local colNum = {0, -1, 1, 0}; 

    
	for i=#segments+1, #segments + shortestPathLen do
		segments[i] = {}
	   -- cnvobj.connector[connectorID].segments[i].ID = segLen + 1
		if i==#segments+1 then
			segments[i].start_x = (srcX-1)*grdx
			segments[i].start_y = (srcY-1)*grdy
		else
			segments[i].start_x = segments[i-1].end_x  
			segments[i].start_y = segments[i-1].end_y
		end
		segments[i].end_x = math.floor(segments[i].start_x + (rowNum[shortestpathTable[i]])*grdx)
		segments[i].end_y = math.floor(segments[i].start_y + (colNum[shortestpathTable[i]])*grdy)   
	end
	print("total seg in this connector"..#segments)
	return true
end

local function equalCoordinate(v1,v2)
	return v1.x == v2.x and v1.y == v2.y
end

-- Function to check all ports at coordinate X,Y and check whether conn is already connected to those ports. If not then conn is connected to those ports by updating the ports data structure and conn's data structure
local function checkAndAddPorts(cnvobj,X,Y,conn)
	local allPorts = cnvobj:getPortFromXY(X,Y)
	for j = 1,#allPorts do
		if not tu.inArray(allPorts[j].conn,conn) then
			-- Add the connector to the port
			allPorts[j].conn[#allPorts[j].conn + 1] = conn
			-- Add the port to the connector
			conn.port[#conn.port + 1] = allPorts[j]
		end
	end
end

-- Function to check if any ports in the drawn data (or, if given, in the ports array) touch the given connector 'conn'. All touching ports are connected to the connector if not already done
-- if conn is not given then all connectors are processed
function connectOverlapPorts(cnvobj,conn,ports)
	-- Check all the ports in the drawn structure and see if any port lies on this connector then connect to it
	ports = ports or cnvobj.drawn.port
	local segs
	for i = 1,#ports do
		local X,Y = ports[i].x,ports[i].y
		local allConns,sgmnts = getConnFromXY(cnvobj,X,Y)
		for j = 1,#allConns do
			conn = conn or allConns[j]
			segs = conn.segments
			if allConns[j] == conn and not tu.inArray(conn.port,ports[i]) then
				-- This connector lies on the port
				-- Add the connector to the port
				ports[i].conn[#ports[i].conn + 1] = conn
				-- Add the port to the connector
				conn.port[#conn.port + 1] = ports[i]
				-- Check if the port is in between a segment then this segment needs to split
				for l = 1,#sgmnts[j].seg do
					local k = sgmnts[j].seg[l]	-- Contains the segment number where the point X,Y lies
					-- Check whether any of the end points match X,Y (allSegs[i].x,allSegs[i].y)
					if not(segs[k].start_x == X and segs[k].start_y == Y or segs[k].end_x == X and segs[k].end_y == Y) then 
						-- The point X,Y lies somewhere on this segment in between so split the segment into 2
						table.insert(segs,k+1,{
							start_x = X,
							start_y = Y,
							end_x = segs[k].end_x,
							end_y = segs[k].end_y
						})
						segs[k].end_x = X
						segs[k].end_y = Y
					end
				end
				break
			end
		end
	end	
	return true
end

-- Function to check whether segments are valid and if any segments need to be split further or merged and overlaps are removed and junctions are regenerated
-- This function does not touch the ports of the connector nor check their validity
local function repairSegAndJunc(cnvobj,conn)
	
	-- Function to check whether 2 line segments have the same line equation or not
	-- The 1st line segment is from x1,y1 to x2,y2
	-- The 2nd line segment is from x3,y3 to x4,y4
	local function sameeqn(x1,y1,x2,y2,x3,y3,x4,y4)
		local sameeqn 
		if x1==x2 and x3==x4 and x1==x3 then
			-- equation is x = c for both lines
			sameeqn = true
		elseif x1~=x2 and x3~=x4 then
			-- equation x = c is not true for both lines
			local m1 = math.floor((y2-y1)/(x2-x1)*100)/100
			local m2 = math.floor((y4-y3)/(x4-x3)*100)/100
			if m1 == m2 and math.floor((y1-x1*m1)*100) == math.floor((y3-x3*m2)*100) then
				sameeqn = true
			end
		end
		return sameeqn
	end
	-- First find the dangling nodes. Note that dangling segments are the ones which may merge with other segments
	-- Dangling end point is defined as one which satisfies the following:
	-- * The end point does not match the end points of any other segment or
	-- * The end point matches the end point of only 1 segment with the same line equation
	-- AND
	-- * The end point does not lie on a port
	local s,e = {},{}		-- Starting and ending node dangling segments indexes
	local segs = conn.segments
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
					chkPorts = false
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
					chkPorts = false
				end
			end
			-- Ending node is dangling, check if it connects to any port
			if #cnvobj:getPortFromXY(ex,ey) == 0 then
				e[i] = true		-- segment i ending point is dangling
			end
		end
	end		-- for i = 1,#segs do ends here
	-- Function to create segments given the coordinate pairs
	-- Segment is only created if its length is > 0
	-- coors is an array of coordinates. Each entry has the following table:
	-- {x1,y1,x2,y2} where x1,y1 and x2,y2 represent the ends of the segment to create
	local function createSegments(coors)
		local segs = {}
		for i =1,#coors do
			if not(coors[i][1] == coors[i][3] and coors[i][2] == coors[i][4]) then
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
					if coorc.PointOnLine(x1,y1,x2,y2,x3,y3,0) then	
						-- C lies on AB - Cases 3,4,8,9
						if coorc.PointOnLine(x1,y1,x2,y2,x4,y4,0) then
							-- D lies on AB - Cases 3 and 9
							if coorc.PointOnLine(x1,y1,x4,y4,x3,y3,0) then
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
								-- D lies on AC - Case 9
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
							if coorc.PointOnLine(x1,y1,x4,y4,x2,y2,0) then
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
						if coorc.PointOnLine(x1,y1,x2,y2,x4,y4,0) then
							-- D lies on AB - Cases 2 and 10
							if coorc.PointOnLine(x1,y1,x3,y3,x2,y2,0) then
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
							if coorc.PointOnLine(x3,y3,x4,y4,x1,y1,0) then
								-- A lies on CD then - Cases 6 and 12
								if coorc.PointOnLine(x3,y3,x2,y2,x1,y1,0) then
									-- A lies on CB - Case 6
					--[[
					6. (overlap) The merge is 3 segments CA, AB and BD. If A and B are dangling then merged is CD. If A is dangling then merged are CB and BD. If B is dangling then merged are CA and AD
					  C-----------D
						A------B	]]
									if adang and bdang then
										newSegs = createSegments({
												{x3,y3,x4,y4},	-- CD										
											})
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
								-- Cases 1,5,7,11
								overlap = false
							end
						end	-- if check D lies on AB ends
					end		-- if check C lies on AB ends
				end		-- if sameeqn then ends here
			end		-- if i ~= j then ends here
			if overlap then
				-- Handle the merge of the new segments here
				table.remove(segs,i)
				table.remove(segs,j)
				for k = #newSegs,1,-1 do
					table.insert(segs,i,newSegs[k])
				end
				j = 1	-- Reset j to run with all segments again
			end
			j = j + 1
		end		-- while j <= #segs ends
		i = i + 1
	end		-- for i = 1,#segs do ends
	-- Now all merging of the overlaps is done
	-- Now check if any segment needs to split up
	local donecoor = {}
	for i = 1,#segs do
		-- Do the starting coordinate
		local X,Y = segs[i].start_x,segs[i].start_y
		if not donecoor[X] then
			donecoor[X] = {}
		end
		if not donecoor[X][Y] then
			donecoor[X][Y] = 1
			local conns,segmts = getConnFromXY(X,Y,0)	-- 0 resolution check
			-- We should just have 1 connector here
			if #conns > 1 or conns[1] ~= conn then
				error("Fatal error. Connector other than the current connector found at "..X..","..Y.." in running repairSegAndJunc.")
			end
			for k = 1,#segmts[1].seg do
				local j = segmts[1].seg[k]	-- Contains the segment number where the point X,Y lies
				-- Check whether any of the end points match X,Y (allSegs[i].x,allSegs[i].y)
				if not(segs[j].start_x == X and segs[j].start_y == Y or segs[j].end_x == X and segs[j].end_y == Y) then 
					-- The point X,Y lies somewhere on this segment in between so split the segment into 2
					table.insert(segs,j+1,{
						start_x = X,
						start_y = Y,
						end_x = segs[j].end_x,
						end_y = segs[j].end_y
					})
					segs[j].end_x = X
					segs[j].end_y = Y
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
			local conns,segmts = getConnFromXY(X,Y,0)	-- 0 resolution check
			-- We should just have 1 connector here
			if #conns > 1 or conns[1] ~= conn then
				error("Fatal error. Connector other than the current connector found at "..X..","..Y.." in running repairSegAndJunc.")
			end
			for k = 1,#segmts[1].seg do
				local j = segmts[1].seg[k]	-- Contains the segment number where the point X,Y lies
				-- Check whether any of the end points match X,Y (allSegs[i].x,allSegs[i].y)
				if not(segs[j].start_x == X and segs[j].start_y == Y or segs[j].end_x == X and segs[j].end_y == Y) then 
					-- The point X,Y lies somewhere on this segment in between so split the segment into 2
					table.insert(segs,j+1,{
						start_x = X,
						start_y = Y,
						end_x = segs[j].end_x,
						end_y = segs[j].end_y
					})
					segs[j].end_x = X
					segs[j].end_y = Y
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

-- Function to look at the given connector conn and short an merge it with any other connector its segments end points touch
-- All the touching connectors are merged into 1 connector and all data structures updated appropriately
-- Order of the resulting connector will be the highest order of all the merged conectors
-- The connector ID of the resultant connector is the highest connector ID of all the connectors
local shortAndMergeConnectors = function(cnvobj,conn)
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
	local allConns,segs 
	local allSegs = {}		-- To store the list of all segs structures returned for all coordinates in coor. A segs structure is one returned by getConnFromXY as the second argument where it has 2 keys: 'conn' contains the index of the connector at X,Y in the cnvobj.drawn.conn array and 'seg' key contains the array of indexes of the segments of that connector which are at X,Y coordinate
	local isJunc = {}		-- To store a boolean value whether coor[i] storing the coordinate x,y is to be created a junction 
	for i = 1,#coor do
		allConns,segs = getConnFromXY(coor[i].x,coor[i].y,0)	-- 0 resolution check
		if #segs > 1 then
			-- More than 1 connector at this coordinate so this has to be a junction
			isJunc[i] = true
		end
		tu.mergeArrays(segs,allSegs,nil,function(one,two)
				return one.conn == two.conn
			end)	-- Just collect the unique connectors
	end		-- for i = 1,#coor ends here
	-- Now allSegs has data about all the connectors that are present at coordinates in coor and also all their segment numbers
	-- 1st sort allSegs with descending order of segment number so that when we split a segment it does not effect the segment number of the lower index segments that need to be split
	table.sort(allSegs,function(one,two)
			return one.conn > two.conn		-- Sort in descending connector indexes so the previous index is not affected when the connector is merged and deleted
		end)	-- Now we need to see whether we need to split a segment and which new junctions to create
	-- Check if more than one connector in allSegs
	if #allSegs == 1 then
		-- only 1 connector and nothing to merge
		return true
	end
	local connM = cnvobj.drawn.conn[allSegs[#allSegs].conn]		-- The master connector where all connectors are merged (Taken as last one in allSegs since that will have the lowest index all others with higher indexes will be removed
	-- The destination arrays
	local segTableD = connM.segments
	local portD = connM.port
	local juncD = connM.junction
	-- All connector data structure
	local conns = cnvobj.drawn.conn
	local maxOrder = connM.order		-- To store the maximum order of all the connectors
	local orders = {maxOrder}	-- Store the orders of all the connectors since they need to be removed from the orders array and only 1 placed finally
	local connToRemove = {}
	for i = 1,#allSegs-1 do	-- Loop through all except the master connector
		orders[#orders + 1] = conns[allSegs[i].conn].order		-- Store the order
		if conns[allSegs[i].conn].order > maxOrder then
			maxOrder = conns[allSegs[i].conn].order				-- Get the max order of all the connectors which will be used for the master connector
		end
		-- Copy the segments over
		local segTableS = conns[allSegs[i].conn].segments
		tu.mergeArrays(segTableS,segTableD,nil,function(one,two)
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
		connToRemove[#connToRemove + 1] = allSegs[i].conn
	end
	-- Remove all the merged connectors from the connectors array
	table.sort(connToRemove)
	for i = #connToRemove,1,-1 do
		table.remove(conns,connToRemove[i])
	end
	-- Remove all the merged connectors from the order array
	table.sort(orders)
	for i = #orders,1,-1 do
		table.remove(cnvobj.drawn.order,orders[i])
	end
	-- Set the order to the highest
	connM.order = maxOrder
	-- Put the connector at the right place in the order
	table.insert(cnvobj.drawn.order,{type="connector",item=connM},maxOrder-#orders + 1)
	-- Fix the order of all the items
	for i = 1,#cnvobj.drawn.order do
		cnvobj.drawn.order[i].item.order = i
	end
	
	-- Now add the junctions if required
	for i = 1,#coor do
		if isJunc[i] then
			if not tu.inArray(juncD,coor[i],equalCoordinate) then
				juncD[#juncD + 1] = coor[i]
			end
		end
	end
	-- Run repairSegAndJunc on the connector
	repairSegAndJunc(cnvobj,conn)
	return connM	-- Merging done
end

-- Function to split a connector into N connectors at the given Coordinate. If the coordinate is in the middle of a segment then the segment is split first and then the connector is split
-- The result will be N (>1) connectors that are returned as an array 
-- The order of the connectors is not set nor they are put in the order array
-- The connectors are also not placed in the cnvobj.drawn.conn array
-- The original connector is not modified but the ports it connects to has the entry for it removed
-- The id of the 1st connector in the returned list is the same as that of the given connector. If the connector could not be split there will be only 1 connector in the returned list which can directly replace the given connector in the cnvobj.drawn.conn array and the order array after initializint its order key
local function splitConnectorAtCoor(cnvobj,conn,coor)
	-- First check if coor is in the middle of a segment. If it is then split the segment to make coor at the end
	local X,Y = coor.x,coor.y
	local allConns,sgmnts = getConnFromXY(cnvobj,X,Y)
	local segs = conn.segments
	for j = 1,#allConns do
		if allConns[j] == conn then
			-- Check all the segments that lie on X,Y
			for l = 1,#sgmnts[j].seg do
				local k = sgmnts[j].seg[l]	-- Contains the segment number where the point X,Y lies
				-- Check whether any of the end points match X,Y
				if not(segs[k].start_x == X and segs[k].start_y == Y or segs[k].end_x == X and segs[k].end_y == Y) then 
					-- The point X,Y lies somewhere on this segment in between so split the segment into 2
					table.insert(segs,k+1,{
						start_x = X,
						start_y = Y,
						end_x = segs[k].end_x,
						end_y = segs[k].end_y
					})
					segs[k].end_x = X
					segs[k].end_y = Y
				end
			end
			break	-- The connector has only 1 entry in allConns as returned by getConnFromXY
		end
	end
	
	local connA = {}		-- Initialize the connector array
	local segsDone = {}		-- Data structure to store segments in the path for each starting segment
	-- Function to find and return all segments connected to x,y ignoring segments already in segsDone
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
				y = csegs[j]._y,
				i = 0		-- segment index that will be traversed
			}			
		end
		
		segPath[1].segs = findSegs(segs,segPath[1].x,segPath[1].y,segsDone[j])	-- get all segments connected at this step
		-- Create the segment traversal algorithm (i is the step index corresponding to the index of segPath)
		local found
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
				local sgmnt = segPath.segs[segPath[i].i]
				-- Check the end points of this new segment with the end points of other members in csegs
				local k = j + 1
				while k <= #csegs do
					local ex,ey
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
				-- Traverse this segment
				segsDone[j][sgmnt] = true
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
				if sgmnt.start_x == segPath[i].x and sgmnt.start_y == segPath[i].y then
					segPath[i].x = sgmnt.end_x
					segPath[i].y = sgmnt.end_y
				else
					segPath[i].x = sgmnt.start_x
					segPath[i].y = sgmnt.start_y
				end
				segPath[i].segs = findSegs(segs,segPath[i].x,segPath[i].y,segsDone[j])
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
				-- this port goes in conn1
				connA[#connA].port[#connA.port + 1] = conn.port[i]
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
		local grdx,grdy = cnvobj.grid_x,cnvobj.grid_y
		if not cnvobj.snapGrid then
			grdx,grdy = 1,1
		end
		offx = coorc.snapX(offx, grdx)
		offy = coorc.snapY(offy, grdy)
		
		-- Move each segment
		for i = 1,#segList do
			local seg = segList[i].conn.segments[segList[i].seg]	-- The segment that is being dragged
			-- route connector from previous end_x,end_y to the new end_x,end_y
			local newSegs = {}
			generateSegments(cnvobj,seg.end_x+offx,seg.end_y+offy,seg.end_x,seg.end_y,newSegs)
			-- Add these segments after this current segment
			for j = #newSegs,1,-1 do
				table.insert(segList[i].conn.segments,newSegs[j],segList[i].seg+1)
			end
			-- route connector from previous start_x,start_y to the new start_x,start_y
			newSegs = {}
			generateSegments(cnvobj,seg.start_x,seg.start_y,seg.start_x+offx,seg.start_y+offy,newSegs)
			for j = #newSegs,1,-1 do
				table.insert(segList[i].conn.segments,newSegs[j],segList[i].seg)
			end
			-- Move the segment
			seg.start_x = seg.start_x + offx
			seg.start_y = seg.start_y + offy
			seg.end_x = seg.end_x + offx
			seg.end_y = seg.end_y + offy
			-- Connect overlapping ports
			connectOverlapPorts(cnvobj,segList[i].conn)
			-- Now lets check whether there are any shorts to any other connector by this dragged segment. The shorts can be on the segment end points
			-- remove any overlaps in the final merged connector
			repairSegAndJunc(cnvobj,shortAndMergeConnectors(cnvobj,{
					{x = seg.start_x,y=seg.start_y},
					{x = seg.end_x,y=seg.end_y}
				}))
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
			connectOverlapPorts(cnvobj,segList[i].conn)
			-- Now lets check whether there are any shorts to any other connector by this dragged segment. The shorts can be on the segment end points
			local seg = segList[i].conn.segments[segList[i].seg]
			-- remove any overlaps in the final merged connector
			repairSegAndJunc(cnvobj,shortAndMergeConnectors(cnvobj,{
					{x = seg.start_x,y=seg.start_y},
					{x = seg.end_x,y=seg.end_y}
				}))
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
	cnvobj.op.oldSegs = {}
	for i = 1,#segList do
		cnvobj.op.oldSegs[i] = tu.copyTable(segList[i].conn.segments,{},true)	-- Copy the entire segments table by duplicating it value by value
	end
	
	-- button_CB to handle segment dragging
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		y = cnvobj.height - y
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
		y = cnvobj.height - y
		local grdx,grdy = cnvobj.grid_x,cnvobj.grid_y
		if not cnvobj.snapGrid then
			grdx,grdy = 1,1
		end
		x = coorc.snapX(x, grdx)
		y = coorc.snapY(y, grdy)
		local offx,offy = x-refX,y-refY
		cnvobj.op.offx = offx
		cnvobj.op.offy = offy

		-- Now shift the segments and redo the connectors
		for i = 1,#segList do
			-- First copy the old segments to the connector
			segList[i].conn.segments = {}
			tu.copyTable(cnvobj.op.oldSegs[i],segList[i].conn.segments,true)	-- Copy the oldSegs[i] table back to the connector segments
		end
		for i = 1,#segList do
			local seg = segList[i].conn.segments[segList[i].seg]	-- The segment that is being dragged
			-- route connector from previous end_x,end_y to the new end_x,end_y
			local newSegs = {}
			generateSegments(cnvobj,seg.end_x+offx,seg.end_y+offy,seg.end_x,seg.end_y,newSegs)
			-- Add these segments after this current segment
			for j = #newSegs,1,-1 do
				table.insert(segList[i].conn.segments,newSegs[j],segList[i].seg+1)
			end
			-- route connector from previous start_x,start_y to the new start_x,start_y
			newSegs = {}
			generateSegments(cnvobj,seg.start_x,seg.start_y,seg.start_x+offx,seg.start_y+offy,newSegs)
			for j = #newSegs,1,-1 do
				table.insert(segList[i].conn.segments,newSegs[j],segList[i].seg)
			end
			-- Move the segment
			seg.start_x = seg.start_x + offx
			seg.start_y = seg.start_y + offy
			seg.end_x = seg.end_x + offx
			seg.end_y = seg.end_y + offy
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
		local grdx,grdy = cnvobj.grid_x,cnvobj.grid_y
		if not cnvobj.snapGrid then
			grdx,grdy = 1,1
		end
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
			segs[i].start_x = coorc.snapX(segs[i].start_x, grdx)
			segs[i].start_y = coorc.snapY(segs[i].start_y, grdy)
			segs[i].end_x = coorc.snapX(segs[i].end_x, grdx)
			segs[i].end_y = coorc.snapY(segs[i].end_y, grdy)
			local jcst,jcen=0,0	-- counters to count how many segments does the start point of the i th segment connects to (jcst) and how many connectors does the end point of the i th segment connects to (jcen)
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
					if not ep and (coorc.PointOnLine(segs[j].start_x, segs[j].start_y, segs[j].end_x, segs[j].end_y, segs[i].start_x, segs[i].start_y, 0)  
					  or coorc.PointOnLine(segs[j].start_x, segs[j].start_y, segs[j].end_x, segs[j].end_y, segs[i].end_x, segs[i].end_y, 0)) then
						return nil, "The end point of a segment touches a mid point of another segment."	-- This is not allowed since that segment should have been split into 2 segments
					end
				end
			end
			if jcst > 1 then
				-- More than 1 segment connects the starting point of the ith segment so the starting point is a junction
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
		-- Check all the ports in the drawn structure and see if any port lies on this connector then connect to it
		connectOverlapPorts(cnvobj,conn)
		
		local coor = {}	-- To collect the coordinates of all the segment end points
		for i = 1,#segs do
			local coor1 = {x = segs[i].start_x,y=segs[i].start_y}
			local coor2 = {x = segs[i].end_x,y=segs[i].end_y}
			if not tu.inArray(coor,coor1,equalCoordinate) then
				coor[#coor + 1] = coor1
			end
			if not tu.inArray(coor,coor2,equalCoordinate) then
				coor[#coor + 1] = coor2
			end
		end
		-- Now lets check whether there are any shorts to any other connector. The shorts can be on the segment end points compiled in coor and then 
		-- remove any overlaps in the final merged connector
		repairSegAndJunc(cnvobj,shortAndMergeConnectors(cnvobj,coor))
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
		-- Get the ports at the start of the connector and add it
		checkAndAddPorts(cnvobj,segTable[1].start_x,segTable[1].start_y,conn)
		-- Get the ports at the end of the connector
		checkAndAddPorts(cnvobj,segTable[#segTable].end_x,segTable[#segTable].end_y,conn)
		-- Update the connector id counter
		cnvobj.drawn.conn.ids = cnvobj.drawn.conn.ids + 1
		-- Add the connector to be drawn in the order array
		cnvobj.drawn.order[#cnvobj.drawn.order + 1] = {
			type = "connector",
			item = cnvobj.drawn.conn[cnvobj.op.cIndex]
		}
		-- Now check whether the starting point or the ending point was at a connector then this connector needs to be merged with them
		shortAndMergeConnectors(cnvobj,{
				{x=segTable[1].start_x,y=segTable[1].start_y},
				{x=segTable[#segTable].end_x,y=segTable[#segTable].end_y}
			}) 
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB
	end		-- Function endConnector ends here
	
	local function startConnector(x,y)
		local conn = cnvobj.drawn.conn
		local grdx, grdy = cnvobj.grid_x,cnvobj.grid_y
		if not cnvobj.snapGrid then
			grdx,grdy = 1,1
		end
		local X,Y  =  coorc.snapX(x, grdx),coorc.snapY(x, grdy)
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
		y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
		if button == iup.BUTTON1 and pressed == 1 then
			if cnvobj.op.mode ~= "DRAWCONN" then
				startConnector(x,y)
			elseif #cnvobj:getPortFromXY(x, y) > 0 or #getConnFromXY(cnvobj,x,y,0) > 0 then
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
			y = cnvobj.height - y
			local cIndex = cnvobj.op.cIndex
			local segStart = cnvobj.op.startseg
			local startX = cnvobj.op.start.x
			local startY = cnvobj.op.start.y
			cnvobj.drawn.conn[cIndex] = cnvobj.drawn.conn[cIndex] or 	-- new connector object described below:
				{
					segments = {},
					id=cnvobj.op.connID,
					order=#cnvobj.drawn.order+1,
					junction={},
					port={}
				}
			local connector = cnvobj.drawn.conn[cIndex]
			for i = #connector.segments,segStart,-1 do
				table.remove(connector.segments,i)
			end
			generateSegments(cnvobj, startX,startY,x, y,connector.segments)
			CC.update(cnvobj)
		end			
	end
	
end	-- end drawConnector function


