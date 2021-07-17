--[[dropdownData = {
    type = "multiselect",
    dataType = "set" -- or "list"
    name = "My Multiple Selection Combo Box", -- or string id or function returning a string
    choices = {"table", "of", "choices"},
    choicesValues = {"foo", 2, "three"}, -- if specified, these values will get passed to setFunc instead (optional)
    multiSelectionTextFormatter = "<<1[$d Item/$d Items]>>" -- if specified, this will be used with zo_strformat(multiSelectionTextFormat, numSelectedItems) to set the "selected item text" (optional)
    getFunc = function() return db.var end,
    setFunc = function(var) db.var = var doStuff() end,
    tooltip = "Dropdown's tooltip text.", -- or string id or function returning a string (optional)
    choicesTooltips = {"tooltip 1", "tooltip 2", "tooltip 3"}, -- or array of string ids or array of functions returning a string (optional)
    sort = "name-up", -- or "name-down", "numeric-up", "numeric-down", "value-up", "value-down", "numericvalue-up", "numericvalue-down" (optional) - if not provided, list will not be sorted
    width = "full", -- or "half" (optional)
    disabled = function() return db.someBooleanSetting end, -- or boolean (optional)
    warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
    requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
    default = default.var, -- default values or function that returns the default values (optional)
    helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
    reference = "MyAddonMultiselect" -- unique global reference to control (optional)
} ]]


local widgetVersion = 1
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("multiselect", widgetVersion) then return end

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

local function size(t)
    local s = 0
    for k, v in pairs(t) do
        s = s + 1
    end
    return s
end

local function SetSelected(control, values)
    control.dropdown.m_selectedItemData = {}
    if control.data.dataType == "set" then
        for k, kIsInSet in pairs(values) do
            if kIsInSet then
                control.dropdown:AddItemToSelected(control.entries[k])
            end
        end
    elseif control.data.dataType == "list" then
        for _, v in ipairs(values) do
            control.dropdown:AddItemToSelected(control.entries[v])
        end
    else
        d(string.format("unknown multiselect dataType: %s", control.data.dataType))
    end
    control.dropdown:RefreshSelectedItemText()
end

