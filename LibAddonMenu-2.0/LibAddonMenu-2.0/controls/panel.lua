--[[panelData = {
	type = "panel",
	name = "Window Title",
	displayName = "My Longer Window Title",	--(optional) (can be useful for long addon names or if you want to colorize it)
	author = "Seerah",	--(optional)
	version = "2.0",	--(optional)
	keywords = "settings",	--(optional) additional keywords for search filter (it looks for matches in name..keywords..author)
	slashCommand = "/myaddon",	--(optional) will register a keybind to open to this panel (don't forget to include the slash!)
	registerForRefresh = true,	--boolean (optional) (will refresh all options controls when a setting is changed and when the panel is shown)
	registerForDefaults = true,	--boolean (optional) (will set all options controls back to default values)
	resetFunc = function() print("defaults reset") end,	--(optional) custom function to run after settings are reset to defaults
}	]]


local widgetVersion = 9
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("panel", widgetVersion) then return end

local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER

local function RefreshPanel(control)
	local panel = control.panel or control	--callback can be fired by a single control or by the panel showing
	local panelControls = panel.controlsToRefresh

	for i = 1, #panelControls do
		local updateControl = panelControls[i]
		if  updateControl ~= control then
			if updateControl.UpdateValue then
				updateControl:UpdateValue()
			end
			if updateControl.UpdateDisabled then
				updateControl:UpdateDisabled()
			end
		end
	end
end

local function ForceDefaults(panel)
	local panelControls = panel.controlsToRefresh

	for i = 1, #panelControls do
		local updateControl = panelControls[i]
		if updateControl.UpdateValue and updateControl.data.default ~= nil then
			updateControl:UpdateValue(true)
		end
	end

	if panel.data.resetFunc then
		panel.data.resetFunc()
	end

	cm:FireCallbacks("LAM-RefreshPanel", panel)
end
ESO_Dialogs["LAM_DEFAULTS"] = {
	title = {
		text = SI_INTERFACE_OPTIONS_RESET_TO_DEFAULT_TOOLTIP,
	},
	mainText = {
		text = SI_OPTIONS_RESET_PROMPT,
		align = TEXT_ALIGN_CENTER,
	},
	buttons = {
		[1] = {
			text = SI_OPTIONS_RESET,
			callback = function(dialog) ForceDefaults(dialog.data[1]) end,
		},
		[2] = {
			text = SI_DIALOG_CANCEL,
		},
	},
}

local callbackRegistered = false
LAMCreateControl.scrollCount = LAMCreateControl.scrollCount or 1
function LAMCreateControl.panel(parent, panelData, controlName)
	local control = wm:CreateControl(controlName, parent, CT_CONTROL)

	control.label = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel")
	local label = control.label
	label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 4)
	label:SetText(panelData.displayName or panelData.name)

	if panelData.author or panelData.version then
		control.info = wm:CreateControl(nil, control, CT_LABEL)
		local info = control.info
		info:SetFont("$(CHAT_FONT)|14|soft-shadow-thin")
		info:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, -2)
		if panelData.author and panelData.version then
			info:SetText(string.format("Version: %s  -  %s: %s", panelData.version, GetString(SI_ADDON_MANAGER_AUTHOR), panelData.author))
		elseif panelData.author then
			info:SetText(string.format("%s: %s", GetString(SI_ADDON_MANAGER_AUTHOR), panelData.author))
		else
			info:SetText("Version: "..panelData.version)
		end
	end

	control.container = wm:CreateControlFromVirtual("LAMAddonPanelContainer"..LAMCreateControl.scrollCount, control, "ZO_ScrollContainer")
	LAMCreateControl.scrollCount = LAMCreateControl.scrollCount + 1
	local container = control.container
	container:SetAnchor(TOPLEFT, control.info or label, BOTTOMLEFT, 0, 20)
	container:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -3, -3)
	control.scroll = GetControl(control.container, "ScrollChild")
	control.scroll:SetResizeToFitPadding(0, 20)

	if panelData.registerForDefaults then
		control.defaultButton = wm:CreateControlFromVirtual(nil, control, "ZO_DefaultTextButton")
		local defaultButton = control.defaultButton
		defaultButton:SetFont("ZoFontDialogKeybindDescription")
		defaultButton:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
		--defaultButton:SetText("Reset To Defaults")
		defaultButton:SetText(GetString(SI_OPTIONS_DEFAULTS))
		defaultButton:SetDimensions(200, 30)
		defaultButton:SetAnchor(TOPLEFT, control, BOTTOMLEFT, 0, 2)
		defaultButton:SetHandler("OnClicked", function()
				ZO_Dialogs_ShowDialog("LAM_DEFAULTS", {control})
			end)
	end

	if panelData.registerForRefresh and not callbackRegistered then	--don't want to register our callback more than once
		cm:RegisterCallback("LAM-RefreshPanel", RefreshPanel)
		callbackRegistered = true
	end

	control.data = panelData
	control.controlsToRefresh = {}

	return control
end


-- vi: noexpandtab
