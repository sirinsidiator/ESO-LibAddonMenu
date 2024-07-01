---@class LAM2_DividerData: LAM2_BaseControlData
---@field type "divider"
---@field height nil|integer ex. 10
---@field alpha nil|number 0-1. ex. 0.25


local widgetVersion = 2
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("divider", widgetVersion) then return end

local wm = WINDOW_MANAGER

local MIN_HEIGHT = 10
local MAX_HEIGHT = 50
local MIN_ALPHA = 0
local MAX_ALPHA = 1
local DEFAULT_ALPHA = 0.25

local function GetValueInRange(value, min, max, default)
    if not value or type(value) ~= "number" then
        return default
    end
    return math.min(math.max(min, value), max)
end

---@param dividerData LAM2_DividerData
function LAMCreateControl.divider(parent, dividerData, controlName)
    ---@class LAM2_Divider: LAM2_BaseControl
    local control = LAM.util.CreateBaseControl(parent, dividerData, controlName)
    local isHalfWidth = control.isHalfWidth
    local width = control:GetWidth()
    local height = GetValueInRange(dividerData.height, MIN_HEIGHT, MAX_HEIGHT, MIN_HEIGHT)
    local alpha = GetValueInRange(dividerData.alpha, MIN_ALPHA, MAX_ALPHA, DEFAULT_ALPHA)

    control:SetDimensions(isHalfWidth and width / 2 or width, height)

    control.divider = wm:CreateControlFromVirtual(nil, control, "ZO_Options_Divider")
    local divider = control.divider
    divider:SetWidth(isHalfWidth and width / 2 or width)
    divider:SetAnchor(TOPLEFT)
    divider:SetAlpha(alpha)

    return control
end
