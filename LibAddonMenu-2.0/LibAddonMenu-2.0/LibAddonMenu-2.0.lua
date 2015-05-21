--	LibAddonMenu-2.0 & its files © Ryan Lakanen (Seerah)		--
--	Distributed under The Artistic License 2.0 (see LICENSE)	--
------------------------------------------------------------------


--Register LAM with LibStub
local MAJOR, MINOR = "LibAddonMenu-2.0", 999 -- only for test purposes. releases will get a smaller number
local lam, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lam then return end	--the same or newer version of this lib is already loaded into memory

local messages = {}
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

--UPVALUES--
local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER
local tinsert = table.insert

local addonsForList = {}
local addonToOptionsMap = {}
local optionsCreated = {}
lam.widgets = lam.widgets or {}
local widgets = lam.widgets
lam.util = {}
local util = lam.util

local function CreateBaseControl(parent, controlData, controlName)
	local control = wm:CreateControl(controlName or controlData.reference, parent.scroll or parent, CT_CONTROL)
	control.panel = parent.panel or parent	-- if this is in a submenu, panel is the submenu's parent
	control.data = controlData

	control.isHalfWidth = controlData.width == "half"
	control:SetWidth(control.panel:GetWidth() - 60)
	return control
end

local MIN_HEIGHT = 26
local HALF_WIDTH_LINE_SPACING = 2
local function CreateLabelAndContainerControl(parent, controlData, controlName)
	local control = CreateBaseControl(parent, controlData, controlName)
	local width = control:GetWidth()

	local container = wm:CreateControl(nil, control, CT_CONTROL)
	container:SetDimensions(width / 3, MIN_HEIGHT)
	control.container = container

	local label = wm:CreateControl(nil, control, CT_LABEL)
	label:SetFont("ZoFontWinH4")
	label:SetHeight(MIN_HEIGHT)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	label:SetText(controlData.name)
	control.label = label

	if control.isHalfWidth then
		control:SetDimensions(width / 2, MIN_HEIGHT * 2 + HALF_WIDTH_LINE_SPACING)
		label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
		label:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
		container:SetAnchor(TOPRIGHT, control.label, BOTTOMRIGHT, 0, HALF_WIDTH_LINE_SPACING)
	else
		control:SetDimensions(width, MIN_HEIGHT)
		container:SetAnchor(RIGHT, control, RIGHT, 0, 0)
		label:SetAnchor(LEFT, control, LEFT, 0, 0)
		label:SetAnchor(RIGHT, container, LEFT, 5, 0)
	end

	control.data.tooltipText = control.data.tooltip
	control:SetMouseEnabled(true)
	control:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
	control:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
	return control
end

util.CreateBaseControl = CreateBaseControl
util.CreateLabelAndContainerControl = CreateLabelAndContainerControl

local ADDON_DATA_TYPE = 1
local RESELECTING_DURING_REBUILD = true
local USER_REQUESTED_OPEN = true


--INTERNAL FUNCTION
--scrolls ZO_ScrollList `list` to move the row corresponding to `data`
--	into view (does nothing if there is no such row in the list)
--unlike ZO_ScrollList_ScrollDataIntoView, this function accounts for
--	fading near the list's edges - it avoids the fading area by scrolling
--	a little further than the ZO function
local function ScrollDataIntoView(list, data)
	local targetIndex = data.sortIndex
	if not targetIndex then return end

	local scrollMin, scrollMax = list.scrollbar:GetMinMax()
	local scrollTop = list.scrollbar:GetValue()
	local controlHeight = list.controlHeight
	local targetMin = controlHeight * (targetIndex - 1) - 64
	-- subtracting 64 ain't arbitrary, it's the maximum fading height
	-- (libraries/zo_templates/scrolltemplates.lua/UpdateScrollFade)

	if targetMin < scrollTop then
		ZO_ScrollList_ScrollAbsolute(list, zo_max(targetMin, scrollMin))
	else
		local listHeight = ZO_ScrollList_GetHeight(list)
		local targetMax = controlHeight * targetIndex + 64 - listHeight

		if targetMax > scrollTop then
			ZO_ScrollList_ScrollAbsolute(list, zo_min(targetMax, scrollMax))
		end
	end
end


