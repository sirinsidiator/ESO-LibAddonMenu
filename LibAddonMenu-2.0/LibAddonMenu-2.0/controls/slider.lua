--[[sliderData = {
	type = "slider",
	name = "My Slider",
	tooltip = "Slider's tooltip text.",
	min = 0,
	max = 20,
	step = 1,	--(optional)
	decimals = 0, --(optional)
	getFunc = function() return db.var end,
	setFunc = function(value) db.var = value doStuff() end,
	width = "full",	--or "half" (optional)
	disabled = function() return db.someBooleanSetting end,	--or boolean (optional)
	warning = "Will need to reload the UI.",	--(optional)
	default = defaults.var,	--(optional)
	reference = "MyAddonSlider"	--(optional) unique global reference to control
}	]]


local widgetVersion = 8
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("slider", widgetVersion) then return end

local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER
local round = zo_round
local strformat = string.format
local tinsert = table.insert

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
	if forceDefault then	--if we are forcing defaults
		value = control.data.default
		control.data.setFunc(value)
	elseif value and value >= control.data.min and value <= control.data.max then
		control.data.setFunc(value)
		--after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
		if control.panel.data.registerForRefresh then
			cm:FireCallbacks("LAM-RefreshPanel", control)
		end
	else
		value = control.data.getFunc()
	end

	control.slider:SetValue(value)
	control.slidervalue:SetText(value)
end


function LAMCreateControl.slider(parent, sliderData, controlName)
	local control = LAM.util.CreateLabelAndContainerControl(parent, sliderData, controlName)

	--skipping creating the backdrop...  Is this the actual slider texture?
	control.slider = wm:CreateControl(nil, control.container, CT_SLIDER)
	local slider = control.slider
	slider:SetAnchor(TOPLEFT)
	slider:SetAnchor(TOPRIGHT)
	slider:SetHeight(14)
	slider:SetMouseEnabled(true)
	slider:SetOrientation(ORIENTATION_HORIZONTAL)
	--put nil for highlighted texture file path, and what look to be texture coords
	slider:SetThumbTexture("EsoUI\\Art\\Miscellaneous\\scrollbox_elevator.dds", "EsoUI\\Art\\Miscellaneous\\scrollbox_elevator_disabled.dds", nil, 8, 16)
	local minValue = sliderData.min
	local maxValue = sliderData.max
	slider:SetMinMax(minValue, maxValue)
	slider:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(control) end)
	slider:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseExit(control) end)

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
	control.slidervalueBG:SetDimensions(50, 16)
	control.slidervalueBG:SetAnchor(TOP, slider, BOTTOM, 0, 0)
	control.slidervalue = wm:CreateControlFromVirtual(nil, control.slidervalueBG, "ZO_DefaultEditForBackdrop")
	local slidervalue = control.slidervalue
	slidervalue:ClearAnchors()
	slidervalue:SetAnchor(TOPLEFT, control.slidervalueBG, TOPLEFT, 3, 1)
	slidervalue:SetAnchor(BOTTOMRIGHT, control.slidervalueBG, BOTTOMRIGHT, -3, -1)
	slidervalue:SetTextType(TEXT_TYPE_NUMERIC)
	slidervalue:SetFont("ZoFontGameSmall")
	slidervalue:SetHandler("OnEscape", function(self)
			self:LoseFocus()
			control:UpdateValue()
		end)
	slidervalue:SetHandler("OnEnter", function(self)
			self:LoseFocus()
			control:UpdateValue(false, tonumber(self:GetText()))
		end)
	local function RoundDecimalToPlace(d, place)
		return tonumber(string.format("%." .. tostring(place) .. "f", d))
	end
	local range = maxValue - minValue
	slider:SetValueStep(sliderData.step or 1)
	slider:SetHandler("OnValueChanged", function(self, value, eventReason)
			if eventReason == EVENT_REASON_SOFTWARE then return end
			local new_value = sliderData.decimals and RoundDecimalToPlace(value, sliderData.decimals) or value
			self:SetValue(new_value)	--do we actually need this line?
			slidervalue:SetText(new_value)
		end)
	slider:SetHandler("OnSliderReleased", function(self, value)
			--sliderData.setFunc(value)
			local new_value = sliderData.decimals and RoundDecimalToPlace(value, sliderData.decimals) or value
			control:UpdateValue(false, new_value)	--does this work here instead?
		end)
	slider:SetHandler("OnMouseWheel", function(self, value)
			local new_value = (tonumber(slidervalue:GetText()) or sliderData.min or 0) + ((sliderData.step or 1) * value)
			control:UpdateValue(false, new_value)
		end)

	if sliderData.warning then
		control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
		control.warning:SetAnchor(RIGHT, slider, LEFT, -5, 0)
		control.warning.data = {tooltipText = sliderData.warning}
	end

	if sliderData.disabled ~= nil then
		control.UpdateDisabled = UpdateDisabled
		control:UpdateDisabled()
	end
	control.UpdateValue = UpdateValue
	control:UpdateValue()

	if control.panel.data.registerForRefresh or control.panel.data.registerForDefaults then	--if our parent window wants to refresh controls, then add this to the list
		tinsert(control.panel.controlsToRefresh, control)
	end

	return control
end
