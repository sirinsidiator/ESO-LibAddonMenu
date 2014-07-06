--[[checkboxData = {
	type = "checkbox",
	name = "My Checkbox",
	tooltip = "Checkbox's tooltip text.",
	getFunc = function() return db.var end,
	setFunc = function(value) db.var = value doStuff() end,
	width = "full",	--or "half" (optional)
	disabled = function() return db.someBooleanSetting end,	--or boolean (optional)
	warning = "Will need to reload the UI.",	--(optional)
	default = defaults.var,	--(optional)
	reference = "MyAddonCheckbox"	--(optional) unique global reference to control
}	]]


local widgetVersion = 5
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("checkbox", widgetVersion) then return end

local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER
local tinsert = table.insert
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
	if forceDefault then	--if we are forcing defaults
		value = control.data.default
		control.data.setFunc(value)
	elseif value ~= nil then	--our value could be false
		control.data.setFunc(value)
		--after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
		if control.panel.data.registerForRefresh then
			cm:FireCallbacks("LAM-RefreshPanel", control)
		end
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
	local control = wm:CreateTopLevelWindow(controlName or checkboxData.reference)
	control:SetParent(parent.scroll or parent)
	control:SetMouseEnabled(true)
	control.tooltipText = checkboxData.tooltip
	control:SetHandler("OnMouseEnter", OnMouseEnter)
	control:SetHandler("OnMouseExit", OnMouseExit)
	control:SetHandler("OnMouseUp", function(control)
			if control.isDisabled then return end
			PlaySound(SOUNDS.DEFAULT_CLICK)
			control.value = not control.value
			control:UpdateValue(false, control.value)
		end)
	
	control.label = wm:CreateControl(nil, control, CT_LABEL)
	local label = control.label
	label:SetFont("ZoFontWinH4")
	label:SetText(checkboxData.name)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	label:SetHeight(26)

	control.checkbox = wm:CreateControl(nil, control, CT_LABEL)
	local checkbox = control.checkbox
	checkbox:SetFont("ZoFontGameBold")
	checkbox:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
	control.checkedText = GetString(SI_CHECK_BUTTON_ON):upper()
	control.uncheckedText = GetString(SI_CHECK_BUTTON_OFF):upper()

	local isHalfWidth = checkboxData.width == "half"
	if isHalfWidth then
		control:SetDimensions(250, 55)
		checkbox:SetDimensions(100, 26)
		checkbox:SetAnchor(BOTTOMRIGHT)
		label:SetAnchor(TOPLEFT)
		label:SetAnchor(TOPRIGHT)
	else
		control:SetDimensions(510, 30)
		checkbox:SetDimensions(200, 26)
		checkbox:SetAnchor(RIGHT)
		label:SetAnchor(LEFT)
		label:SetAnchor(RIGHT, checkbox, LEFT, -5, 0)	
	end
	
	if checkboxData.warning then
		control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
		control.warning:SetAnchor(RIGHT, checkbox, LEFT, -5, 0)
		control.warning.tooltipText = checkboxData.warning
	end
	
	control.panel = parent.panel or parent	--if this is in a submenu, panel is its parent
	control.data = checkboxData
	
	if checkboxData.disabled then
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