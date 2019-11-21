-- Module to handle connectors for lua-gl

local table = table
local type = type
local math = math

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
	segments = {	-- Array of segment structures
	},
}
]]
-- The connector structure is located in the array cnvobj.drawn.conn

-- BFS algorithm implementation
local BFS
do
	local Point = {}

	local queueNode  = {}
	local matrix_width, matrix_height = 0, 0

	local function isValid(row, col) 

		-- return true if row number and column number 
		-- is in range 
		if (row > 0) and (row <= matrix_width) and (col > 0) and (col <= matrix_height) then
			return 1
		else
			return 0
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
		if isValid(srcX,srcY) == 0 or isValid(destX, destY)==0 or mat[srcX][srcY]==0 or mat[destX][destY]==0 then 
			return -1
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
	   
		s = {srcX, srcY, 0, str}; 
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

			local pt = tu.copyTable(q[1],P{)
			
			table.remove(q,1); 
			
			for i=1, 4 do
			   
				srcX = pt[1] + rowNum[i]; 
				srcY = pt[2] + colNum[i]; 
			   
				-- if adjacent cell is valid, has path and 
				-- not visited yet, enqueue it. 
			   
				
				if isValid(srcX, srcY)==1 and mat[srcX][srcY]==1 and not visited[srcX][srcY] then
					-- mark cell as visited and enqueue it 
					visited[srcX][srcY] = true; 
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

local function findMatrix(cnvobj)
    local matrix = {}
    local matrix_width = math.floor(cnvobj.width/cnvobj.grid_x) + 1
    local matrix_height = math.floor(cnvobj.height/cnvobj.grid_y) + 1
    for i=1, matrix_width  do
        matrix[i] = {}
        for j=1, matrix_height do 
            local x = (i-1)*cnvobj.grid_x
            local y = (j-1)*cnvobj.grid_y
            local index = check.checkXY(cnvobj,x,y)
         
            if index ~= 0 and index and cnvobj.drawnEle[index].shape == "BLOCKINGRECT" then --index should not nill
                matrix[i][j]=0
            else
                matrix[i][j]=1
            end
        end
    end

    --[[for i=1, matrix_width do
        str = ""
        for j=1, matrix_height  do
            str = str..matrix[i][j].." "
        end
        print(str)
        print()
    end]]
    return matrix
end


-- Function to generate connector segment coordinates given the starting X, Y and the ending x,y coordinates
local function generateSegments(cnvobj, connectorID, segStart,startX, startY, x, y)
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
    
    if shortestPathString == 0 or shortestPathLen == -1 then
        return 
    end

	cnvobj.connector[connectorID] = cnvobj.connector[connectorID] or {segments = {}}
	
    for i = segStart,#cnvobj.connector[connectorID].segments do
        table.remove(cnvobj.connector[connectorID].segments, i)
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

    --[[if shortestPathLen == -1 then
        print("path not found")
    else
        print("Shortest path ", shortestPathLen, shortestPathString)
    end]]
    
    if shortestPathLen ~= -1 and #shortestpathTable>0 then
        
        
        --cnvobj.connector[connectorID].segments[segLen].end_x = math.floor(cnvobj.connector[connectorID].segments[segLen].start_x + rowNum[shortestpathTable[1]]*cnvobj.grid_x)
        --cnvobj.connector[connectorID].segments[segLen].end_y = math.floor(cnvobj.connector[connectorID].segments[segLen].start_y + colNum[shortestpathTable[1]]*cnvobj.grid_y)
        --print(cnvobj.connector[connectorID].segments[segLen].start_x,cnvobj.connector[connectorID].segments[segLen].start_y,cnvobj.connector[connectorID].segments[segLen].end_x,cnvobj.connector[connectorID].segments[segLen].end_y)
    
        for i=1, shortestPathLen do
            
            cnvobj.connector[connectorID].segments[i] = {}
           -- cnvobj.connector[connectorID].segments[i].ID = segLen + 1
            if i==1 then
                cnvobj.connector[connectorID].segments[i].start_x = (srcX-1)*cnvobj.grid_x
                cnvobj.connector[connectorID].segments[i].start_y = (srcY-1)*cnvobj.grid_y
            else
                cnvobj.connector[connectorID].segments[i].start_x = cnvobj.connector[connectorID].segments[i-1].end_x --if i=1 else condition will not run 
                cnvobj.connector[connectorID].segments[i].start_y = cnvobj.connector[connectorID].segments[i-1].end_y
            end
            cnvobj.connector[connectorID].segments[i].end_x =math.floor(cnvobj.connector[connectorID].segments[i].start_x + (rowNum[shortestpathTable[i]])*cnvobj.grid_x)
            cnvobj.connector[connectorID].segments[i].end_y =math.floor(cnvobj.connector[connectorID].segments[i].start_y + (colNum[shortestpathTable[i]])*cnvobj.grid_y)   
        end
        print("total seg in this connector"..#cnvobj.connector[connectorID].segments)
    end
    
end

drawConnector  = function(cnvobj)
	if not cnvobj or type(cnvobj) ~= "table" then
		return
	end
	-- Connector drawing methodology
	-- Connector drawing starts with Event 1. This event may be a mouse event or a keyboard event
	-- Connector waypoint is set with Event 2. This event may be a mouse event or a keyboard event. The waypoint freezes the connector route up till that point
	-- Connector drawing stops with Event 3. This event may be a mouse event or a keyboard event.
	-- For now the events are defined as follows:
	-- Event 1 = Mouse left click
	-- Event 2 = Mouse left click after connector start
	-- Event 3 = Mouse right click or reaching a port
	local oldBCB = cnvobj.cnv.button_cb
	local oldMCB = cnvobj.cnv.motion_cb
	
	local function startConnector(x,y)
		-- Check whether this lies on a segment of a existing connector then add this to that existing connector
		cnvobj.op.mode = "DRAWCONN"	-- Set the mode to drawing object
		cnvobj.op.start = {x,y}
		cnvobj.op.startseg = 1
		cnvobj.op.connID = cnvobj.drawn.conn.ids + 1
	end
	
	local function setWaypoint(x,y)
		cnvobj.op.startseg = #cnvobj.drawn.conn[#cnvobj.drawn.conn].segments
		cnvobj.op.start = {x,y}
	end
	
	local function endConnector(x,y)
		-- Traverse through the segments and check where they overlap with ports and connect to ports
		-- Note that diagnol segments would not be checked for this
		--[[
					local portSegTableLen = #cnvobj.port[p_ID].segmentTable
					cnvobj.port[p_ID].segmentTable[portSegTableLen+1] = {}

					cnvobj.port[p_ID].segmentTable[portSegTableLen+1].segmentID = segLen
					cnvobj.port[p_ID].segmentTable[portSegTableLen+1].connectorID = index
					cnvobj.port[p_ID].segmentTable[portSegTableLen+1].segmentStatus = "ending"
		]]
		local segTable = cnvobj.drawn.conn[cnvobj.op.connID].segments
		for i = 1,#segTable do
			local start,stop,step,mode
			if segTable[i].start_x == segTable[i].end_x then
				start = segTable[i].start_y
				stop = segTable[i].end_y
				step = cnvobj.grid_y
				mode = 1
			elseif segTable[i].start_y == segTable[i].end_y then
				start = segTable[i].start_y
				stop = segTable[i].end_y
				step = cnvobj.grid_y
				mode = 2				
			end	
			for j = start, stop,step do
				local pid 
				if mode == 1 then
					pid = cnvobj:getPortFromXY(segTable[i].start_x,j)
				else
					pid = cnvobj:getPortFromXY(j,segTable[i].start_y)
				end
				if pid then
					local portconn = #cnvobj.drawn.port[pid].conn
					cnvobj.port[pid].connector[portconn+1] = {}

					cnvobj.port[pid].connector[portconn+1].segment = i
					cnvobj.port[pid].connector[portconn+1].connectorID = cnvobj.op.connID
				end	
			end				
		end
		-- Check where the segments cross over ports then connect them to the ports here
		tu.emptyTable(cnvobj.op)
		cnvobj.op.mode = "DISP"	-- Default display mode
		cnvobj.cnv.button_cb = oldBCB
		cnvobj.cnv.motion_cb = oldMCB
	end
	
	-- button_CB to handle connector drawing
	function cnvobj.cnv:button_cb(button,pressed,x,y,status)
		y = cnvobj.height - y
		-- Check if any hooks need to be processed here
		cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
		local pid = cnvobj:getPortFromXY(x, y)
		if button == iup.BUTTON1 and pressed == 1 then
			if cnvobj.op.mode ~= "DRAWCONN" then
				startConnector(x,y)
			elseif pid then
				endConnector(x,y)
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
			generateSegments(cnvobj, cnvobj.op.connID, cnvobj.op.startseg,cnvobj.op.start.x, cnvobj.op.start.y, x, y)
			CC.update(cnvobj)
		end			
	end
	
end	-- end drawConnector function


