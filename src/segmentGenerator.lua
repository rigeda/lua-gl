local print = print
local math = math
local table = table
local pairs = pairs
local string = string
local math = math

local snap = require("snap")
local check = require("ClickFunctions")
local tableUtils = require("tableUtils")
local BreadthFirstSearch = require("BreadthFirstSearch")


local M = {}
package.loaded[...] = M 
local _ENV = M

function s2t_Of_1to4(str)
    t = {}
    for i=1, #str do
        table.insert(t, string.sub(str,i,i))
    end
    for i=1, #t do
        if t[i] == "U" then
            t[i] = 1
        elseif t[i] == "L" then
            t[i] = 2
        elseif t[i] == "R" then
            t[i] = 3
        else
            t[i] = 4
        end
    end
    return t
end

function findMatrix(cnvobj)
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



function generateSegments(cnvobj, connectorID, segLen, startX, startY, x, y)
    --print(connectorID)
   

    local matrix_width = math.floor(cnvobj.width/cnvobj.grid_x) + 1
    local matrix_height = math.floor(cnvobj.height/cnvobj.grid_y) + 1
    
    --srcX is sourceX in binary matrix and startX is exact start point of connector on canvas
    --destX is destinationX in binrary matrix and x is exact end point of connector on canvas
    local srcX  =  snap.Sx(startX, cnvobj.grid_x)/cnvobj.grid_x + 1
    local srcY  =  snap.Sy(startY, cnvobj.grid_y)/cnvobj.grid_y + 1
    local destX =  snap.Sx(x, cnvobj.grid_x)/cnvobj.grid_x + 1
    local destY =  snap.Sy(y, cnvobj.grid_y)/cnvobj.grid_y + 1
   
    local shortestPathLen, shortestPathString = BreadthFirstSearch.BFS(cnvobj.matrix, srcX, srcY, destX, destY, matrix_width, matrix_height)
    
    if shortestPathString == 0 or shortestPathLen == -1 then
        return 
    end

    while segLen > 1 do
        table.remove(cnvobj.connector[connectorID].segments, segLen)
        segLen = segLen - 1
    end

    local shortestpathTable = s2t_Of_1to4(shortestPathString)
    --[[str = ""
    for k,v in pairs(shortestpathTable) do
        str = str..v.." "
    end
    print(str)]]

    rowNum = {-1, 0, 0, 1}; 
    colNum = {0, -1, 1, 0}; 

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
            cnvobj.connector[connectorID].segments[i].ID = segLen + 1
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