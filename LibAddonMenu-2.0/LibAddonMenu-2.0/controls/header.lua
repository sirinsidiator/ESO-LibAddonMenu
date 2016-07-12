--[[headerData = {
    type = "header",
    name = "My Header", -- or string id or function returning a string
    width = "full", --or "half" (optional)
    reference = "MyAddonHeader" -- unique global reference to control (optional)
} ]]


local widgetVersion = 8
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("header", widgetVersion) then return end

local wm = WINDOW_MANAGER

local function UpdateValue(control)
    control.header:SetText(LAM.util.GetStringFromValue(control.data.name))
end

local MIN_HEIGHT = 30
function LAMCreateControl.header(parent, headerData, controlName)
    local control = LAM.util.CreateBaseControl(parent, headerData, controlName)
    local isHalfWidth = control.isHalfWidth
    local width = control:GetWidth()
    control:SetDimensions(isHalfWidth and width / 2 or width, MIN_HEIGHT)

    control.divider = wm:CreateControlFromVirtual(nil, control, "ZO_Options_Divider")
    local divider = control.divider
    divider:SetWidth(isHalfWidth and width / 2 or width)
    divider:SetAnchor(TOPLEFT)

    control.header = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel")
    local header = control.header
    header:SetAnchor(TOPLEFT, divider, BOTTOMLEFT)
    header:SetAnchor(BOTTOMRIGHT)
    header:SetText(LAM.util.GetStringFromValue(headerData.name))

    control.UpdateValue = UpdateValue

    LAM.util.RegisterForRefreshIfNeeded(control)

    return control
end
