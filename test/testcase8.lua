f = io.open("../test/demo.dia","r")
s = f:read("*a")
f:close()
t = tu.s2tr(s)
cnvobj.drawn = t
-- Update routing matrix
rm = cnvobj.rM
for i = 1,#cnvobj.drawn.conn do
	for j = 1,#cnvobj.drawn.conn[i].segments do
		local seg = cnvobj.drawn.conn[i].segments[j]
		rm:addSegment(seg,seg.start_x,seg.start_y,seg.end_x,seg.end_y)
	end
end
for i = 1,#cnvobj.drawn.port do
	local port = cnvobj.drawn.port[i]
	rm:addPort(port,port.x,port.y)
end
cnvobj:refresh()