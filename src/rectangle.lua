-- Module to add rectangle functionality in lua-gl

local coorc = require("lua-gl.CoordiateCalc")

local M = {}
package.loaded[...] = M
_ENV = M


-- Function to check whether rectangle object is selectable by x,y within the given resolution res
function checkXY(obj, x, y, res)
	if obj.shape ~= "RECT" and obj.shape ~= "BLOCKINGRECT" and obj.shape ~= "FILLEDRECT" then
		return nil
	end
	
	
	local x1, y1 = obj.start_x, obj.start_y
	local x3, y3 = obj.end_x , obj.end_y
	local x2, y2, x4, y4 = x1, y3, x3, y1

	if obj.shape == "RECT" then
		local i1 = coorc.PointInRect(x1,y1,x2,y2,x,y,res)
		local i2 = coorc.PointInRect(x2,y2,x3,y3,x,y,res)
		local i3 = coorc.PointInRect(x3,y3,x4,y4,x,y,res)
		local i4 = coorc.PointInRect(x4,y4,x1,y1,x,y,res)

		if i1 or i2 or i3 or i4 then
			return true
		end
	else
		return coorc.PointInRect(x1, y1, x2, y2, x3, y3, x4, y4, x, y)
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
end