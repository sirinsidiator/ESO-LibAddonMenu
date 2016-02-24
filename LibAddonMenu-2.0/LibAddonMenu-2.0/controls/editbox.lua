--[[editboxData = {
	type = "editbox",
	name = "My Editbox",
	tooltip = "Editbox's tooltip text.",
	getFunc = function() return db.text end,
	setFunc = function(text) db.text = text doStuff() end,
	isMultiline = true,	--boolean (optional)
	isExtraWide = true,	--boolean (optional)
	width = "full",	--or "half" (optional)
	disabled = function() return db.someBooleanSetting end,	--or boolean (optional)
	warning = "Will need to reload the UI.",	--(optional)
	default = defaults.text,	--(optional)
	reference = "MyAddonEditbox"	--(optional) unique global reference to control
}	]]


local widgetVersion = 9
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("editbox", widgetVersion) then return end

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
		control.editbox:SetColor(ZO_DEFAULT_DISABLED_MOUSEOVER_COLOR:UnpackRGBA())
	else
		control.label:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
		control.editbox:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
	end
	--control.editbox:SetEditEnabled(not disable)
	control.editbox:SetMouseEnabled(not disable)
end

local function UpdateValue(control, forceDefault, value)
	if forceDefault then	--if we are forcing defaults
		value = control.data.default
		control.data.setFunc(value)
		control.editbox:SetText(value)
	elseif value then
		control.data.setFunc(value)
		--after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
		if control.panel.data.registerForRefresh then
			cm:FireCallbacks("LAM-RefreshPanel", control)
		end
	else
		value = control.data.getFunc()
		control.editbox:SetText(value)
	end
end

local MIN_HEIGHT = 24
local HALF_WIDTH_LINE_SPACING = 2
function LAMCreateControl.editbox(parent, editboxData, controlName)
	local control = LAM.util.CreateLabelAndContainerControl(parent, editboxData, controlName)

	local container = control.container
	control.bg = wm:CreateControlFromVirtual(nil, container, "ZO_EditBackdrop")
	local bg = control.bg
	bg:SetAnchorFill()

	if editboxData.isMultiline then
		control.editbox = wm:CreateControlFromVirtual(nil, bg, "ZO_DefaultEditMultiLineForBackdrop")
		control.editbox:SetHandler("OnMouseWheel", function(self, delta)
			if self:HasFocus() then	--only set focus to new spots if the editbox is currently in use
				local cursorPos = self:GetCursorPosition()
				local text = self:GetText()
				local textLen = text:len()
				local newPos
				if delta > 0 then	--scrolling up
					local reverseText = text:reverse()
					local revCursorPos = textLen - cursorPos
					local revPos = reverseText:find("\n", revCursorPos+1)
					newPos = revPos and textLen - revPos
				else	--scrolling down
					newPos = text:find("\n", cursorPos+1)
				end
				if newPos then	--if we found a new line, then scroll, otherwise don't
					self:SetCursorPosition(newPos)
				end
			end
		end)
	else
		control.editbox = wm:CreateControlFromVirtual(nil, bg, "ZO_DefaultEditForBackdrop")
	end
	local editbox = control.editbox
	editbox:SetText(editboxData.getFunc())
	editbox:SetMaxInputChars(3000)
	editbox:SetHandler("OnFocusLost", function(self) control:UpdateValue(false, self:GetText()) end)
	editbox:SetHandler("OnEscape", function(self) self:LoseFocus() control:UpdateValue(false, self:GetText()) end)
	editbox:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(control) end)
	editbox:SetHandler("OnMouseExit", function() ZO_Options_OnMouseExit(control) end)

	local MIN_WIDTH = (parent.GetWidth and (parent:GetWidth() / 10)) or (parent.panel.GetWidth and (parent.panel:GetWidth() / 10)) or 0

	control.label:ClearAnchors()
	container:ClearAnchors()

	control.label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
	container:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)

	if control.isHalfWidth then
		container:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
	end

	if editboxData.isExtraWide then
		container:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, 0, 0)
	else
		container:SetWidth(MIN_WIDTH * 3.2)
	end

	if editboxData.isMultiline then
		container:SetHeight(MIN_HEIGHT * 3)
	else
		container:SetHeight(MIN_HEIGHT)
	end

	if control.isHalfWidth ~= true and editboxData.isExtraWide ~= true then
		control:SetHeight(container:GetHeight())
	else
		control:SetHeight(container:GetHeight() + control.label:GetHeight())
	end

	editbox:ClearAnchors()
	editbox:SetAnchor(TOPLEFT, container, TOPLEFT, 2, 2)
	editbox:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, -2, -2)

	if editboxData.warning then
		control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
		if editboxData.isExtraWide then
			control.warning:SetAnchor(BOTTOMRIGHT, control.bg, TOPRIGHT, 2, 0)
		else
			control.warning:SetAnchor(TOPRIGHT, control.bg, TOPLEFT, -5, 0)
		end
		control.warning.data = {tooltipText = editboxData.warning}
	end

	if editboxData.disabled ~= nil then
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
