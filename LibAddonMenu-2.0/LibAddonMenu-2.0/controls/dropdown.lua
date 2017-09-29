--[[dropdownData = {
    type = "dropdown",
    name = "My Dropdown", -- or string id or function returning a string
    choices = {"table", "of", "choices"},
    choicesValues = {"foo", 2, "three"}, -- if specified, these values will get passed to setFunc instead (optional)
    getFunc = function() return db.var end,
    setFunc = function(var) db.var = var doStuff() end,
    tooltip = "Dropdown's tooltip text.", -- or string id or function returning a string (optional)
    choicesTooltips = {"tooltip 1", "tooltip 2", "tooltip 3"}, -- or array of string ids or array of functions returning a string (optional)
    sort = "name-up", --or "name-down", "numeric-up", "numeric-down", "value-up", "value-down", "numericvalue-up", "numericvalue-down" (optional) - if not provided, list will not be sorted
    width = "full", --or "half" (optional)
    scrollable = true, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
    disabled = function() return db.someBooleanSetting end, --or boolean (optional)
    warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
    requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
    default = defaults.var, -- default value or function that returns the default value (optional)
    reference = "MyAddonDropdown" -- unique global reference to control (optional)
} ]]


local widgetVersion = 18
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("dropdown", widgetVersion) then return end

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

local function UpdateValue(control, forceDefault, value)
    if forceDefault then --if we are forcing defaults
        value = LAM.util.GetDefaultValue(control.data.default)
        control.data.setFunc(value)
        control.dropdown:SetSelectedItem(control.choices[value])
    elseif value then
        control.data.setFunc(value)
        --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
        LAM.util.RequestRefreshIfNeeded(control)
    else
        value = control.data.getFunc()
        control.dropdown:SetSelectedItem(control.choices[value])
    end
end

local function DropdownCallback(control, choiceText, choice)
    choice.control:UpdateValue(false, choice.value or choiceText)
end

local function SetupTooltips(comboBox, choicesTooltips)
    local function ShowTooltip(control)
        InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, BOTTOMRIGHT)
        SetTooltipText(InformationTooltip, LAM.util.GetStringFromValue(control.tooltip))
        InformationTooltipTopLevel:BringWindowToTop()
    end
    local function HideTooltip(control)
        ClearTooltip(InformationTooltip)
    end

    -- allow for tooltips on the drop down entries
    local originalShow = comboBox.ShowDropdownInternal
    comboBox.ShowDropdownInternal = function(comboBox)
        originalShow(comboBox)
        local entries = ZO_Menu.items
        for i = 1, #entries do
            local entry = entries[i]
            local control = entries[i].item
            control.tooltip = choicesTooltips[i]
            entry.onMouseEnter = control:GetHandler("OnMouseEnter")
            entry.onMouseExit = control:GetHandler("OnMouseExit")
            ZO_PreHookHandler(control, "OnMouseEnter", ShowTooltip)
            ZO_PreHookHandler(control, "OnMouseExit", HideTooltip)
        end
    end

    local originalHide = comboBox.HideDropdownInternal
    comboBox.HideDropdownInternal = function(self)
        local entries = ZO_Menu.items
        for i = 1, #entries do
            local entry = entries[i]
            local control = entries[i].item
            control:SetHandler("OnMouseEnter", entry.onMouseEnter)
            control:SetHandler("OnMouseExit", entry.onMouseExit)
            control.tooltip = nil
        end
        originalHide(self)
    end
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
        control.choices[entry.value or entry.name] = entry.name
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
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = 25 -- same as in zo_combobox.lua
local CONTENT_PADDING = 24
local SCROLLBAR_PADDING = 16
local PADDING = GetMenuPadding() / 2 -- half the amount looks closer to the regular dropdown
local ROUNDING_MARGIN = 0.01 -- needed to avoid rare issue with too many anchors processed
local ScrollableDropdownHelper = ZO_Object:Subclass()

