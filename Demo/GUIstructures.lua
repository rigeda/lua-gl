-- All the Main tables of the Program


-- The GUI structure
GUI = {
	_VERSION = nil,
	images = nil,	-- To Load the images
	toolbar = {
		buttons = {
			lineButton = iup.button{image="IUP_ActionOk"},	-- Button to draw line
			rectButton = iup.button{image="IUP_ActionOk"},	-- Button to draw rectangle
			fRectButton = iup.button{image="IUP_ActionOk"},	-- Button to draw filled rectangle
			bRectButton = iup.button{image="IUP_ActionOk"},	-- Button to draw blocking rectangle
			elliButton = iup.button{image="IUP_ActionOk"},	-- Button to draw ellipse
			fElliButton = iup.button{image="IUP_ActionOk"},	-- Button to draw filled ellipse
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

GUI.mainArea = iup.vbox{

}

-- Status Bar Boxes (Left, Right and Middle)
GUI.statBarBox = iup.hbox
{
	iup.hbox{GUI.statBarL,iup.fill{}},
	iup.hbox{iup.fill{},GUI.statBarM,iup.fill{}}, 
	iup.hbox{iup.fill{},GUI.statBarR};
	border="YES",
	padding = "2x2",
	gap="2"
}		--statBarBox ends

GUI.mainVbox = iup.vbox
{
	GUI.toolbar.hbox,
	GUI.mainArea,
	iup.frame
	{
		GUI.statBarBox;
		border="YES", 
		sunken="YES"
	}
}

GUI.mainDlg = iup.dialog
{
	GUI.mainVbox;
	title = "Lua-gl library demo application"..GUI._VERSION,
	size="HALFxHALF",
	shrink="YES",
	icon = GUI.images.appIcon
}

