--[[sliderData = {
    type = "slider",
    name = "My Slider", -- or string id or function returning a string
    getFunc = function() return db.var end,
    setFunc = function(value) db.var = value doStuff() end,
    min = 0,
    max = 20,
    step = 1, --(optional)
    clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
    decimals = 0, -- when specified the input value is rounded to the specified number of decimals (optional)
    autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
    inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional) 
    tooltip = "Slider's tooltip text.", -- or string id or function returning a string (optional)
    width = "full", --or "half" (optional)
    disabled = function() return db.someBooleanSetting end, --or boolean (optional)
    warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
    requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
    default = defaults.var, -- default value or function that returns the default value (optional)
    reference = "MyAddonSlider" -- unique global reference to control (optional)
} ]]

local widgetVersion = 12
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("slider", widgetVersion) then return end

local wm = WINDOW_MANAGER
local strformat = string.format

local function RoundDecimalToPlace(d, place)
    return tonumber(strformat("%." .. tostring(place) .. "f", d))
end

local function UpdateDisabled(control)
    local disable
    if type(control.data.disabled) == "function" then
        disable = control.data.disabled()
    else
        disable = control.data.disabled
    end

    control.slider:SetEnabled(not disable)
    control.slidervalue:SetEditEnabled(not disable)
    if disable then
        control.label:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
        control.minText:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
        control.maxText:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
        control.slidervalue:SetColor(ZO_DEFAULT_DISABLED_MOUSEOVER_COLOR:UnpackRGBA())
    else
        control.label:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
        control.minText:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
        control.maxText:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
        control.slidervalue:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
    end
end

local function UpdateValue(control, forceDefault, value)
    if forceDefault then --if we are forcing defaults
        value = LAM.util.GetDefaultValue(control.data.default)
        control.data.setFunc(value)
    elseif value then
        if control.data.decimals then
            value = RoundDecimalToPlace(value, control.data.decimals)
        end
        if control.data.clampInput ~= false then
            value = math.max(math.min(value, control.data.max), control.data.min)
        end
        control.data.setFunc(value)
        --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
        LAM.util.RequestRefreshIfNeeded(control)
    else
        value = control.data.getFunc()
    end

    control.slider:SetValue(value)
    control.slidervalue:SetText(value)
end

