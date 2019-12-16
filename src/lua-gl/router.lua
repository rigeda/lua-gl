
local setmetatable = setmetatable
local type = type
local table = table
local pairs = pairs
local min = math.min
local max = math.max
local floor = math.floor

local tu = require("tableUtils")
local coorc = require("lua-gl.CoordinateCalc")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

local function fillLimits(rm,x,y)
	if x < rm.minX then
		rm.minX = x
	elseif x > rm.maxX then
		rm.maxX = x
	end
	if y < rm.minY then
		rm.minY = y
	elseif y > rm.maxY then
		rm.maxY = y
	end
end

-- routing matrix metatable
local rmMeta = {
	__index = {
		addSegment = function(rm,key,x1,y1,x2,y2)
			if y1 == y2 then
				-- This segment is horizontal
				rm.hsegs[key] ={x1 = x1,x2=x2,y1=y1,y2=y2}
			elseif x1 == x2 then
				-- This segment is vertical
				rm.vsegs[key] ={x1 = x1,x2=x2,y1=y1,y2=y2}
			end
			fillLimits(rm,x1,y1)
			fillLimits(rm,x2,y2)
			return true
		end,
		removeSegment = function(rm,key)
			rm.hsegs[key] = nil
			rm.vsegs[key] = nil
			return true
		end,
		addBlockRectangle = function(rm,key,x1,y1,x2,y2)
			rm.blksegs[key] = {x1=x1,y1=y1,x2=x2,y2=y2}
			fillLimits(rm,x1,y1)
			fillLimits(rm,x2,y2)
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
			fillLimits(rm,x,y)
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
				local intersect = coorc.doIntersect(v.x1,v.y1,v.x1,v.y2,x1,y1,x2,y2) -- p1,q1,p2,q2
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
				-- Segment 2 is x1,y1 x2,y1 of blksegs
				intersect = coorc.doIntersect(v.x1,v.y1,v.x2,v.y1,x1,y1,x2,y2) -- p1,q1,p2,q2
				if intersect and intersect > 2 then	-- 3,4,5 are not allowed i.e. crossing the blk segment (5), blk segment end lies on the step line (3,4)
					return false
				end
				if intersect then	-- case 1 and 2
					-- This has to be a port and final destination
					return x2 == dstX and y2 == dstY and rm.ports[x2][y2]
				end
				-- Segment 3 is x1,y2 x2,y2 of blksegs
				intersect = coorc.doIntersect(v.x1,v.y2,v.x2,v.y2,x1,y1,x2,y2) -- p1,q1,p2,q2
				if intersect and intersect > 2 then	-- 3,4,5 are not allowed i.e. crossing the blk segment (5), blk segment end lies on the step line (3,4)
					return false
				end
				if intersect then	-- case 1 and 2
					-- This has to be a port and final destination
					return x2 == dstX and y2 == dstY and rm.ports[x2][y2]
				end
				-- Segment 4 is x2,y1 x2,y2 of blksegs
				intersect = coorc.doIntersect(v.x2,v.y1,v.x2,v.y2,x1,y1,x2,y2) -- p1,q1,p2,q2
				if intersect and intersect > 2 then	-- 3,4,5 are not allowed i.e. crossing the blk segment (5), blk segment end lies on the step line (3,4)
					return false
				end
				if intersect then	-- case 1 and 2
					-- This has to be a port and final destination
					return x2 == dstX and y2 == dstY and rm.ports[x2][y2]
				end				
			end
			if rm.ports[x2][y2] then
				return x2 == dstX and y2 == dstY
			end
			-- Go through the segments
			local vmove = x1 == x2
			local hmove = y1 == y2
			for k,v in pairs(rm.vsegs) do
				if v.x1 == x2 and (v.y1 == y2  or v.y2 == y2) then
					-- stepping on end point (only allowed if that is the destination)
					return x2 == dstX and y2 == dstY
				end
				if vmove and v.x1 == x1 and y2 > min(v.y1,v.y2) and y < max(v.y1,v.y2) then
					-- cannot do vertical move on a vertical segment
					return false
				end
			end
			for k,v in pairs(rm.hsegs) do 
				if v.y1 == y2 and (v.x1 == x2 or v.x2 == x2) then
					-- stepping on end point (only allowed if that is the destination)
					return x2 == dstX and y2 == dstY
				end
				if hmove and v.y1 == y1 and x2 > min(v.x1,v.x2) and y < max(v.x1,v.x2) then
					-- cannot do horizontal move on a horizontal segment
					return false
				end
			end
			return true	-- step is allowed
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
local function BFS(rM,srcX,srcY,destX,destY,stepX,stepY,minX,minY,maxX,maxY) 

	-- Setup the Matrix width and height according to the min and max in the routing matrix
	minX = minX or (rM.minX - stepX)
	minY = minY or (rM.minY - stepY)
	maxX = maxX or (rM.maxX + stepX)
	maxY = maxY or (rM.maxY + stepY)
	
	local function valid(X, Y) 
		return X >= minX and X <= maxX and Y >= minY and Y <= maxY 
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
function generateSegments(cnvobj, X,Y,x, y,segments)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	local grdx, grdy = cnvobj.grid_x,cnvobj.grid_y
	if not cnvobj.snapGrid then
		grdx,grdy = 1,1
	end
	local minX = cnvobj.size and -floor(cnvobj.size.width/2)
	local maxX = cnvobj.size and floor(cnvobj.size.width/2)
	local minY = cnvobj.size and -floor(cnvobj.size.height/2)
	local maxY = cnvobj.size and floor(cnvobj.size.height/2)
    
	-- The start and end points
    local srcX  =  coorc.snapX(X, grdx)/grdx
    local srcY  =  coorc.snapY(Y, grdy)/grdy
    local destX =  coorc.snapX(x, grdx)/grdx
    local destY =  coorc.snapY(y, grdy)/grdy
	
	if srcX == destX and srcY == destY then
		-- No distance yet so no segments should be generated
		return true
	end
	local rM = cnvobj.rM
   
    local shortestPathLen, shortestPathString = BFS(rM, srcX, srcY, destX, destY, grdx, grdy, minX, minY, maxX, maxY)
    
	if not shortestPathLen then
        return nil,"Cannot reach destination" 
    end
	
	local xstep = {
		U = 0,
		D = 0,
		L = -1,
		R = 1
	}
	local ystep = {
		U = -1,
		D = 1,
		L = 0,
		R = 0,
	}
	
	-- Now generate the segments
	local i = 1
	while i <= #shortestPathString do
		local c = shortestPathString:sub(i,i)	-- Get the character at position i
		-- Now count how many of them are repeated
		local st = shortestPathString:find("[^"..c.."]",i+1)
		local t = {}
		if i == 1 then
			t.start_x = srcX
			t.start_y = srcY
		else
			t.start_x = segments[#segments].end_x
			t.start_y = segments[#segments].end_y
		end
		t.end_x = t.start_x + grdx* (st-i)*xstep[c]
		t.end_y = t.start_y + grdy* (st-i)*ystep[c]
		segments[#segments + 1] = t
		-- Add the segment to routing matrix with t as the key
		rM:addSegment(t,t.start_x,t.start_y,t.end_x,t.end_y)
    end
	
	return true
end
