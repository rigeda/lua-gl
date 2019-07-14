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


local function RectAroundLine(x1, y1, x2, y2, x, y, h)
    local rect = {}
    local h = h/2
    local dx = x1- x2
    local dy = y1 - y2
    local d = math.sqrt(dx * dx + dy * dy)
    dx = h * dx / d
    dy = h * dy / d
    rect[1] = {}
    rect[1].x, rect[1].y = x1 - dy, y1 + dx
    rect[2] = {}
    rect[2].x, rect[2].y = x1 + dy, y1 - dx
    rect[3] = {}
    rect[3].x, rect[3].y = x2 - dy, y2 + dx
    rect[4] = {}
    rect[4].x, rect[4].y = x2 + dy, y2 - dx

    local xyLiesInsideRect = check(rect[1].x, rect[1].y, rect[2].x, rect[2].y, rect[4].x, rect[4].y, rect[3].x, rect[3].y, x, y)
   
    if xyLiesInsideRect then
        return 1  
    else 
        return 0
    end
end


function main(cnvobj, x, y)
    local index = 0
    if #cnvobj.drawnEle > 0 then
        y = cnvobj.height - y
        for i=#cnvobj.drawnEle, 1, -1 do

            -- for line
            if cnvobj.drawnEle[i].shape == "LINE" then

                x1 = cnvobj.drawnEle[i].start_x
                y1 = cnvobj.drawnEle[i].start_y
                x2 = cnvobj.drawnEle[i].end_x
                y2 = cnvobj.drawnEle[i].end_y

                index = RectAroundLine(x1, y1, x2, y2, x, y, cnvobj.grid_x)
                
                if index == 1 then
                    cnvobj.activeEle[1] = cnvobj.drawnEle[i]
                    table.remove(cnvobj.drawnEle, i)
                    return index
                end
               
            end

            -- for rect
            if cnvobj.drawnEle[i].shape == "RECT" then
                -- four coor. of rect
                local x1, y1 = cnvobj.drawnEle[i].start_x, cnvobj.drawnEle[i].start_y
                local x3, y3 = cnvobj.drawnEle[i].end_x , cnvobj.drawnEle[i].end_y
                local x2, y2, x4, y4
                --print(x1,y1,x3,y3)
                if x1 < x3 and y1 < y3 then
                    x2 = x1 
                    y2 = y3
                    x4 = x3
                    y4 = y1
                elseif x1 < x3 and y1 > y3 then
                    x2 = x3
                    y2 = y1
                    x4 = x1
                    y4 = y3
                elseif x1 > x3 and y1 < y3 then
                    x2 = x3 
                    y2 = y1
                    x4 = x1
                    y4 = y3
                elseif x1 > x3 and y1 < y3 then
                    x2 = x3
                    y2 = y1 
                    x4 = x1
                    y4 = y3
                end

                local i1 = RectAroundLine(x1,y1,x2,y2,x,y,cnvobj.grid_x)
                local i2 = RectAroundLine(x2,y2,x3,y3,x,y,cnvobj.grid_x)
                local i3 = RectAroundLine(x3,y3,x4,y4,x,y,cnvobj.grid_x)
                local i4 = RectAroundLine(x4,y4,x1,y1,x,y,cnvobj.grid_x)
                
                if i1==1 or i2 == 1 or i3 == 1 or i4 == 1 then
                    cnvobj.activeEle[1] = cnvobj.drawnEle[i]
                    table.remove(cnvobj.drawnEle, i)
                    return i
                end

            end
        end
        return index
    end
end