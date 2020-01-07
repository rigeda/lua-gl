-- Test case 4 with 1 object with a port and the port surrounded by blocking rectangle on 3 sides and connector on the other. So drawing a connector from the port will always create a jumping connector
o1 = cnvobj:drawObj("RECT",2,{{x=200,y=300},{x=300,y=450}})

-- Now add a port to each object
p1 = cnvobj:addPort(300,380,o1.id)

-- Add the port visual rectangles
cnvobj.grid.snapGrid = false
o2 = cnvobj:drawObj("FILLEDRECT",2,{{x=300-3,y=380-3},{x=300+3,y=380+3}})
cnvobj.grid.snapGrid = true
-- Group the port visuals with the objects
cnvobj:groupObjects({o1,o2})

-- Now draw the connector
cnvobj:drawConnector({
		{start_x = 300,start_y=380,end_x=150,end_y=380},
	})
	
-- Now draw the blocking rectangles
o3 = cnvobj:drawObj("BLOCKINGRECT",2,{{x=250,y=300},{x=340,y=374}})	-- Misaligned to the grid by 4 (Grid is 10x10) in Demo project
o4 = cnvobj:drawObj("BLOCKINGRECT",2,{{x=250,y=386},{x=340,y=460}})	-- Misaligned to the grid by 4 (Grid is 10x10) in Demo project
o5 = cnvobj:drawObj("BLOCKINGRECT",2,{{x=310,y=320},{x=360,y=440}})

cnvobj:refresh()
