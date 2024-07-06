---@class LAM2_HeaderData: LAM2_LabelAndContainerControlData
---@field type "header"
---@field resetFunc nil|fun(headerControl: LAM2_Header) custom function to run after the control is reset to defaults ex. function(headerControl) d("defaults reset") end


local widgetVersion = 11
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("header", widgetVersion) then return end

local wm = WINDOW_MANAGER

local function UpdateValue(control)
    control.header:SetText(LAM.util.GetStringFromValue(control.data.name))
end

local MIN_HEIGHT = 30

---@param headerData LAM2_HeaderData
function LAMCreateControl.header(parent, headerData, controlName)
    ---@class LAM2_Header: LAM2_BaseControl
    local control = LAM.util.CreateBaseControl(parent, headerData, controlName)
    local isHalfWidth = control.isHalfWidth
    local width = control:GetWidth()
    control:SetDimensions(isHalfWidth and width / 2 or width, MIN_HEIGHT)

    control.divider = wm:CreateControlFromVirtual(nil, control, "ZO_Options_Divider")
    local divider = control.divider
    divider:SetWidth(isHalfWidth and width / 2 or width)
    divider:SetAnchor(TOPLEFT)

    control.header = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel") --[[@as LabelControl]]
    local header = control.header
    header:SetAnchor(TOPLEFT, divider, BOTTOMLEFT)
    header:SetAnchor(BOTTOMRIGHT)
    header:SetText(LAM.util.GetStringFromValue(headerData.name))
    LAM.util.SetUpTooltip(header, headerData)
    local faqTexture = LAM.util.CreateFAQTexture(control)
    if faqTexture then
        faqTexture:SetAnchor(RIGHT, header, RIGHT, 0, 0)
    end

    control.UpdateValue = UpdateValue

    LAM.util.RegisterForRefreshIfNeeded(control)

    return control
end
