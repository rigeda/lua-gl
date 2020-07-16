
local setmetatable = setmetatable
local type = type
local insert = table.insert
local remove = table.remove
local pairs = pairs
local min = math.min
local max = math.max
local abs = math.abs
local floor = math.floor
local rep = string.rep

local tu = require("tableUtils")
local coorc = require("lua-gl.CoordinateCalc")

local print = print

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
		addSegment = function(rm,key,x1,y1,x2,y2)	-- key can be anything to index the router segment. In lua-gl it is actually the segment table itself.
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
		getSegment = function(rm,key)	-- Returns the copy of the structure stored in the outing matrix fot the given key
			if rm.hsegs[key] then
				return {
					x1 = rm.hsegs[key].x1, 
					y1 = rm.hsegs[key].y1, 
					x2 = rm.hsegs[key].x2, 
					y2 = rm.hsegs[key].y2
				}
			elseif rm.vsegs[key] then
				return {
					x1 = rm.vsegs[key].x1, 
					y1 = rm.vsegs[key].y1, 
					x2 = rm.vsegs[key].x2, 
					y2 = rm.vsegs[key].y2
				}
			end
			return nil
		end,
		addBlockingRectangle = function(rm,key,x1,y1,x2,y2)
			rm.blksegs[key] = {x1=x1,y1=y1,x2=x2,y2=y2}
			fillLimits(rm,x1,y1)
			fillLimits(rm,x2,y2)
			return true
		end,
		removeBlockingRectangle = function(rm,key)
			rm.blksegs[key] = nil
		end,
		getBlockingRectangle = function(rm,key)
			if rm.blksegs[key] then
				return {
					x1 = rm.blksegs[key].x1, 
					y1 = rm.blksegs[key].y1, 
					x2 = rm.blksegs[key].x2, 
					y2 = rm.blksegs[key].y2
				}
			end
			return nil
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
			-- The rules in order are as follows:
			--[[
				# Check whether we are crossing a blocking segment, stepping on it or none. Crossing a blocking segment is not allowed. Stepping may be allowed if it is a port and final destination.
				# Check if this is a horizontal move then it should not be overlapping any horizontal segment
				# Check if this is a vertical move then it should not be overlapping any vertical segment
				# Check if x2,y2 is a port and x2==dstX and y2=dstY. x2,y2 can only be a port if it is the destination and not crossing a blocking segment
				# Check if stepping on segment end points. If it is not the destination then it is not allowed.
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
					if intersect == 2 then
						-- This has to be a port and final destination
						return x2 == dstX and y2 == dstY and rm.ports[x2] and rm.ports[x2][y2]
					else
						-- p2 can lie on p1 q1 since p2 is the source. It was already allowed by the calling function
						return true
					end
				end
				-- Segment 2 is x1,y1 x2,y1 of blksegs
				intersect = coorc.doIntersect(v.x1,v.y1,v.x2,v.y1,x1,y1,x2,y2) -- p1,q1,p2,q2
				if intersect and intersect > 2 then	-- 3,4,5 are not allowed i.e. crossing the blk segment (5), blk segment end lies on the step line (3,4)
					return false
				end
				if intersect then	-- case 1 and 2
					if intersect == 2 then
						-- This has to be a port and final destination
						return x2 == dstX and y2 == dstY and rm.ports[x2] and rm.ports[x2][y2]
					else
						-- p2 can lie on p1 q1 since p2 is the source. It was already allowed by the calling function
						return true
					end
				end
				-- Segment 3 is x1,y2 x2,y2 of blksegs
				intersect = coorc.doIntersect(v.x1,v.y2,v.x2,v.y2,x1,y1,x2,y2) -- p1,q1,p2,q2
				if intersect and intersect > 2 then	-- 3,4,5 are not allowed i.e. crossing the blk segment (5), blk segment end lies on the step line (3,4)
					return false
				end
				if intersect then	-- case 1 and 
					if intersect == 2 then
						-- This has to be a port and final destination
						return x2 == dstX and y2 == dstY and rm.ports[x2] and rm.ports[x2][y2]
					else
						-- p2 can lie on p1 q1 since p2 is the source. It was already allowed by the calling function
						return true
					end
				end
				-- Segment 4 is x2,y1 x2,y2 of blksegs
				intersect = coorc.doIntersect(v.x2,v.y1,v.x2,v.y2,x1,y1,x2,y2) -- p1,q1,p2,q2
				if intersect and intersect > 2 then	-- 3,4,5 are not allowed i.e. crossing the blk segment (5), blk segment end lies on the step line (3,4)
					return false
				end
				if intersect then	-- case 1 and 2
					if intersect == 2 then
						-- This has to be a port and final destination
						return x2 == dstX and y2 == dstY and rm.ports[x2] and rm.ports[x2][y2]
					else
						-- p2 can lie on p1 q1 since p2 is the source. It was already allowed by the calling function
						return true
					end
				end				
			end
			-- Go through the segments
			local vmove = x1 == x2
			local hmove = y1 == y2
			
			for k,v in pairs(rm.vsegs) do
				if vmove and v.x1 == x1 and ((y2 > min(v.y1,v.y2) and y2 < max(v.y1,v.y2)) or  
				  (y1 > min(v.y1,v.y2) and y1 < max(v.y1,v.y2))) then
					-- cannot do vertical move on a vertical segment
					return false
				end
				if v.x1 == x2 and (v.y1 == y2  or v.y2 == y2) then
					-- stepping on end point (only allowed if that is the destination)
					return x2 == dstX and y2 == dstY
				end
			end
			for k,v in pairs(rm.hsegs) do 
				if hmove and v.y1 == y1 and ((x2 > min(v.x1,v.x2) and x2 < max(v.x1,v.x2)) or 
				  (x1 > min(v.x1,v.x2) and x1 < max(v.x1,v.x2))) then
					-- cannot do horizontal move on a horizontal segment
					return false
				end
				if v.y1 == y2 and (v.x1 == x2 or v.x2 == x2) then
					-- stepping on end point (only allowed if that is the destination)
					return x2 == dstX and y2 == dstY
				end
			end
			if rm.ports[x2] and rm.ports[x2][y2] then
				return x2 == dstX and y2 == dstY
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

-- Routing functions for different modes
-- Fully Manual. A single segment is made from source to destination irrespective of routing matrix
-- use noRoute function below with jumpSeg=2 in generateSegments
function noRoute()
	return ""
end

-- Fully Manual orthogonal. Segments can only be vertical or horizontal. From source to destination whichever is longer of the 2 would be returned
-- FOr the above use this function with jumpSegs = nil
function orthoRoute(rM,srcX,srcY,destX,destY,stepX,stepY)
	if abs(srcX-destX) > abs(srcY-destY) then
		-- Create a horizontal path
		if srcX > destX then
			return rep("L",(srcX-destX)/stepX)
		else
			return rep("R",(destX-srcX)/stepX)
		end
	else
		-- Create a vertical path
		if srcY > destY then
			return rep("U",(srcY-destY)/stepY)
		else
			return rep("D",(destY-srcY)/stepY)
		end
	end
end

-- Manual orthogonal with routing matrix guidance?
function orthoRouteRM(rM,srcX,srcY,destX,destY,stepX,stepY,minX,minY,maxX,maxY)
	local xmul,ymul,cX,cY
	if srcX > destX then
		xmul = 1
		cX = "L"
	else
		xmul = -1
		cX = "R"
	end
	if srcY > destY then
		ymul = 1
		cY = "U"
	else
		ymul = -1
		cY = "D"
	end
	local function doX(x1,y1,x2,y2)
		while not rM:validStep(x1,y1,x2,y2,destX,destY) do
			x2 = x2 + xmul*stepX
			if xmul*x2 >= xmul*srcX then
				break
			end
		end
		if xmul*x2 > xmul*srcX then 
			return nil
		end
		return rep(cX,abs(x1-x2)/stepX)		
	end
	local function doY(x1,y1,x2,y2)
		while not rM:validStep(x1,y1,x2,y2,destX,destY) do
			y2 = y2 + ymul*stepY
			if ymul*y2 >= ymul*srcY then
				break
			end
		end
		if ymul*y2 > ymul*srcY then 
			return nil
		end
		return rep(cY,abs(y1-y2)/stepY)		
	end
	if abs(srcX-destX) > abs(srcY-destY) then
		-- Create a horizontal path
		local ret = doX(srcX,srcY,destX,destY)
		if not ret then
			return doY(srcX,srcY,destX,destY) or ""
		else
			return ret
		end
	else
		-- Create a vertical path
		local ret = doY(srcX,srcY,destX,destY)
		if not ret then
			return doX(srcX,srcY,destX,destY) or ""
		else
			return ret
		end
	end	
end

-- BFS algorithm implementation for routing connector
-- function to find the shortest path and string between 
-- a given source cell to a destination cell. 
-- rM is the routing Matrix object which is used to check for valid paths. rM is not modified in any way
-- srcX and srcY are the starting coordinates
-- destX and destY are the ending coordinates
-- stepX and stepY are the increments to apply to X and Y to get to the next coordinate in the X and Y directions
function BFS(rM,srcX,srcY,destX,destY,stepX,stepY,minX,minY,maxX,maxY) 

	-- Setup the Matrix width and height according to the min and max in the routing matrix
	minX = minX or min(rM.minX - stepX,destX-stepX,srcX-stepX)
	minY = minY or min(rM.minY - stepY,destY-stepY,srcY-stepY)
	maxX = maxX or max(rM.maxX + stepX,destX+stepX,srcX+stepX)
	maxY = maxY or max(rM.maxY + stepY,destY+stepY,srcY+stepY)
	
	-- These arrays are used to get row and column 
	-- numbers of 4 neighbours of a given cell 
	local delX = {-stepX, 0, 0, stepX}
	local delY = {0, -stepY, stepY, 0} 
	local stepStr = {"L","U","D","R"}
	
	local visited = {}	-- To mark the visited coordinates
	
	visited[srcX] = {}
	-- Mark the source cell as visited 
	visited[srcX][srcY] = true; 
  
	-- Create a queue for BFS where the nodes from where exploration has not been fully completed are placed
	local q = {}
	local dist,str,dist2,str2

	q[#q+1] = {srcX, srcY, ""}
	dist = abs(destX-srcX)+abs(destY-srcY)
	str = ""	-- To store the string to the closest approach
  
	-- Do a BFS starting from source cell 
	while #q > 0 do 
		
		-- If we have reached the destination cell we are done 
		-- Since this is a que (FIFO) so we always check the 1st element 
		if (q[1][1] == destX and q[1][2] == destY) then
			return q[1][3] 
		end
		-- Otherwise dequeue the front cell in the queue 
		-- and enqueue its adjacent cells 

		local pt = q[1]
		
		remove(q,1); 
		
		for i=1, 4 do
			-- Coordinates for the adjacent cell
			srcX = pt[1] + delX[i]
			srcY = pt[2] + delY[i]
		   
			-- if adjacent cell is valid, has path and 
			-- not visited yet, enqueue it. 
			
--			if valid(srcX, srcY) and rM:validStep(pt[1],pt[2],srcX,srcY,destX,destY) and not visited[srcX][srcY] then
			if srcX >= minX and srcX <= maxX and srcY >= minY and srcY <= maxY and rM:validStep(pt[1],pt[2],srcX,srcY,destX,destY) and (not visited[srcX] or not visited[srcX][srcY]) then
				-- mark cell as visited and enqueue it 
				visited[srcX] = visited[srcX] or {}
				visited[srcX][srcY] = true
				-- Add the step string
				str2 = pt[3]..stepStr[i]
				-- Add the adjacent cell
				--insert(q, { srcX, srcY, pt[3] + 1, str})
				q[#q+1] = { srcX, srcY, str2}
				dist2 = abs(destX-srcX)+abs(destY-srcY)
				if dist2 < dist then
					dist = dist2
					str = str2
				end
			end
		end		-- for i=1, 4 do ends 
	end		-- while #q > 0 do  ends
  
	-- Could not reach destination, return the closest approached step
	return str
end

-- Function to generate connector segment coordinates given the starting X, Y and the ending x,y coordinates
-- The new segments are added to the end of the segments array passed to it
-- router is a auto-routing function to be used for routing the connector
-- jumpSeg indicates whether to generate a jumping segment or not and if to set its attributes
--	= 1 generate jumping Segment and set its visual attribute to the default jumping segment visual attribute from the visualProp table
-- 	= 2 generate jumping segment but don't set any special attribute
--  = 0 then do not generate jumping segment
-- Function returns the x,y coordinates up to which the segments were generated
function generateSegments(cnvobj, X,Y,x, y,segments,router,jumpSeg)
	print("GENERATE SEGMENTS",X,Y,x,y,"jumpSeg="..jumpSeg,jumpSeg>0)
	local grdx,grdy = cnvobj.grid.snapGrid and cnvobj.grid.grid_x or 1, cnvobj.grid.snapGrid and cnvobj.grid.grid_y or 1
	local minX = cnvobj.size and -floor(cnvobj.size.width/2)
	local maxX = cnvobj.size and floor(cnvobj.size.width/2)
	local minY = cnvobj.size and -floor(cnvobj.size.height/2)
	local maxY = cnvobj.size and floor(cnvobj.size.height/2)
    
	-- The start and end points
    local srcX  =  coorc.snapX(X, grdx)
    local srcY  =  coorc.snapY(Y, grdy)
    local destX =  coorc.snapX(x, grdx)
    local destY =  coorc.snapY(y, grdy)
	
	if srcX == destX and srcY == destY then
		-- No distance yet so no segments should be generated
		print("SOURCE AND DESTINATION SAME")
		return true
	end
	local rM = cnvobj.rM
	print("Do BFS srcX="..srcX..",srcY="..srcY..",destX="..destX..",destY="..destY..",stepX="..grdx..",stepY="..grdy..",minX="..(minX or "NIL")..",minY="..(minY or "NIL")..",maxX="..(maxX or "NIL")..",maxY="..(maxY or "NIL"))
    local shortestPathString = router(rM, srcX, srcY, destX, destY, grdx, grdy, minX, minY, maxX, maxY)
	print("GENSEGS:",shortestPathString,#shortestPathString)
	
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
	
	local reX,reY
	if shortestPathString == "" then
		reX = srcX
		reY = srcY
	end
	
	-- Now generate the segments
	local i = 1
	while i <= #shortestPathString do
		local c = shortestPathString:sub(i,i)	-- Get the character at position i
		-- Now count how many of them are repeated
		local st = shortestPathString:find("[^"..c.."]",i+1) or #shortestPathString+1
		local t = {}
		if i == 1 then
			t.start_x = srcX
			t.start_y = srcY
		else
			t.start_x = segments[#segments].end_x
			t.start_y = segments[#segments].end_y
		end
		reX = t.start_x + grdx* (st-i)*xstep[c]
		t.end_x = reX
		reY = t.start_y + grdy* (st-i)*ystep[c]
		t.end_y = reY
		segments[#segments + 1] = t
		print("Generated Segment")
		-- Add the segment to routing matrix with t as the key
		--print("Add segment",t.start_x,t.start_y,t.end_x,t.end_y)
		rM:addSegment(t,t.start_x,t.start_y,t.end_x,t.end_y)
		i = st
    end
	if jumpSeg>0 and (reX ~= destX or reY ~= destY) then
		-- Add a segment for the last jump, this is a jumping connector
		print("Generate jumpSeg")
		local s = {
			start_x = reX,
			start_y = reY,
			end_x = destX,
			end_y = destY
		}
		segments[#segments + 1] = s
		rM:addSegment(s,reX,reY,destX,destY)
		reX = destX
		reY = destY
		-- Set the attribute for the jumping segment
		cnvobj.attributes.visualAttr[s] = jumpSeg == 1 and {vAttr = 5,visualAttr = GUIFW.getFilledObjAttrFunc(cnvobj.viewOptions.visualProp[5]),attr = cnvobj.viewOptions.visualProp[5]}	-- The default jumping connector attribute
	end
	print("FINISH GENSEGS")
	return reX,reY
end
