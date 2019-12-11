
local setmetatable = setmetatable
local type = type
local table = table

local tu = require("tableUtils")

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
		end,
		removeSegment = function(rm,key)
		end,
		addBlockRectangle = function(rm,key,x1,y1,x2,y2)
		end,
		removeBlockingRectangle = function(rm,key)
		end,
		stepAllowed = function(rm,x1,y1,x2,y2)
		end
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
		maxY = 0
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
			
			
			if valid(srcX, srcY) and rM[srcX][srcY]==1 and not visited[srcX][srcY] then
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
