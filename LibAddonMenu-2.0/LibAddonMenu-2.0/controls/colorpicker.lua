--[[colorpickerData = {
	type = "colorpicker",
	name = "My Color Picker",
	tooltip = "Color Picker's tooltip text.",
	getFunc = function() return db.r, db.g, db.b, db.a end,	--(alpha is optional)
	setFunc = function(r,g,b,a) db.r=r, db.g=g, db.b=b, db.a=a end,	--(alpha is optional)
	width = "full",	--or "half" (optional)
	disabled = function() return db.someBooleanSetting end,	--or boolean (optional)
	warning = "Will need to reload the UI.",	--(optional)
	default = {r = defaults.r, g = defaults.g, b = defaults.b, a = defaults.a},	--(optional) table of default color values (or default = defaultColor, where defaultColor is a table with keys of r, g, b[, a])
	reference = "MyAddonColorpicker"	--(optional) unique global reference to control
}	]]


local widgetVersion = 8
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("colorpicker", widgetVersion) then return end

local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER
local tinsert = table.insert


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
	if forceDefault then	--if we are forcing defaults
		local color = control.data.default
		valueR, valueG, valueB, valueA = color.r, color.g, color.b, color.a
		control.data.setFunc(valueR, valueG, valueB, valueA)
	elseif valueR and valueG and valueB then
		control.data.setFunc(valueR, valueG, valueB, valueA or 1)
		--after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
		if control.panel.data.registerForRefresh then
			cm:FireCallbacks("LAM-RefreshPanel", control)
		end
	else
		valueR, valueG, valueB, valueA = control.data.getFunc()
	end

	control.thumb:SetColor(valueR, valueG, valueB, valueA or 1)
end

function LAMCreateControl.colorpicker(parent, colorpickerData, controlName)
	local control = LAM.util.CreateLabelAndContainerControl(parent, colorpickerData, controlName)

	control.color = control.container
	local color = control.color

	control.thumb = wm:CreateControl(nil, color, CT_TEXTURE)
	local thumb = control.thumb
	thumb:SetDimensions(36, 18)
	thumb:SetAnchor(LEFT, color, LEFT, 4, 0)

	color.border = wm:CreateControl(nil, color, CT_TEXTURE)
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
			COLOR_PICKER:Show(ColorPickerCallback, r, g, b, a, colorpickerData.name)
		end
	end)

	if colorpickerData.warning then
		control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
		control.warning:SetAnchor(RIGHT, control.color, LEFT, -5, 0)
		control.warning.data = {tooltipText = colorpickerData.warning}
	end

	control.data.tooltipText = LAM.util.GetTooltipText(colorpickerData.tooltip)

	if colorpickerData.disabled ~= nil then
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
