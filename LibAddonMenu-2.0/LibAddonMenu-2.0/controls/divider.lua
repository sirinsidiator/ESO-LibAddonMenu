--[[dividerData = {
    type = "divider",
    width = "full", --or "half" (optional)
    height = 10, (optional)
    alpha = 0.25, (optional)
    reference = "MyAddonDivider" -- unique global reference to control (optional)
} ]]


local widgetVersion = 1
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("divider", widgetVersion) then return end

local wm = WINDOW_MANAGER

local MIN_HEIGHT = 10
local DEFAULT_ALPHA = 0.25
function LAMCreateControl.divider(parent, dividerData, controlName)
    local control = LAM.util.CreateBaseControl(parent, dividerData, controlName)
    local isHalfWidth = control.isHalfWidth
    local width = control:GetWidth()
    local height = dividerData.height
    if not height or type(height) ~= "numeric" or height < MIN_HEIGHT then
        height = MIN_HEIGHT
    end
    control:SetDimensions(isHalfWidth and width / 2 or width, height)

    
    local alpha = dividerData.alpha
    if not alpha or type(alpha) ~= "numeric" or alpha > 1 or alpha < 0 then
        alpha = DEFAULT_ALPHA
    end
    control.divider = wm:CreateControlFromVirtual(nil, control, "ZO_Options_Divider")
    local divider = control.divider
    divider:SetWidth(isHalfWidth and width / 2 or width)
    divider:SetAnchor(TOPLEFT)
    divider:SetAlpha(alpha)

    return control
end
