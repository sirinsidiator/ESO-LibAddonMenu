---@class LAM2_CheckboxData: LAM2_LabelAndContainerControlData
---@field type "checkbox"
---@field getFunc fun(): boolean ex. function() return db.var end
---@field setFunc fun(boolean) ex. function(value) db.var = value doStuff() end
---@field disabled nil|boolean|fun(): boolean ex. function() return db.someBooleanSetting
---@field warning nil|Stringy ex. "May cause permanent awesomeness"
---@field requiresReload nil|boolean if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed.
---@field default nil|boolean|fun(): boolean ex. defaults.var
---@field resetFunc nil|fun(checkboxControl: LAM2_Checkbox) custom function to run after the control is reset to defaults ex. function(checkboxControl) d("defaults reset") end


local widgetVersion = 15
local LAM = LibAddonMenu2
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

---@param checkboxData LAM2_CheckboxData
---@param controlName string|nil
function LAMCreateControl.checkbox(parent, checkboxData, controlName)
    ---@class LAM2_Checkbox: LAM2_LabelAndContainerControl
    local control = LAM.util.CreateLabelAndContainerControl(parent, checkboxData, controlName)
    control:SetHandler("OnMouseEnter", OnMouseEnter)
    control:SetHandler("OnMouseExit", OnMouseExit)
    control:SetHandler("OnMouseUp", function(control)
        if control.isDisabled then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        control.value = not control.value
        control:UpdateValue(false, control.value)
    end)

    control.checkbox = wm:CreateControl(nil, control.container, CT_LABEL) --[[@as LabelControl]]
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
