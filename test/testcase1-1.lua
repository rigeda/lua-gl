-- Test case 1 with 2 objects with 1 port each connect to each other with 2 connectors between them
o1 = cnvobj:drawObj("RECT",2,{{x=200,y=40},{x=300,y=200}})
o2 = cnvobj:drawObj("RECT",2,{{x=500,y=320},{x=600,y=450}})
-- Now add a port to each object
p1 = cnvobj:addPort(300,130,o1.id)
p2 = cnvobj:addPort(500,380,o2.id)
-- Add the port visual rectangles
cnvobj.grid.snapGrid = false
o3 = cnvobj:drawObj("FILLEDRECT",2,{{x=300-3,y=130-3},{x=300+3,y=130+3}})
o4 = cnvobj:drawObj("FILLEDRECT",2,{{x=500-3,y=380-3},{x=500+3,y=380+3}})
cnvobj.grid.snapGrid = true
-- Group the port visuals with the objects
cnvobj:groupObjects({o1,o3})
cnvobj:groupObjects({o2,o4})
-- Now draw the connectors between them
-- One connector is just 2 segment direct ther other one is 4 segments but give it as 1 and it should split it into 2 across ports
cnvobj:drawConnector({
		{start_x = 300,start_y=130,end_x=300,end_y=380},
		{start_x = 300,start_y=380,end_x=500,end_y=380},
		{start_x = 500,start_y=380,end_x=500,end_y=360},
		{start_x = 500,start_y=360,end_x=320,end_y=360},
		{start_x = 320,start_y=360,end_x=320,end_y=130},
		{start_x = 320,start_y=130,end_x=300,end_y=130}
	})
cnvobj:refresh()
