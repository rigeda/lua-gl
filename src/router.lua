
local setmetatable = setmetatable
local type = type

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
	
	local rm = {cnvobj = cnvobj}	-- routing Matrix table
	setmetatable(rm,rmMeta)
	return rm
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
