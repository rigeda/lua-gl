local table = table
local print = print

local M = {}
package.loaded[...] = M 
local _ENV = M


Point = {}

queueNode  = {}
matrix_width, matrix_height = 0, 0

function table.clone(org)
    return {table.unpack(org)}
end


function isValid(row, col) 

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
rowNum = {-1, 0, 0, 1}; 
colNum = {0, -1, 1, 0}; 
  
-- function to find the shortest path and string between 
-- a given source cell to a destination cell. 
function BFS(mat, srcX,srcY,destX, destY, mWidth, mHeight) 
   
    -- check source and destination cell 
    -- of the matrix have value 1 
    matrix_width, matrix_height = mWidth, mHeight
    if isValid(srcX,srcY) == 0 or isValid(destX, destY)==0 and mat[srcX][srcY]==0 and mat[destX][destY]==0 then 
        return -1
    end

    visited = {}
    for i=1, matrix_width do 
        visited[i] = {}
        for j=1, matrix_height do 
            visited[i][j] = false
        end
    end
      
    -- Mark the source cell as visited 
    visited[srcX][srcY] = true; 
  
    -- Create a queue for BFS 
    q = {}

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

        pt = table.clone(q[1])
        
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
                
                Adjcell = { srcX, srcY, pt[3] + 1, str}; 
              
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
  
