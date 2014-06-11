--[[buttonData = {
	type = "button",
	name = "My Button",
	tooltip = "Button's tooltip text.",
	func = function() end,
	width = "full",	--or "half" (optional)
	disabled = function() return db.someBooleanSetting end,	--or boolean (optional)
	icon = "icon\\path.dds",	--(optional)
	warning = "Will need to reload the UI.",	--(optional)
	reference = "MyAddonButton"	--(optional) unique global reference to control
}	]]


local widgetVersion = 2
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("button", widgetVersion) then return end

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
	
	control.button:SetEnabled(not disable)
end


--controlName is optional
function LAMCreateControl.button(parent, buttonData, controlName)
	local control = wm:CreateTopLevelWindow(controlName or buttonData.reference)
	control:SetParent(parent.scroll)
	
	local isHalfWidth = buttonData.width == "half"
	control:SetDimensions(isHalfWidth and 250 or 510, isHalfWidth and 55 or 28)
	control:SetMouseEnabled(true)
	
	if buttonData.icon then
		control.button = wm:CreateControl(nil, control, CT_BUTTON)
		control.button:SetDimensions(26, 26)
		control.button:SetNormalTexture(buttonData.icon)
		control.button:SetPressedOffset(2, 2)
	else
		--control.button = wm:CreateControlFromVirtual(controlName.."Button", control, "ZO_DefaultButton")
		control.button = wm:CreateControlFromVirtual(nil, control, "ZO_DefaultButton")
		control.button:SetWidth(isHalfWidth and 180 or 200)
		control.button:SetText(buttonData.name)
	end
	local button = control.button
	button:SetAnchor(isHalfWidth and CENTER or RIGHT)
	button:SetClickSound("Click")
	button.tooltipText = buttonData.tooltip
	button:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
	button:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
	button:SetHandler("OnClicked", function(self, ...)
			buttonData.func(self, ...)
			if control.panel.data.registerForRefresh then
				cm:FireCallbacks("LAM-RefreshPanel", control)
			end
		end)
	
	if buttonData.warning then
		control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
		control.warning:SetAnchor(RIGHT, button, LEFT, -5, 0)
		control.warning.tooltipText = buttonData.warning
	end
	
	control.panel = parent.panel or parent	--if this is in a submenu, panel is its parent
	control.data = buttonData
	
	if buttonData.disabled then
		control.UpdateDisabled = UpdateDisabled
		control:UpdateDisabled()
		
		--this is here because buttons don't have an UpdateValue method
		if control.panel.data.registerForRefresh then	--if our parent window wants to refresh controls, then add this to the list
			tinsert(control.panel.controlsToRefresh, control)
		end
	end
	
	return control
end