-- Module to handle connectors for lua-gl

local table = table
local type = type
local math = math
local tonumber = tonumber

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
	id = <integer>,		-- unique ID for the connector. Format is C<num> i.e. C followed by a unique number
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
		for j = 1,#segs do
			if coorc.PointOnLine(segs[j].start_x, segs[j].start_y, segs[j].end_x, segs[j].end_y, x, y, res)  then
				allConns[#allConns + 1] = conns[i]
				segs[#segs + 1] = {conn = i, seg = j}
				break
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
		return
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
		local conn = cnvobj.drawn.conn
		local shorted = {}		-- To store all connector information which get shorted to this new connector whose segments are given in segs
		local junc = {}			-- To store all new created junctions
		for i = 1,#segs do
			if type(segs[i]) ~= "table" then
				return nil,"Invalid segments table given"
			end
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
			-- This segment is valid. Check if this shorts to any other connector
			local allConns,segsI
			local X,Y = segs[i].start_x,segs[i].start_y
			allConns,segsI = getConnFromXY(cnvobj,X,Y,0)	-- 0 resolution check
			if #allConns > 0 then
				-- Since it shorts to other connectors add it as a junction
				junc[#junc + 1] = {x=segs[i].start_x,y=segs[i].start_y}
				-- Now split the segments if required
				-- Add all the shorted connectors
				for j = 1,#segsI do
					local segTable = allConns[j].segments
					local k = segsI[j].seg
					-- check whether we need to split a segment and which new junctions to create
					if not(segTable[k].start_x == X and segTable[k].start_y == Y ) then 
						-- The point X,Y lies somewhere on this segment in between so split the segment into 2
						table.insert(segTable,k+1,{
							start_x = X,
							start_y = Y,
							end_x = segTable[k].end_x,
							end_y = segTable[k].end_y
						})
						segTable[k].end_x = X
						segTable[k].end_y = Y
					end					
					shorted[#shorted + 1] = segsI[j]
				end
			end			-- if segs[i].start_? coordinates lie on any connector ends
			X,Y = segs[i].end_x,segs[i].end_y
			allConns,segsI = getConnFromXY(cnvobj,X,Y,0)	-- 0 resolution check
			if #allConns > 0 then
				-- Since it shorts to other connectors add it as a junction
				junc[#junc + 1] = {x=segs[i].end_x,y=segs[i].end_y}
				-- Now split the segments if required
				-- Add all the shorted connectors
				for j = 1,#segsI do
					local segTable = allConns[j].segments
					local k = segsI[j].seg
					-- check whether we need to split a segment and which new junctions to create
					if not(segTable[k].end_x == X and segTable[k].end_y == Y ) then 
						-- The point X,Y lies somewhere on this segment in between so split the segment into 2
						table.insert(segTable,k+1,{
							start_x = X,
							start_y = Y,
							end_x = segTable[k].end_x,
							end_y = segTable[k].end_y
						})
						segTable[k].end_x = X
						segTable[k].end_y = Y
					end					
					shorted[#shorted + 1] = segsI[j]
				end
			end		-- if segs[i].end_? coordinates lie on any connector ends
		end	-- for i segs ends here
		-- Merge all the connectors in shorted, splitting is already done and junctions are already there
		if #shorted > 0 then
			local connM = cnvobj.drawn.conn[shorted[1].conn]	-- Master connector where everything will end up
			local conns = cnvobj.drawn.conn						-- All connectors structure
			local maxOrder = connM.order
			for i = 2,#shorted do
				if conns[shorted[i].conn].order > maxOrder then
					maxOrder = conns[shorted[i].conn].order
				end
				-- Copy the segments over
				local segTableD = connM.segments
				local segTableS = conns[shorted[i].conn].segments
				for i = 1,#segTableS do
					segTableD[#segTableD + 1] = segTableS[i]
				end
				-- Now add segments in segs after checking overlapping segments and merging them
				for i = 1,#segs do
					for j = 1,#segTableD do
						-- There are 8 overlapping cases
						if segTableD[j].y == segs[i].y then
							-- 4 overlapping cases
							
							
						elseif segTableD[j].x == segs[i].x then
							
						end
					end
				end
				-- Copy and update the ports
				local portD = connM.port
				local portS = conns[shorted[i].conn].port
				for i = 1,#portS do
					-- Check if this port already exists
					local found
					for j = 1,#portD do
						if portS[i] == portD[j] then
							found = true
							break
						end
					end
					if not found then
						portD[#portD + 1] = portS[i]
						-- Update the port to refer to the connM connector
						portS[i].conn[#portS[i].conn + 1] = connM
					end
				end
				-- Copy the junctions
				local juncD = connM.junction
				local juncS = conns[shorted[i].conn].junction
				for i = 1,#juncS do
					-- Check if this junction already exists
					local found
					for j = 1,#juncD do
						if juncS[i].x == juncD[j].x and juncS[i].y == juncD[j].y then
							found = true
							break
						end
					end
					if not found then
						juncD[#juncD + 1] = juncS[i]
					end
				end
			end
			-- Set the order to the highest
			connM.order = maxOrder
			-- Add a junctions if any
			local juncD = connM.junction
			for i = 1,#junc do
				local X,Y = junc[i].x,junc[i].y	
				local found
				for i = 1,#juncD do
					if juncD[i].x == X and juncD[i].y == Y then
						found = true
						break
					end
				end
				if not found then
					juncD[#juncD + 1] = junc[i]
				end
			end			
		else
			-- Create a new connector
			
		end
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
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
		
	local function setWaypoint(x,y)
		cnvobj.op.startseg = #cnvobj.drawn.conn[#cnvobj.drawn.conn].segments+1
		cnvobj.op.start = {x=x,y=y}
	end
	
	local function endConnector()
		-- Check whether the new segments overlap any port
		local conn = cnvobj.drawn.conn[cnvobj.op.cIndex]
		local segTable = conn.segments
		for i = cnvobj.op.startseg do
			local prts = cnvobj:getPortFromXY(segTable[i].start_x,j)
			for j = 1,#prts do
				local portconn = prts[j].conn
				-- Add info to the port structure about the connector
				portconn[#portconn+1] = conn
				-- Add info to the connector structure about the port
				conn.port[#conn.port + 1] = prts[j]
			end	
		end
		-- Now we also need to handle merging of connectors in case the drawn connector started and or ended on another connector
		-- First we need to see whether we need to split a segment and which new junctions to create
		local jstart,jend	-- booleans to indicate which of start and end or both of this new connector are junctions to be added in the merged connector
		-- Check whether the last point ended on a connector
		local allConns,segs = getConnFromXY(cnvobj,segTable[#segTable].end_x,segTable[#segTable].end_y,0)	-- 0 resolution check
		if #cnvobj.op.merge > 0 or #segs > 0 then
			-- Conectors need to be merged
			if #segs > 1 then	-- At least 1 connector which is drawn just now should be returned
				jstop = true	-- junction needs to be created at the ending point
				-- lets split the segments in the connectors where the start points appear
				segTable = conn.segments
				local X,Y = segTable[#segTable].end_x,segTable[#segTable].end_y	-- The ending point of the new drawn connector can be on another connectors
				for i = 1,#segs do
					local segTable = cnvobj.drawn.conn[segs[i].conn].segments
					local j = segs[i].seg	-- Contains the segment number where the point X,Y lies
					-- Check whether any of the end points match X1,Y1
					if not(segTable[j].start_x == X and segTable[j].start_y == Y or segTable[j].end_x == X and segTable[j].end_y == Y) then 
						-- The point X,Y lies somewhere on this segment in between so split the segment into 2
						table.insert(segTable,j+1,{
							start_x = X,
							start_y = Y,
							end_x = segTable[j].end_x,
							end_y = segTable[j].end_y
						})
						segTable[j].end_x = X
						segTable[j].end_y = Y
					end
				end
			end
			if #cnvobj.op.merge > 0 then
				jstart = true	-- junction needs to be created at the starting point
				-- lets split the segments in the connectors where the start points appear
				segTable = conn.segments
				local X,Y = segTable[1].start_x,segTable[1].start_y	-- The starting point of the new drawn connector can be on another connectors
				local segs = cnvobj.op.merge
				for i = 1,#segs do
					local segTable = cnvobj.drawn.conn[segs[i].conn].segments
					local j = segs[i].seg	-- Contains the segment number where the point X,Y lies
					-- Check whether any of the end points match X1,Y1
					if not(segTable[j].start_x == X and segTable[j].start_y == Y or segTable[j].end_x == X and segTable[j].end_y == Y) then 
						-- The point X,Y lies somewhere on this segment in between so split the segment into 2
						table.insert(segTable,j+1,{
							start_x = X,
							start_y = Y,
							end_x = segTable[j].end_x,
							end_y = segTable[j].end_y
						})
						segTable[j].end_x = X
						segTable[j].end_y = Y
					end
				end
			end
			-- Now merge all the connectors
			local connM = cnvobj.drawn.conn[segs[1].conn]	-- Master connector where everything will end up
			local conns = cnvobj.drawn.conn					-- All connectors structure
			local maxOrder = connM.order
			for i = 2,#segs do
				if conns[segs[i].conn].order > maxOrder then
					maxOrder = conns[segs[i].conn].order
				end
				-- Copy the segments over
				local segTableD = connM.segments
				local segTableS = conns[segs[i].conn].segments
				for i = 1,#segTableS do
					segTableD[#segTableD + 1] = segTableS[i]
				end
				-- Copy and update the ports
				local portD = connM.port
				local portS = conns[segs[i].conn].port
				for i = 1,#portS do
					-- Check if this port already exists
					local found
					for j = 1,#portD do
						if portS[i] == portD[j] then
							found = true
							break
						end
					end
					if not found then
						portD[#portD + 1] = portS[i]
						-- Update the port to refer to the connM connector
						portS[i].conn[#portS[i].conn + 1] = connM
					end
				end
				-- Copy the junctions
				local juncD = connM.junction
				local juncS = conns[segs[i].conn].junction
				for i = 1,#juncS do
					-- Check if this junction already exists
					local found
					for j = 1,#juncD do
						if juncS[i].x == juncD[j].x and juncS[i].y == juncD[j].y then
							found = true
							break
						end
					end
					if not found then
						juncD[#juncD + 1] = juncS[i]
					end
				end
			end
			-- Set the order to the highest
			connM.order = maxOrder
			-- Add a junctions if required for jstart and jstop
			local juncD = connM.junction
			segTable = conn.segments
			if jstart then
				local X,Y = segTable[1].start_x,segTable[1].start_y	-- The starting point of the new drawn connector can be on another connectors
				local found
				for i = 1,#juncD do
					if juncD[i].x == X and juncD[i].y == Y then
						found = true
						break
					end
				end
				if not found then
					juncD[#juncD + 1] = {x=X,y=Y}
				end
			end			
			if jend then
				local X,Y = segTable[#segTable].end_x,segTable[#segTable].end_y	-- The ending point of the new drawn connector can be on another connectors
				local found
				for i = 1,#juncD do
					if juncD[i].x == X and juncD[i].y == Y then
						found = true
						break
					end
				end
				if not found then
					juncD[#juncD + 1] = {x=X,y=Y}
				end				
			end
		else
			-- New connector was added in this case
			cnvobj.drawn.conn.ids = cnvobj.drawn.conn.ids + 1
			-- Add the connector to be drawn in the order array
			cnvobj.drawn.order[#cnvobj.drawn.order + 1] = {
				type = "connector",
				item = cnvobj.drawn.conn[cnvobj.op.cIndex]
			}
		end
		-- Check where the segments cross over ports then connect them to the ports here
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB
	end		-- Function endConnector ends here
	
	local function startConnector(x,y)
		cnvobj.op.mode = "DRAWCONN"	-- Set the mode to drawing object
		cnvobj.op.start = {x=x,y=y}	-- snapping is done in generateSegments
		-- Check whether this lies on any connector then this would be a junction and add segments to that connector
		-- Note however if x,y is at a crossover where multiple connectors lie it will connect to the connector that was drawn last
		local conn = cnvobj.drawn.conn
		local grdx, grdy = cnvobj.grid_x,cnvobj.grid_y
		if not cnvobj.snapGrid then
			grdx,grdy = 1,1
		end
		local X,Y  =  coorc.snapX(x, grdx),coorc.snapY(x, grdy)
		cnvobj.op.startseg = 1
		-- Check if the starting point lays on another connector
		local allConns,segs = getConnFromXY(cnvobj,X,Y,0)	-- 0 resolution check
		cnvobj.op.connID = (#allConns > 0 and "MERGE") or ("C"..tostring(cnvobj.drawn.conn.ids + 1))
		cnvobj.op.cIndex = #cnvobj.drawn.conn + 1
		-- Add this connector to the merge list
		--segs[#segs + 1] = {conn=cnvobj.op.cIndex,seg=1}
		cnvobj.op.merge = segs	-- segs contains the connector number and segment number of all the connectors where X,Y lies
		cnvobj.op.end = endConnector
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
			endConnector()
		end
		-- Process any hooks 
		cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y,status})
	end
	
	function cnvobj.cnv:motion_cb(x,y,status)
		--connectors
		if cnvobj.op.mode == "DRAWCONN" and cnvobj.connectorFlag == true then
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


