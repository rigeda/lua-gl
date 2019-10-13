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



function generateSegments(cnvobj, connectorID, segLen, x, y)
    local matrix_width = math.floor(cnvobj.width/cnvobj.grid_x) + 1
    local matrix_height = math.floor(cnvobj.height/cnvobj.grid_y) + 1
    

    local srcX  =  snap.Sx(cnvobj.connector[connectorID].segments[segLen].start_x, cnvobj.grid_x)/cnvobj.grid_x + 1
    local srcY  =  snap.Sy(cnvobj.connector[connectorID].segments[segLen].start_y, cnvobj.grid_y)/cnvobj.grid_y + 1
    local destX =  snap.Sx(x, cnvobj.grid_x)/cnvobj.grid_x + 1
    local destY =  snap.Sy(y, cnvobj.grid_y)/cnvobj.grid_y + 1
    --print(srcX, srcY, destX, destY)

    local shortestPathLen, shortestPathString = BreadthFirstSearch.BFS(cnvobj.matrix, srcX, srcY, destX, destY, matrix_width, matrix_height)
    if shortestPathString == 0 or shortestPathLen == -1 then
        return 
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
        
        cnvobj.connector[connectorID].segments[segLen].end_x = math.floor(cnvobj.connector[connectorID].segments[segLen].start_x + rowNum[shortestpathTable[1]]*cnvobj.grid_x)
        cnvobj.connector[connectorID].segments[segLen].end_y = math.floor(cnvobj.connector[connectorID].segments[segLen].start_y + colNum[shortestpathTable[1]]*cnvobj.grid_y)
        --print(cnvobj.connector[connectorID].segments[segLen].start_x,cnvobj.connector[connectorID].segments[segLen].start_y,cnvobj.connector[connectorID].segments[segLen].end_x,cnvobj.connector[connectorID].segments[segLen].end_y)

        for i=2, shortestPathLen do
            
            local segLen = #cnvobj.connector[connectorID].segments
            cnvobj.connector[connectorID].segments[segLen+1] = {}
            cnvobj.connector[connectorID].segments[segLen+1].ID = segLen + 1
            cnvobj.connector[connectorID].segments[segLen+1].start_x = cnvobj.connector[connectorID].segments[segLen].end_x 
            cnvobj.connector[connectorID].segments[segLen+1].start_y = cnvobj.connector[connectorID].segments[segLen].end_y
            cnvobj.connector[connectorID].segments[segLen+1].end_x =math.floor(cnvobj.connector[connectorID].segments[segLen+1].start_x + (rowNum[shortestpathTable[i]])*cnvobj.grid_x)
            cnvobj.connector[connectorID].segments[segLen+1].end_y =math.floor(cnvobj.connector[connectorID].segments[segLen+1].start_y + (colNum[shortestpathTable[i]])*cnvobj.grid_y)
            --print(cnvobj.connector[connectorID].segments[segLen+1].start_x,cnvobj.connector[connectorID].segments[segLen+1].start_y,cnvobj.connector[connectorID].segments[segLen+1].end_x,cnvobj.connector[connectorID].segments[segLen+1].end_y)
        
        end
    end
    
end