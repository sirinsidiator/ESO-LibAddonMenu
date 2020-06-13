--[[customData = {
    type = "custom",
    reference = "MyAddonCustomControl", -- unique name for your control to use as reference (optional)
    refreshFunc = function(customControl) end, -- function to call when panel/controls refresh (optional)
    width = "full", -- or "half" (optional)
} ]]

local widgetVersion = 7
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

    if control.isHalfWidth then --note these restrictions
        control:SetDimensionConstraints(width / 2, MIN_HEIGHT, width / 2, MIN_HEIGHT * 4)
    else
        control:SetDimensionConstraints(width, MIN_HEIGHT, width, MIN_HEIGHT * 4)
    end

    control.UpdateValue = UpdateValue

    LAM.util.RegisterForRefreshIfNeeded(control)

    return control
end
