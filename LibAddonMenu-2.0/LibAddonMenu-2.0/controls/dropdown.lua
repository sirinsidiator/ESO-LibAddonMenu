--[[dropdownData = {
    type = "dropdown",
    name = "My Dropdown", -- or string id or function returning a string
    choices = {"table", "of", "choices"},
    getFunc = function() return db.var end,
    setFunc = function(var) db.var = var doStuff() end,
    tooltip = "Dropdown's tooltip text.", -- or string id or function returning a string (optional)
    sort = "name-up", --or "name-down", "numeric-up", "numeric-down" (optional) - if not provided, list will not be sorted
    width = "full", --or "half" (optional)
    disabled = function() return db.someBooleanSetting end, --or boolean (optional)
    warning = "Will need to reload the UI.",  -- or string id or function returning a string (optional)
    default = defaults.var, -- default value or function that returns the default value (optional)
    reference = "MyAddonDropdown" -- unique global reference to control (optional)
} ]]


local widgetVersion = 13
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("dropdown", widgetVersion) then return end

local wm = WINDOW_MANAGER

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
        control.dropdown:SetSelectedItem(value)
    elseif value then
        control.data.setFunc(value)
        --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
        LAM.util.RequestRefreshIfNeeded(control)
    else
        value = control.data.getFunc()
        control.dropdown:SetSelectedItem(value)
    end
end

local function DropdownCallback(control, choiceText, choice)
    choice.control:UpdateValue(false, choiceText)
end

local function UpdateChoices(control, choices)
    control.dropdown:ClearItems() --remove previous choices --(need to call :SetSelectedItem()?)

    --build new list of choices
    local choices = choices or control.data.choices
    for i = 1, #choices do
        local entry = control.dropdown:CreateItemEntry(choices[i], DropdownCallback)
        entry.control = control
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

function LAMCreateControl.dropdown(parent, dropdownData, controlName)
    local control = LAM.util.CreateLabelAndContainerControl(parent, dropdownData, controlName)

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
    if dropdownData.sort then
        local sortInfo = GrabSortingInfo(dropdownData.sort)
        local sortType, sortOrder = sortInfo[1], sortInfo[2]
        dropdown:SetSortOrder(sortOrder == "up" and ZO_SORT_ORDER_UP or ZO_SORT_ORDER_DOWN, sortType == "name" and ZO_SORT_BY_NAME or ZO_SORT_BY_NAME_NUMERIC)
    end

    if dropdownData.warning then
        control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
        control.warning:SetAnchor(RIGHT, combobox, LEFT, -5, 0)
        control.warning.data = {tooltipText = LAM.util.GetStringFromValue(dropdownData.warning)}
    end

    control.UpdateChoices = UpdateChoices
    control:UpdateChoices(dropdownData.choices)
    control.UpdateValue = UpdateValue
    control:UpdateValue()
    if dropdownData.disabled ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)

    return control
end
