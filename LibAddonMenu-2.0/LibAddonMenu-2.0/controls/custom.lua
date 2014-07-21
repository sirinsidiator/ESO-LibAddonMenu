--[[customData = {
	type = "custom",
	reference = "MyAddonCustomControl",	--(optional) unique name for your control to use as reference
	refreshFunc = function(customControl) end,	--(optional) function to call when panel/controls refresh
	width = "full",	--or "half" (optional)
}	]]

local widgetVersion = 4
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
	local control = wm:CreateTopLevelWindow(controlName or customData.reference)
	control:SetResizeToFitDescendents(true)
	control:SetParent(parent.scroll or parent)
	
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
	
	control.UpdateValue = UpdateValue
	
	if control.panel.data.registerForRefresh or control.panel.data.registerForDefaults then	--if our parent window wants to refresh controls, then add this to the list
		tinsert(control.panel.controlsToRefresh, control)
	end
	
	return control
end