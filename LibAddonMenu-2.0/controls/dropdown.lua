---@alias LAM2_SortType "name-up"|"name-down"|"numeric-up"|"numeric-down"|"value-up"|"value-down"|"numericvalue-up"|"numericvalue-down"

---@class LAM2_DropdownData: LAM2_LabelAndContainerControlData
---@field type "dropdown"
---@field choices string[] ex. {"table", "of", "choices"}
---@field getFunc fun(): string|string[] ex. function() return db.var end
---@field setFunc fun(var: string|string[]) ex. function(var) db.var = var doStuff() end
---@field choicesValues nil|any[] if specified, these values will get passed to setFunc instead ex. {"foo", 2, "three"}
---@field choicesTooltips nil|Stringy[] ex. {"tooltip 1", "tooltip 2", "tooltip 3"}
---@field sort nil|LAM2_SortType if not provided, list will not be sorted
---@field scrollable nil|boolean|integer if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used
---@field disabled nil|boolean|fun(): boolean ex. function() return db.someBooleanSetting end
---@field warning nil|Stringy ex. "May cause permanent awesomeness"
---@field requiresReload nil|boolean if set to true, the warning text will contain a notice that changes are only applied after a UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed
---@field default nil|string|string[]|fun(): (string|string[]) default value or function that returns the default value
---@field helpUrl nil|Stringy ex. "https://www.esoui.com/portal.php?id=218&a=faq"
---@field resetFunc nil|fun(dropdownControl: LAM2_Dropdown) custom function to run after the control is reset to defaults ex. function(dropdownControl) d("defaults reset") end
---@field multiSelect nil|boolean|fun(): boolean if set to true, you can have multiple entries selected at the same time
---@field multiSelectTextFormatter nil|Stringy If specified, this will be used with zo_strformat(multiSelectTextFormatter, numSelectedItems) to set the "selected item text". Only in combination with multiSelect = true. ex SI_COMBO_BOX_DEFAULT_MULTISELECTION_TEXT_FORMATTER
---@field multiSelectNoSelectionText nil|Stringy Only incombination with multiSelect = true. ex. SI_COMBO_BOX_DEFAULT_NO_SELECTION_TEXT
---@field multiSelectMaxSelections nil|integer|fun(): integer The maximum number of entries that can be selected at once. If not specified there is no limit. Only incombination with multiSelect = true. ex. 5

---@class LAM2_SingleSelectDropdownData: LAM2_DropdownData
---@field multiSelect nil
---@field getFunc fun(): string
---@field setFunc fun(var: string)
---@field default nil|string|fun(): string
---@field multiSelectTextFormatter nil
---@field multiSelectNoSelectionText nil
---@field multiSelectMaxSelections nil

---@class LAM2_MultiSelectDropdownData: LAM2_DropdownData
---@field multiSelect true
---@field getFunc fun(): string[]
---@field setFunc fun(var: string[])
---@field default nil|string[]|fun(): string[]


local widgetVersion = 27
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("dropdown", widgetVersion) then return end

local GetDefaultValue = LAM.util.GetDefaultValue

local wm = WINDOW_MANAGER

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

local DEFAULT_VISIBLE_ROWS = 10
local PADDING_Y = ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y
local ROUNDING_MARGIN = 0.01 -- needed to avoid rare issue with too many anchors processed
local SCROLLBAR_PADDING = ZO_SCROLL_BAR_WIDTH
local MULTISELECT_NO_SCROLLBAR_PADDING = 6
local PADDING_X = GetMenuPadding()
local CONTENT_PADDING = PADDING_X * 4


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

local function UpdateMultiSelectSelected(control, values)
    local data = control.data
    assert(values ~= nil, string.format("[LAM2]Dropdown - Values for multiSelect %q are missing", control:GetName()))

    local dropdown = control.dropdown
    dropdown.m_selectedItemData = {}
    dropdown.m_multiSelectItemData = {}

    local choicesValues = data.choicesValues
    local usesChoicesValues = choicesValues ~= nil

    for _, v in ipairs(values) do
        local toCompare = v
        if usesChoicesValues then
            toCompare = choicesValues[v]
        end
        dropdown:SetSelectedItemByEval(function(entry)
            if usesChoicesValues then
                return entry.value == toCompare
            else
                return entry.name == toCompare
            end
        end, true)
    end
    dropdown:RefreshSelectedItemText()
end

