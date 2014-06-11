--[[customData = {
	type = "custom",
	reference = "MyAddonCustomControl",	--unique name for your control to use as reference
	width = "full",	--or "half" (optional)
}	]]

local widgetVersion = 2
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("custom", widgetVersion) then return end

local wm = WINDOW_MANAGER

function LAMCreateControl.custom(parent, customData, controlName)
	local control = wm:CreateTopLevelWindow(controlName or customData.reference)
	control:SetResizeToFitDescendents(true)
	control:SetParent(parent.scroll)
	
	local isHalfWidth = customData.width == "half"
	if isHalfWidth then	--note these restrictions
		control:SetDimensionConstraints(250, 55, 250, 100)
		control:SetDimensions(250, 55)
	else
		control:SetDimensionConstraints(510, 30, 510, 100)
		control:SetDimensions(510, 30)
	end
	
	control.panel = parent.panel or parent	--if this is in a submenu, panel is its parent
	control.data = customData
	
	return control
end