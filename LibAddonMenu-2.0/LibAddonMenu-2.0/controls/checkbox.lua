--[[checkboxData = {
    type = "checkbox",
    name = "My Checkbox", -- or string id or function returning a string
    getFunc = function() return db.var end,
    setFunc = function(value) db.var = value doStuff() end,
    tooltip = "Checkbox's tooltip text.", -- or string id or function returning a string (optional)
    width = "full", -- or "half" (optional)
    disabled = function() return db.someBooleanSetting end, --or boolean (optional)
    warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
    requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
    default = defaults.var, -- a boolean or function that returns a boolean (optional)
    reference = "MyAddonCheckbox", -- unique global reference to control (optional)
} ]]


local widgetVersion = 14
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("checkbox", widgetVersion) then return end

local wm = WINDOW_MANAGER

--label
local enabledColor = ZO_DEFAULT_ENABLED_COLOR
local enabledHLcolor = ZO_HIGHLIGHT_TEXT
local disabledColor = ZO_DEFAULT_DISABLED_COLOR
local disabledHLcolor = ZO_DEFAULT_DISABLED_MOUSEOVER_COLOR
--checkbox
local checkboxColor = ZO_NORMAL_TEXT
local checkboxHLcolor = ZO_HIGHLIGHT_TEXT


local function UpdateDisabled(control)
    local disable
    if type(control.data.disabled) == "function" then
        disable = control.data.disabled()
    else
        disable = control.data.disabled
    end

    control.label:SetColor((disable and ZO_DEFAULT_DISABLED_COLOR or control.value and ZO_DEFAULT_ENABLED_COLOR or ZO_DEFAULT_DISABLED_COLOR):UnpackRGBA())
    control.checkbox:SetColor((disable and ZO_DEFAULT_DISABLED_COLOR or ZO_NORMAL_TEXT):UnpackRGBA())
    --control:SetMouseEnabled(not disable)
    --control:SetMouseEnabled(true)

    control.isDisabled = disable
end

local function ToggleCheckbox(control)
    if control.value then
        control.label:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
        control.checkbox:SetText(control.checkedText)
    else
        control.label:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
        control.checkbox:SetText(control.uncheckedText)
    end
end

local function UpdateValue(control, forceDefault, value)
    if forceDefault then --if we are forcing defaults
        value = LAM.util.GetDefaultValue(control.data.default)
        control.data.setFunc(value)
    elseif value ~= nil then --our value could be false
        control.data.setFunc(value)
        --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
        LAM.util.RequestRefreshIfNeeded(control)
    else
        value = control.data.getFunc()
    end
    control.value = value

    ToggleCheckbox(control)
end

local function OnMouseEnter(control)
    ZO_Options_OnMouseEnter(control)

    if control.isDisabled then return end

    local label = control.label
    if control.value then
        label:SetColor(ZO_HIGHLIGHT_TEXT:UnpackRGBA())
    else
        label:SetColor(ZO_DEFAULT_DISABLED_MOUSEOVER_COLOR:UnpackRGBA())
    end
    control.checkbox:SetColor(ZO_HIGHLIGHT_TEXT:UnpackRGBA())
end

local function OnMouseExit(control)
    ZO_Options_OnMouseExit(control)

    if control.isDisabled then return end

    local label = control.label
    if control.value then
        label:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
    else
        label:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
    end
    control.checkbox:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
end

--controlName is optional
function LAMCreateControl.checkbox(parent, checkboxData, controlName)
    local control = LAM.util.CreateLabelAndContainerControl(parent, checkboxData, controlName)
    control:SetHandler("OnMouseEnter", OnMouseEnter)
    control:SetHandler("OnMouseExit", OnMouseExit)
    control:SetHandler("OnMouseUp", function(control)
        if control.isDisabled then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        control.value = not control.value
        control:UpdateValue(false, control.value)
    end)

    control.checkbox = wm:CreateControl(nil, control.container, CT_LABEL)
    local checkbox = control.checkbox
    checkbox:SetAnchor(LEFT, control.container, LEFT, 0, 0)
    checkbox:SetFont("ZoFontGameBold")
    checkbox:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    control.checkedText = GetString(SI_CHECK_BUTTON_ON):upper()
    control.uncheckedText = GetString(SI_CHECK_BUTTON_OFF):upper()

    if checkboxData.warning ~= nil or checkboxData.requiresReload then
        control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
        control.warning:SetAnchor(RIGHT, checkbox, LEFT, -5, 0)
        control.UpdateWarning = LAM.util.UpdateWarning
        control:UpdateWarning()
    end

    control.data.tooltipText = LAM.util.GetStringFromValue(checkboxData.tooltip)

    control.UpdateValue = UpdateValue
    control:UpdateValue()
    if checkboxData.disabled ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)
    LAM.util.RegisterForReloadIfNeeded(control)

    return control
end
