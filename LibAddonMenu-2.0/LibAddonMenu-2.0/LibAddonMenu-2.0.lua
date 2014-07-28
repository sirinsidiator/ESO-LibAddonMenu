--	LibAddonMenu-2.0 & its files © Ryan Lakanen (Seerah)	--
--	All Rights Reserved										--
--	Permission is granted to use Seerah's LibAddonMenu-2.0	--
--	in your project. Any modifications to LibAddonMenu-2.0	--
--	may not be redistributed.								--
--------------------------------------------------------------


--Register LAM with LibStub
local MAJOR, MINOR = "LibAddonMenu-2.0", 14
local lam, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lam then return end	--the same or newer version of this lib is already loaded into memory 


--UPVALUES--
local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER
local tinsert = table.insert
local optionsWindow = ZO_OptionsWindowSettingsScrollChild
local _

local addonsForList = {}
local addonToOptionsMap = {}
local optionsCreated = {}
lam.widgets = lam.widgets or {}
local widgets = lam.widgets


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
--	panel = userdata; the panel returned by the :RegisterOptionsPanel method
--local settings = {en = "Settings", de = "Einstellungen", fr = "Réglages"}
--local locSettings = settings[GetCVar("Language.2")]
local locSettings = GetString(SI_GAME_MENU_SETTINGS)
function lam:OpenToPanel(panel)
	SCENE_MANAGER:Show("gameMenuInGame")
	zo_callLater(function()
			ZO_GameMenu_InGame.gameMenu.headerControls[locSettings]:SetOpen(true)
			SCENE_MANAGER:AddFragment(OPTIONS_WINDOW_FRAGMENT)
			ZO_OptionsWindow_ChangePanels(lam.panelID)
			if not lam.panelSubCategoryControl then
				lam.panelSubCategoryControl = _G["ZO_GameMenu_InGameNavigationContainerScrollChildZO_GameMenu_SubCategory"..(lam.panelID + 1)]
			end
			ZO_TreeEntry_OnMouseUp(lam.panelSubCategoryControl, true)
			panel:SetHidden(false)
		end, 200)
end


--INTERNAL FUNCTION
--creates controls when options panel is first shown
--controls anchoring of these controls in the panel
local function CreateOptionsControls(panel)
	local addonID = panel:GetName()
	local optionsTable = addonToOptionsMap[addonID]
	
	if optionsTable then
		local lastAddedControl, lacAtHalfRow
		for _, widgetData in ipairs(optionsTable) do
			local widgetType = widgetData.type
			if widgetType == "submenu" then
				local submenu = LAMCreateControl[widgetType](panel, widgetData)
				if lastAddedControl then
					submenu:SetAnchor(TOPLEFT, lastAddedControl, BOTTOMLEFT, 0, 15)
				else
					submenu:SetAnchor(TOPLEFT)
				end
				lastAddedControl = submenu
				lacAtHalfRow = false
				
				local lastAddedControlSub, lacAtHalfRowSub
				for _, subWidgetData in ipairs(widgetData.controls) do
					local subWidgetType = subWidgetData.type
					local subWidget = LAMCreateControl[subWidgetType](submenu, subWidgetData)
					local isHalf = subWidgetData.width == "half"
					if lastAddedControlSub then
						if lacAtHalfRowSub and isHalf then
							subWidget:SetAnchor(TOPLEFT, lastAddedControlSub, TOPRIGHT, 5, 0)
							lacAtHalfRowSub = false
						else
							subWidget:SetAnchor(TOPLEFT, lastAddedControlSub, BOTTOMLEFT, 0, 15)
							lacAtHalfRowSub = isHalf and true or false
							lastAddedControlSub = subWidget
						end
					else
						subWidget:SetAnchor(TOPLEFT)
						lacAtHalfRowSub = isHalf and true or false
						lastAddedControlSub = subWidget
					end
				end
			else
				local widget = LAMCreateControl[widgetType](panel, widgetData)
				local isHalf = widgetData.width == "half"
				if lastAddedControl then
					if lacAtHalfRow and isHalf then
						widget:SetAnchor(TOPLEFT, lastAddedControl, TOPRIGHT, 10, 0)
						lacAtHalfRow = false
					else
						widget:SetAnchor(TOPLEFT, lastAddedControl, BOTTOMLEFT, 0, 15)
						lacAtHalfRow = isHalf and true or false
						lastAddedControl = widget
					end
				else
					widget:SetAnchor(TOPLEFT)
					lacAtHalfRow = isHalf and true or false
					lastAddedControl = widget
				end
			end
		end	
	end
	
	optionsCreated[addonID] = true
	cm:FireCallbacks("LAM-PanelControlsCreated", panel)
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


--METHOD: REGISTER ADDON PANEL
--registers your addon with LibAddonMenu and creates a panel
--Usage:
--	addonID = "string"; unique ID which will be the global name of your panel
--	panelData = table; data object for your panel - see controls\panel.lua
function lam:RegisterAddonPanel(addonID, panelData)
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
local function HandlePanelSwitching(panel)
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
		local controlPanelNames = {en = "Addon Settings", fr = "Extensions", de = "Erweiterungen", ru = "Îacòpoéêè äoïoìîeîèé"}

		ZO_OptionsWindow_AddUserPanel(controlPanelID, controlPanelNames[GetCVar("Language.2")] or controlPanelName["en"])

		lam.panelID = _G[controlPanelID]
		
		ZO_PreHook("ZO_OptionsWindow_ChangePanels", HandlePanelSwitching)
		
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
	
	list.controlType = OPTIONS_CUSTOM
	list.panel = lam.panelID
	
	ZO_OptionsWindow_InitializeControl(list)

	return list
end


--INITIALIZING
CreateAddonSettingsPanel()
CreateAddonList()