local function CallMultiSelectSetFunc(control, values)
    local data = control.data
    if values == nil then
        values = {}
        local usesChoicesValues = data.choicesValues ~= nil
        for _, entry in ipairs(control.dropdown:GetSelectedItemData()) do
            if usesChoicesValues then
                values[#values + 1] = entry.value
            else
                values[#values + 1] = entry.name
            end
        end
    end
    data.setFunc(values)
end

local function UpdateValue(control, forceDefault, value)
    local isMultiSelectionEnabled = control.isMultiSelectionEnabled
    if forceDefault then --if we are forcing defaults
        local value = GetDefaultValue(control.data.default)
        if isMultiSelectionEnabled then
            value = value or {}
            control.data.setFunc(value)
            UpdateMultiSelectSelected(control, value)
        else
            control.data.setFunc(value)
            control.dropdown:SetSelectedItem(control.choices[value])
        end
    elseif value ~= nil then
        if isMultiSelectionEnabled then
            --Coming from LAM 2.0 DiscardChangesOnReloadControls? Passing in the saved control.startValue table
            if type(value) ~= "table" then value = nil end
            CallMultiSelectSetFunc(control, value)
        else
            control.data.setFunc(value)
        end
        --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
        LAM.util.RequestRefreshIfNeeded(control)
    else
        if isMultiSelectionEnabled then
            local values = control.data.getFunc()
            values = values or {}
            UpdateMultiSelectSelected(control, values)
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
    local tooltipText = LAM.util.GetStringFromValue(tooltip)
    if tooltipText ~= nil and tooltipText ~= "" then
        InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, BOTTOMRIGHT)
        SetTooltipText(InformationTooltip, tooltipText)
        ---@type TopLevelWindow
        InformationTooltipTopLevel = InformationTooltipTopLevel
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
    SecurePostHook(ZO_ComboBoxDropdown_Keyboard, "OnEntryMouseEnter", function(comboBoxRowCtrl)
        local lComboBox = comboBoxRowCtrl.m_owner
        if lComboBox ~= nil and lComboBox == comboBox then
            ShowTooltip(comboBoxRowCtrl)
        end
    end)

    SecurePostHook(ZO_ComboBoxDropdown_Keyboard, "OnEntryMouseExit", function(comboBoxCtrl)
        HideTooltip()
    end)
end

local function UpdateChoices(control, choices, choicesValues, choicesTooltips)
    control.dropdown:ClearItems() --remove previous choices --(need to call :SetSelectedItem()?)
    ZO_ClearTable(control.choices)

    --build new list of choices
    choices = choices or control.data.choices
    choicesValues = choicesValues or control.data.choicesValues
    choicesTooltips = choicesTooltips or control.data.choicesTooltips

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

        -- why the "and 2" at the end?
        control.dropdown:AddItem(entry, not control.data.sort and ZO_COMBOBOX_SUPPRESS_UPDATE) --if sort type/order isn't specified, then don't sort
    end
end

---@param sortInfo LAM2_SortType
---@return ["name"|"numeric"|"value"|"numericvalue", "up"|"down"]
local function GrabSortingInfo(sortInfo)
    local t, i = {}, 1
    for info in string.gmatch(sortInfo, "([^%-]+)") do
        t[i] = info
        i = i + 1
    end

    return t
end

--Change the height of the combobox dropdown
local function SetDropdownHeight(control, dropdown, dropdownData)
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
    local entryHeightWithSpacing
    if GetAPIVersion() < 101041 then
        entryHeightWithSpacing = dropdown:GetEntryTemplateHeightWithSpacing()
    else
        entryHeightWithSpacing = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT + dropdown.m_dropdownObject.spacing
    end
    local allItemsHeight = (entryHeightWithSpacing * numEntries) - entrySpacing + (PADDING_Y * 2) + ROUNDING_MARGIN
    dropdown:SetHeight(allItemsHeight)
    ZO_ScrollList_Commit(dropdown.m_scroll)

    return visibleRows, min, max
end

---@param dropdown ZO_ComboBox
local function CalculateContentWidth(dropdown)
    local dataType = ZO_ScrollList_GetDataTypeTable(dropdown.m_scroll, 1)

    local dummy = dataType.pool:AcquireObject() --[[@as ZO_ComboBoxDropdown_Keyboard_Entry]]
    local item = {
        m_owner = dropdown,
        name = "Dummy"
    }
    if GetAPIVersion() >= 101041 then
        item = dropdown.m_dropdownObject:CreateScrollableEntry(item, 1, 1)
    end
    dataType.setupCallback(dummy, item, dropdown)

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

---@param control LAM2_Dropdown
---@param dropdown ZO_ComboBox
---@param dropdownData LAM2_DropdownData
local function AdjustDimensions(control, dropdown, dropdownData)
    local numItems = #dropdown.m_sortedItems
    local dropdownObject = dropdown.m_dropdown
    local scroll = dropdownObject:GetNamedChild("Scroll") --[[@as ZO_ScrollList]]
    local scrollContent = scroll:GetNamedChild("Contents")
    local anchorOffset = 0

    local isMultiSelectionEnabled = GetDefaultValue(dropdownData.multiSelect)
    if isMultiSelectionEnabled then
        anchorOffset = -MULTISELECT_NO_SCROLLBAR_PADDING
    end

    local contentWidth = CalculateContentWidth(dropdown) + CONTENT_PADDING
    local visibleRows = SetDropdownHeight(control, dropdown, dropdownData)

    local hasScrollbar = false
    if numItems > visibleRows then
        numItems = visibleRows
        if isMultiSelectionEnabled then
            hasScrollbar = dropdownData.scrollable ~= nil and not scroll.scrollbar:IsHidden()
        else
            hasScrollbar = true
        end
    end

    if hasScrollbar then
        contentWidth = contentWidth + SCROLLBAR_PADDING
        anchorOffset = -SCROLLBAR_PADDING
    end

    local width = zo_max(contentWidth, dropdown.m_container:GetWidth())
    dropdownObject:SetWidth(width)

    scrollContent:SetAnchor(BOTTOMRIGHT, nil, nil, anchorOffset)
end

local function OnMultiSelectComboBoxMouseUp(control, combobox, button, upInside, alt, shift, ctrl, command)
    if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
        ClearMenu()
        local lDropdown = ZO_ComboBox_ObjectFromContainer(combobox)

        AddMenuItem(GetString(SI_ITEMFILTERTYPE0), function()
            lDropdown.m_multiSelectItemData = {}
            local maxSelections = lDropdown.m_maxNumSelections
            for index, _ in pairs(lDropdown.m_sortedItems) do
                if maxSelections == nil or maxSelections == 0 or maxSelections >= index then
                    lDropdown:SetSelected(index, true)
                end
            end
            lDropdown:RefreshSelectedItemText()
            CallMultiSelectSetFunc(control, nil)
        end)
        AddMenuItem(GetString(SI_KEEPRESOURCETYPE0), function()
            lDropdown:ClearAllSelections()
            CallMultiSelectSetFunc(control, nil)
        end)
        ShowMenu(combobox)
    end
end

---@param dropdownData LAM2_DropdownData
function LAMCreateControl.dropdown(parent, dropdownData, controlName)
    ---@class LAM2_Dropdown: LAM2_LabelAndContainerControl
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
    control.combobox = wm:CreateControlFromVirtual(zo_strjoin(nil, name, "Combobox", comboboxCount), control.container, "ZO_ComboBox") --[[@as ZO_ComboBox_Control]]

    local combobox = control.combobox
    combobox:SetAnchor(TOPLEFT)
    combobox:SetDimensions(control.container:GetDimensions())
    combobox:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(control) end)
    combobox:SetHandler("OnMouseExit", function() ZO_Options_OnMouseExit(control) end)
    control.dropdown = ZO_ComboBox_ObjectFromContainer(combobox)
    local dropdown = control.dropdown
    dropdown:SetSortsItems(false) -- need to sort ourselves in order to be able to sort by value
    if GetAPIVersion() < 101041 then
        dropdown.m_dropdown:SetParent(combobox:GetOwningWindow()) -- TODO remove workaround once the problem is fixed in the game
    end

    local isMultiSelectionEnabled = GetDefaultValue(dropdownData.multiSelect)
    control.isMultiSelectionEnabled = isMultiSelectionEnabled

    --Multiselection
    if isMultiSelectionEnabled == true then
        --Add context menu to the multiselect dropdown: Select all / Clear all selections
        combobox:SetHandler("OnMouseUp", function(...) OnMultiSelectComboBoxMouseUp(control, ...) end, "LAM2DropdownWidgetOnMouseUp")

        local multiSelectionTextFormatter = GetDefaultValue(dropdownData.multiSelectTextFormatter) or GetString(SI_COMBO_BOX_DEFAULT_MULTISELECTION_TEXT_FORMATTER)
        local multiSelectionNoSelectionText = GetDefaultValue(dropdownData.multiSelectNoSelectionText) or GetString(SI_COMBO_BOX_DEFAULT_NO_SELECTION_TEXT)
        dropdown:EnableMultiSelect(multiSelectionTextFormatter, multiSelectionNoSelectionText)

        local maxSelections = GetDefaultValue(dropdownData.multiSelectMaxSelections)
        if type(maxSelections) == "number" then
            dropdown:SetMaxSelections(maxSelections)
        end
    else
        dropdown:DisableMultiSelect()
    end

    --After the items are added and the dropdown shows: Change the height of the dropdown
    SecurePostHook(dropdown, "AddMenuItems", function()
        control.AdjustDimensions(control, dropdown, dropdownData)
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
        control.m_sortType, control.m_sortOrder = SORT_BY_VALUE, ZO_SORT_ORDER_UP
    end

    if dropdownData.warning ~= nil or dropdownData.requiresReload then
        control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
        control.warning:SetAnchor(RIGHT, combobox, LEFT, -5, 0)
        control.UpdateWarning = LAM.util.UpdateWarning
        control:UpdateWarning()
    end

    control.SetDropdownHeight = SetDropdownHeight
    control.AdjustDimensions = AdjustDimensions
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
