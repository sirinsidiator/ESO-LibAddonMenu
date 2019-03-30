--[[buttonData = {
    type = "button",
    name = "My Button", -- string id or function returning a string
    func = function() end,
    tooltip = "Button's tooltip text.", -- string id or function returning a string (optional)
    width = "full", --or "half" (optional)
    disabled = function() return db.someBooleanSetting end, --or boolean (optional)
    icon = "icon\\path.dds", --(optional)
    isDangerous = false, -- boolean, if set to true, the button text will be red and a confirmation dialog with the button label and warning text will show on click before the callback is executed (optional)
    warning = "Will need to reload the UI.", --(optional)
    reference = "MyAddonButton", -- unique global reference to control (optional)
} ]]

local widgetVersion = 11
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("button", widgetVersion) then return end

local wm = WINDOW_MANAGER

local function UpdateDisabled(control)
    local disable = control.data.disabled
    if type(disable) == "function" then
        disable = disable()
    end
    control.button:SetEnabled(not disable)
end

--controlName is optional
local MIN_HEIGHT = 28 -- default_button height
local HALF_WIDTH_LINE_SPACING = 2
function LAMCreateControl.button(parent, buttonData, controlName)
    local control = LAM.util.CreateBaseControl(parent, buttonData, controlName)
    control:SetMouseEnabled(true)

    local width = control:GetWidth()
    if control.isHalfWidth then
        control:SetDimensions(width / 2, MIN_HEIGHT * 2 + HALF_WIDTH_LINE_SPACING)
    else
        control:SetDimensions(width, MIN_HEIGHT)
    end

    if buttonData.icon then
        control.button = wm:CreateControl(nil, control, CT_BUTTON)
        control.button:SetDimensions(26, 26)
        control.button:SetNormalTexture(buttonData.icon)
        control.button:SetPressedOffset(2, 2)
    else
        --control.button = wm:CreateControlFromVirtual(controlName.."Button", control, "ZO_DefaultButton")
        control.button = wm:CreateControlFromVirtual(nil, control, "ZO_DefaultButton")
        control.button:SetWidth(width / 3)
        control.button:SetText(LAM.util.GetStringFromValue(buttonData.name))
        if buttonData.isDangerous then control.button:SetNormalFontColor(ZO_ERROR_COLOR:UnpackRGBA()) end
    end
    local button = control.button
    button:SetAnchor(control.isHalfWidth and CENTER or RIGHT)
    button:SetClickSound("Click")
    button.data = {tooltipText = LAM.util.GetStringFromValue(buttonData.tooltip)}
    button:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
    button:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
    button:SetHandler("OnClicked", function(...)
        local args = {...}
        local function callback()
            buttonData.func(unpack(args))
            LAM.util.RequestRefreshIfNeeded(control)
        end

        if(buttonData.isDangerous) then
            local title = LAM.util.GetStringFromValue(buttonData.name)
            local body = LAM.util.GetStringFromValue(buttonData.warning)
            LAM.util.ShowConfirmationDialog(title, body, callback)
        else
            callback()
        end
    end)

    if buttonData.warning ~= nil then
        control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
        control.warning:SetAnchor(RIGHT, button, LEFT, -5, 0)
        control.UpdateWarning = LAM.util.UpdateWarning
        control:UpdateWarning()
    end

    if buttonData.disabled ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)

    return control
end
