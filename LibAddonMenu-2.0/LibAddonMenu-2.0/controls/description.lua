--[[descriptionData = {
	type = "description",
	title = "My Title",	--(optional)
	text = "My description text to display.",
	width = "full",	--or "half" (optional)
	reference = "MyAddonDescription"	--(optional) unique global reference to control
}	]]


local widgetVersion = 6
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("description", widgetVersion) then return end

local wm = WINDOW_MANAGER
local tinsert = table.insert

local function UpdateValue(control)
	if control.title then
		control.title:SetText(control.data.title)
	end
	control.desc:SetText(control.data.text)
end

function LAMCreateControl.description(parent, descriptionData, controlName)
	local control = wm:CreateControl(controlName or descriptionData.reference, parent.scroll or parent, CT_CONTROL)
	control:SetResizeToFitDescendents(true)
	local isHalfWidth = descriptionData.width == "half"
	local width = parent:GetWidth() - 20
	if isHalfWidth then
		control:SetDimensionConstraints(width / 2, 55, width / 2, 100)
		control:SetDimensions(width / 2, 55)
	else
		control:SetDimensionConstraints(width, 40, width, 100)
		control:SetDimensions(width, 30)
	end

	control.desc = wm:CreateControl(nil, control, CT_LABEL)
	local desc = control.desc
	desc:SetVerticalAlignment(TEXT_ALIGN_TOP)
	desc:SetFont("ZoFontGame")
	desc:SetText(descriptionData.text)
	desc:SetWidth(isHalfWidth and width / 2 or width)

	if descriptionData.title then
		control.title = wm:CreateControl(nil, control, CT_LABEL)
		local title = control.title
		title:SetWidth(isHalfWidth and width / 2 or width)
		title:SetAnchor(TOPLEFT, control, TOPLEFT)
		title:SetFont("ZoFontWinH4")
		title:SetText(descriptionData.title)
		desc:SetAnchor(TOPLEFT, title, BOTTOMLEFT)
	else
		desc:SetAnchor(TOPLEFT)
	end

	control.panel = parent.panel or parent	--if this is in a submenu, panel is its parent
	control.data = descriptionData

	control.UpdateValue = UpdateValue

	if control.panel.data.registerForRefresh or control.panel.data.registerForDefaults then	--if our parent window wants to refresh controls, then add this to the list
		tinsert(control.panel.controlsToRefresh, control)
	end

	return control

end