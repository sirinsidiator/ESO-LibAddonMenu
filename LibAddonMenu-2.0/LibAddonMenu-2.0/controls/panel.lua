--[[panelData = {
	type = "panel",
	name = "Window Title",
	displayName = "My Longer Window Title",	--(optional) (can be useful for long addon names or if you want to colorize it)
	author = "Seerah",	--(optional)
	version = "2.0",	--(optional)
	slashCommand = "/myaddon",	--(optional) will register a keybind to open to this panel (don't forget to include the slash!)
	registerForRefresh = true,	--boolean (optional) (will refresh all options controls when a setting is changed and when the panel is shown)
	registerForDefaults = true,	--boolean (optional) (will set all options controls back to default values)
	resetFunc = function() print("defaults reset") end,	--(optional) custom function to run after settings are reset to defaults
}	]]


local widgetVersion = 4
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
		text = SI_OPTIONS_RESET_TITLE,
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

local scrollCount = 1
function LAMCreateControl.panel(parent, panelData, controlName)
	local control = wm:CreateTopLevelWindow(controlName)
	control:SetParent(parent)
	
	control.bg = wm:CreateControl(nil, control, CT_BACKDROP)
	local bg = control.bg
	bg:SetAnchorFill()
	bg:SetEdgeTexture("EsoUI\\Art\\Tooltips\\UI-Border.dds", 128, 16)
	bg:SetCenterColor(0, 0, 0, 0)
	
	control.label = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel")
	local label = control.label
	label:SetAnchor(TOPLEFT, control, TOPLEFT, 10, 10)
	label:SetText(panelData.displayName and panelData.displayName or panelData.name)
	
	if panelData.author or panelData.version then
		control.info = wm:CreateControl(nil, control, CT_LABEL)
		local info = control.info
		info:SetFont("$(CHAT_FONT)|14|soft-shadow-thin")
		info:SetColor(ZO_HIGHLIGHT_TEXT:UnpackRGBA())
		info:SetHeight(13)
		info:SetAnchor(TOPRIGHT, control, BOTTOMRIGHT, -5, 2)
		if panelData.author and panelData.version then
			--info:SetText("Version: "..panelData.version.."  -  "..GetString(SI_ADDON_MANAGER_AUTHOR)..": "..panelData.author)
			info:SetText(string.format("Version: %s  -  %s: %s", panelData.version, GetString(SI_ADDON_MANAGER_AUTHOR), panelData.author))
		elseif panelData.author then
			info:SetText(string.format("%s: %s", GetString(SI_ADDON_MANAGER_AUTHOR), panelData.author))
		else
			info:SetText("Version: "..panelData.version)
		end
	end
	
	control.container = wm:CreateControlFromVirtual("LAMAddonPanelContainer"..scrollCount, control, "ZO_ScrollContainer")
	scrollCount = scrollCount + 1
	local container = control.container
	container:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 20)
	container:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -3, -3)
	control.scroll = GetControl(control.container, "ScrollChild")
	control.scroll:SetResizeToFitPadding(0, 20)
	
	if panelData.registerForDefaults then
		control.defaultButton = wm:CreateControlFromVirtual(nil, control, "ZO_DefaultTextButton")
		local defaultButton = control.defaultButton
		defaultButton:SetFont("ZoFontDialogKeybindDescription")
		defaultButton:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
		--defaultButton:SetText("Reset To Defaults")
		defaultButton:SetText(GetString(SI_OPTIONS_RESET_TITLE))
		defaultButton:SetDimensions(200, 30)
		defaultButton:SetAnchor(TOPLEFT, control, BOTTOMLEFT, 0, 2)
		defaultButton:SetHandler("OnClicked", function()
				ZO_Dialogs_ShowDialog("LAM_DEFAULTS", {control})
			end)
	end

	if panelData.registerForRefresh then
		cm:RegisterCallback("LAM-RefreshPanel", RefreshPanel)
	end

	control.data = panelData
	control.controlsToRefresh = {}
	
	return control
end