function ScrollableDropdownHelper:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function ScrollableDropdownHelper:Initialize(parent, control, visibleRows)
    local combobox = control.combobox
    local dropdown = control.dropdown
    self.parent = parent
    self.control = control
    self.combobox = combobox
    self.dropdown = dropdown
    self.visibleRows = visibleRows

    -- clear anchors so we can adjust the width dynamically
    dropdown.m_dropdown:ClearAnchors()
    dropdown.m_dropdown:SetAnchor(TOPLEFT, combobox, BOTTOMLEFT)

    -- handle dropdown or settingsmenu opening/closing
    local function onShow() self:OnShow() end
    local function onHide() self:OnHide() end
    local function doHide() self:DoHide() end

    ZO_PreHook(dropdown, "ShowDropdownOnMouseUp", onShow)
    ZO_PreHook(dropdown, "HideDropdownInternal", onHide)
    combobox:SetHandler("OnEffectivelyHidden", onHide)
    parent:SetHandler("OnEffectivelyHidden", doHide)

    -- dont fade entries near the edges
    local scrollList = dropdown.m_scroll
    scrollList.selectionTemplate = nil
    scrollList.highlightTemplate = nil
    ZO_ScrollList_EnableSelection(scrollList, "ZO_SelectionHighlight")
    ZO_ScrollList_EnableHighlight(scrollList, "ZO_SelectionHighlight")
    ZO_Scroll_SetUseFadeGradient(scrollList, false)

    -- adjust scroll content anchor to mimic menu padding
    local scroll = dropdown.m_dropdown:GetNamedChild("Scroll")
    local anchor1 = {scroll:GetAnchor(0)}
    local anchor2 = {scroll:GetAnchor(1)}
    scroll:ClearAnchors()
    scroll:SetAnchor(anchor1[2], anchor1[3], anchor1[4], anchor1[5] + PADDING, anchor1[6] + PADDING)
    scroll:SetAnchor(anchor2[2], anchor2[3], anchor2[4], anchor2[5] - PADDING, anchor2[6] - PADDING)
    ZO_ScrollList_Commit(scrollList)
    
    -- hook mouse enter/exit
    local function onMouseEnter(control) self:OnMouseEnter(control) end
    local function onMouseExit(control) self:OnMouseExit(control) end

    -- adjust row setup to mimic the highlight padding
    local dataType1 = ZO_ScrollList_GetDataTypeTable(dropdown.m_scroll, 1)
    local dataType2 = ZO_ScrollList_GetDataTypeTable(dropdown.m_scroll, 2)
    local oSetup = dataType1.setupCallback -- both types have the same setup function
    local function SetupEntry(control, data, list)
        oSetup(control, data, list)
        control.m_label:SetAnchor(LEFT, nil, nil, 2)
        -- no need to store old ones since we have full ownership of our dropdown controls
        if not control.hookedMouseHandlers then --only do it once per control
            control.hookedMouseHandlers = true
            ZO_PreHookHandler(control, "OnMouseEnter", onMouseEnter)
            ZO_PreHookHandler(control, "OnMouseExit", onMouseExit)
            -- we could also just replace the handlers
            --control:SetHandler("OnMouseEnter", onMouseEnter)
            --control:SetHandler("OnMouseExit", onMouseExit)
        end
    end
    dataType1.setupCallback = SetupEntry
    dataType2.setupCallback = SetupEntry

    -- adjust dimensions based on entries
    local scrollContent = scroll:GetNamedChild("Contents")
    ZO_PreHook(dropdown, "AddMenuItems", function()
        local width = PADDING * 2 + zo_max(self:GetMaxWidth(), combobox:GetWidth())
        local numItems = #dropdown.m_sortedItems
        local anchorOffset = 0
        if(numItems > self.visibleRows) then
            width = width + CONTENT_PADDING + SCROLLBAR_PADDING
            anchorOffset = -SCROLLBAR_PADDING
            numItems = self.visibleRows
        end
        scrollContent:SetAnchor(BOTTOMRIGHT, nil, nil, anchorOffset)
        local height = PADDING * 2 + numItems * (SCROLLABLE_ENTRY_TEMPLATE_HEIGHT + dropdown.m_spacing) - dropdown.m_spacing + ROUNDING_MARGIN
        dropdown.m_dropdown:SetWidth(width)
        dropdown.m_dropdown:SetHeight(height)
    end)
end

function ScrollableDropdownHelper:OnShow()
    local dropdown = self.dropdown
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

function ScrollableDropdownHelper:GetMaxWidth()
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
    -- call original code if we replace instead of hook the handler
        --ZO_ScrollableComboBox_Entry_OnMouseEnter(control)
    -- show tooltip
    if control.m_data.tooltip then
        InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, BOTTOMRIGHT)
        SetTooltipText(InformationTooltip, LAM.util.GetStringFromValue(control.m_data.tooltip))
        InformationTooltipTopLevel:BringWindowToTop()
    end
end
function ScrollableDropdownHelper:OnMouseExit(control)
    -- call original code if we replace instead of hook the handler
        --ZO_ScrollableComboBox_Entry_OnMouseExit(control)
    -- hide tooltip
    if control.m_data.tooltip then
        ClearTooltip(InformationTooltip)
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
    control.combobox = wm:CreateControlFromVirtual(zo_strjoin(nil, name, "Combobox", comboboxCount), control.container, dropdownData.scrollable and "ZO_ScrollableComboBox" or "ZO_ComboBox")

    local combobox = control.combobox
    combobox:SetAnchor(TOPLEFT)
    combobox:SetDimensions(control.container:GetDimensions())
    combobox:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(control) end)
    combobox:SetHandler("OnMouseExit", function() ZO_Options_OnMouseExit(control) end)
    control.dropdown = ZO_ComboBox_ObjectFromContainer(combobox)
    local dropdown = control.dropdown
    dropdown:SetSortsItems(false) -- need to sort ourselves in order to be able to sort by value

    if dropdownData.scrollable then
        local visibleRows = type(dropdownData.scrollable) == "number" and dropdownData.scrollable or DEFAULT_VISIBLE_ROWS 
        control.scrollHelper = ScrollableDropdownHelper:New(parent, control, visibleRows)
    end

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
