--[[customData = {
	type = "custom",
	reference = "MyAddonCustomControl",	--(optional) unique name for your control to use as reference
	refreshFunc = function(customControl) end,	--(optional) function to call when panel/controls refresh
	width = "full",	--or "half" (optional)
}	]]

local widgetVersion = 6
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("custom", widgetVersion) then return end

local wm = WINDOW_MANAGER
local tinsert = table.insert

local function UpdateValue(control)
	if control.data.refreshFunc then
		control.data.refreshFunc(control)
	end
end

function LAMCreateControl.custom(parent, customData, controlName)
	local control = wm:CreateControl(controlName or customData.reference, parent.scroll or parent, CT_CONTROL)
	control:SetResizeToFitDescendents(true)

	local isHalfWidth = customData.width == "half"
	local width = parent:GetWidth() - 20
	if isHalfWidth then	--note these restrictions
		control:SetDimensionConstraints(width / 2, 55, width / 2, 100)
		control:SetDimensions(width / 2, 55)
	else
		control:SetDimensionConstraints(width, 30, width, 100)
		control:SetDimensions(width, 30)
	end

	control.panel = parent.panel or parent	--if this is in a submenu, panel is its parent
	control.data = customData

	control.UpdateValue = UpdateValue

	if control.panel.data.registerForRefresh or control.panel.data.registerForDefaults then	--if our parent window wants to refresh controls, then add this to the list
		tinsert(control.panel.controlsToRefresh, control)
	end

	return control
end