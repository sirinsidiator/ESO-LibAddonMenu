--[[dropdownData = {
    type = "dropdown",
    name = "My Dropdown", -- or string id or function returning a string
    choices = {"table", "of", "choices"},
    choicesValues = {"foo", 2, "three"}, -- if specified, these values will get passed to setFunc instead (optional)
    getFunc = function() return db.var end, -- if multiSelect is true the getFunc must return a table. See multiSelectType for table key and values
    setFunc = function(var) db.var = var doStuff() end, -- if multiSelect is true the setFunc's var must be a table. See multiSelectType for table key and values
    tooltip = "Dropdown's tooltip text.", -- or string id or function returning a string (optional)
    choicesTooltips = {"tooltip 1", "tooltip 2", "tooltip 3"}, -- or array of string ids or array of functions returning a string (optional)
    sort = "name-up", -- or "name-down", "numeric-up", "numeric-down", "value-up", "value-down", "numericvalue-up", "numericvalue-down" (optional) - if not provided, list will not be sorted
    width = "full", -- or "half" (optional)
    scrollable = true, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
    disabled = function() return db.someBooleanSetting end, -- or boolean (optional)
    warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
    requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
    default = defaults.var, -- default value or function that returns the default value (optional)
    helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
    reference = "MyAddonDropdown", -- unique global reference to control (optional)
    resetFunc = function(dropdownControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
    multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
    multiSelectTextFormatter = SI_COMBO_BOX_DEFAULT_MULTISELECTION_TEXT_FORMATTER, -- or string id or function returning a string. If specified, this will be used with zo_strformat(multiSelectTextFormatter, numSelectedItems) to set the "selected item text". Only incombination with multiSelect = true (optional)
    multiSelectNoSelectionText = SI_COMBO_BOX_DEFAULT_NO_SELECTION_TEXT, -- or string id or function returning a string. Only incombination with multiSelect = true (optional)
    multiSelectType = "normal", -- String or function returning a string "normal" or "allowed". "normal" = a list with key = number index and value = String / "allowed" = a list with key = any String or number and value = boolean. If value == true then the entry will be added. Default = "normal". Only incombination with multiSelect = true (optional)
    multiSelectMaxSelections = 5, --Number or function returning a number of the maximum of selectable entries. If not specified there is no max selection. Only incombination with multiSelect = true (optional)
} ]]


local widgetVersion = 25
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("dropdown", widgetVersion) then return end

local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER
local SORT_BY_VALUE         = { ["value"] = {} }
local SORT_BY_VALUE_NUMERIC = { ["value"] = { isNumeric = true } }
local SORT_TYPES = {
    name = ZO_SORT_BY_NAME,
    numeric = ZO_SORT_BY_NAME_NUMERIC,
    value = SORT_BY_VALUE,
    numericvalue = SORT_BY_VALUE_NUMERIC,
}
local SORT_ORDERS = {
    up = ZO_SORT_ORDER_UP,
    down = ZO_SORT_ORDER_DOWN,
}

local function UpdateDisabled(control)
    local disable
    if type(control.data.disabled) == "function" then
        disable = control.data.disabled()
    else
        disable = control.data.disabled
    end

    control.dropdown:SetEnabled(not disable)
    if disable then
        control.label:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
    else
        control.label:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
    end
end

local function updateMultiSelectSelected(control, values)
    local multiSelectType = control.data.multiSelectType
    assert(multiSelectType == "normal" or multiSelectType == "allowed", string.format("[LAM2]Dropdown - Unknown multiSelectType: %s", multiSelectType))
    assert(values ~= nil, string.format("[LAM2]Dropdown - Values for multiSelect %q are missing", control:GetName()))

    local dropdown = control.dropdown
    dropdown.m_selectedItemData = {}
    if multiSelectType == "normal" then
        for k, v in ipairs(values) do
            --dropdown:SelectItemByIndex(k, true)
            dropdown:SetSelectedItemByEval(function(entry)
d("[LAM2]dropdown - k: " .. tostring(k) .. ", v: " ..tostring(v) .. ", entry.value: " ..tostring(entry.value) ..", entry.name: " ..tostring(entry.name))
FCOCS._debugEntry = entry
FCOCS._debugEntryV = v
                if entry.value ~= nil then
                    return entry.value == v
                else
                    return entry.name ~= nil and entry.name == v
                end
            end, true)
        end
    elseif multiSelectType == "allowed" then
        for k, isAllowed in pairs(values) do
            if isAllowed == true then
                dropdown:SetSelectedItemByEval(function(entry)
d("[LAM2]dropdown - k: " .. tostring(k) .. ", entry.value: " ..tostring(entry.value) ..", entry.name: " ..tostring(entry.name))
    FCOCS._debugEntry = entry
    FCOCS._debugEntryK = k
                    if entry.value ~= nil then
                        return entry.value == k
                    else
                        return entry.name ~= nil and entry.name == k
                    end
                end, true)
            end
        end
    end
    dropdown:RefreshSelectedItemText()
end

local refreshIsNeeded = false
local function callMultiSelectSetFunc(control, values)
    if values == nil then
        values = {}
        local multiSelectType = control.data.multiSelectType
        for _, entry in ipairs(control.dropdown:GetSelectedItemData()) do
            local k = (entry.value ~= nil and entry.value) or entry.name
            if multiSelectType == "normal" then
                values[#values + 1] = k
            elseif multiSelectType == "allowed" then
                values[k] = true
            end
        end
    end
    control.data.setFunc(values)

    --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
    -- util.RequestRefreshIfNeeded(control)
    -->Atention: Closes dropdown! To prevent this set a flag "doRefresh" and hook into OnDropdownHideInternal and check if "doRefresh"
    --> was set to true > call the refresh then?
    refreshIsNeeded = true
end

local function UpdateValue(control, forceDefault, value)
    local isMultiSelectionEnabled = control.isMultiSelectionEnabled
    if forceDefault then --if we are forcing defaults
        if isMultiSelectionEnabled then
            local values = LAM.util.GetDefaultValue(control.data.default)
            values = values or {}
            updateMultiSelectSelected(control, values)
            control.data.setFunc(values)
        else
            value = LAM.util.GetDefaultValue(control.data.default)
            control.data.setFunc(value)
            control.dropdown:SetSelectedItem(control.choices[value])
        end
    elseif value ~= nil then
        if isMultiSelectionEnabled then
            --Coming from LAM 2.0 DiscardChangesOnReloadControls? Passing in the saved control.startValue table
            if type(value) ~= "table" then
                value = nil
            --else
                --d(">>table was passed in as value")
            end
            callMultiSelectSetFunc(control, value)
        else
            control.data.setFunc(value)
        end
        --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
        LAM.util.RequestRefreshIfNeeded(control)
    else
        if isMultiSelectionEnabled then
            local values = control.data.getFunc()
            values = values or {}
            updateMultiSelectSelected(control, values)
        else
            value = control.data.getFunc()
            control.dropdown:SetSelectedItem(control.choices[value])
        end
    end
end

local function DropdownCallback(control, choiceText, choice)
    local updateValue = choice.value
    if updateValue == nil then updateValue = choiceText end
    choice.control:UpdateValue(false, updateValue)
end

local TOOLTIP_HANDLER_NAMESPACE = "LAM2_Dropdown_Tooltip"

local function DoShowTooltip(control, tooltip)
    InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, BOTTOMRIGHT)
    local tooltipText = LAM.util.GetStringFromValue(tooltip)
    if tooltipText ~= nil then
        SetTooltipText(InformationTooltip, tooltipText)
        InformationTooltipTopLevel:BringWindowToTop()
    end
end

local function ShowTooltip(control)
    DoShowTooltip(control, control.dataEntry.data.tooltip)
end

local function HideTooltip()
    ClearTooltip(InformationTooltip)
end

local function SetupTooltips(comboBox)
    SecurePostHook("ZO_ComboBox_Entry_OnMouseEnter", function(comboBoxRowCtrl)
        local lComboBox = comboBoxRowCtrl.m_owner
        if lComboBox ~= nil and lComboBox == comboBox then
            ShowTooltip(comboBoxRowCtrl)
        end
    end)

    SecurePostHook("ZO_ComboBox_Entry_OnMouseExit", function(comboBoxCtrl)
        HideTooltip()
    end)
end

local function UpdateChoices(control, choices, choicesValues, choicesTooltips)
    control.dropdown:ClearItems() --remove previous choices --(need to call :SetSelectedItem()?)
    ZO_ClearTable(control.choices)

    --build new list of choices
    local choices = choices or control.data.choices
    local choicesValues = choicesValues or control.data.choicesValues
    local choicesTooltips = choicesTooltips or control.data.choicesTooltips

    if choicesValues then
        assert(#choices == #choicesValues, "choices and choicesValues need to have the same size")
    end

    if choicesTooltips then
        assert(#choices == #choicesTooltips, "choices and choicesTooltips need to have the same size")
        SetupTooltips(control.dropdown)
    end

    for i = 1, #choices do
        local entry = control.dropdown:CreateItemEntry(choices[i], DropdownCallback)
        entry.control = control
        if choicesValues then
            entry.value = choicesValues[i]
        end
        if choicesTooltips then
            entry.tooltip = choicesTooltips[i]
        end
        local entryValue = entry.value
        if entryValue == nil then entryValue = entry.name end
        control.choices[entryValue] = entry.name

        control.dropdown:AddItem(entry, not control.data.sort and ZO_COMBOBOX_SUPRESS_UPDATE) --if sort type/order isn't specified, then don't sort
    end
end

local function GrabSortingInfo(sortInfo)
    local t, i = {}, 1
    for info in string.gmatch(sortInfo, "([^%-]+)") do
        t[i] = info
        i = i + 1
    end

    return t
end


local DEFAULT_VISIBLE_ROWS = 10
local PADDING_Y = ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y
local ROUNDING_MARGIN = 0.01 -- needed to avoid rare issue with too many anchors processed
--[[
local ENTRY_ID = 1
local LAST_ENTRY_ID = 2
local OFFSET_X_INDEX = 4
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = ZO_SCROLLABLE_ENTRY_TEMPLATE_HEIGHT
local SCROLLBAR_PADDING = ZO_SCROLL_BAR_WIDTH
local PADDING_X = GetMenuPadding()
local LABEL_OFFSET_X = 2
local CONTENT_PADDING = PADDING_X * 4
local ScrollableDropdownHelper = ZO_Object:Subclass()

function ScrollableDropdownHelper:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function ScrollableDropdownHelper:Initialize(panel, control, visibleRows)
    local combobox = control.combobox
    local dropdown = control.dropdown
    self.panel = panel
    self.control = control
    self.combobox = combobox
    self.dropdown = dropdown
    self.visibleRows = visibleRows

    -- clear anchors so we can adjust the width dynamically
    dropdown.m_dropdown:ClearAnchors()
    dropdown.m_dropdown:SetAnchor(TOPLEFT, combobox, BOTTOMLEFT)

    -- handle dropdown or settingsmenu opening/closing
    local function onShow() return self:OnShow() end
    local function onHide() self:OnHide() end
    local function doHide(closedPanel)
        if closedPanel == panel then self:DoHide() end
    end

    ZO_PreHook(dropdown, "ShowDropdownOnMouseUp", onShow)
    ZO_PreHook(dropdown, "HideDropdownInternal", onHide)
    combobox:SetHandler("OnEffectivelyHidden", onHide)
    cm:RegisterCallback("LAM-PanelClosed", doHide)

    -- dont fade entries near the edges
    local scrollList = dropdown.m_scroll
    scrollList.selectionTemplate = nil
    scrollList.highlightTemplate = nil
    ZO_ScrollList_EnableSelection(scrollList, "ZO_SelectionHighlight")
    ZO_ScrollList_EnableHighlight(scrollList, "ZO_SelectionHighlight")
    ZO_Scroll_SetUseFadeGradient(scrollList, false)

    -- adjust scroll content anchor to mimic menu padding
    local scroll = dropdown.m_dropdown:GetNamedChild("Scroll")
    local anchor1 = {select(2, scroll:GetAnchor(0))}
    local anchor2 = {select(2, scroll:GetAnchor(1))}
    anchor1[OFFSET_X_INDEX] = PADDING_X - LABEL_OFFSET_X
    anchor2[OFFSET_X_INDEX] = -anchor1[OFFSET_X_INDEX]
    scroll:ClearAnchors()
    scroll:SetAnchor(unpack(anchor1))
    scroll:SetAnchor(unpack(anchor2))
    ZO_ScrollList_Commit(scrollList)

    -- hook mouse enter/exit
    local function onMouseEnter(control) self:OnMouseEnter(control) end
    local function onMouseExit(control) self:OnMouseExit(control) end

    -- adjust row setup to mimic the highlight padding
    local dataType1 = ZO_ScrollList_GetDataTypeTable(dropdown.m_scroll, ENTRY_ID)
    local dataType2 = ZO_ScrollList_GetDataTypeTable(dropdown.m_scroll, LAST_ENTRY_ID)
    local oSetup = dataType1.setupCallback -- both types have the same setup function
    local function SetupEntry(control, data, list)
        oSetup(control, data, list)
        control.m_label:SetAnchor(LEFT, nil, nil, LABEL_OFFSET_X)
        control.m_label:SetAnchor(RIGHT, nil, nil, -LABEL_OFFSET_X)
        -- no need to store old ones since we have full ownership of our dropdown controls
        if not control.hookedMouseHandlers then --only do it once per control
            control.hookedMouseHandlers = true
            control:SetHandler("OnMouseEnter", onMouseEnter, TOOLTIP_HANDLER_NAMESPACE)
            control:SetHandler("OnMouseExit", onMouseExit, TOOLTIP_HANDLER_NAMESPACE)
        end
    end
    dataType1.setupCallback = SetupEntry
    dataType2.setupCallback = SetupEntry

    -- adjust dimensions based on entries
    local scrollContent = scroll:GetNamedChild("Contents")
    dropdown.AddMenuItems = ScrollableDropdownHelper.AddMenuItems

    dropdown.AdjustDimensions = function()
        local numItems = #dropdown.m_sortedItems
        local contentWidth = self:CalculateContentWidth() + CONTENT_PADDING
        local anchorOffset = 0
        if(numItems > self.visibleRows) then
            numItems = self.visibleRows
            contentWidth = contentWidth + SCROLLBAR_PADDING
            anchorOffset = -SCROLLBAR_PADDING
        end

        local width = zo_max(contentWidth, dropdown.m_container:GetWidth())
        local height = dropdown:GetEntryTemplateHeightWithSpacing() * numItems - dropdown.m_spacing + (PADDING_Y * 2) + ROUNDING_MARGIN

        dropdown.m_dropdown:SetWidth(width)
        dropdown.m_dropdown:SetHeight(height)
        ZO_ScrollList_SetHeight(dropdown.m_scroll, height)

        scrollContent:SetAnchor(BOTTOMRIGHT, nil, nil, anchorOffset)
    end
end

local function CreateScrollableComboBoxEntry(self, item, index, isLast)
    item.m_index = index
    item.m_owner = self
    local entryType = isLast and LAST_ENTRY_ID or ENTRY_ID
    local entry = ZO_ScrollList_CreateDataEntry(entryType, item)

    return entry
end

function ScrollableDropdownHelper.AddMenuItems(self) -- self refers to the ZO_ScrollableComboBox here
    ZO_ScrollList_Clear(self.m_scroll)

    local numItems = #self.m_sortedItems
    local dataList = ZO_ScrollList_GetDataList(self.m_scroll)

    for i = 1, numItems do
        local item = self.m_sortedItems[i]
        local entry = CreateScrollableComboBoxEntry(self, item, i, i == numItems)
        table.insert(dataList, entry)
    end

    self:AdjustDimensions()

    ZO_ScrollList_Commit(self.m_scroll)
end

function ScrollableDropdownHelper:OnShow()
    local dropdown = self.dropdown

    -- don't show if there are no entries
    if #dropdown.m_sortedItems == 0 then return true end

    if dropdown.m_lastParent ~= ZO_Menus then
        dropdown.m_lastParent = dropdown.m_dropdown:GetParent()
        dropdown.m_dropdown:SetParent(ZO_Menus)
        ZO_Menus:BringWindowToTop()
    end
end

function ScrollableDropdownHelper:OnHide()
    local dropdown = self.dropdown
    if dropdown.m_lastParent then
        dropdown.m_dropdown:SetParent(dropdown.m_lastParent)
        dropdown.m_lastParent = nil
    end
end

function ScrollableDropdownHelper:DoHide()
    local dropdown = self.dropdown
    if dropdown:IsDropdownVisible() then
        dropdown:HideDropdown()
    end
end

function ScrollableDropdownHelper:CalculateContentWidth()
    local dropdown = self.dropdown
    local dataType = ZO_ScrollList_GetDataTypeTable(dropdown.m_scroll, 1)

    local dummy = dataType.pool:AcquireObject()
    dataType.setupCallback(dummy, {
        m_owner = dropdown,
        name = "Dummy"
    }, dropdown)

    local maxWidth = 0
    local label = dummy.m_label
    local entries = dropdown.m_sortedItems
    local numItems = #entries
    for index = 1, numItems do
        label:SetText(entries[index].name)
        local width = label:GetTextWidth()
        if (width > maxWidth) then
            maxWidth = width
        end
    end

    dataType.pool:ReleaseObject(dummy.key)
    return maxWidth
end

function ScrollableDropdownHelper:OnMouseEnter(control)
    if control.m_data.tooltip then
        DoShowTooltip(control, control.m_data.tooltip)
    end
end
function ScrollableDropdownHelper:OnMouseExit(control)
    if control.m_data.tooltip then
        HideTooltip()
    end
end
]]

--Change the height of the combobox dropdown
local function SetDropdownHeight(combobox, dropdown, dropdownData)
    local entrySpacing = dropdown:GetSpacing()
    local numSortedItems = #dropdown.m_sortedItems
    local visibleRows, min, max

    local isScrollable = dropdownData.scrollable
    visibleRows = type(dropdownData.scrollable) == "number" and dropdownData.scrollable or DEFAULT_VISIBLE_ROWS
    --Either scrollable combobox: Show number of entries passed in by the data.scrollable, or use default number of entries (10)
    --but if less than default number of entries in the dropdown list, then shrink the max value to the number of entrries!
    if numSortedItems < visibleRows then
        min = numSortedItems
        max = numSortedItems
    else
        if isScrollable then
            min = (DEFAULT_VISIBLE_ROWS < visibleRows and DEFAULT_VISIBLE_ROWS) or visibleRows
            max = (DEFAULT_VISIBLE_ROWS > visibleRows and DEFAULT_VISIBLE_ROWS) or visibleRows
        else
            --Or show all entries if no scrollbar is requested
            min = DEFAULT_VISIBLE_ROWS
            max = numSortedItems
        end
    end

    --Entries to actually calculate the height = "number of sorted items" * "template height" + "number of sorted items -1" * spacing (last item got no spacing)
    local numEntries = zo_clamp(numSortedItems, min, max)
    local allItemsHeight = (dropdown:GetEntryTemplateHeightWithSpacing() * numEntries) - entrySpacing + (PADDING_Y * 2) + ROUNDING_MARGIN
    dropdown:SetHeight(allItemsHeight)
    ZO_ScrollList_Commit(dropdown.m_scroll)
end

function LAMCreateControl.dropdown(parent, dropdownData, controlName)
    local control = LAM.util.CreateLabelAndContainerControl(parent, dropdownData, controlName)
    control.choices = {}

    local countControl = parent
    local name = parent:GetName()
    if not name or #name == 0 then
        countControl = LAMCreateControl
        name = "LAM"
    end
    local comboboxCount = (countControl.comboboxCount or 0) + 1
    countControl.comboboxCount = comboboxCount
    control.combobox = wm:CreateControlFromVirtual(zo_strjoin(nil, name, "Combobox", comboboxCount), control.container, "ZO_ComboBox")

    local combobox = control.combobox
    combobox:SetAnchor(TOPLEFT)
    combobox:SetDimensions(control.container:GetDimensions())
    combobox:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(control) end)
    combobox:SetHandler("OnMouseExit", function() ZO_Options_OnMouseExit(control) end)
    control.dropdown = ZO_ComboBox_ObjectFromContainer(combobox)
    local dropdown = control.dropdown
    dropdown:SetSortsItems(false) -- need to sort ourselves in order to be able to sort by value
    dropdown.m_dropdown:SetParent(combobox:GetOwningWindow()) -- TODO remove workaround once the problem is fixed in the game

    --Multiselection
    local isMultiSelectionEnabled = LAM.util.GetDefaultValue(dropdownData.multiSelect)
    control.isMultiSelectionEnabled = isMultiSelectionEnabled
    if isMultiSelectionEnabled == true then
        local multiSelectType = LAM.util.GetDefaultValue(dropdownData.multiSelectType)
        control.data.multiSelectType = multiSelectType or "normal"

        --Add context menu to the multiselect dropdown: Select all / Clear all selections
        control.CallMultiSelectSetFunc = callMultiSelectSetFunc
        local mouseUp = combobox:GetHandler("OnMouseUp")
        local function onMouseUp(combobox, button, upInside, alt, shift, ctrl, command)
            if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
                ClearMenu()
                local lDropdown = ZO_ComboBox_ObjectFromContainer(combobox)
                AddMenuItem(GetString(SI_ITEMFILTERTYPE0), function()
                    lDropdown.m_multiSelectItemData = {}
                    local maxSelections = self.m_maxNumSelections
                    for index, _ in pairs(lDropdown.m_sortedItems) do
                        if maxSelections == nil or maxSelections == 0 or maxSelections >= index then
                            lDropdown:SetSelected(index, true)
                        end
                    end
                    lDropdown:RefreshSelectedItemText()
                    control:CallMultiSelectSetFunc(nil)
                end)
                AddMenuItem(GetString(SI_KEEPRESOURCETYPE0), function()
                    lDropdown:ClearAllSelections()
                    control.data.setFunc({})
                end)
                ShowMenu(combobox)
            else
                mouseUp(combobox, button, upInside, alt, shift, ctrl, command)
            end
        end
        combobox:SetHandler("OnMouseUp", onMouseUp)

        local multiSelectionTextFormatter = LAM.util.GetDefaultValue(dropdownData.multiSelectTextFormatter)
        local multiSelectionNoSelectionText = LAM.util.GetDefaultValue(dropdownData.multiSelectNoSelectionText)
        dropdown:EnableMultiSelect(multiSelectionTextFormatter, multiSelectionNoSelectionText)

        local maxSelections = LAM.util.GetDefaultValue(dropdownData.multiSelectMaxSelections)
        if type(maxSelections) == "number" then
            dropdown:SetMaxSelections(maxSelections)
        end
    else
        dropdown:DisableMultiSelect()
    end

    --After the items are added and the dropdown shows: Change the height of the dropdown
    SecurePostHook(dropdown, "AddMenuItems", function()
        SetDropdownHeight(combobox, dropdown, dropdownData)
    end)

    ZO_PreHook(dropdown, "UpdateItems", function(self)
        assert(not self.m_sortsItems, "built-in dropdown sorting was reactivated, sorting is handled by LAM")
        if control.m_sortOrder ~= nil and control.m_sortType then
            local sortKey = next(control.m_sortType)
            local sortFunc = function(item1, item2) return ZO_TableOrderingFunction(item1, item2, sortKey, control.m_sortType, control.m_sortOrder) end
            table.sort(self.m_sortedItems, sortFunc)
        end
    end)

    if dropdownData.sort then
        local sortInfo = GrabSortingInfo(dropdownData.sort)
        control.m_sortType, control.m_sortOrder = SORT_TYPES[sortInfo[1]], SORT_ORDERS[sortInfo[2]]
    elseif dropdownData.choicesValues then
        control.m_sortType, control.m_sortOrder = ZO_SORT_ORDER_UP, SORT_BY_VALUE
    end

    if dropdownData.warning ~= nil or dropdownData.requiresReload then
        control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
        control.warning:SetAnchor(RIGHT, combobox, LEFT, -5, 0)
        control.UpdateWarning = LAM.util.UpdateWarning
        control:UpdateWarning()
    end

    control.SetDropdownHeight = SetDropdownHeight
    control.UpdateChoices = UpdateChoices
    control:UpdateChoices(dropdownData.choices, dropdownData.choicesValues)
    control.UpdateValue = UpdateValue
    control:UpdateValue()
    if dropdownData.disabled ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)
    LAM.util.RegisterForReloadIfNeeded(control)

    return control
end
