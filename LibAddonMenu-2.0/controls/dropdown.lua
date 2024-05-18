--[[dropdownData = {
    type = "dropdown",
    name = "My Dropdown", -- or string id or function returning a string
    choices = {"table", "of", "choices"},
    choicesValues = {"foo", 2, "three"}, -- if specified, these values will get passed to setFunc instead (optional)
    getFunc = function() return db.var end, -- if multiSelect is true the getFunc must return a table
    setFunc = function(var) db.var = var doStuff() end, -- if multiSelect is true the setFunc's var must be a table
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
    multiSelectMaxSelections = 5, --Number or function returning a number of the maximum of selectable entries. If not specified there is no max selection. Only incombination with multiSelect = true (optional)
} ]]


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

local function CalculateContentWidth(dropdown)
    local dataType = ZO_ScrollList_GetDataTypeTable(dropdown.m_scroll, 1)

    local dummy = dataType.pool:AcquireObject()
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

local function AdjustDimensions(control, dropdown, dropdownData)
    local numItems = #dropdown.m_sortedItems
    local dropdownObject = dropdown.m_dropdown
    local scroll = dropdownObject:GetNamedChild("Scroll")
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
        control.m_sortType, control.m_sortOrder = ZO_SORT_ORDER_UP, SORT_BY_VALUE
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
