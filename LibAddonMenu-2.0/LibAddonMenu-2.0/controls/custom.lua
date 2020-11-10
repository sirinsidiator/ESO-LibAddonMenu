--[[customData = {
    type = "custom",
    reference = "MyAddonCustomControl", -- unique name for your control to use as reference (optional)
    createFunc = function(customControl) end, -- function to call when this custom control was created (optional)
    refreshFunc = function(customControl) end, -- function to call when panel/controls refresh (optional)
    width = "full", -- or "half" (optional)
    minHeight = function() return db.minHeightNumber end, --or number for the minimum height of this control. Default: 26 (optional)
    maxHeight = function() return db.maxHeightNumber end, --or number for the maximum height of this control. Default: 4 * minHeight (optional)
} ]]

local widgetVersion = 8
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("custom", widgetVersion) then return end

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

    local minHeight = (control.data.minHeight and LAM.util.GetDefaultValue(control.data.minHeight)) or MIN_HEIGHT
    local maxHeight = (control.data.maxHeight and LAM.util.GetDefaultValue(control.data.maxHeight)) or (minHeight * 4)

    if control.isHalfWidth then --note these restrictions
        control:SetDimensionConstraints(width / 2, minHeight, width / 2, maxHeight)
    else
        control:SetDimensionConstraints(width, minHeight, width, maxHeight)
    end

    control.UpdateValue = UpdateValue

    LAM.util.RegisterForRefreshIfNeeded(control)

    if customData.createFunc then customData.createFunc(control) end
    return control
end