--INTERNAL FUNCTION
--populates `addonList` with entries from `addonsForList`
--	addonList = ZO_ScrollList control
--	filter = [optional] function(data)
local function PopulateAddonList(addonList, filter)
	local entryList = ZO_ScrollList_GetDataList(addonList)
	local numEntries = 0
	local selectedData = nil

	ZO_ScrollList_Clear(addonList)

	for i, data in ipairs(addonsForList) do
		if not filter or filter(data) then
			local dataEntry = ZO_ScrollList_CreateDataEntry(ADDON_DATA_TYPE, data)
			numEntries = numEntries + 1
			data.sortIndex = numEntries
			entryList[numEntries] = dataEntry
			-- select the first panel passing the filter, or the currently
			-- shown panel, but only if it passes the filter as well
			if selectedData == nil or data.panel == lam.currentAddonPanel then
				selectedData = data
			end
		else
			data.sortIndex = nil
		end
	end

	ZO_ScrollList_Commit(addonList)

	if selectedData then
		if selectedData.panel == lam.currentAddonPanel then
			ZO_ScrollList_SelectData(addonList, selectedData, nil, RESELECTING_DURING_REBUILD)
		else
			ZO_ScrollList_SelectData(addonList, selectedData, nil)
		end
		ScrollDataIntoView(addonList, selectedData)
	end
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
--	panel = userdata; the panel returned by the :RegisterOptionsPanel method
local locSettings = GetString(SI_GAME_MENU_SETTINGS)
function lam:OpenToPanel(panel)

	-- find and select the panel's row in addon list

	local addonList = lam.addonList
	local selectedData = nil

	for _, addonData in ipairs(addonsForList) do
		if addonData.panel == panel then
			selectedData = addonData
			ScrollDataIntoView(addonList, selectedData)
			break
		end
	end

	ZO_ScrollList_SelectData(addonList, selectedData)
	ZO_ScrollList_RefreshVisible(addonList, selectedData)

	-- note that ZO_ScrollList doesn't require `selectedData` to be actually
	-- present in the list, and that the list will only be populated once LAM
	-- "Addon Settings" menu entry is selected for the first time

	local function openAddonSettingsMenu()
		local gameMenu = ZO_GameMenu_InGame.gameMenu
		local settingsMenu = gameMenu.headerControls[locSettings]

		if settingsMenu then -- an instance of ZO_TreeNode
			local children = settingsMenu:GetChildren()
			for i = 1, (children and #children or 0) do
				local childNode = children[i]
				local data = childNode:GetData()
				if data and data.id == lam.panelId then
					-- found LAM "Addon Settings" node, yay!
					childNode:GetTree():SelectNode(childNode)
					break
				end
			end
		end
	end

	if SCENE_MANAGER:GetScene("gameMenuInGame"):GetState() == SCENE_SHOWN then
		openAddonSettingsMenu()
	else
		SCENE_MANAGER:CallWhen("gameMenuInGame", SCENE_SHOWN, openAddonSettingsMenu)
		SCENE_MANAGER:Show("gameMenuInGame")
	end
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
		local anchorOffsetSub, lastAddedControlSub, lacAtHalfRowSub
		local anchorOffset = 0
		local missingEntries = (#optionsTable ~= NonContiguousCount(optionsTable))
		for oIndex=1,#optionsTable do
			widgetData = optionsTable[oIndex]
			if not widgetData then
				missingEntries = true
			else
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
					if #widgetData.controls ~= NonContiguousCount(widgetData.controls) then missingEntries = true end
					for sIndex=1,#widgetData.controls do
						subWidgetData = widgetData.controls[sIndex]
						if not subWidgetData then
							missingEntries = true
						else
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
		if missingEntries then
			PrintLater("Missing one or more entries in the settings menu of " .. addonID .. ". Check your options table for missing indices.")
		end
	end

	optionsCreated[addonID] = true
	cm:FireCallbacks("LAM-PanelControlsCreated", panel)
end


--INTERNAL FUNCTION
--handles switching between panels
local function ToggleAddonPanels(panel)	--called in OnShow of newly shown panel
	local currentlySelected = lam.currentAddonPanel
	if currentlySelected and currentlySelected ~= panel then
		currentlySelected:SetHidden(true)
	end
	lam.currentAddonPanel = panel

	-- refresh visible rows to reflect panel IsHidden status
	ZO_ScrollList_RefreshVisible(lam.addonList)

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
	local container = lam:GetAddonPanelContainer()
	local panel = lamcc.panel(container, panelData, addonID)	--addonID==global name of panel
	panel:SetHidden(true)
	panel:SetAnchorFill(container)
	panel:SetHandler("OnShow", ToggleAddonPanels)

	local function stripMarkup(str)
		return str:gsub("|[Cc]%x%x%x%x%x%x", ""):gsub("|[Rr]", "")
	end

	local addonData = {
		panel = panel,
		name = stripMarkup(panelData.name),
	}

	tinsert(addonsForList, addonData)

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
--creates LAM's Addon Settings entry in ZO_GameMenu
local function CreateAddonSettingsMenuEntry()
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

	local panelData = {
		id = KEYBOARD_OPTIONS.currentPanelId,
		name = controlPanelNames[GetCVar("Language.2")] or controlPanelNames["en"],
	}

	KEYBOARD_OPTIONS.currentPanelId = panelData.id + 1
	KEYBOARD_OPTIONS.panelNames[panelData.id] = panelData.name

	lam.panelId = panelData.id

	local addonListSorted = false

	function panelData.callback()
		SCENE_MANAGER:AddFragment(lam:GetAddonSettingsFragment())
		KEYBOARD_OPTIONS:ChangePanels(lam.panelId)

		local title = LAMAddonSettingsWindow:GetNamedChild("Title")
		title:SetText(panelData.name)

		if not addonListSorted and #addonsForList > 0 then
			--we're about to show our list for the first time - let's sort it
			table.sort(addonsForList, function(a, b) return a.name < b.name end)
			PopulateAddonList(lam.addonList, nil)
			addonListSorted = true
		end
	end

	function panelData.unselectedCallback()
		SCENE_MANAGER:RemoveFragment(lam:GetAddonSettingsFragment())
		if SetCameraOptionsPreviewModeEnabled then -- available since API version 100011
			SetCameraOptionsPreviewModeEnabled(false)
		end
	end

	ZO_GameMenu_AddSettingPanel(panelData)
end


--INTERNAL FUNCTION
--creates the left-hand menu in LAM's window
local function CreateAddonList(name, parent)
	local addonList = wm:CreateControlFromVirtual(name, parent, "ZO_ScrollList")

	local function addonListRow_OnMouseDown(control, button)
		if button == 1 then
			local data = ZO_ScrollList_GetData(control)
			ZO_ScrollList_SelectData(addonList, data, control)
		end
	end

	local function addonListRow_OnMouseEnter(control)
		ZO_ScrollList_MouseEnter(addonList, control)
	end

	local function addonListRow_OnMouseExit(control)
		ZO_ScrollList_MouseExit(addonList, control)
	end

	local function addonListRow_Select(previouslySelectedData, selectedData, reselectingDuringRebuild)
		if not reselectingDuringRebuild then
			if previouslySelectedData then
				previouslySelectedData.panel:SetHidden(true)
			end
			if selectedData then
				selectedData.panel:SetHidden(false)
				PlaySound(SOUNDS.MENU_SUBCATEGORY_SELECTION)
			end
		end
	end

	local function addonListRow_Setup(control, data)
		control:SetText(data.name)
		control:SetSelected(not data.panel:IsHidden())
	end

	ZO_ScrollList_AddDataType(addonList, ADDON_DATA_TYPE, "ZO_SelectableLabel", 28, addonListRow_Setup)
	-- I don't know how to make highlights clear properly; they often
	-- get stuck and after a while the list is full of highlighted rows
	--ZO_ScrollList_EnableHighlight(addonList, "ZO_ThinListHighlight")
	ZO_ScrollList_EnableSelection(addonList, "ZO_ThinListHighlight", addonListRow_Select)

	local addonDataType = ZO_ScrollList_GetDataTypeTable(addonList, ADDON_DATA_TYPE)
	local addonListRow_CreateRaw = addonDataType.pool.m_Factory

	local function addonListRow_Create(pool)
		local control = addonListRow_CreateRaw(pool)
		control:SetHandler("OnMouseDown", addonListRow_OnMouseDown)
		--control:SetHandler("OnMouseEnter", addonListRow_OnMouseEnter)
		--control:SetHandler("OnMouseExit", addonListRow_OnMouseExit)
		control:SetHeight(28)
		control:SetFont("ZoFontHeader")
		control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
		control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
		return control
	end

	addonDataType.pool.m_Factory = addonListRow_Create

	return addonList
end


--INTERNAL FUNCTION
--creates LAM's Addon Settings top-level window
local function CreateAddonSettingsWindow()
	local tlw = wm:CreateTopLevelWindow("LAMAddonSettingsWindow")
	tlw:SetHidden(true)
	tlw:SetDimensions(1010, 914) -- same height as ZO_OptionsWindow

	ZO_ReanchorControlForLeftSidePanel(tlw)

	-- create black background for the window (mimic ZO_RightFootPrintBackground)

	local bgLeft = wm:CreateControl("$(parent)BackgroundLeft", tlw, CT_TEXTURE)
	bgLeft:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds")
	bgLeft:SetDimensions(1024, 1024)
	bgLeft:SetAnchor(TOPLEFT, nil, TOPLEFT)
	bgLeft:SetDrawLayer(DL_BACKGROUND)
	bgLeft:SetExcludeFromResizeToFitExtents(true)

	local bgRight = wm:CreateControl("$(parent)BackgroundRight", tlw, CT_TEXTURE)
	bgRight:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_right.dds")
	bgRight:SetDimensions(64, 1024)
	bgRight:SetAnchor(TOPLEFT, bgLeft, TOPRIGHT)
	bgRight:SetDrawLayer(DL_BACKGROUND)
	bgRight:SetExcludeFromResizeToFitExtents(true)

	-- create gray background for addon list (mimic ZO_TreeUnderlay)

	local underlayLeft = wm:CreateControl("$(parent)UnderlayLeft", tlw, CT_TEXTURE)
	underlayLeft:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_indexArea_left.dds")
	underlayLeft:SetDimensions(256, 1024)
	underlayLeft:SetAnchor(TOPLEFT, bgLeft, TOPLEFT)
	underlayLeft:SetDrawLayer(DL_BACKGROUND)
	underlayLeft:SetExcludeFromResizeToFitExtents(true)

	local underlayRight = wm:CreateControl("$(parent)UnderlayRight", tlw, CT_TEXTURE)
	underlayRight:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_indexArea_right.dds")
	underlayRight:SetDimensions(128, 1024)
	underlayRight:SetAnchor(TOPLEFT, underlayLeft, TOPRIGHT)
	underlayRight:SetDrawLayer(DL_BACKGROUND)
	underlayRight:SetExcludeFromResizeToFitExtents(true)

	-- create title bar (mimic ZO_OptionsWindow)

	local title = wm:CreateControl("$(parent)Title", tlw, CT_LABEL)
	title:SetAnchor(TOPLEFT, nil, TOPLEFT, 65, 70)
	title:SetFont("ZoFontWinH1")
	title:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)

	local divider = wm:CreateControlFromVirtual("$(parent)Divider", tlw, "ZO_Options_Divider")
	divider:SetAnchor(TOPLEFT, nil, TOPLEFT, 65, 108)

	-- create scrollable addon list

	local addonList = CreateAddonList("$(parent)AddonList", tlw)
	addonList:SetAnchor(TOPLEFT, nil, TOPLEFT, 65, 120)
	addonList:SetDimensions(285, 675)

	lam.addonList = addonList -- for easy access from elsewhere

	-- create container for option panels

	local panelContainer = wm:CreateControl("$(parent)PanelContainer", tlw, CT_CONTROL)
	panelContainer:SetAnchor(TOPLEFT, addonList, TOPRIGHT, 15, 0)
	panelContainer:SetDimensions(645, 675)

	return tlw
end


--INITIALIZING
local safeToInitialize = false
local hasInitialized = false

local eventHandle = table.concat({MAJOR, MINOR}, "r")
local function OnLoad(_, addonName)
	-- wait for the first loaded event
	EVENT_MANAGER:UnregisterForEvent(eventHandle, EVENT_ADD_ON_LOADED)
	safeToInitialize = true
end
EVENT_MANAGER:RegisterForEvent(eventHandle, EVENT_ADD_ON_LOADED, OnLoad)

local function OnActivated(_, addonName)
	EVENT_MANAGER:UnregisterForEvent(eventHandle, EVENT_PLAYER_ACTIVATED)
	FlushMessages()
end
EVENT_MANAGER:RegisterForEvent(eventHandle, EVENT_PLAYER_ACTIVATED, OnActivated)

function CheckSafetyAndInitialize(addonID)
	if not safeToInitialize then
		local msg = string.format("The panel with id '%s' was registered before addon loading has completed. This might break the AddOn Settings menu.", addonID)
		PrintLater(msg)
	end
	if not hasInitialized then
		hasInitialized = true
	end
end


--TODO documentation
function lam:GetAddonPanelContainer()
	local fragment = lam:GetAddonSettingsFragment()
	local window = fragment:GetControl()
	return window:GetNamedChild("PanelContainer")
end


--TODO documentation
function lam:GetAddonSettingsFragment()
	assert(hasInitialized or safeToInitialize)
	if not LAMAddonSettingsFragment then
		local window = CreateAddonSettingsWindow()
		LAMAddonSettingsFragment = ZO_FadeSceneFragment:New(window)
		CreateAddonSettingsMenuEntry()
	end
	return LAMAddonSettingsFragment
end


-- vi: noexpandtab
