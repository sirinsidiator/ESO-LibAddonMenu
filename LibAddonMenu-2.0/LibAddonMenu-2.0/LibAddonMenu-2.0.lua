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
local em = EVENT_MANAGER
local sm = SCENE_MANAGER
local cm = CALLBACK_MANAGER
local tconcat = table.concat
local tinsert = table.insert

local addonsForList = {}
local addonToOptionsMap = {}
local optionsCreated = {}
lam.widgets = lam.widgets or {}
local widgets = lam.widgets
lam.util = {}
local util = lam.util

local function GetDefaultValue(default)
	if type(default) == "function" then
		return default()
	end
	return default
end

local function GetStringFromValue(value)
	if type(value) == "function" then
		return value()
	elseif type(value) == "number" then
		return GetString(value)
	end
	return value
end

local function CreateBaseControl(parent, controlData, controlName)
	local control = wm:CreateControl(controlName or controlData.reference, parent.scroll or parent, CT_CONTROL)
	control.panel = parent.panel or parent	-- if this is in a submenu, panel is the submenu's parent
	control.data = controlData

	control.isHalfWidth = controlData.width == "half"
	local width = 510 -- set default width in case a custom parent object is passed
	if control.panel.GetWidth ~= nil then width = control.panel:GetWidth() - 60 end
	control:SetWidth(width)
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
	label:SetText(GetStringFromValue(controlData.name))
	control.label = label

	if control.isHalfWidth then
		control:SetDimensions(width / 2, MIN_HEIGHT * 2 + HALF_WIDTH_LINE_SPACING)
		label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
		label:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
		container:SetAnchor(TOPRIGHT, control.label, BOTTOMRIGHT, 0, HALF_WIDTH_LINE_SPACING)
	else
		control:SetDimensions(width, MIN_HEIGHT)
		container:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
		label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
		label:SetAnchor(TOPRIGHT, container, TOPLEFT, 5, 0)
	end

	control.data.tooltipText = GetStringFromValue(control.data.tooltip)
	control:SetMouseEnabled(true)
	control:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
	control:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
	return control
end

util.GetTooltipText = GetStringFromValue -- deprecated, use util.GetStringFromValue instead
util.GetStringFromValue = GetStringFromValue
util.GetDefaultValue = GetDefaultValue
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
--constructs a string pattern from the text in `searchEdit` control
--	* metacharacters are escaped, losing their special meaning
--	* whitespace matches anything (including empty substring)
--if there is nothing but whitespace, returns nil
--otherwise returns a filter function, which takes a `data` table argument
--	and returns true iff `data.filterText` matches the pattern
local function GetSearchFilterFunc(searchEdit)
	local text = searchEdit:GetText():lower()
	local pattern = text:match("(%S+.-)%s*$")

	if not pattern then -- nothing but whitespace
		return nil
	end

	-- escape metacharacters, e.g. "ESO-Datenbank.de" => "ESO%-Datenbank%.de"
	pattern = pattern:gsub("[-*+?^$().[%]%%]", "%%%0")

	-- replace whitespace with "match shortest anything"
	pattern = pattern:gsub("%s+", ".-")

	return function(data)
		return data.filterText:lower():find(pattern) ~= nil
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

-- INTERNAL METHOD: fires the LAM-PanelOpened callback if not already done
local function OpenCurrentPanel()
	if(lam.currentAddonPanel and not lam.currentPanelOpened) then
		lam.currentPanelOpened = true
		cm:FireCallbacks("LAM-PanelOpened", lam.currentAddonPanel)
	end
end

-- INTERNAL METHOD: fires the LAM-PanelClosed callback if not already done
local function CloseCurrentPanel()
	if(lam.currentAddonPanel and lam.currentPanelOpened) then
		lam.currentPanelOpened = false
		cm:FireCallbacks("LAM-PanelClosed", lam.currentAddonPanel)
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

	local srchEdit = LAMAddonSettingsWindow:GetNamedChild("SearchFilterEdit")
	srchEdit:Clear()

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

	if sm:GetScene("gameMenuInGame"):GetState() == SCENE_SHOWN then
		openAddonSettingsMenu()
	else
		sm:CallWhen("gameMenuInGame", SCENE_SHOWN, openAddonSettingsMenu)
		sm:Show("gameMenuInGame")
	end
end

