--	LibAddonMenu-2.0 & its files © Ryan Lakanen (Seerah)		--
--	Distributed under The Artistic License 2.0 (see LICENSE)	--
------------------------------------------------------------------


--Register LAM with LibStub
local MAJOR, MINOR = "LibAddonMenu-2.0", 17
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
		local isHalf, widget
		local lastAddedControl, lacAtHalfRow, oIndex, widgetData, widgetType
		local submenu, subWidgetData, sIndex, subWidgetType, subWidget
        local anchorOffset = 0
        local anchorOffsetSub
        local lastAddedControlSub, lacAtHalfRowSub
		for oIndex=1,#optionsTable do
			widgetData = optionsTable[oIndex]
			widgetType = widgetData.type
			if widgetType == "submenu" then
				submenu = LAMCreateControl[widgetType](panel, widgetData)
                if lastAddedControl then
                    submenu:SetAnchor(TOPLEFT, lastAddedControl, BOTTOMLEFT, 0, 15 + anchorOffset)
                else
                    submenu:SetAnchor(TOPLEFT)
                end
                lastAddedControl = submenu
                lacAtHalfRow = false

                anchorOffsetSub = 0
                lacAtHalfRowSub = nil
                lastAddedControlSub = nil
				for sIndex=1,#widgetData.controls do
					subWidgetData = widgetData.controls[sIndex]
					subWidgetType = subWidgetData.type
					subWidget = LAMCreateControl[subWidgetType](submenu, subWidgetData)
					isHalf = subWidgetData.width == "half"
                    if lastAddedControlSub then
                        if lacAtHalfRowSub and isHalf then
                            subWidget:SetAnchor(TOPLEFT, lastAddedControlSub, TOPRIGHT, 5, 0)
                            lacAtHalfRowSub = false
                            anchorOffsetSub = zo_max(0, subWidget:GetHeight() - lastAddedControlSub:GetHeight())
                        else
                            subWidget:SetAnchor(TOPLEFT, lastAddedControlSub, BOTTOMLEFT, 0, 15 + anchorOffsetSub)
                            lacAtHalfRowSub = isHalf
                            anchorOffsetSub = 0
                            lastAddedControlSub = subWidget
                        end
                    else
                        subWidget:SetAnchor(TOPLEFT)
                        lacAtHalfRowSub = isHalf
                        lastAddedControlSub = subWidget
                    end
                end
            else
                widget = LAMCreateControl[widgetType](panel, widgetData)
                isHalf = widgetData.width == "half"
                if lastAddedControl then
                    if lacAtHalfRow and isHalf then
                        widget:SetAnchor(TOPLEFT, lastAddedControl, TOPRIGHT, 10, 0)
                        anchorOffset = zo_max(0, widget:GetHeight() - lastAddedControl:GetHeight())
                        lacAtHalfRow = false
                    else
                        widget:SetAnchor(TOPLEFT, lastAddedControl, BOTTOMLEFT, 0, 15 + anchorOffset)
                        lacAtHalfRow = isHalf
                        anchorOffset = 0
                        lastAddedControl = widget
                    end
                else
                    widget:SetAnchor(TOPLEFT)
                    lacAtHalfRow = isHalf
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
local function HandlePanelSwitching(self, panel)
	if panel == lam.panelID then	--our addon settings panel
		oldDefaultButton:SetCallback(dummyFunc)
		oldDefaultButton:SetHidden(true)
		oldDefaultButton:SetAlpha(0)	--just because it still bugs out
        local width = 1082
        local padding = 24
		panelWindow:SetDimensions(width, 960)
		bgL:SetWidth(width - 256 + padding)
		bgR:SetWidth(256)
		bgL:ClearAnchors()
		bgL:SetAnchor(TOPLEFT, ZO_OptionsWindow, TOPLEFT, -padding, 0)
	else
		local shown = LAMAddonPanelsMenu.currentlySelected
		if shown then shown:SetHidden(true) end
		oldDefaultButton:SetCallback(oldCallback)
		oldDefaultButton:SetHidden(false)
		oldDefaultButton:SetAlpha(1)
		panelWindow:SetDimensions(768, 914)
		bgL:ClearAnchors()
		bgL:SetWidth(512)
		bgL:SetAnchor(TOPLEFT)
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
--creates the left-hand menu in LAM's panel
local function CreateAddonList()
	--INTERNAL FUNCTION
	--adds each registered addon to the menu in LAM's panel
	local function CreateAddonButtons(list, addons)
		local buttons = {}
		local function SelectAddonClick(self)
			self.panel:SetHidden(false)
			local t, control
			for t = 1, #buttons do
				control = buttons[t]
				control:SetState(control == self and BSTATE_PRESSED or BSTATE_NORMAL, false)
			end
		end

		local i, lastButton, button
		for i = 1, #addons do
			button = wm:CreateControlFromVirtual("LAMAddonMenuButton"..i, list.scrollChild, "ZO_MenuDropDownTextButton")
			button.name = addons[i].name
			button.panel = _G[addons[i].panel]
			button:SetText(button.name)
			button:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
			button:SetWidth(240)
			button:SetHeight(28)
			if i == 1 then
				button:SetAnchor(TOPLEFT, list.scrollChild, TOPLEFT, 20, 5)
				button:SetState(BSTATE_PRESSED, false)
			else
    			button:SetAnchor(TOPLEFT, lastButton, BOTTOMLEFT, 0, 0)
			end
			button:SetHandler("OnClicked", SelectAddonClick)
			buttons[#buttons+1] = button
			lastButton = button
		end
	end

	local list
	--check if an earlier loaded copy of LAM created it already
	list = LAMAddonPanelsMenu or wm:CreateControlFromVirtual("LAMAddonPanelsMenu", optionsWindow, "ZO_ScrollContainer")
	list:ClearAnchors()
	list:SetAnchor(TOPLEFT)
	list:SetHeight(675)
	list:SetWidth(260)

	local bg = list.bg
	if bg then
		bg:SetAnchorFill()	--offsets of 8?
		bg:SetCenterColor(0, 0, 0, 0)
		bg:SetEdgeColor(0, 0, 0, 0)
		bg:SetInsets(0, 0, 0, 0)
	end

	local underlayLeft = wm:CreateControl(nil, list, CT_TEXTURE)
	underlayLeft:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_indexArea_left.dds")
	underlayLeft:SetDimensions(208, 1024)
	underlayLeft:SetAnchor(TOPLEFT, list, TOPLEFT, -44, -156)
	underlayLeft:SetExcludeFromResizeToFitExtents(true)

	local underlayRight = wm:CreateControl(nil, list, CT_TEXTURE)
	underlayRight:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_indexArea_right.dds")
	underlayRight:SetDimensions(128, 1024)
	underlayRight:SetAnchor(TOPLEFT, underlayLeft, TOPRIGHT)
	underlayRight:SetExcludeFromResizeToFitExtents(true)

	list.scrollChild = LAMAddonPanelsMenuScrollChild
	list.scrollChild:SetResizeToFitPadding(0, 15)
	
	local generatedButtons
	list:SetHandler("OnShow", function(self)
			if not generatedButtons and #addonsForList > 0 then
				--we're about to show our list for the first time - let's sort the buttons before creating them
				local i
				for i=1,#addonsForList do
					addonsForList[i].sortName = addonsForList[i].name:gsub("|[Cc][%x][%x][%x][%x][%x][%x]", ""):gsub("|[Rr]", "")
				end
				table.sort(addonsForList, function(a, b)	return a.sortName < b.sortName	end)

				CreateAddonButtons(list, addonsForList)
				self.currentlySelected = LAMAddonMenuButton1 and LAMAddonMenuButton1.panel
				--since our addon panels don't have a parent, let's make sure they hide when we're done with them
				ZO_PreHookHandler(ZO_OptionsWindow, "OnHide", function() self.currentlySelected:SetHidden(true) end)
				generatedButtons = true
			end
			if self.currentlySelected then self.currentlySelected:SetHidden(false) end
		end)
	
	list.data = {
		controlType = OPTIONS_CUSTOM,
		panel = lam.panelID,
	}
	
	ZO_OptionsWindow_InitializeControl(list)
end


--INITIALIZING
CreateAddonSettingsPanel()
CreateAddonList()

