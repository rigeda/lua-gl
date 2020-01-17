-- Utility functions

local type = type
local table = table
local pairs = pairs
local tostring = tostring

local GUIFW = require("lua-gl.guifw")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- function to validate the visual attributes function
--[[
For non filled objects attributes to set are: (given a table (attr) with all these keys and attributes
* Draw color(color)	- Table with RGB e.g. {127,230,111}
* Line Style(style)	- number or a table. Number should be one of M.CONTINUOUS, M.DASHED, M.DOTTED, M.DASH_DOT, M.DASH_DOT_DOT. FOr table it should be array of integers specifying line length in pixels and then space length in pixels. Pattern repeats
* Line width(width) - number for width in pixels
* Line Join style(join) - should be one of the constants M.MITER, M.BEVEL, M.ROUND
* Line Cap style (cap) - should be one of the constants M.CAPFLAT, M.CAPROUND, M.CAPSQUARE
]]
--[[
For Filled objects the attributes to be set are:
* Fill Color(color)	- Table with RGB e.g. {127,230,111}
* Background Opacity (bopa) - One of the constants M.OPAQUE, M.TRANSPARENT	
* Fill interior style (style) - One of the constants M.SOLID, M.HOLLOW, M.STIPPLE, M.HATCH, M.PATTERN
* Hatch style (hatch) (OPTIONAL) - Needed if style == M.HATCH. Must be one of the constants M.HORIZONTAL, M.VERTICAL, M.FDIAGONAL, M.BDIAGONAL, M.CROSS or M.DIAGCROSS
* Stipple style (stipple) (OPTIONAL) - Needed if style = M.STIPPLE. Should be a  wxh matrix of zeros (0) and ones (1). The zeros are mapped to the background color or are transparent, according to the background opacity attribute. The ones are mapped to the foreground color.
* Pattern style (pattern) (OPTIONAL) - Needed if style = M.PATTERN. Should be a wxh color matrix of tables with RGB numbers`
]]
function validateVisualAttr(attr)
	if not attr or type(attr) ~= "table" then
		return nil, "Need the attribute table as the second argument"
	end
	-- color is in both cases
	if not attr.color or type(attr.color) ~= "table" or #attr.color ~= 3 then
		return nil,"Color attribute not given as a {R,G,B} table"
	end
	for i = 1,3 do
		if type(attr.color[i]) ~= "number" or math.floor(attr.color[i]) ~= attr.color[i] then
			return nil,"Color attribute table has non integer values"
		end
		if attr.color[i]<0 or attr.color[i]>255 then
			return nil,"Color attribute table is not in the range [0,255]"
		end
	end
	local filled
	if attr.bopa then
		filled = true
	end
	if filled then
		-- check attr as a filled attributes table
		if attr.bopa ~= GUIFW.OPAQUE and attr.bopa ~= GUIFW.TRANSPARENT then
			return nil, "Filled attributes given but value of 'bopa' invalid"
		end
		if not attr.style or (attr.style ~= GUIFW.SOLID and attr.style ~= GUIFW.HOLLOW and attr.style ~= GUIFW.STIPPLE and attr.style ~= GUIFW.HATCH and attr.style ~= GUIFW.PATTERN) then
			return nil, "Filled attributes given but style not given or invalid"
		end
		if attr.style == GUIFW.HATCH then
			if not attr.hatch or (attr.hatch ~= GUIFW.HORIZONTAL and attr.hatch ~= GUIFW.VERTICAL and attr.hatch ~= GUIFW.FDIAGNOL and attr.hatch ~= GUIFW.BDIAGBNOL and attr.hatch ~= GUIFW.CROSS and attr.hatch ~= GUIFW.DIAGCROSS) then
				return nil, "Filled attributes given but hatch not given or invalid with style set to hatch"
			end			
		elseif attr.style == GUIFW.STIPPLE then
			if not attr.stipple or type(attr.stipple) ~= "table" or type(attr.stipple[1]) ~= "table" then 
				return nil,"Filled attributes given with style = stipple, but stipple is not a wxh matrix"
			end
			for i = 1,#attr.stipple do
				if type(attr.stipple[i]) ~= "table" or #attr.stipple[i] ~= attr.stipple[1] then
					return nil,"Filled attributes given with style = stipple, but stipple is not a wxh matrix"
				end
				for j = 1,#attr.stipple[i] do
					if type(attr.stipple[i][j]) ~= "number" or (attr.stipple[i][j] ~= 0 and attr.stipple[i][j] ~= 1) then
						return nil,"Filled attributes given with style = stipple but stipple matrix does not contain 1 or 0"
					end
				end
			end			
		elseif attr.style == GUIFW.PATTERN then
			if not attr.pattern or type(attr.pattern) ~= "table" or type(attr.pattern[1]) ~= "table" then 
				return nil,"Filled attributes given with style = pattern, but pattern is not a wxh matrix"
			end
			for i = 1,#attr.pattern do
				if type(attr.pattern[i]) ~= "table" or #attr.pattern[i] ~= attr.pattern[1] then
					return nil,"Filled attributes given with style = pattern, but pattern is not a wxh matrix"
				end
				for j = 1,#attr.pattern[i] do
					local col = attr.pattern[i][j]
					if type(col) ~= "table" or #col ~= 3 then
						return nil,"Filled attributes given with style = pattern but pattern matrix does not contain {R,G,B} table"
					end
					
					for k = 1,3 do
						if type(col[k]) ~= "number" or floor(col[k]) ~= col[k] then
							return nil,"Filled attributes given with style = pattern, but color table has non integer values"
						end
						if col[k]<0 or col[k]>255 then
							return nil,"Filled attributes given with style = pattern, but color table values are not in the range [0,255]"
						end
					end
				end
			end			
		end
	else
		if not attr.cap or (attr.cap ~= GUIFW.CAPFLAT and attr.cap ~= GUIFW.CAPROUND and attr.cap ~= GUIFW.CAPSQUARE) then
			return nil, "Non filled attributes given but cap not given or invalid"
		end
		if not attr.join or (attr.join ~= GUIFW.MITER and attr.join ~= GUIFW.BEVEL and attr.join ~= GUIFW.ROUND) then
			return nil, "Non filled attributes given but join not given or invalid"
		end
		if not attr.width or type(attr.width) ~= "number" or floor(attr.width) ~= attr.width then
			return nil, "Non filled attributes given but width not given or invalid"
		end
		if not attr.style then
			return nil, "Non filled attributes given but join not given or invalid"
		end
		if type(attr.style) == "number" then
			if attr.style ~= GUIFW.CONTINUOUS and attr.style ~= GUIFW.DASHED and attr.style ~= GUIFW.DOTTED and attr.style ~= GUIFW.DASH_DOT and attr.style ~= GUIFW.DASH_DOT_DOT then
				return nil,"Non filled attributes given but attr.style is an invalid number"
			end
		elseif type(attr.style) == "table" then
			-- table should be an array with all integers
			if #attr.style == 0 then
				return nil,"Non filled attributes given but attr.style is a 0 length table"
			end
			for i = 1,#attr.style do
				if type(attr.style[i]) ~= "number" or math.floor(attr.style[i]) ~= attr.style[i] then
					return nil,"Non filled attributes given but attr.style table has non integer values"
				end
			end
		else
			return nil,"Non filled attributes given but attr.style is invalid"
		end
	end		-- if attr.bopa then ends here
	return true, filled
end

-- Function to check the routing matrix against the elements in the drawn table
-- The routing matrix functionality should be used from Lua code and not a C module
-- So this function can be used while debugging to check the structures integrity after some step or operation to make sure the code is handling the routing matrix correctly
function checkRM(cnvobj,dump)
	-- Get the routing matrix
	local rm = cnvobj.rM
	local obj = cnvobj.drawn.obj
	local conn = cnvobj.drawn.conn
	local dumpStr
	local function foundAndMatching(arr,item)
		local found
		local matching = true
		local bs = arr[item]
		if bs then	
			found = true
			if bs.x1 ~= item.start_x or bs.y1 ~= item.start_y or bs.x2 ~= item.end_x or bs.y2 ~= item.end_y then
				matching = false
			end
		end
		return found,matching
	end
	local rbs = 0
	for k,v in pairs(rm.blksegs) do
		rbs = rbs + 1
	end
	local rhs,rvs = 0,0
	for k,v in pairs(rm.hsegs) do
		rhs = rhs + 1
	end
	for k,v in pairs(rm.vsegs) do
		rvs = rvs + 1
	end
	if dump then
		-- Create a dump string
		local dmp = {}
		-- First add the blocking rectangles
		dmp[#dmp + 1] = "BLOCKING RECTANGLES:"
		local count = 0
		for i = 1,#obj do
			if obj[i].shape == "BLOCKINGRECT" then
				local found, matching = foundAndMatching(rm.blksegs,obj[i])
				local bs = rm.blksegs[obj[i]]
				dmp[#dmp + 1] = "ID: "..obj[i].id.."\t"..tostring(obj[i]).."\t {"..obj[i].start_x..","..obj[i].start_y..","..obj[i].end_x..","..obj[i].end_y.."}\t"..(found and (matching and "Matching" or "MISMATCH:{"..bs.x1..","..bs.y1..","..bs.x2..","..bs.y2.."}")  or "MISSING!")
				count = count + 1
			end
		end
		dmp[#dmp + 1] = "Total Blocking Rectangles = "..count
		dmp[#dmp + 1] = "Total Blocking Rectangles in routing matrix = "..rbs
		-- Now lets look at the connectors
		dmp[#dmp + 1] = "---------------------------------------------------\nCONNECTORS:"
		local hs,vs = 0,0
		for i = 1,#conn do
			-- Segments of the connector
			for j = 1,#conn[i].segments do
				local seg = conn[i].segments[j]
				if seg.start_x == seg.end_x then
					-- Vertical segment
					vs = vs + 1
					local found, matching = foundAndMatching(rm.vsegs,seg)
					local bs = rm.vsegs[seg]
					dmp[#dmp + 1] = "ID: "..conn[i].id.."S"..j.."\t"..tostring(seg).."\t {"..seg.start_x..","..seg.start_y..","..seg.end_x..","..seg.end_y.."}\t"..(found and (matching and "Matching" or "MISMATCH:{"..bs.x1..","..bs.y1..","..bs.x2..","..bs.y2.."}")  or "MISSING!")
				elseif seg.start_y == seg.end_y then
					-- Horizontal segment
					hs = hs + 1
					local found, matching = foundAndMatching(rm.hsegs,seg)
					local bs = rm.hsegs[seg]
					dmp[#dmp + 1] = "ID: "..conn[i].id.."S"..j.."\t"..tostring(seg).."\t {"..seg.start_x..","..seg.start_y..","..seg.end_x..","..seg.end_y.."}\t"..(found and (matching and "Matching" or "MISMATCH:{"..bs.x1..","..bs.y1..","..bs.x2..","..bs.y2.."}")  or "MISSING!")
				end
			end
		end
		dmp[#dmp + 1] = "Total horizontal segments = "..hs
		dmp[#dmp + 1] = "Total horizontal segments in routing matrix = "..rhs
		dmp[#dmp + 1] = "Total vertical segments = "..vs
		dmp[#dmp + 1] = "Total vertical segments in routing matrix = "..rvs
		-- Now lets see and list the extra stuff in routing matrix
		dmp[#dmp + 1] = "---------------------------------------------------\nEXTRA IN ROUTING MATRIX:"
		dmp[#dmp + 1] = "BLOCKING RECTANGLES:"
		for k,v in pairs(rm.blksegs) do
			local found
			for i = 1,#obj do
				if obj[i] == k then
					found = true
					break
				end
			end
			if not found then
				dmp[#dmp + 1] = "ID: "..k.id.."\t"..tostring(k).."\t {"..k.start_x..","..k.start_y..","..k.end_x..","..k.end_y.."}\tRouting Matrix Entry:{"..v.x1..","..v.y1..","..v.x2..","..v.y2.."}"
			end
		end
		dmp[#dmp + 1] = "HORIZONTAL SEGMENTS:"
		for k,v in pairs(rm.hsegs) do
			local found
			for i = 1,#conn do
				for j = 1,#conn[i].segments do
					if k == conn[i].segments[j] then
						found = true
						break
					end
				end
				if found then
					break
				end
			end
			if not found then
				dmp[#dmp + 1] = "HSEGMENT: "..tostring(k).." {"..k.start_x..","..k.start_y..","..k.end_x..","..k.end_y.."}\tRouting Matrix Entry:{"..v.x1..","..v.y1..","..v.x2..","..v.y2.."}"
			end			
		end
		dmp[#dmp + 1] = "VERTICAL SEGMENTS:"
		for k,v in pairs(rm.vsegs) do
			local found
			for i = 1,#conn do
				for j = 1,#conn[i].segments do
					if k == conn[i].segments[j] then
						found = true
						break
					end
				end
				if found then
					break
				end
			end
			if not found then
				dmp[#dmp + 1] = "VSEGMENT: "..tostring(k).." {"..k.start_x..","..k.start_y..","..k.end_x..","..k.end_y.."}\tRouting Matrix Entry:{"..v.x1..","..v.y1..","..v.x2..","..v.y2.."}"
			end			
		end
		dumpStr = table.concat(dmp,"\n")
	end
	local count,hs,vs = 0,0,0
	for i = 1,#obj do
		if obj[i].shape == "BLOCKINGRECT" then
			local found, matching = foundAndMatching(rm.blksegs,obj[i])
			if not found then
				return nil,dumpStr or obj[i].id.." blocking rectangle not in routing matrix."
			end
			if not matching then
				return nil,dumpStr or obj[i].id.." blocking rectangle does not match."
			end
			count = count + 1
		end
	end
	if count ~= rbs then
		return nil,dumpStr or count.." blocking rectangles found but routing matrix has "..rbs
	end
	for i = 1,#conn do
		-- Segments of the connector
		for j = 1,#conn[i].segments do
			local seg = conn[i].segments[j]
			local found,matching
			if seg.start_x == seg.end_x then
				-- Vertical segment
				vs = vs + 1
				found, matching = foundAndMatching(rm.vsegs,seg)
			elseif seg.start_y == seg.end_y then
				-- Horizontal segment
				hs = hs + 1
				found, matching = foundAndMatching(rm.hsegs,seg)
			else
				found = true
				matching = true
			end
			if not found then
				return nil,dumpStr or conn[i].id.."S"..j.." not in routing matrix."
			end
			if not matching then
				return nil,dumpStr or conn[i].id.."S"..j.." does not match."
			end
		end
	end
	if hs ~= rhs then
		return nil,dumpStr or hs.." horizontal segments found but routing matrix has "..rhs
	end
	if vs ~= rvs then
		return nil,dumpStr or vs.." vertical segments found but routing matrix has "..rvs
	end
	return true,dumpStr
end