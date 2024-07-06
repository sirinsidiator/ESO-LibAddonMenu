---@alias ColorTable {["r"]: number, ["g"]: number, ["b"]: number, ["a"]: number|nil}

---@class LAM2_ColorPickerData: LAM2_LabelAndContainerControlData
---@field type "colorpicker"
---@field getFunc fun(): number, number, number, number|nil returns r, g, b, a
---@field setFunc fun(r: number, g: number, b: number, a:number|nil)
---@field disabled nil|boolean|fun(): boolean ex. function() return db.someBooleanSetting end
---@field warning nil|Stringy ex. "May cause permanent awesomeness."
---@field requiresReload nil|boolean if set to true, the warning text will contain a notice that changes are only applied after a UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed
---@field default nil|ColorTable|fun(): ColorTable table of default color values ex. {r = defaults.r, g = defaults.g, b = defaults.b, a = defaults.a}
---@field resetFunc nil|fun(colorPickerControl: LAM2_ColorPicker) custom function to run after the control is reset to defaults ex. function(colorpickerControl) d("defaults reset") end

local widgetVersion = 15
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("colorpicker", widgetVersion) then return end

local wm = WINDOW_MANAGER

local function UpdateDisabled(control)
    local disable
    if type(control.data.disabled) == "function" then
        disable = control.data.disabled()
    else
        disable = control.data.disabled
    end

    if disable then
        control.label:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
    else
        control.label:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
    end

    control.isDisabled = disable
end

local function UpdateValue(control, forceDefault, valueR, valueG, valueB, valueA)
    if forceDefault then --if we are forcing defaults
        local color = LAM.util.GetDefaultValue(control.data.default)
        valueR, valueG, valueB, valueA = color.r, color.g, color.b, color.a
        control.data.setFunc(valueR, valueG, valueB, valueA)
    elseif valueR and valueG and valueB then
        control.data.setFunc(valueR, valueG, valueB, valueA or 1)
        --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
        LAM.util.RequestRefreshIfNeeded(control)
    else
        valueR, valueG, valueB, valueA = control.data.getFunc()
    end

    control.thumb:SetColor(valueR, valueG, valueB, valueA or 1)
end

---@param colorpickerData LAM2_ColorPickerData
function LAMCreateControl.colorpicker(parent, colorpickerData, controlName)
    ---@class LAM2_ColorPicker: LAM2_LabelAndContainerControl
    local control = LAM.util.CreateLabelAndContainerControl(parent, colorpickerData, controlName)

    ---@class LAM2_BorderedContainer: Control
    ---@field border TextureControl
    control.color = control.container
    local color = control.color

    control.thumb = wm:CreateControl(nil, color, CT_TEXTURE) --[[@as TextureControl]]
    local thumb = control.thumb
    thumb:SetDimensions(36, 18)
    thumb:SetAnchor(LEFT, color, LEFT, 4, 0)

    color.border = wm:CreateControl(nil, color, CT_TEXTURE) --[[@as TextureControl]]
    local border = color.border
    border:SetTexture("EsoUI\\Art\\ChatWindow\\chatOptions_bgColSwatch_frame.dds")
    border:SetTextureCoords(0, .625, 0, .8125)
    border:SetDimensions(40, 22)
    border:SetAnchor(CENTER, thumb, CENTER, 0, 0)

    local function ColorPickerCallback(r, g, b, a)
        control:UpdateValue(false, r, g, b, a)
    end

    control:SetHandler("OnMouseUp", function(self, btn, upInside)
        if self.isDisabled then return end

        if upInside then
            local r, g, b, a = colorpickerData.getFunc()
            if IsInGamepadPreferredMode() then
                COLOR_PICKER_GAMEPAD:Show(ColorPickerCallback, r, g, b, a)
            else
                COLOR_PICKER:Show(ColorPickerCallback, r, g, b, a)
            end
        end
    end)

    if colorpickerData.warning ~= nil or colorpickerData.requiresReload then
        control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
        control.warning:SetAnchor(RIGHT, control.color, LEFT, -5, 0)
        control.UpdateWarning = LAM.util.UpdateWarning
        control:UpdateWarning()
    end

    control.data.tooltipText = LAM.util.GetStringFromValue(colorpickerData.tooltip)

    control.UpdateValue = UpdateValue
    control:UpdateValue()
    if colorpickerData.disabled ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)
    LAM.util.RegisterForReloadIfNeeded(control)

    return control
end
