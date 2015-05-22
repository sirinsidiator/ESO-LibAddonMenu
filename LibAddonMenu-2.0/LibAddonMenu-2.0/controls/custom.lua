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

local MIN_HEIGHT = 26
function LAMCreateControl.custom(parent, customData, controlName)
	local control = LAM.util.CreateBaseControl(parent, customData, controlName)
	local width = control:GetWidth()
	control:SetResizeToFitDescendents(true)

	if control.isHalfWidth then	--note these restrictions
		control:SetDimensionConstraints(width / 2, MIN_HEIGHT, width / 2, MIN_HEIGHT * 4)
	else
		control:SetDimensionConstraints(width, MIN_HEIGHT, width, MIN_HEIGHT * 4)
	end

	control.UpdateValue = UpdateValue

	if control.panel.data.registerForRefresh or control.panel.data.registerForDefaults then	--if our parent window wants to refresh controls, then add this to the list
		tinsert(control.panel.controlsToRefresh, control)
	end

	return control
end