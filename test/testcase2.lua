-- Test case 1 with 2 objects with 1 port each connect to each other with 2 connectors between them
o1 = cnvobj:drawObj("RECT",2,{{x=200,y=40},{x=300,y=200}})
o2 = cnvobj:drawObj("RECT",2,{{x=600,y=40},{x=700,y=200}})
-- Now add a port to each object
p1 = cnvobj:addPort(300,130,o1.id)
p2 = cnvobj:addPort(600,130,o2.id)
-- Add the port visual rectangles
cnvobj.grid.snapGrid = false
o3 = cnvobj:drawObj("FILLEDRECT",2,{{x=300-3,y=130-3},{x=300+3,y=130+3}})
o4 = cnvobj:drawObj("FILLEDRECT",2,{{x=600-3,y=130-3},{x=600+3,y=130+3}})
cnvobj.grid.snapGrid = true
-- Group the port visuals with the objects
cnvobj:groupObjects({o1,o3})
cnvobj:groupObjects({o2,o4})
-- Now draw 1 connector up to mid point
-- One connector is just 2 segment direct ther other one is 4 segments but give it as 1 and it should split it into 2 across ports
cnvobj:drawConnector({
		{start_x = 300,start_y=130,end_x=450,end_y=130},
	})
cnvobj:refresh()
