-- Module to handle the ports structure

local M = {}
package.loaded[...] = M
_ENV = M

-- Add a port to a shape
-- A port is defined as a stick point for a connector. Any connector that passes over a point occupied by a port will get connected to it.
-- Subsequent movement of the port or connector will try to maintain the port connections
-- Note ports can only be added to shapes
addPort = function(cnvobj,x,y,objID)
	if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
		return
	end
	if not shapeID or type(shapeID) ~= "number" or not cnvobj.drawn.obj[shapeID] then
		return nil,"Need valid shapeID"
	end
	local obj = cnvobj:getObjFromID(objID)
	if not obj then
		return nil,"Object not found"
	end
	local grdx,grdy = cnvobj.grid_x,cnvobj.grid_y
	if not cnvobj.snapGrid then
		grdx,grdy = 1,1
	end
	x = snap.Sx(x, grdx)
	y = snap.Sy(y, grdy)
	local index = #cnvobj.port + 1
	local portID = cnvobj.drawn.port.ids + 1
	
	cnvobj.drawn.port[index] = {
		id = portID,
		conn = {},
		obj = obj,
		x = x,
		y = y
	}
	
	-- Link the port table to the object
	obj.port[#obj.port + 1] = cnvobj.drawn.port[index]		
	return true
end

removePort = function(cnvobj,portID)
	if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
		return
	end
	
end