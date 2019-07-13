local print = print
local math = math
local pairs = pairs
local table = table
local M = {}
package.loaded[...] = M
_ENV = M


local function area(x1, y1, x2, y2, x3, y3) 
    return math.abs((x1 * (y2 - y3) + x2 * (y3 - y1) +  x3 * (y1 - y2)) / 2.0) 
end

local function check(x1, y1, x2, y2, x3, y3, x4, y4, x, y) 
             
    local A = area(x1, y1, x2, y2, x3, y3) +  area(x1, y1, x4, y4, x3, y3) 
  
    local A1 = area(x, y, x1, y1, x2, y2)
  
    local A2 = area(x, y, x2, y2, x3, y3)
  
    local A3 = area(x, y, x3, y3, x4, y4) 
  
    local  A4 = area(x, y, x1, y1, x4, y4)
    return math.abs(A - (A1 + A2 + A3 + A4)) < 5 
end


local function RectAroundLine(cnvobj, i, x, y)
    local rect = {}
    local h = cnvobj.grid_x
    local dx = cnvobj.drawnEle[i].start_x - cnvobj.drawnEle[i].end_x
    local dy = cnvobj.drawnEle[i].start_y - cnvobj.drawnEle[i].end_y
    local d = math.sqrt(dx * dx + dy * dy)
    dx = 0.5 * h * dx / d
    dy = 0.5 * h * dy / d
    rect[1] = {}
    rect[1].x, rect[1].y = cnvobj.drawnEle[i].start_x - dy, cnvobj.drawnEle[i].start_y + dx
    rect[2] = {}
    rect[2].x, rect[2].y = cnvobj.drawnEle[i].start_x + dy, cnvobj.drawnEle[i].start_y - dx
    rect[3] = {}
    rect[3].x, rect[3].y = cnvobj.drawnEle[i].end_x - dy, cnvobj.drawnEle[i].end_y + dx
    rect[4] = {}
    rect[4].x, rect[4].y = cnvobj.drawnEle[i].end_x + dy, cnvobj.drawnEle[i].end_y - dx
    local xyLiesInsideRect = check(rect[1].x, rect[1].y, rect[2].x, rect[2].y, rect[4].x, rect[4].y, rect[3].x, rect[3].y, x, y)
   
    if xyLiesInsideRect then
        return i  
    end
end


function main(cnvobj, x, y)
    if #cnvobj.drawnEle > 0 then
        y = cnvobj.height - y
        local index = 0
        for i=1, #cnvobj.drawnEle, 1 do
            
            if cnvobj.drawnEle[i].shape == "LINE" then
                index = RectAroundLine(cnvobj, i, x, y)
                
                if index == i then
                    cnvobj.activeEle[1] = cnvobj.drawnEle[index]
                    table.remove(cnvobj.drawnEle,index)
                    return index
                end
               
            end
        end
        return index
    end
end