function LAMCreateControl.slider(parent, sliderData, controlName)
    local control = LAM.util.CreateLabelAndContainerControl(parent, sliderData, controlName)
    local isInputOnRight = sliderData.inputLocation == "right" 

    --skipping creating the backdrop...  Is this the actual slider texture?
    control.slider = wm:CreateControl(nil, control.container, CT_SLIDER)
    local slider = control.slider
    slider:SetAnchor(TOPLEFT)
    slider:SetHeight(14)
    if(isInputOnRight) then
        slider:SetAnchor(TOPRIGHT, nil, nil, -60)
    else
        slider:SetAnchor(TOPRIGHT)
    end
    slider:SetMouseEnabled(true)
    slider:SetOrientation(ORIENTATION_HORIZONTAL)
    --put nil for highlighted texture file path, and what look to be texture coords
    slider:SetThumbTexture("EsoUI\\Art\\Miscellaneous\\scrollbox_elevator.dds", "EsoUI\\Art\\Miscellaneous\\scrollbox_elevator_disabled.dds", nil, 8, 16)
    local minValue = sliderData.min
    local maxValue = sliderData.max
    slider:SetMinMax(minValue, maxValue)
    slider:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(control) end)
    slider:SetHandler("OnMouseExit", function() ZO_Options_OnMouseExit(control) end)

    slider.bg = wm:CreateControl(nil, slider, CT_BACKDROP)
    local bg = slider.bg
    bg:SetCenterColor(0, 0, 0)
    bg:SetAnchor(TOPLEFT, slider, TOPLEFT, 0, 4)
    bg:SetAnchor(BOTTOMRIGHT, slider, BOTTOMRIGHT, 0, -4)
    bg:SetEdgeTexture("EsoUI\\Art\\Tooltips\\UI-SliderBackdrop.dds", 32, 4) 

    control.minText = wm:CreateControl(nil, slider, CT_LABEL)
    local minText = control.minText
    minText:SetFont("ZoFontGameSmall")
    minText:SetAnchor(TOPLEFT, slider, BOTTOMLEFT)
    minText:SetText(sliderData.min)

    control.maxText = wm:CreateControl(nil, slider, CT_LABEL)
    local maxText = control.maxText
    maxText:SetFont("ZoFontGameSmall")
    maxText:SetAnchor(TOPRIGHT, slider, BOTTOMRIGHT)
    maxText:SetText(sliderData.max)

    control.slidervalueBG = wm:CreateControlFromVirtual(nil, slider, "ZO_EditBackdrop")
    if(isInputOnRight) then
        control.slidervalueBG:SetDimensions(60, 26)
        control.slidervalueBG:SetAnchor(LEFT, slider, RIGHT, 5, 0)
    else
        control.slidervalueBG:SetDimensions(50, 16)
        control.slidervalueBG:SetAnchor(TOP, slider, BOTTOM, 0, 0)
    end
    control.slidervalue = wm:CreateControlFromVirtual(nil, control.slidervalueBG, "ZO_DefaultEditForBackdrop")
    local slidervalue = control.slidervalue
    slidervalue:ClearAnchors()
    slidervalue:SetAnchor(TOPLEFT, control.slidervalueBG, TOPLEFT, 3, 1)
    slidervalue:SetAnchor(BOTTOMRIGHT, control.slidervalueBG, BOTTOMRIGHT, -3, -1)
    slidervalue:SetTextType(TEXT_TYPE_NUMERIC)
    if(isInputOnRight) then
        slidervalue:SetFont("ZoFontGameLarge")
    else
        slidervalue:SetFont("ZoFontGameSmall")
    end

    local isHandlingChange = false
    local function HandleValueChanged(value)
        if isHandlingChange then return end
        if sliderData.decimals then
            value = RoundDecimalToPlace(value, sliderData.decimals)
        end
        isHandlingChange = true
        slider:SetValue(value)
        slidervalue:SetText(value)
        isHandlingChange = false
    end

    slidervalue:SetHandler("OnEscape", function(self)
        HandleValueChanged(sliderData.getFunc())
        self:LoseFocus()
    end)
    slidervalue:SetHandler("OnEnter", function(self)
        self:LoseFocus()
    end)
    slidervalue:SetHandler("OnFocusLost", function(self)
        local value = tonumber(self:GetText())
        control:UpdateValue(false, value)
    end)
    slidervalue:SetHandler("OnTextChanged", function(self)
        local input = self:GetText()
        if(#input > 1 and not input:sub(-1):match("[0-9]")) then return end
        local value = tonumber(input)
        if(value) then
            HandleValueChanged(value)
        end
    end)
    if(sliderData.autoSelect) then
        ZO_PreHookHandler(slidervalue, "OnFocusGained", function(self)
            self:SelectAll()
        end)
    end

    local range = maxValue - minValue
    slider:SetValueStep(sliderData.step or 1)
    slider:SetHandler("OnValueChanged", function(self, value, eventReason)
        if eventReason == EVENT_REASON_SOFTWARE then return end
        HandleValueChanged(value)
    end)
    slider:SetHandler("OnSliderReleased", function(self, value)
        control:UpdateValue(false, value)
    end)
    slider:SetHandler("OnMouseWheel", function(self, value)
        if(not self:GetEnabled()) then return end
        local new_value = (tonumber(slidervalue:GetText()) or sliderData.min or 0) + ((sliderData.step or 1) * value)
        control:UpdateValue(false, new_value)
    end)

    if sliderData.warning ~= nil or sliderData.requiresReload then
        control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
        control.warning:SetAnchor(RIGHT, slider, LEFT, -5, 0)
        control.UpdateWarning = LAM.util.UpdateWarning
        control:UpdateWarning()
    end

    control.UpdateValue = UpdateValue
    control:UpdateValue()

    if sliderData.disabled ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)
    LAM.util.RegisterForReloadIfNeeded(control)

    return control
end