local function SetFuncWithSelectedItems(control)
    local values = {}
    -- TODO: use control.selected instead of 'values' for more efficiency?
    for _, entry in ipairs(control.dropdown.m_selectedItemData) do
        local k = entry.value or entry.name
        if control.data.dataType == "set" then
            values[k] = true
        elseif control.data.dataType == "list" then
            values[#values + 1] = k
        end
    end
    control.data.setFunc(values)
    -- TODO: determine a more controlled way to do this? currently, this call closes the dropdown, which is annoying when changing multiple things
    -- LAM.util.RequestRefreshIfNeeded(control)
end

local function UpdateValue(control, forceDefault, value)
    if forceDefault then --if we are forcing defaults
        local values = LAM.util.GetDefaultValue(control.data.default)
        SetSelected(control, values)
        control.data.setFunc(values)
    elseif value then
        SetFuncWithSelectedItems(control)
    else
        local values = control.data.getFunc()
        SetSelected(control, values)
    end
    -- control.selected = values
    -- validate control.selected (if set, either set other choices to 'false' or ensure they are deleted from values
end

local function DropdownCallback(control, choiceText, choice)
    choice.control:UpdateValue(false, choice.value or choiceText)
end

local TOOLTIP_HANDLER_NAMESPACE = "LAM2_Multiselect_Tooltip"

local function DoShowTooltip(control, tooltip)
    InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, BOTTOMRIGHT)
    SetTooltipText(InformationTooltip, LAM.util.GetStringFromValue(tooltip))
    InformationTooltipTopLevel:BringWindowToTop()
end

local function ShowTooltip(control)
    DoShowTooltip(control, control.tooltip)
end

local function HideTooltip()
    ClearTooltip(InformationTooltip)
end

local function SetupTooltips(comboBox, choicesTooltips)
    -- allow for tooltips on the drop down entries
    local originalShow = comboBox.ShowDropdownInternal
    comboBox.ShowDropdownInternal = function(comboBox)
        originalShow(comboBox)
        local entries = ZO_Menu.items
        for i = 1, #entries do
            local control = entries[i].item
            control.tooltip = choicesTooltips[i]
            if control.tooltip then
                control:SetHandler("OnMouseEnter", ShowTooltip, TOOLTIP_HANDLER_NAMESPACE)
                control:SetHandler("OnMouseExit", HideTooltip, TOOLTIP_HANDLER_NAMESPACE)
            end
        end
    end

    local originalHide = comboBox.HideDropdownInternal
    comboBox.HideDropdownInternal = function(self)
        local entries = ZO_Menu.items
        for i = 1, #entries do
            local control = entries[i].item
            if control.tooltip then
                control:SetHandler("OnMouseEnter", nil, TOOLTIP_HANDLER_NAMESPACE)
                control:SetHandler("OnMouseExit", nil, TOOLTIP_HANDLER_NAMESPACE)
                control.tooltip = nil
            end
        end
        originalHide(self)
    end
end

local function UpdateChoices(control, choices, choicesValues, choicesTooltips)
    control.dropdown:ClearItems() --removes previous choices
    ZO_ClearTable(control.entries)

    --build new list of choices
    local choices = choices or control.data.choices
    local choicesValues = choicesValues or control.data.choicesValues
    local choicesTooltips = choicesTooltips or control.data.choicesTooltips

    if choicesValues then
        assert(#choices == #choicesValues, "choices and choicesValues need to have the same size")
    end

    if choicesTooltips then
        assert(#choices == #choicesTooltips, "choices and choicesTooltips need to have the same size")
        if not control.scrollHelper then -- only do this for non-scrollable
            SetupTooltips(control.dropdown, choicesTooltips)
        end
    end

    for i = 1, #choices do
        local entry = control.dropdown:CreateItemEntry(choices[i], DropdownCallback)
        entry.control = control
        if choicesValues then
            entry.value = choicesValues[i]
        end
        if choicesTooltips and control.scrollHelper then
            entry.tooltip = choicesTooltips[i]
        end
        control.entries[entry.value or entry.name] = entry
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

local ENTRY_ID = 1
local LAST_ENTRY_ID = 2
local OFFSET_X_INDEX = 4
local DEFAULT_VISIBLE_ROWS = 10
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = ZO_SCROLLABLE_ENTRY_TEMPLATE_HEIGHT
local SCROLLBAR_PADDING = ZO_SCROLL_BAR_WIDTH
local PADDING_X = GetMenuPadding()
local PADDING_Y = ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y
local LABEL_OFFSET_X = 2
local CONTENT_PADDING = PADDING_X * 4
local ROUNDING_MARGIN = 0.01 -- needed to avoid rare issue with too many anchors processed

-- TODO: copy and adjust Scrollable code from controls/dropdown.lua

function LAMCreateControl.multiselect(parent, dropdownData, controlName)
    local control = LAM.util.CreateLabelAndContainerControl(parent, dropdownData, controlName)
    control.entries = {}
    -- control.selected = {}

    local countControl = parent
    local name = parent:GetName()
    if not name or #name == 0 then
        countControl = LAMCreateControl
        name = "LAM"
    end
    local comboboxCount = (countControl.comboboxCount or 0) + 1
    countControl.comboboxCount = comboboxCount
    control.combobox = wm:CreateControlFromVirtual(zo_strjoin(nil, name, "Multiselect", comboboxCount), control.container, "ZO_MultiselectComboBox")

    local combobox = control.combobox
    combobox:SetAnchor(TOPLEFT)
    combobox:SetDimensions(control.container:GetDimensions())
    combobox:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(control) end)
    combobox:SetHandler("OnMouseExit", function() ZO_Options_OnMouseExit(control) end)
    
    control.SetFuncWithSelectedItems = SetFuncWithSelectedItems
    local mouseUp = combobox:GetHandler("OnMouseUp")
    local function onMouseUp(combobox, button, upInside, alt, shift, ctrl, command)
        if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
            ClearMenu()
            local dropdown = ZO_ComboBox_ObjectFromContainer(combobox)
            AddMenuItem("Select all", function()
                dropdown.m_selectedItemData = {}
                for _, entry in pairs(dropdown.m_sortedItems) do
                    table.insert(dropdown.m_selectedItemData, entry)
                end
                dropdown:RefreshSelectedItemText()
                control:SetFuncWithSelectedItems()
            end)
            AddMenuItem("Deselect all", function()
                dropdown:ClearAllSelections()
                control.data.setFunc({})
            end)
            ShowMenu(combobox)
        else
            mouseUp(combobox, button, upInside, alt, shift, ctrl, command)
        end
    end
    combobox:SetHandler("OnMouseUp", onMouseUp)
    control.dropdown = ZO_ComboBox_ObjectFromContainer(combobox)
    local dropdown = control.dropdown
    dropdown:SetSortsItems(false) -- need to sort ourselves in order to be able to sort by value

    dropdown.noSelectionText = "None"
    dropdown.multiSelectionTextFormatter = dropdownData.multiSelectionTextFormatter

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