local TwinOptionsContainer_Index = 0
local function TwinOptionsContainer(parent, leftWidget, rightWidget)
	TwinOptionsContainer_Index = TwinOptionsContainer_Index + 1
	local cParent = parent.scroll or parent
	local panel = parent.panel or cParent
	local container = wm:CreateControl("$(parent)TwinContainer" .. tostring(TwinOptionsContainer_Index),
										cParent, CT_CONTROL)
	container:SetResizeToFitDescendents(true)
	container:SetAnchor(select(2, leftWidget:GetAnchor(0) ))

	leftWidget:ClearAnchors()
	leftWidget:SetAnchor(TOPLEFT, container, TOPLEFT)
	rightWidget:SetAnchor(TOPLEFT, leftWidget, TOPRIGHT, 5, 0)

	leftWidget:SetWidth( leftWidget:GetWidth() - 2.5 ) -- fixes bad alignment with 'full' controls
	rightWidget:SetWidth( rightWidget:GetWidth() - 2.5 )

	leftWidget:SetParent(container)
	rightWidget:SetParent(container)

	container.data = {type = "container"}
	container.panel = panel
	return container
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
					widget.lineControl = anchorTarget
					isHalf = false
					offsetY = 0
					anchorTarget = TwinOptionsContainer(parent, anchorTarget, widget)
				else -- otherwise we just put it below the previous one normally
					widget:SetAnchor(TOPLEFT, anchorTarget, BOTTOMLEFT, 0, 15)
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
				optionsCreated[addonID] = true
				cm:FireCallbacks("LAM-PanelControlsCreated", panel)
				OpenCurrentPanel()
			end
		end

		if SetupCreationCalls(panel, optionsTable) then
			PrintLater(("The settings menu of %s is missing some entries."):format(addonID))
		end
		DoCreateSettings()
	else
		optionsCreated[addonID] = true
		cm:FireCallbacks("LAM-PanelControlsCreated", panel)
		OpenCurrentPanel()
	end
end


