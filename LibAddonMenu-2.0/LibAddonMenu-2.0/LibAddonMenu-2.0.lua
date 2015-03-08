--	LibAddonMenu-2.0 & its files © Ryan Lakanen (Seerah)		--
--	Distributed under The Artistic License 2.0 (see LICENSE)	--
------------------------------------------------------------------


--Register LAM with LibStub
local MAJOR, MINOR = "LibAddonMenu-2.0", 999 -- only for test purposes. releases will get a smaller number
local lam, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lam then return end	--the same or newer version of this lib is already loaded into memory

--UPVALUES--
local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER
local em = EVENT_MANAGER
local tinsert = table.insert
local optionsWindow = ZO_OptionsWindowSettingsScrollChild
local _

local messages = {}
local eventHandle = table.concat({MAJOR, MINOR}, "r")
local addonsForList = {}
local addonToOptionsMap = {}
local optionsCreated = {}
lam.widgets = lam.widgets or {}
local widgets = lam.widgets

local MESSAGE_PREFIX = "[LAM2] "

local function PrintLater(msg)
	if CHAT_SYSTEM.primaryContainer then
		d(MESSAGE_PREFIX .. msg)
	else
		messages[#messages + 1] = msg
	end
end

local function FlushMessages()
	for i = 1, #messages do
		d(MESSAGE_PREFIX .. messages[i])
	end
	messages = {}
end

if LAMSettingsPanelCreated and not LAMCompatibilityWarning then
	PrintLater("An old version of LibAddonMenu with compatibility issues was detected. For more information on how to proceed search for LibAddonMenu on esoui.com")
	LAMCompatibilityWarning = true
end

--METHOD: REGISTER WIDGET--
--each widget has its version checked before loading,
--so we only have the most recent one in memory
--Usage:
--	widgetType = "string"; the type of widget being registered
--	widgetVersion = integer; the widget's version number
LAMCreateControl = LAMCreateControl or {}
local lamcc = LAMCreateControl

function lam:RegisterWidget(widgetType, widgetVersion)
	if widgets[widgetType] and widgets[widgetType] >= widgetVersion then
		return false
	else
		widgets[widgetType] = widgetVersion
		return true
	end
end


--METHOD: OPEN TO ADDON PANEL--
--opens to a specific addon's option panel
--Usage:
--  panel = userdata; the panel returned by the :RegisterOptionsPanel method
local locSettings = GetString(SI_GAME_MENU_SETTINGS)
function lam:OpenToPanel(panel)
	SCENE_MANAGER:Show("gameMenuInGame")
	zo_callLater(function()
		local settingsMenu = ZO_GameMenu_InGame.gameMenu.headerControls[locSettings]
		settingsMenu:SetOpen(true)
		SCENE_MANAGER:AddFragment(OPTIONS_WINDOW_FRAGMENT)
		KEYBOARD_OPTIONS:ChangePanels(lam.panelID)
		for i, child in pairs(settingsMenu.children) do
			if type(child) == "table" and child.data.name == KEYBOARD_OPTIONS.panelNames[lam.panelID] then
				ZO_TreeEntry_OnMouseUp(child.control, true)
				break
			end
		end
		local scroll = LAMAddonPanelsMenuScrollChild
		for i = 1, scroll:GetNumChildren() do
			local button = scroll:GetChild(i)
			if button.panel == panel then
				zo_callHandler(button, "OnClicked")
				ZO_Scroll_ScrollControlToTop(LAMAddonPanelsMenu, button)
				break
			end
		end
	end, 200)
end


--INTERNAL FUNCTION
--creates controls when options panel is first shown
--controls anchoring of these controls in the panel
local function CreateOptionsControls(panel)
	local addonID = panel:GetName()
	local optionsTable = addonToOptionsMap[addonID]

	if optionsTable then
		local function CreateAndAnchorWidget(parent, widgetData, offsetX, offsetY, anchorTarget, wasHalf)
			local widget
			local status, err = pcall(function() widget = LAMCreateControl[widgetData.type](parent, widgetData) end)
			if not status then
				return err or true, offsetY, anchorTarget, wasHalf
			else
				local isHalf = (widgetData.width == "half")
				if not anchorTarget then -- the first widget in a panel is just placed in the top left corner
					widget:SetAnchor(TOPLEFT)
					anchorTarget = widget
				elseif wasHalf and isHalf then -- when the previous widget was only half width and this one is too, we place it on the right side
					widget:SetAnchor(TOPLEFT, anchorTarget, TOPRIGHT, 5 + (offsetX or 0), 0)
					offsetY = zo_max(0, widget:GetHeight() - anchorTarget:GetHeight()) -- we need to get the common height of both widgets to know where the next row starts
					isHalf = false
				else -- otherwise we just put it below the previous one normally
					widget:SetAnchor(TOPLEFT, anchorTarget, BOTTOMLEFT, 0, 15 + offsetY)
					offsetY = 0
					anchorTarget = widget
				end
				return false, offsetY, anchorTarget, isHalf
			end
		end

		local THROTTLE_TIMEOUT, THROTTLE_COUNT = 10, 20
		local fifo = {}
		local anchorOffset, lastAddedControl, wasHalf
		local CreateWidgetsInPanel, err

		local function PrepareForNextPanel()
			anchorOffset, lastAddedControl, wasHalf = 0, nil, false
		end

		local function SetupCreationCalls(parent, widgetDataTable)
			fifo[#fifo + 1] = PrepareForNextPanel
			local count = #widgetDataTable
			for i = 1, count, THROTTLE_COUNT do
				fifo[#fifo + 1] = function()
					CreateWidgetsInPanel(parent, widgetDataTable, i, zo_min(i + THROTTLE_COUNT - 1, count))
				end
			end
			return count ~= NonContiguousCount(widgetDataTable)
		end

		CreateWidgetsInPanel = function(parent, widgetDataTable, startIndex, endIndex)
			for i=startIndex,endIndex do
				local widgetData = widgetDataTable[i]
				if not widgetData then
					PrintLater("Skipped creation of missing entry in the settings menu of " .. addonID .. ".")
				else
					local widgetType = widgetData.type
					local offsetX = 0
					local isSubmenu = (widgetType == "submenu")
					if isSubmenu then
						wasHalf = false
						offsetX = 5
					end

					err, anchorOffset, lastAddedControl, wasHalf = CreateAndAnchorWidget(parent, widgetData, offsetX, anchorOffset, lastAddedControl, wasHalf)
					if err then
						PrintLater(("Could not create %s '%s' of %s."):format(widgetData.type, widgetData.name or "unnamed", addonID))
					end

					if isSubmenu then
						if SetupCreationCalls(lastAddedControl, widgetData.controls) then
							PrintLater(("The sub menu '%s' of %s is missing some entries."):format(widgetData.name or "unnamed", addonID))
						end
					end
				end
			end
		end

		local function DoCreateSettings()
			if #fifo > 0 then
				local nextCall = table.remove(fifo, 1)
				nextCall()
				if(nextCall == PrepareForNextPanel) then
					DoCreateSettings()
				else
					zo_callLater(DoCreateSettings, THROTTLE_TIMEOUT)
				end
			else
				if missingEntries then
					PrintLater("Missing one or more entries in the settings menu of " .. addonID .. ". Check your options table for missing indices.")
				end

				optionsCreated[addonID] = true
				cm:FireCallbacks("LAM-PanelControlsCreated", panel)
			end
		end

		if SetupCreationCalls(panel, optionsTable) then
			PrintLater(("The settings menu of %s is missing some entries."):format(addonID))
		end
		DoCreateSettings()
	end
end


--INTERNAL FUNCTION
--handles switching between panels
local function ToggleAddonPanels(panel)	--called in OnShow of newly shown panel
	local currentlySelected = LAMAddonPanelsMenu.currentlySelected
	if currentlySelected and currentlySelected ~= panel then
		currentlySelected:SetHidden(true)
	end
	LAMAddonPanelsMenu.currentlySelected = panel

	if not optionsCreated[panel:GetName()] then	--if this is the first time opening this panel, create these options
		CreateOptionsControls(panel)
	end

	cm:FireCallbacks("LAM-RefreshPanel", panel)
end

local CheckSafetyAndInitialize

--METHOD: REGISTER ADDON PANEL
--registers your addon with LibAddonMenu and creates a panel
--Usage:
--	addonID = "string"; unique ID which will be the global name of your panel
--	panelData = table; data object for your panel - see controls\panel.lua
function lam:RegisterAddonPanel(addonID, panelData)
	CheckSafetyAndInitialize(addonID)
	local panel = lamcc.panel(nil, panelData, addonID)	--addonID==global name of panel
	panel:SetHidden(true)
	panel:SetAnchor(TOPLEFT, LAMAddonPanelsMenu, TOPRIGHT, 10, 0)
	panel:SetAnchor(BOTTOMLEFT, LAMAddonPanelsMenu, BOTTOMRIGHT, 10, 0)
	panel:SetWidth(549)
	panel:SetDrawLayer(DL_OVERLAY)
	tinsert(addonsForList, {panel = addonID, name = panelData.name})
	panel:SetHandler("OnShow", ToggleAddonPanels)
	if panelData.slashCommand then
		SLASH_COMMANDS[panelData.slashCommand] = function()
			lam:OpenToPanel(panel)
		end
	end

	return panel	--return for authors creating options manually
end


--METHOD: REGISTER OPTION CONTROLS
--registers the options you want shown for your addon
--these are stored in a table where each key-value pair is the order
--of the options in the panel and the data for that control, respectively
--see exampleoptions.lua for an example
--see controls\<widget>.lua for each widget type
--Usage:
--	addonID = "string"; the same string passed to :RegisterAddonPanel
--	optionsTable = table; the table containing all of the options controls and their data
function lam:RegisterOptionControls(addonID, optionsTable)	--optionsTable = {sliderData, buttonData, etc}
	addonToOptionsMap[addonID] = optionsTable
end


--INTERNAL FUNCTION
--handles switching between LAM's Addon Settings panel and other panels in the Settings menu
local oldDefaultButton = ZO_OptionsWindowResetToDefaultButton
local oldCallback = oldDefaultButton.callback
local dummyFunc = function() end
local panelWindow = ZO_OptionsWindow
local bgL = ZO_OptionsWindowBGLeft
local bgR = ZO_OptionsWindowBGLeftBGRight
local function HandlePanelSwitching(self, panel)
	if panel == lam.panelID then	--our addon settings panel
		oldDefaultButton:SetCallback(dummyFunc)
		oldDefaultButton:SetHidden(true)
		oldDefaultButton:SetAlpha(0)	--just because it still bugs out
		panelWindow:SetDimensions(999, 960)
		bgL:SetWidth(666)
		bgR:SetWidth(333)
	else
		local shown = LAMAddonPanelsMenu.currentlySelected
		if shown then shown:SetHidden(true) end
		oldDefaultButton:SetCallback(oldCallback)
		oldDefaultButton:SetHidden(false)
		oldDefaultButton:SetAlpha(1)
		panelWindow:SetDimensions(768, 914)
		bgL:SetWidth(512)
		bgR:SetWidth(256)
	end
end


--INTERNAL FUNCTION
--creates LAM's Addon Settings panel
local function CreateAddonSettingsPanel()
	if not LAMSettingsPanelCreated then
		local controlPanelID = "LAM_ADDON_SETTINGS_PANEL"
		--Russian for TERAB1T's RuESO addon, which creates an "ru" locale
		--game font does not support Cyrillic, so they are using custom fonts + extended latin charset
		--Spanish provided by Luisen75 for their translation project
		local controlPanelNames = {
			en = "Addon Settings",
			fr = "Extensions",
			de = "Erweiterungen",
			ru = "Îacòpoéêè äoïoìîeîèé",
			es = "Configura Addons",
		}

		ZO_OptionsWindow_AddUserPanel(controlPanelID, controlPanelNames[GetCVar("Language.2")] or controlPanelNames["en"], PANEL_TYPE_SETTINGS)

		lam.panelID = _G[controlPanelID]

		ZO_PreHook(ZO_KeyboardOptions, "ChangePanels", HandlePanelSwitching)

		LAMSettingsPanelCreated = true
	end
end


--INTERNAL FUNCTION
--adds each registered addon to the menu in LAM's panel
local function CreateAddonButtons(list, addons)
	for i = 1, #addons do
		local button = wm:CreateControlFromVirtual("LAMAddonMenuButton"..i, list.scrollChild, "ZO_DefaultTextButton")
		button.name = addons[i].name
		button.panel = _G[addons[i].panel]
		button:SetText(button.name)
		button:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
		button:SetWidth(190)
		if i == 1 then
			button:SetAnchor(TOPLEFT, list.scrollChild, TOPLEFT, 5, 5)
		else
			button:SetAnchor(TOPLEFT, _G["LAMAddonMenuButton"..i-1], BOTTOMLEFT)
		end
		button:SetHandler("OnClicked", function(self) self.panel:SetHidden(false) end)
	end
end


--INTERNAL FUNCTION
--creates the left-hand menu in LAM's panel
local function CreateAddonList()
	local list
	--check if an earlier loaded copy of LAM created it already
	list = LAMAddonPanelsMenu or wm:CreateControlFromVirtual("LAMAddonPanelsMenu", optionsWindow, "ZO_ScrollContainer")
	list:ClearAnchors()
	list:SetAnchor(TOPLEFT)
	list:SetHeight(675)
	list:SetWidth(200)

	list.bg = list.bg or wm:CreateControl(nil, list, CT_BACKDROP)
	local bg = list.bg
	bg:SetAnchorFill()	--offsets of 8?
	bg:SetEdgeTexture("EsoUI\\Art\\miscellaneous\\borderedinsettransparent_edgefile.dds", 128, 16)
	bg:SetCenterColor(0, 0, 0, 0)

	list.scrollChild = LAMAddonPanelsMenuScrollChild
	list.scrollChild:SetResizeToFitPadding(0, 15)

	local generatedButtons
	list:SetHandler("OnShow", function(self)
		if not generatedButtons and #addonsForList > 0 then
			--we're about to show our list for the first time - let's sort the buttons before creating them
			table.sort(addonsForList, function(a, b)
				return a.name < b.name
			end)
			CreateAddonButtons(list, addonsForList)
			self.currentlySelected = LAMAddonMenuButton1 and LAMAddonMenuButton1.panel
			--since our addon panels don't have a parent, let's make sure they hide when we're done with them
			ZO_PreHookHandler(ZO_OptionsWindow, "OnHide", function() self.currentlySelected:SetHidden(true) end)
			generatedButtons = true
		end
		if self.currentlySelected then self.currentlySelected:SetHidden(false) end
	end)

	--list.controlType = OPTIONS_CUSTOM
	--list.panel = lam.panelID
	list.data = {
		controlType = OPTIONS_CUSTOM,
		panel = lam.panelID,
	}

	ZO_OptionsWindow_InitializeControl(list)

	return list
end

--INITIALIZING
local safeToInitialize = false
local hasInitialized = false

local function OnLoad(_, addonName)
	-- wait for the first loaded event
	em:UnregisterForEvent(eventHandle, EVENT_ADD_ON_LOADED)
	safeToInitialize = true
end
em:RegisterForEvent(eventHandle, EVENT_ADD_ON_LOADED, OnLoad)

local function OnActivated(_, addonName)
	em:UnregisterForEvent(eventHandle, EVENT_PLAYER_ACTIVATED)
	FlushMessages()
end
em:RegisterForEvent(eventHandle, EVENT_PLAYER_ACTIVATED, OnActivated)

function CheckSafetyAndInitialize(addonID)
	if not safeToInitialize then
		local msg = string.format("The panel with id '%s' was registered before addon loading has completed. This might break the AddOn Settings menu.", addonID)
		PrintLater(msg)
	end
	if not hasInitialized then
		CreateAddonSettingsPanel()
		CreateAddonList()
		hasInitialized = true
	end
end
