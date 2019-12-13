
local setmetatable = setmetatable
local type = type
local table = table
local pairs = pairs

local tu = require("tableUtils")
local coorc = require("lua-gl.CoordinateCalc")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- routing matrix metatable
local rmMeta = {
	__index = {
		addSegment = function(rm,key,x1,y1,x2,y2)
			if x1 == x2 then
				-- This segment is horizontal
				rm.hsegs[key] ={x1 = x1,x2=x2,y1=y1,y2=y2}
			elseif y1 == y2 then
				-- This segment is vertical
				rm.vsegs[key] ={x1 = x1,x2=x2,y1=y1,y2=y2}
			end
			-- Add the end points
			rm.segendpts[key] = {x1 = x1,x2=x2,y1=y1,y2=y2}
			return true
		end,
		removeSegment = function(rm,key)
			rm.hsegs[key] = nil
			rm.vsegs[key] = nil
			rm.segendpts[key] = nil
			return true
		end,
		addBlockRectangle = function(rm,key,x1,y1,x2,y2)
			rm.blksegs[key] = {x1=x1,y1=y1,x2=x2,y2=y2}
			return true
		end,
		removeBlockingRectangle = function(rm,key)
			rm.blksegs[key] = nil
		end,
		addPort = function(rm,key,x,y)
			if not rm.ports[x] then
				rm.ports[x] = {}
			end
			if not rm.ports[x][y] then
				rm.ports[x][y] = 0
			end
			rm.ports[key] = {x=x,y=y}
			rm.ports[x][y] = rm.ports[x][y] + 1
			return true
		end,
		removePort = function(rm,key)
			local x,y = rm.ports[key].x,rm.ports[key].y
			rm.ports[key] = nil
			rm.ports[x][y] = rm.ports[x][y] - 1
			if rm.ports[x][y] == 0 then
				rm.ports[x][y] = nil
			end
			return true
		end,
		validStep = function(rm,x1,y1,x2,y2,dstX,dstY)
			-- Function to check whether a step from x1,y1 to x2,y2 is allowed. 
			-- dstX and dstY is the final destination
			-- The rules are as follows:
			--[[
				# Check whether we are crossing a blocking segment, stepping on it or none. Crossing a blocking segment is not allowed. Stepping may be allowed if it is a port and final destination.
				# Check if x2,y2 is a port and x2==dstX and y2=dstY. x2,y2 can only be a port if it is the destination and not crossing a blocking segment
				# Check if stepping on segment end points. If it is not the destination then it is not allowed.
				# Check if this is a horizontal move then it should not be overlapping any horizontal segment
				# Check if this is a vertical move then it should not be overlapping any vertical segment
			]]
			for k,v in pairs(rm.blksegs) do
				-- Segment 1 is x1,y1 x1,y2 of blksegs
				local intersect = coorc.doIntersect(v.x1,v.y1,v.x2,v.y2,x1,y1,x2,y2) -- p1,q1,p2,q2
				-- doIntersect:
				-- Returns 5 if they intersect
				-- Returns 1 if p2 lies on p1 q1
				-- Returns 2 if q2 lies on p1 q1
				-- Returns 3 if p1 lies on p2 q2 
				-- Returns 4 if q1 lies on p2 q2
				-- Returns false if no intersection				
				if intersect and intersect > 2 then	-- 3,4,5 are not allowed i.e. crossing the blk segment (5), blk segment end lies on the step line (3,4)
					return false
				end
				if intersect then	-- case 1 and 2
					-- This has to be a port and final destination
					return x2 == dstX and y2 == dstY and rm.ports[x2][y2]
				end
				if rm.ports[x2][y2] then
					return x2 == dstX and y2 == dstY
				end
				
				
				
			end
		end,
	}
}

-- Function to generate and return a new routing Matrix
function newRoutingMatrix(cnvobj)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	
	local rm = {
		cnvobj = cnvobj,
		minX = 0,
		maxX = 0,
		minY = 0,
		maxY = 0,
		hsegs = {},		-- To store horizontal segments
		vsegs = {},		-- To store vertical segments
		blksegs = {},	-- To store blocking segments
		segendpts = {},	-- To store the end points of segments where we cannot go through
		ports = {}		-- To store the ports
	}	-- routing Matrix table
	setmetatable(rm,rmMeta)
	return rm
end

-- BFS algorithm implementation
-- function to find the shortest path and string between 
-- a given source cell to a destination cell. 
-- rM is the routing Matrix object
-- srcX and srcY are the starting coordinates
-- destX and destY are the ending coordinates
-- stepX and stepY are the increments to apply to X and Y to get to the next coordinate in the X and Y directions
function BFS(rM,srcX,srcY,destX,destY,stepX,stepY) 
	local minX,minY,maxX,maxY

	-- Setup the Matrix width and height according to the min and max in the routing matrix
	minX = rM.minX - stepX
	minY = rM.minY - stepY
	maxX = rM.maxX + stepX
	maxY = rM.maxY + stepY
	
	local function valid(X, Y) 
		if X >= minX and X <= maxX and Y >= minY and Y <= maxY then
			return true
		end
	end 
	
	-- These arrays are used to get row and column 
	-- numbers of 4 neighbours of a given cell 
	local delX = {-stepX, 0, 0, stepX}
	local delY = {0, -stepY, stepY, 0} 
	local stepStr = {"L","U","D","R"}
	
	local visited = {}	-- To mark the visited coordinates
	  
	-- Mark the source cell as visited 
	visited[srcX][srcY] = true; 
  
	-- Create a queue for BFS where the nodes from where exploration has not been fully completed are placed
	local q = {}

	-- Distance of source cell is 0 
	local str = ""	-- Path string
   
	table.insert(q,{srcX, srcY, 0, str})  -- Enqueue source cell 
  
	-- Do a BFS starting from source cell 
	while #q > 0 do 
		
		-- If we have reached the destination cell we are done 
		-- Since this is a que (FIFO) so we always check the 1st element 
		if (q[1][1] == destX and q[1][2] == destY) then
			return q[1][3], q[1][4]; 
		end
		-- Otherwise dequeue the front cell in the queue 
		-- and enqueue its adjacent cells 

		local pt = q[1]
		
		table.remove(q,1); 
		
		for i=1, 4 do
			-- Coordinates for the adjacent cell
			srcX = pt[1] + delX[i]
			srcY = pt[2] + delY[i]
		   
			-- if adjacent cell is valid, has path and 
			-- not visited yet, enqueue it. 
			if not visited[srcX] then
				visited[srcX] = {}
			end
			
			
			if valid(srcX, srcY) and rM:validStep(pt[1],pt[2],srcX,srcY,destX,destY) and not visited[srcX][srcY] then
				-- mark cell as visited and enqueue it 
				visited[srcX][srcY] = true
				-- Add the step string
				str = pt[4]..stepStr[i]					
				-- Add the adjacent cell
				table.insert(q, { srcX, srcY, pt[3] + 1, str})
			end
		end		-- for i=1, 4 do ends 
	end		-- while #q > 0 do  ends
  
	-- Return -1 if destination cannot be reached 
	return nil,"Cannot reach destination" 
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
