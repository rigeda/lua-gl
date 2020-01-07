-- File to test and benchmark the router module
require("submodsearcher")
router = require("lua-gl.router")
crouter = require("luaglib.crouter")
tu = require("tableUtils")

cnvobj = {
	grid = {
		snapGrid = true,
		grid_x = 2,
		grid_y = 2
	}
}

--[[
-- Create 101 routing matrices
rm = {}
for i = 0,100 do 
	rm[i] = router.newRoutingMatrix(cnvobj)
end

cnvobj.rM = rm[0]
]]

cnvobj.rM = router.newRoutingMatrix(cnvobj)
cnvobj.rM = crouter.newRoutingMatrix()
print("created routing matrix")
-- Do a full garbage collection cycle
collectgarbage()
print("finished garbage collection")

segments = {}
t1 = os.clock()
print(router.generateSegments(cnvobj,10,10,1000,1000,segments))
t2 = os.clock()
print(tu.t2spp(segments))
print("Time taken:",t2-t1)

