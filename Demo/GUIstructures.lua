-- All the Main tables of the Program


-- The GUI structure
GUI = {
	_VERSION = nil,
	images = nil,	-- To Load the images
	toolbar = {
		buttons = {
		},		-- buttons ends
		top = nil,	-- left toolbar ends
		right = nil,
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
	saveButton = iup.button{image="IUP_FileSave",tip="Save to file"},	-- Button to save drawing
	loadButton = iup.button{image="IUP_FileOpen",tip="Load from file"},	-- Button to load drawing
	snapGridButton = iup.button{image=GUI.images.ongrid,tip="Set snapping off"},
	showGridButton = iup.toggle{image=GUI.images.grid,tip="Turn off grid",value="ON"},
	xygrid = iup.button{image=GUI.images.xygrid,tip="Change Grid size"},
	showBlockingRect = iup.toggle{image=GUI.images.blockingRectVisible,tip = "Show blocking rectangles",value="ON"},
	dragButton = iup.button{image=GUI.images.drag,tip="Drag Element"},
	moveButton = iup.button{image=GUI.images.move,tip="Move Element"},
	groupButton = iup.button{image=GUI.images.group,tip="Group Objects"},
	portButton = iup.button{image=GUI.images.port,tip="Add Port"},
	refreshButton = iup.button{image="IUP_NavigateRefresh",tip="Refresh Screen"},
	connButton = iup.button{image=GUI.images.connector,tip="Draw connector"},
	connModeList = iup.list{
		["1"] = "Manual",
		["2"] = "Manual Orthogonal",
		["3"] = "Guided Orthogonal",
		["4"] = "Auto Router";
		DROPDOWN = "YES",
		VALUE = 1
	},
	newButton = iup.button{image="IUP_FileNew",tip="New Drawing"},
	checkButton = iup.button{image="IUP_ActionOk",tip="Run Custom function"},
	textButton = iup.button{image = GUI.images.T,tip="Add Text"}
}		-- buttons ends

GUI.toolbar.top = iup.hbox{
	GUI.toolbar.buttons.newButton,
	GUI.toolbar.buttons.saveButton,
	GUI.toolbar.buttons.loadButton,
	GUI.toolbar.buttons.snapGridButton,
	GUI.toolbar.buttons.showGridButton,
	GUI.toolbar.buttons.xygrid,
	GUI.toolbar.buttons.showBlockingRect,
	GUI.toolbar.buttons.refreshButton,
	GUI.toolbar.buttons.checkButton,
	GUI.toolbar.buttons.connModeList,
	iup.fill{};
	margin = "2x2",
	gap=2,
	alignment = "ACENTER"
}
GUI.toolbar.right = iup.vbox{
	GUI.toolbar.buttons.lineButton,
	GUI.toolbar.buttons.rectButton,
	GUI.toolbar.buttons.fRectButton,
	GUI.toolbar.buttons.bRectButton,
	GUI.toolbar.buttons.elliButton,
	GUI.toolbar.buttons.fElliButton,
	GUI.toolbar.buttons.textButton,
	GUI.toolbar.buttons.portButton,
	GUI.toolbar.buttons.connButton,
	iup.space{size="2x1"},
	iup.label{separator="HORIZONTAL"},
	iup.space{size="2x1"},
	GUI.toolbar.buttons.dragButton,
	GUI.toolbar.buttons.moveButton,
	GUI.toolbar.buttons.groupButton,
	iup.fill{};
	margin="2x2",
	gap="2",
	alignment="ACENTER"
}

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
	GUI.toolbar.top,
	iup.hbox{
		GUI.mainArea,
		GUI.toolbar.right
	},
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

