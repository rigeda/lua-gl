local print = print
local math = math
local pairs = pairs
local table = table
local type = type
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

local function findRemainingCoor(x1,y1,x3,y3)
    local x2, y2, x4, y4
    --print(x1,y1,x3,y3)
    --print("("..type(x1)..","..type(y1)..") ("..type(x3)..","..type(y3)..")")
    x2 = x1
    y2 = y3 
    x4 = x3
    y4 = y1
    return x2, y2, x4, y4
end


function checkXY(cnvobj, x, y)
    local index = 0
    if #cnvobj.drawnEle > 0 then
        for i=#cnvobj.drawnEle, 1, -1 do

            -- for line
            if cnvobj.drawnEle[i].shape == "LINE" then

                x1 = cnvobj.drawnEle[i].start_x
                y1 = cnvobj.drawnEle[i].start_y
                x2 = cnvobj.drawnEle[i].end_x
                y2 = cnvobj.drawnEle[i].end_y

                index = RectAroundLine(x1, y1, x2, y2, x, y, cnvobj.grid_x)
                
                if index == 1 then
                    return i
                end
               
            end

            -- for rect and filled rect
            if cnvobj.drawnEle[i].shape == "RECT" or cnvobj.drawnEle[i].shape == "FILLEDRECT" then
                
                local x1, y1 = cnvobj.drawnEle[i].start_x, cnvobj.drawnEle[i].start_y
                local x3, y3 = cnvobj.drawnEle[i].end_x , cnvobj.drawnEle[i].end_y
                local x2, y2, x4, y4 = findRemainingCoor(x1, y1, x3, y3)

                if cnvobj.drawnEle[i].shape == "RECT" then
                    local i1 = RectAroundLine(x1,y1,x2,y2,x,y,cnvobj.grid_x)
                    local i2 = RectAroundLine(x2,y2,x3,y3,x,y,cnvobj.grid_x)
                    local i3 = RectAroundLine(x3,y3,x4,y4,x,y,cnvobj.grid_x)
                    local i4 = RectAroundLine(x4,y4,x1,y1,x,y,cnvobj.grid_x)

                    if i1==1 or i2 == 1 or i3 == 1 or i4 == 1 then
                        return i
                    end
                end

                if cnvobj.drawnEle[i].shape == "FILLEDRECT" then
                    --print(i)
                    local xyLiesInsideRect = check(x1, y1, x2, y2, x3, y3, x4, y4, x, y)
                    --print(xyLiesInsideRect)
                    if xyLiesInsideRect==true then
                        return i
                    end
                    
                end

            end
            -- Ellipse or FILLED Ellipse
            if cnvobj.drawnEle[i].shape == "ELLIPSE" or cnvobj.drawnEle[i].shape == "FILLEDELLIPSE" then
                -- four coor. of rect
                local x1, y1 = cnvobj.drawnEle[i].start_x, cnvobj.drawnEle[i].start_y
                local x3, y3 = cnvobj.drawnEle[i].end_x , cnvobj.drawnEle[i].end_y
                local x2, y2, x4, y4 = findRemainingCoor(x1, y1, x3, y3)
                midx1 = (x2 + x1)/2
                midy1 = (y2 + y1)/2

                midx2 = (x3 + x2)/2
                midy2 = (y3 + y2)/2

                midx3 = (x4 + x3)/2
                midy3 = (y4 + y3)/2

                midx4 = (x1 + x4)/2
                midy4 = (y1 + y4)/2
                --print("("..x1, y1..") ("..x2, y2..") ("..x3, y3..") ("..x4, y4..")")
                --print(midx1,midy1, midx2, midy2, midx3, midy3, midx4, midy4)
                local a = (math.abs(midx1 - midx3))/2
                local b = (math.abs(midy2 - midy4))/2
                
                local cx, cy = (x1 + x3)/2 , (y1 + y3)/2
                --print(a,b,cx,cy,x,y)
                
                local eq = math.pow(x-cx,2)/math.pow(a,2) + math.pow(y-cy,2)/math.pow(b,2)
                --print(eq)
                if cnvobj.drawnEle[i].shape == "ELLIPSE" and eq > 0.8 and eq < 1.2 then
                    return i
                end

                if cnvobj.drawnEle[i].shape == "FILLEDELLIPSE" and eq < 1.2 then
                    return i
                end
            end

        end
        return index
    end
end