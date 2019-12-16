-- All the Main tables of the Program


-- The GUI structure
GUI = {
	_VERSION = nil,
	images = nil,	-- To Load the images
	toolbar = {
		buttons = {
		},		-- buttons ends
		left = nil,	-- left toolbar ends
		center = nil,
		right = nil,
		hbox = nil
	},		-- toolbar ends
	mainDlg = nil,
	mainArea = nil,		-- Main area where the widgets are
	statBarBox = nil,
	statBarL = nil,	-- Status Bar label left
	statBarM = nil,	-- Status Bar label middle to display the channel parameters
	statBarR = iup.label{expand = "HORIZONTAL"},	-- Status Bar label Right to display the scripts directory	
}

-- Fill GUI up with elements
GUI._VERSION = "1.19.12.15"
GUI.images = require("images")
GUI.statBarL = iup.label{title = "Ready",expand = "HORIZONTAL"}	-- Status Bar label left
GUI.statBarM = iup.label{expand = "HORIZONTAL"}	-- Status Bar label middle to display the channel parameters
GUI.statBarR = iup.label{expand = "HORIZONTAL"}	-- Status Bar label Right to display the scripts directory

GUI.toolbar.buttons = {
	lineButton = iup.button{image=GUI.images.line,tip="Draw a Line object"},	-- Button to draw line
	rectButton = iup.button{image=GUI.images.rectangle,tip="Draw a Rectangle object"},	-- Button to draw rectangle
	fRectButton = iup.button{image=GUI.images.filledrectangle,tip="Draw a Filled Rectangle object"},	-- Button to draw filled rectangle
	bRectButton = iup.button{image=GUI.images.blockingrectangle,tip="Draw a blocking rectangle"},	-- Button to draw blocking rectangle
	elliButton = iup.button{image=GUI.images.ellipse,tip="Draw an Ellipse object"},	-- Button to draw ellipse
	fElliButton = iup.button{image=GUI.images.filledellipse,tip="Draw a Filled Ellipse object"},	-- Button to draw filled ellipse
	saveButton = iup.button{image="IUP_FileSave",tip="Save image to file"},	-- Button to save drawing
	loadButton = iup.button{image="IUP_FileOpen",tip="Load image from file"},	-- Button to load drawing
	snapGridButton = iup.button{image=GUI.images.ongrid,tip="Set snapping off"},
	showGridButton = iup.toggle{image=GUI.images.grid,tip="Turn off grid",value="ON"},
}		-- buttons ends

GUI.toolbar.left = iup.hbox{
	GUI.toolbar.buttons.saveButton,
	GUI.toolbar.buttons.loadButton,
	GUI.toolbar.buttons.snapGridButton,
	GUI.toolbar.buttons.showGridButton,
	iup.fill{};
	margin = "2x2",
	gap=2,
	alignment = "ACENTER"
}
GUI.toolbar.center = iup.hbox{
	GUI.toolbar.buttons.lineButton,
	GUI.toolbar.buttons.rectButton,
	GUI.toolbar.buttons.fRectButton,
	GUI.toolbar.buttons.bRectButton,
	GUI.toolbar.buttons.elliButton,
	GUI.toolbar.buttons.fElliButton,
	iup.fill{};
	margin="2x2",
	gap="2",
	alignment="ACENTER"
}
GUI.toolbar.right = iup.hbox{iup.fill{};margin="2x2",gap="2"}
GUI.toolbar.hbox = iup.hbox{
	GUI.toolbar.left,
	GUI.toolbar.center,
	GUI.toolbar.right
}		-- toolbar hbox ends

GUI.mainArea = iup.vbox{

}

-- Status Bar Boxes (Left, Right and Middle)
GUI.statBarBox = iup.hbox{
	iup.hbox{GUI.statBarL,iup.fill{}},
	iup.hbox{iup.fill{},GUI.statBarM,iup.fill{}}, 
	iup.hbox{iup.fill{},GUI.statBarR};
	border="YES",
	padding = "2x2",
	gap="2"
}		--statBarBox ends

GUI.mainVbox = iup.vbox{
	GUI.toolbar.hbox,
	GUI.mainArea,
	iup.frame
	{
		GUI.statBarBox;
		border="YES", 
		sunken="YES"
	}
}

GUI.mainDlg = iup.dialog{
	GUI.mainVbox;
	title = "Lua-gl library demo application "..GUI._VERSION,
	size="HALFxHALF",
	shrink="YES",
	icon = GUI.images.appIcon
}