--INTERNAL FUNCTION
--handles switching between panels
local function ToggleAddonPanels(panel)	--called in OnShow of newly shown panel
	local currentlySelected = lam.currentAddonPanel
	if currentlySelected and currentlySelected ~= panel then
		currentlySelected:SetHidden(true)
		CloseCurrentPanel()
	end
	lam.currentAddonPanel = panel

	-- refresh visible rows to reflect panel IsHidden status
	ZO_ScrollList_RefreshVisible(lam.addonList)

	if not optionsCreated[panel:GetName()] then	--if this is the first time opening this panel, create these options
		CreateOptionsControls(panel)
	else
		OpenCurrentPanel()
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

	local filterParts = {panelData.name, nil, nil}
	-- append keywords and author separately, the may be nil
	filterParts[#filterParts + 1] = panelData.keywords
	filterParts[#filterParts + 1] = panelData.author

	local addonData = {
		panel = panel,
		name = stripMarkup(panelData.name),
		filterText = stripMarkup(tconcat(filterParts, "\t")):lower(),
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
	--Japanese provided by k0ta0uchi
    local controlPanelNames = {
        en = "Addon Settings",
        fr = "Extensions",
        de = "Erweiterungen",
        ru = "Îacòpoéêè äoïoìîeîèé",
        es = "Configura Addons",
        jp = "アドオン設定",
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
		sm:AddFragment(lam:GetAddonSettingsFragment())
		KEYBOARD_OPTIONS:ChangePanels(lam.panelId)

		local title = LAMAddonSettingsWindow:GetNamedChild("Title")
		title:SetText(panelData.name)

		if not addonListSorted and #addonsForList > 0 then
			local searchEdit = LAMAddonSettingsWindow:GetNamedChild("SearchFilterEdit")
			--we're about to show our list for the first time - let's sort it
			table.sort(addonsForList, function(a, b) return a.name < b.name end)
			PopulateAddonList(lam.addonList, GetSearchFilterFunc(searchEdit))
			addonListSorted = true
		end
	end

	function panelData.unselectedCallback()
		sm:RemoveFragment(lam:GetAddonSettingsFragment())
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
local function CreateSearchFilterBox(name, parent)
	local boxControl = wm:CreateControl(name, parent, CT_CONTROL)

	local srchButton =  wm:CreateControl("$(parent)Button", boxControl, CT_BUTTON)
	srchButton:SetDimensions(32, 32)
	srchButton:SetAnchor(LEFT, nil, LEFT, 2, 0)
	srchButton:SetNormalTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_up.dds")
	srchButton:SetPressedTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_down.dds")
	srchButton:SetMouseOverTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_over.dds")

	local srchEdit = wm:CreateControlFromVirtual("$(parent)Edit", boxControl, "ZO_DefaultEdit")
	srchEdit:SetAnchor(LEFT, srchButton, RIGHT, 4, 1)
	srchEdit:SetAnchor(RIGHT, nil, RIGHT, -4, 1)
	srchEdit:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())

	local srchBg = wm:CreateControl("$(parent)Bg", boxControl, CT_BACKDROP)
	srchBg:SetAnchorFill()
	srchBg:SetAlpha(0)
	srchBg:SetCenterColor(0, 0, 0, 0.5)
	srchBg:SetEdgeColor(ZO_DISABLED_TEXT:UnpackRGBA())
	srchBg:SetEdgeTexture("", 1, 1, 0, 0)

	-- search backdrop should appear whenever you hover over either
	-- the magnifying glass button or the edit field (which is only
	-- visible when it contains some text), and also while the edit
	-- field has keyboard focus

	local srchActive = false
	local srchHover = false

	local function srchBgUpdateAlpha()
		if srchActive or srchEdit:HasFocus() then
			srchBg:SetAlpha(srchHover and 0.8 or 0.6)
		else
			srchBg:SetAlpha(srchHover and 0.6 or 0.0)
		end
	end

	local function srchMouseEnter(control)
		srchHover = true
		srchBgUpdateAlpha()
	end

	local function srchMouseExit(control)
		srchHover = false
		srchBgUpdateAlpha()
	end

	boxControl:SetMouseEnabled(true)
	boxControl:SetHitInsets(1, 1, -1, -1)
	boxControl:SetHandler("OnMouseEnter", srchMouseEnter)
	boxControl:SetHandler("OnMouseExit", srchMouseExit)

	srchButton:SetHandler("OnMouseEnter", srchMouseEnter)
	srchButton:SetHandler("OnMouseExit", srchMouseExit)

	local focusLostTime = 0

	srchButton:SetHandler("OnClicked", function(self)
		srchEdit:Clear()
		if GetFrameTimeMilliseconds() - focusLostTime < 100 then
			-- re-focus the edit box if it lost focus due to this
			-- button click (note that this handler may run a few
			-- frames later)
			srchEdit:TakeFocus()
		end
	end)

	srchEdit:SetHandler("OnMouseEnter", srchMouseEnter)
	srchEdit:SetHandler("OnMouseExit", srchMouseExit)
	srchEdit:SetHandler("OnFocusGained", srchBgUpdateAlpha)

	srchEdit:SetHandler("OnFocusLost", function()
		focusLostTime = GetFrameTimeMilliseconds()
		srchBgUpdateAlpha()
	end)

	srchEdit:SetHandler("OnEscape", function(self)
		self:Clear()
		self:LoseFocus()
	end)

	srchEdit:SetHandler("OnTextChanged", function(self)
		local filterFunc = GetSearchFilterFunc(self)
		if filterFunc then
			srchActive = true
			srchBg:SetEdgeColor(ZO_SECOND_CONTRAST_TEXT:UnpackRGBA())
			srchButton:SetState(BSTATE_PRESSED)
		else
			srchActive = false
			srchBg:SetEdgeColor(ZO_DISABLED_TEXT:UnpackRGBA())
			srchButton:SetState(BSTATE_NORMAL)
		end
		srchBgUpdateAlpha()
		PopulateAddonList(lam.addonList, filterFunc)
		PlaySound(SOUNDS.SPINNER_DOWN)
	end)

	return boxControl
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

	-- create search filter box

	local srchBox = CreateSearchFilterBox("$(parent)SearchFilter", tlw)
	srchBox:SetAnchor(TOPLEFT, nil, TOPLEFT, 63, 120)
	srchBox:SetDimensions(260, 30)

	-- create scrollable addon list

	local addonList = CreateAddonList("$(parent)AddonList", tlw)
	addonList:SetAnchor(TOPLEFT, nil, TOPLEFT, 65, 160)
	addonList:SetDimensions(285, 665)

	lam.addonList = addonList -- for easy access from elsewhere

	-- create container for option panels

	local panelContainer = wm:CreateControl("$(parent)PanelContainer", tlw, CT_CONTROL)
	panelContainer:SetAnchor(TOPLEFT, nil, TOPLEFT, 365, 120)
	panelContainer:SetDimensions(645, 675)

	return tlw
end


--INITIALIZING
local safeToInitialize = false
local hasInitialized = false

local eventHandle = table.concat({MAJOR, MINOR}, "r")
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
		LAMAddonSettingsFragment = ZO_FadeSceneFragment:New(window, true, 100)
		LAMAddonSettingsFragment:RegisterCallback("StateChange", function(oldState, newState)
			if(newState == SCENE_FRAGMENT_SHOWN) then
				OpenCurrentPanel()
			elseif(newState == SCENE_FRAGMENT_HIDDEN) then
				CloseCurrentPanel()
			end
		end)
		CreateAddonSettingsMenuEntry()
	end
	return LAMAddonSettingsFragment
end


-- vi: noexpandtab
