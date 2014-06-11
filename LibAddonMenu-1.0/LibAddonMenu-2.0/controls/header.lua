--[[headerData = {
	type = "header",
	name = "My Header",
	width = "full",	--or "half" (optional)
	reference = "MyAddonHeader"	--(optional) unique global reference to control
}	]]


local widgetVersion = 2
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("header", widgetVersion) then return end

local wm = WINDOW_MANAGER

function LAMCreateControl.header(parent, headerData, controlName)
	local control = wm:CreateTopLevelWindow(controlName or headerData.reference)
	control:SetParent(parent.scroll)
	local isHalfWidth = headerData.width == "half"
	control:SetDimensions(isHalfWidth and 250 or 510, 30)
	
	control.divider = wm:CreateControlFromVirtual(nil, control, "ZO_Options_Divider")
	local divider = control.divider
	divider:SetWidth(isHalfWidth and 250 or 510)
	divider:SetAnchor(TOPLEFT)

	control.header = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel")
	local header = control.header
	header:SetAnchor(TOPLEFT, divider, BOTTOMLEFT)
	header:SetAnchor(BOTTOMRIGHT)
	header:SetText(headerData.name)
	
	control.panel = parent.panel or parent	--if this is in a submenu, panel is its parent
	control.data = headerData
	
	return control
end