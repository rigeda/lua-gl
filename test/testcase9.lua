-- Test case 9 with 1 object with 1 port to test rotate and flip
o1 = cnvobj:drawObj("RECT",2,{{x=200,y=40},{x=300,y=200}})
-- Now add a port 
p1 = cnvobj:addPort(300,130,o1.id)
-- Add the port visual rectangles
cnvobj.grid.snapGrid = false
o2 = cnvobj:drawObj("FILLEDRECT",2,{{x=300-3,y=130-3},{x=300+3,y=130+3}})
cnvobj.grid.snapGrid = true
-- Group the port visuals with the objects
cnvobj:groupObjects({o1,o2})
cnvobj:refresh()
