---@class LAM2_CustomData: LAM2_BaseControlData
---@field type "custom"
---@field createFunc nil|fun(customControl: LAM2_Custom) called when this custom control is created
---@field refreshFunc nil|fun(customControl: LAM2_Custom) called when the created custom control is refreshed
---@field minHeight nil|number|fun(): number default 26. the minimum height of the control.
---@field maxHeight nil|number|fun(): number default 4*minHeight. the maximum height of the control.
---@field resetFunc nil|fun(customControl: LAM2_Custom) custom function to run after the control is reset to defaults ex. function(customControl) d("defaults reset") end


local widgetVersion = 9
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("custom", widgetVersion) then return end

local function UpdateValue(control)
    if control.data.refreshFunc then
        control.data.refreshFunc(control)
    end
end

local MIN_HEIGHT = 26

---@param customData LAM2_CustomData
function LAMCreateControl.custom(parent, customData, controlName)
    ---@class LAM2_Custom: LAM2_BaseControl
    ---@field data LAM2_CustomData
    local control = LAM.util.CreateBaseControl(parent, customData, controlName)
    local width = control:GetWidth()
    control:SetResizeToFitDescendents(true)

    local minHeight = (control.data.minHeight and LAM.util.GetDefaultValue(control.data.minHeight)) or MIN_HEIGHT
    local maxHeight = (control.data.maxHeight and LAM.util.GetDefaultValue(control.data.maxHeight)) or (minHeight * 4)

    if control.isHalfWidth then --note these restrictions
        control:SetDimensionConstraints(width / 2, minHeight, width / 2, maxHeight)
        control:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_Y)
    else
        control:SetDimensionConstraints(width, minHeight, width, maxHeight)
        control:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_Y)
    end

    control.UpdateValue = UpdateValue

    LAM.util.RegisterForRefreshIfNeeded(control)

    if customData.createFunc then customData.createFunc(control) end
    return control
end
