--[[datepickerData = {
    type = "datepicker",
    datePickerType = "normal", -- (optional)
    name = "My Datepicker", -- or string id or function returning a string
    getFunc = function() return db.var end,
    setFunc = function(var) db.var = var doStuff() end,
    tooltip = "Datepicker's tooltip text.", -- or string id or function returning a string (optional)
    width = "full", -- or "half" (optional)
    disabled = function() return db.someBooleanSetting end, -- or boolean (optional)
    warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
    requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
    default = defaults.var, -- default value or function that returns the default value (optional)
    helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
    reference = "MyAddonDatepicker" -- unique global reference to control (optional)
} ]]


local widgetVersion = 1
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("datepicker", widgetVersion) then return end

local datePickers = 0
local noDropDownCallback = false

local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER
local lang = string.lower(GetCVar("Language.2"))

--Event handler constants
local EVENT_HANDLER_NAMESPACE = "LAM2_Datepicker_Event"

--Constants visuals
local DEFAULT_DATEPICKER_WIDTH                      = 310
local DEFAULT_DATEPICKER_HEIGHT                     = 250
local DEFAULT_DATEPICKER_HEADLINE_LABEL_OFFSETX     = 0
local DEFAULT_DATEPICKER_HEADLINE_LABEL_OFFSETY     = 35
local DEFAULT_DATEPICKER_HEADLINE_LABEL_HEIGHT      = 20
local DEFAULT_DATEPICKER_HEADLINE_LABEL_WIDTH       = 35
local DEFAULT_DATEPICKER_LABEL_SPACE_BETWEEN        = 10
local DEFAULT_DATEPICKER_DAY_LABEL_HEIGHT           = 20
local DEFAULT_DATEPICKER_DAY_LABEL_WIDTH            = 35
local DEFAULT_DATEPICKER_DAY_LABEL_OFFSETY          = 10

local DEFAULT_DATEPICKER_HEADLINE_LABEL_FONT        = "ZoFontWinH3"
local DEFAULT_DATEPICKER_HEADLINE_LABEL_FONT_COLOR  = "%s"
local DEFAULT_DATEPICKER_DAY_LABEL_FONT             = "ZoFontWinH5"
local DEFAULT_DATEPICKER_DAY_LABEL_FONT_COLOR       = "|cAFAFAF%s|r"
local DEFAULT_DATEPICKER_DAY_LABEL_OTHER_MONTH_FONT_COLOR = "|c4D4D4D%s|r"
local DEFAULT_DATEPICKER_TODAY_LABEL_FONT_COLOR     = "|c00DD00%s|r"

--Constants date & time
local maxDaysInWeek     = 7
local maxMonths         = 12
local maxWeeksInMonth   = 5
--35 labels = 5 rows à 7 days, + 1 extra row where the start weekday is a saturday and thus not all 31 days fit into 35 fields
local maxCalendarLabels = maxDaysInWeek * (maxWeeksInMonth + 1)
local currentYear       = os.date("%Y")
local minYear           = 1970
local maxYear           = tonumber(currentYear) + 10

local offsetStartOfWeek = 0 --0=Sunday, 1=Monday, 2=Tuesday, ...

local weekDayNames      = LAM.util.L.WEEKDAYS
local weekDayNamesLong  = LAM.util.L.WEEKDAYS_LONG
local monthNames        = LAM.util.L.MONTHS
local monthNamesLong    = LAM.util.L.MONTHS_LONG
local dayLabelNameTemplate = "DayLabel_%s"

--Date functions
local function osTimeTable(dateTab)
    local newTimestamp
    if dateTab.year < minYear or (dateTab.year == minYear and dateTab.month <= 1 and
            dateTab.day <= 1) then
        newTimestamp = 0
    else
        newTimestamp = os.time(dateTab)
        if newTimestamp < 0 then
            newTimestamp = 0
        end
    end
    return newTimestamp
end

local function buildWeekDayNames()
--df("buildWeekDayNames")
    local calendarTabHeadLine = {}
    --Check if week starts with Sunday or other day
    if offsetStartOfWeek < 0 then offsetStartOfWeek = 0 end
    if offsetStartOfWeek > (maxDaysInWeek -1) then offsetStartOfWeek = maxDaysInWeek -1 end
    --Calendar headline with weekday names
    for weekDay = 1, maxDaysInWeek, 1 do
        calendarTabHeadLine[weekDay] = weekDayNames[weekDay + offsetStartOfWeek]
    end
    return calendarTabHeadLine
end

local function datePartsToTimestamp(dd, mm, yyyy, hh, MM, ss)
--df("datePartsToTimestamp - dd %s, mm %s, yyyy %s", tostring(dd), tostring(mm), tostring(yyyy))
 local timeStamp = osTimeTable({year=yyyy, month=mm, day=dd, hour=hh, minute=MM, seconds=ss})
 return timeStamp
end

local function getDateTable(timestamp)
    timestamp = timestamp or GetTimeStamp()
    --[[
    --os.date("*t", timestamp) -> returns dateTable = {
        year = 1998, month = 9, day = 16, yday = 259, wday = 4,
        hour = 23, min = 48, sec = 10, isdst = false
    }
    ]]
    return os.date("*t", timestamp)
end

local function get_first_weekday_of_month(mm, yyyy)
--df("year=%s,month=%s,day=%s", tostring(yyyy), tostring(mm), tostring(01))
  local weekday=os.date('*t', osTimeTable({year=yyyy,month=mm,day=1})).wday
  return weekday, (weekDayNames)[weekday]
end

local function get_days_in_month(month, year)
  local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  local d = days_in_month[month]
  -- check for leap year
  if (month == 2) then
    if year % 4 == 0 then
     if year % 100 == 0 then
      if year % 400 == 0 then
          d = 29
      end
     else
      d = 29
     end
    end
  end
  return d
end

local function getDateFormat(lang)
    local dateFormats = {
        --American format
        ["us"] = "%s/%s/%s",
        --German
        ["de"] = "%s.%s.%s",
        --French
        ["fr"] = "%s/%s/%s",
        --Russian
        ["ru"] = "%s.%s.%s",
    }
    lang = lang or "en"
    return dateFormats[lang] or dateFormats["en"]
end

local function buildDateFromData(data)
--df("buildDateFromData - headline: %s, lang: %s", tostring(data.isHeadline), tostring(lang))
    if not data then return end
    local dateStr, first, second, third
    if data.isHeadline == true then
        dateStr = data.weekDayName
    else
        local dateFormat = getDateFormat(lang)
        if lang == "en" then
            --American format
            first   = data.month
            second  = data.day
            third   = data.year
        elseif lang == "de" or lang == "fr" or lang == "ru" then
            first   = data.day
            second  = data.month
            third   = data.year
        end
        dateStr = string.format(dateFormat, tostring(first),tostring(second),tostring(third))
    end
    return dateStr
end

local function dayChecks(days)
    if days <= 0 then days = 1 end
    return days
end

local function monthChecks(months)
    if months <= 0 then months = 1 end
    return months
end

local function changePosOrNeg(posOrNeg, value)
    if value == nil then return end
    if posOrNeg == nil then posOrNeg = 1 end
    if posOrNeg < 0 then posOrNeg = -1 end
    return tonumber(posOrNeg * value)
end

local function changeDay(currentCalendarData, posOrNeg, days)
    if posOrNeg == nil then posOrNeg = 1 end
    local newDateTable = {
        year    = tonumber(currentCalendarData.year),
        month   = tonumber(currentCalendarData.month),
        day     = tonumber(currentCalendarData.day) + changePosOrNeg(posOrNeg, days),
    }
--df("changeDay - year %s, month %s, day %s", tostring(currentCalendarData.year), tostring(currentCalendarData.month), tostring(newDateTable.day))
    return getDateTable(osTimeTable(newDateTable))
end

local function changeMonth(currentCalendarData, posOrNeg, months)
    if posOrNeg == nil then posOrNeg = 1 end
    local newDateTable = {
        year    = tonumber(currentCalendarData.year),
        month   = tonumber(currentCalendarData.month) + changePosOrNeg(posOrNeg, months),
        day     = tonumber(currentCalendarData.day),
    }
--df("changeMonth - year %s, month %s, day %s", tostring(currentCalendarData.year), tostring(newDateTable.month), tostring(currentCalendarData.day))
    return getDateTable(osTimeTable(newDateTable))
end

local function changeYear(currentCalendarData, posOrNeg, years)
    if posOrNeg == nil then posOrNeg = 1 end
    local newDateTable = {
        year    = tonumber(currentCalendarData.year) + changePosOrNeg(posOrNeg, years),
        month   = tonumber(currentCalendarData.month),
        day     = tonumber(currentCalendarData.day),
    }
--df("changeYear - year %s, month %s, day %s", tostring(newDateTable.year), tostring(currentCalendarData.month), tostring(currentCalendarData.day))
    return getDateTable(osTimeTable(newDateTable))
end

local function getNewMonth(refToDatePicker, comboBox, nextOrPrev)
    local currentSelectedMonthIndex = comboBox.m_comboBox:GetSelectedItemData().value
--df("getMonth - current: %s", tostring(currentSelectedMonthIndex), tostring(nextOrPrev))
    local newMonth = currentSelectedMonthIndex
    if nextOrPrev > 0 then
        newMonth = newMonth + 1
        if newMonth > maxMonths then
            newMonth = 1
            --Increase the year
            if refToDatePicker:IncreaseYear(1) == nil then
                newMonth = currentSelectedMonthIndex
            end
        end
    else
        newMonth = newMonth - 1
        if newMonth <= 0 then
            newMonth = maxMonths
            --Decrease the year
            if refToDatePicker:DecreaseYear(1) == nil then
                newMonth = currentSelectedMonthIndex
            end
        end
    end
    return newMonth, currentSelectedMonthIndex
end


--Tooltip
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


--Global mouse up event
local shownDatePickerControl
local function getShownDatePickerControl()
    return shownDatePickerControl
end

local function setShownDatePickerControl(datePickerControl)
    shownDatePickerControl = datePickerControl
end

local clickedCount = 0
local function unregisterGlobalMouseUp()
--df("unregisterGlobalMouseUp")
    clickedCount = 0
    return EVENT_MANAGER:UnregisterForEvent(EVENT_HANDLER_NAMESPACE .. "_DatePicker_GlobalMouseUp", EVENT_GLOBAL_MOUSE_UP)
end

local function hideDatePicker(control)
    unregisterGlobalMouseUp()
    setShownDatePickerControl(nil)
    if control == nil then return end
    control:SetHidden(true)
    control:SetMouseEnabled(false)
end

local function onHide(control)
    control = control or getShownDatePickerControl()
    hideDatePicker(control)
end

local function callback_EVENT_GLOBAL_MOUSE_UP_dropdownDatePicker(eventId, button, ctrl, alt, shift, command)
    --df("Global OnMouseUp")
    local datePickerControl = getShownDatePickerControl()
    if datePickerControl == nil or (datePickerControl ~= nil and datePickerControl:IsControlHidden() == true) then
        return unregisterGlobalMouseUp()
    end
    clickedCount = clickedCount + 1
    --1st click will be the one on the dropdownbox itssel, directly closing it again
    if clickedCount == 1 then return end
    if button == MOUSE_BUTTON_INDEX_LEFT and (datePickerControl ~= nil and not MouseIsOver(datePickerControl)) then
--df("<<Clicked somewhere else! %s", tostring(controlBelowMouseName))
        onHide(datePickerControl)
        unregisterGlobalMouseUp()
    end
end

local function registerGlobalMouseUp()
    unregisterGlobalMouseUp()
    EVENT_MANAGER:RegisterForEvent(EVENT_HANDLER_NAMESPACE .. "_DatePicker_GlobalMouseUp",
            EVENT_GLOBAL_MOUSE_UP,
            callback_EVENT_GLOBAL_MOUSE_UP_dropdownDatePicker
    )
end

--Combobox
local function setComboBoxSelectedDateText(combobox, timestamp)
--df("setComboBoxSelectedDateText - value: %s", tostring(timestamp))
    if not combobox then return end
    local value = timestamp ~= nil and os.date("%x", timestamp) or ""
    combobox.m_comboBox.m_selectedItemText:SetText(value)
end

local function getValue(control)
--df("getValue - value: %s", tostring(control.data.getFunc()))
    return control.data.getFunc()
end

local function getSavedDatePickerData(p_selfVar)
    --Get values from getFunc here!
    local timeStampOfGetFunc = getValue(p_selfVar.control)
    --Currently: Current day
    local dateTable = getDateTable(timeStampOfGetFunc)
    local datePickerData = {
        dd      = dateTable.day,
        mm      = dateTable.month,
        yyyy    = dateTable.year,
    }
    return datePickerData
end

--Date picker update & disabled
local function UpdateDisabled(control)
    local disable
    if type(control.data.disabled) == "function" then
        disable = control.data.disabled()
    else
        disable = control.data.disabled
    end

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
        setComboBoxSelectedDateText(control.combobox, value)
    elseif value then
        control.data.setFunc(value)
        setComboBoxSelectedDateText(control.combobox, value)
        --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
        LAM.util.RequestRefreshIfNeeded(control)
    else
        value = control.data.getFunc()
        setComboBoxSelectedDateText(control.combobox, value)
    end
end


--Date picker headline and day labels
local function OnControlMouseEnter(labelControl)
    ShowTooltip(labelControl)
end

local function OnControlMouseExit(labelControl)
    HideTooltip()
end

local function updateAndClose(datePickerControl, data, doNotClose)
    doNotClose = doNotClose or false
    local timeStampToSave = datePartsToTimestamp(data.day, data.month, data.year, 0, 0, 0)
    UpdateValue(datePickerControl.invokerControl, false, timeStampToSave)
    datePickerControl.currentMonthCombobox.m_comboBox:SelectItemByIndex(tonumber(data.month))
    if not doNotClose then
        onHide(datePickerControl)
    end
end

local function OnLabelMouseUp(labelControl, mouseButton, upInside, shift, alt, ctrl, command)
    if not upInside then return end
    if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
        updateAndClose(labelControl:GetParent(), labelControl.data, false)
    end
end

--Datepicker combobox helper
local DatePicker = ZO_Object:Subclass()

function DatePicker:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function DatePicker:Initialize(panel, control, datepickerData)
    local combobox = control.combobox
    local selfVar = self
    self.panel = panel
    self.control = control
    self.combobox = combobox
    self.datepickerData = datepickerData

    if self.datepickerData.datePickerType == "normal" then
        --Sets self.control.datePickerControl
        self:CreateDatePicker()
        --else
        --todo: Maybe add other datepickers like a dateTimePicker
    end
    local datePickerControl = self.control.datePickerControl

    -- handle dropdown or settingsmenu opening/closing
    local function onShow(p_selfVar)
        return p_selfVar:ShowDatePicker(combobox, getSavedDatePickerData(p_selfVar))
    end
    local function doHide(closedPanel)
        if closedPanel == panel then
            onHide(datePickerControl)
        end
    end
    local function toggleShow(ctrl, mouseButton, upInside, shift, ctrl, alt, command)
        if not upInside or mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if datePickerControl:IsControlHidden() then
            onShow(selfVar)
        else
            onHide(datePickerControl)
        end
    end

    combobox:SetHandler("OnMouseUp", toggleShow)
    combobox:GetNamedChild("OpenDropdown"):SetHandler("OnMouseUp", toggleShow)
    combobox:SetHandler("OnEffectivelyHidden", function() onHide(datePickerControl) end)
    cm:RegisterCallback("LAM-PanelClosed", doHide)
end

function DatePicker:CreateDatePickerLabel(labelData, onlyUpdate)
--df("CreateDatePickerLabel - name: %s, onlyUpdate: %s", tostring(labelData.name), tostring(onlyUpdate))
    onlyUpdate = onlyUpdate or false
    local datePickerCtrl = self.control.datePickerControl
    local isHeadline = labelData.isHeadline

    local datePickerName = datePickerCtrl:GetName()
    local labelName = labelData.name
    --local label = GetControl(datePickerCtrl, labelName)
    local label = wm:GetControlByName(datePickerName, labelName)
    if label == nil then
        if onlyUpdate == true then
            df("[LibAddonMenu-2.0]ERROR: DatePicker label for update does not exist - name: %s", tostring(labelData.name))
            return
        end
        label = wm:CreateControl(datePickerName .. labelName, datePickerCtrl, CT_LABEL)
    else
--df("Found label: %s", tostring(datePickerName .. labelName))
    end

    local calendarHeadLineLabels    = self.control.calendarHeadLineLabels
    local calendarLabels            = self.control.calendarLabels

    --Reset old label data
    label:ClearAnchors()
    label.data = nil
    label.tooltip = nil
    label:SetHandler("OnMouseUp", nil)
    label:SetHandler("OnMouseEnter", nil)
    label:SetHandler("OnMouseExit", nil)

    --Set new label data
    label:SetFont(labelData.font or (isHeadline and DEFAULT_DATEPICKER_HEADLINE_LABEL_FONT) or DEFAULT_DATEPICKER_DAY_LABEL_FONT)
    label:SetHeight(labelData.height or (isHeadline and DEFAULT_DATEPICKER_HEADLINE_LABEL_HEIGHT) or DEFAULT_DATEPICKER_DAY_LABEL_HEIGHT)
    label:SetWidth(labelData.width or (isHeadline and DEFAULT_DATEPICKER_HEADLINE_LABEL_WIDTH) or DEFAULT_DATEPICKER_DAY_LABEL_WIDTH)

    label:SetWrapMode(labelData.wrapMode or TEXT_WRAP_MODE_ELLIPSIS)
    label:SetText(LAM.util.GetStringFromValue(labelData.text))
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    --label:SetDimensions(24, 24)
    --label:SetDimensionConstraints(24, 24, 24, 24)

    --7 Labels will be created and updated for the headline. The number will be given in labelData.headlineNr.
    --Headline
    if isHeadline then
        local headlineLabelNr = labelData.headlineNr
        if headlineLabelNr == 1 then
--df(">HEADLINE 1")
            label:SetAnchor(TOPLEFT, datePickerCtrl, TOPLEFT,
                    labelData.offsetX or DEFAULT_DATEPICKER_HEADLINE_LABEL_OFFSETX,
                    labelData.offsetY or DEFAULT_DATEPICKER_HEADLINE_LABEL_OFFSETY
            )
        else
            local lastHeadLineLabel = calendarHeadLineLabels[headlineLabelNr - 1]
local nam = lastHeadLineLabel and lastHeadLineLabel.GetName and lastHeadLineLabel:GetName() or "n/a"
--df(">HEADLINE %s, %s", tostring(headlineLabelNr), nam)
            if not lastHeadLineLabel then return end
            label:SetAnchor(TOPLEFT, lastHeadLineLabel, TOPRIGHT, DEFAULT_DATEPICKER_LABEL_SPACE_BETWEEN, 0)
        end

    --31 labels will be created and updated for the dayLabels. The number of the label will be given in labelData.dayNr.
    --No headline
    else
        local dayLabelNr = tonumber(labelData.dayNr)
        local row
        if dayLabelNr <= maxDaysInWeek then
            row = 1
        else
            row = zo_floor(dayLabelNr / maxDaysInWeek) + 1
        end
--df(">DAY row: %s, day: %s", tostring(row), tostring(dayLabelNr))
        local lastLabel
        if row == 1 then
            --Days (below the headline)
            lastLabel = calendarHeadLineLabels[dayLabelNr]
        else
            --Days (below other day labels)
            lastLabel = calendarLabels[dayLabelNr - maxDaysInWeek]
        end
        if not lastLabel then
--df("<!ERROR: LastLabel not found %s", tostring(dayLabelNr - maxDaysInWeek))
            return
        end
--df(">anchoring to %s", tostring(lastLabel:GetName()))
        label:SetAnchor(TOP, lastLabel, BOTTOM, 0, labelData.offsetY or DEFAULT_DATEPICKER_DAY_LABEL_OFFSETY)
    end

    label:SetHidden(labelData.hidden or false)
    label:SetMouseEnabled(labelData.mouseEnabled or false)

    label.data = labelData
    label.tooltip = buildDateFromData(labelData)

    if not labelData.noOnMouseUpHandler then
        label:SetHandler("OnMouseUp",   OnLabelMouseUp,         EVENT_HANDLER_NAMESPACE)
    end
    label:SetHandler("OnMouseEnter",    OnControlMouseEnter,    EVENT_HANDLER_NAMESPACE)
    label:SetHandler("OnMouseExit",     OnControlMouseExit,     EVENT_HANDLER_NAMESPACE)

    return label
end


function DatePicker:CreateLabelNow(labelData)
--d("CreateLabelNow")
    local mouseEnabled = labelData.mouseEnabled
    if mouseEnabled == nil then mouseEnabled = true end
    local dayText = labelData.dayText
    if not dayText then
        dayText                      = ""
        labelData.hidden             = true
        labelData.mouseEnabled       = false
        labelData.noOnMouseUpHandler = true
    end
    local labelDayData = {
        name            = string.format(dayLabelNameTemplate, tostring(labelData.dayNr)),
        text            = dayText,
        isHeadline      = false,
        dayNr           = labelData.dayNr,
        wrapMode        = TEXT_WRAP_MODE_ELLIPSIS,
        hidden          = labelData.hidden or false,
        mouseEnabled    = mouseEnabled,
        --payload with date info
        data = {
            day     = labelData.day,
            month   = labelData.month,
            year    = labelData.year,
            isToday = labelData.isToday,
            noOnMouseUpHandler = labelData.noOnMouseUpHandler
        }
    }
    return self:CreateDatePickerLabel(labelDayData, false)
end

function DatePicker:SetDate(dd, mm, yyyy)
    local newData = {yyyy=tonumber(yyyy), mm=tonumber(mm), dd=tonumber(dd)}
    local retVar = self:UpdateDatePickerData(newData)
    self:UpdateDatePickerUI()
    return retVar
end

function DatePicker:GetCurrentDateTable()
    local datePickerControl = self.control.datePickerControl
    local currentDatePickerDateTable = datePickerControl.calendarData
    if currentDatePickerDateTable == nil or currentDatePickerDateTable[-1] == nil then
        local todayData = self:GetToday()
        self:BuildCalendarData(todayData.day, todayData.month, todayData.year)
        currentDatePickerDateTable = self.control.datePickerControl.calendarData
    end
    return currentDatePickerDateTable[-1]
end

function DatePicker:GetCurrentDate(formatStr)
    formatStr = formatStr or "%x"
    local currentDateTable = self:GetCurrentDateTable()
    if currentDateTable == nil then return end
    return os.date(formatStr, osTimeTable(currentDateTable))
end

function DatePicker:DecreaseYear(years)
    years = years or 1
    --years = yearsChecks(years)
    local newDateResultTable = changeYear(self:GetCurrentDateTable(), -1, years)
    if newDateResultTable.year <= minYear then
        return
    end
    return self:SetDate(tonumber(newDateResultTable.day), tonumber(newDateResultTable.month), tonumber(newDateResultTable.year))
end

function DatePicker:IncreaseYear(years)
    years = years or 1
    --years = yearsChecks(years)
    local newDateResultTable = changeYear(self:GetCurrentDateTable(), 1, years)
    if newDateResultTable.year >= maxYear then
        return
    end
    return self:SetDate(tonumber(newDateResultTable.day), tonumber(newDateResultTable.month), tonumber(newDateResultTable.year))
end

function DatePicker:SetYear(yyyy)
    --Update the currently shown datePicker with the same month, and day, and the new selected year
    local currentCalendarData = self:GetCurrentDateTable()
    if currentCalendarData.year == yyyy then return end
    return self:SetDate(tonumber(currentCalendarData.day), tonumber(currentCalendarData.month), tonumber(yyyy))
end

function DatePicker:DecreaseMonth(months)
    months = months or 1
    months = monthChecks(months)
    local newDateResultTable = changeMonth(self:GetCurrentDateTable(), -1, months)
    return self:SetDate(tonumber(newDateResultTable.day), tonumber(newDateResultTable.month), tonumber(newDateResultTable.year))
end

function DatePicker:IncreaseMonth(months)
    months = months or 1
    months = monthChecks(months)
    local newDateResultTable = changeMonth(self:GetCurrentDateTable(), 1, months)
    return self:SetDate(tonumber(newDateResultTable.day), tonumber(newDateResultTable.month), tonumber(newDateResultTable.year))
end

function DatePicker:SetMonth(mm)
    --Update the currently shown datePicker with the same month, and day, and the new selected year
    local currentCalendarData = self:GetCurrentDateTable()
--df("SetMonth - year %s, month %s, day %s", tostring(currentCalendarData.year), tostring(currentCalendarData.month), tostring(currentCalendarData.day))
    if currentCalendarData.month == mm then return end
    return self:SetDate(tonumber(currentCalendarData.day), tonumber(mm), tonumber(currentCalendarData.year))
end

function DatePicker:DecreaseDay(days)
    days = days or 1
    days = dayChecks(days)
    local newDateResultTable = changeDay(self:GetCurrentDateTable(), -1, days)
    return self:SetDate(tonumber(newDateResultTable.day), tonumber(newDateResultTable.month), tonumber(newDateResultTable.year))
end

function DatePicker:IncreaseDay(days)
    days = days or 1
    days = dayChecks(days)
    local newDateResultTable = changeDay(self:GetCurrentDateTable(), 1, days)
    return self:SetDate(tonumber(newDateResultTable.day), tonumber(newDateResultTable.month), tonumber(newDateResultTable.year))
end

function DatePicker:SetDay(dd)
    --Update the currently shown datePicker with the same month, and day, and the new selected year
    local currentCalendarData = self:GetCurrentDateTable()
    if currentCalendarData.day == dd then return end
    return self:SetDate(tonumber(dd), tonumber(currentCalendarData.month), tonumber(currentCalendarData.year))
end

function DatePicker:GetToday()
    local currentDayDateTable = getDateTable()
    return currentDayDateTable
end

function DatePicker:SetToday(doNotClose)
    doNotClose = doNotClose or false
    local todayData = self:GetToday()
    self:SetDate(tonumber(todayData.day), tonumber(todayData.month), tonumber(todayData.year))
    updateAndClose(self.control.datePickerControl, todayData, doNotClose)
    return todayData
end

function DatePicker:OnYearSpinnerValueChanged(yyyy)
    self:SetYear(yyyy)
    self:UpdateDatePickerUI()
end

--Datepicker calendar
function DatePicker:BuildCalendarData(dd, mm, yyyy)
--df("buildCalendarData - day: %s, month: %s, year: %s", tostring(dd), tostring(mm), tostring(yyyy))
    local datePickerControl = self.control.datePickerControl
    local daysInSelectedMonth = get_days_in_month(mm, yyyy)
    --Returns the weekday number (1=Sunday, 2=Monday, ... 7=Saturday) of the first day of the month
    local firstWeekdayOfSelectedMonth, firstWeekdayNameOfSelectedMonth = get_first_weekday_of_month(mm, yyyy)
--df(">daysInSelectedMonth: %s, firstWeekdayOfSelectedMonth: %s, firstWeekdayNameOfSelectedMonth: %s", tostring(daysInSelectedMonth), tostring(firstWeekdayOfSelectedMonth), tostring(firstWeekdayNameOfSelectedMonth))
    local todayData = self:GetToday()
    local todayDay = tonumber(todayData.day)
    local todayWDay = todayData.wday
    local todayMonth = tonumber(todayData.month)
    local todayYear = tonumber(todayData.year)
    LibAddonMenu2._todayDay = todayDay
    LibAddonMenu2._todayWDay = todayWDay
    LibAddonMenu2._todayData = todayData
    LibAddonMenu2._days_in_month = daysInSelectedMonth
    LibAddonMenu2._first_day_nr_of_week_in_month = firstWeekdayOfSelectedMonth
    LibAddonMenu2._first_day_name_of_week_in_month = firstWeekdayNameOfSelectedMonth
    LibAddonMenu2._first_day_nr_of_week_in_monthDay = dd
    LibAddonMenu2._first_day_nr_of_week_in_monthMonth = mm
    LibAddonMenu2._first_day_nr_of_week_in_monthYear = yyyy

    local calendarTab = {}

    --Add the selected day, month and year into the row -1
    calendarTab[-1] = {
        day     = dd,
        month   = mm,
        year    = yyyy
    }

    --Criteria to use:
    --maxDaysInMonth                    -- Number of the max days in any month (31)
    --firstWeekdayOfSelectedMonth       -- Number of the first weekday in the month (e.g. 0=Sunday, 1=Monday, ...)
    --daysInSelectedMonth               -- Number of the days in the currently seleted month

    --Create 1 table row with 31 entries for the 31 pre-created day labels
    calendarTab[1] = {}
    local dayInCurrentMonth, day, month, year
    local isToday = false
    local startingWeekdayFound = false
    local isBeforeStartingWeekday = false
    local isAfterEndOfMonthDays = false
    local isValidInMonth = false
    local offset = firstWeekdayOfSelectedMonth - 1 --(where 1 is Sunday. If start would be monday it should be - 2)
    local newMonthDay = 0
--df(">offset: " ..tostring(offset))
    dayInCurrentMonth = 0
    for dayLabel = 1, maxCalendarLabels, 1 do --use 35 labels!
        --The day that should be added is before the first weekday of the currently selected month (e.g. day 1 would be
        --Sunday in the calendar, but the month starts at a Tuesday. Sunday + Monday are days before the starting weekday)
        --[[
        dateTable = {
            year = 1998, month = 9, day = 16, yday = 259, wday = 4,
            hour = 23, min = 48, sec = 10, isdst = false
        }
        ]]
        local dayToUse
        if (dayLabel -1) < offset then
            isBeforeStartingWeekday = true
            dayToUse = (offset - dayLabel) *  -1 --count the days backwards
            month = mm
        else
            isBeforeStartingWeekday = false
            startingWeekdayFound = true
            dayInCurrentMonth = dayInCurrentMonth + 1
            isAfterEndOfMonthDays = dayInCurrentMonth > daysInSelectedMonth
            if isAfterEndOfMonthDays == true then
                newMonthDay = newMonthDay + 1
                dayToUse = daysInSelectedMonth + newMonthDay
                month = mm
            else
                dayToUse = dayInCurrentMonth
                month = mm
            end
        end
        isValidInMonth = dayInCurrentMonth <= daysInSelectedMonth

        local dateTable = getDateTable(osTimeTable({day=dayToUse, month=month, year=yyyy}))
--df(">>dayLabel: %s, day: %s, month: %s, year: %s, wday: %s, isBeforeStartWday: %s, isAfterEndOfMonthDays: %s", tostring(dayLabel), tostring(dayToUse), tostring(month), tostring(yyyy), tostring(dateTable.wday), tostring(isBeforeStartingWeekday), tostring(isAfterEndOfMonthDays))
        --Was the starting weekday found?
        day     = dateTable.day
        month   = dateTable.month
        year    = dateTable.year

        local dayStr = tostring(day)
        if tonumber(month) == todayMonth and tonumber(day) == todayDay and tonumber(year) == todayYear then
            isToday = true
            dayStr = string.format(DEFAULT_DATEPICKER_DAY_LABEL_FONT_COLOR, "[") ..
                    string.format(DEFAULT_DATEPICKER_TODAY_LABEL_FONT_COLOR, dayStr) ..
                    string.format(DEFAULT_DATEPICKER_DAY_LABEL_FONT_COLOR, "]")
        else
            if isBeforeStartingWeekday == true or isAfterEndOfMonthDays == true then
               dayStr = string.format(DEFAULT_DATEPICKER_DAY_LABEL_OTHER_MONTH_FONT_COLOR, dayStr)
            else
               dayStr = string.format(DEFAULT_DATEPICKER_DAY_LABEL_FONT_COLOR, dayStr)
            end
        end

        --Add the day data to the dayLabel's table entry
        calendarTab[1][dayLabel] = {
            isHeadline              = false,
            isValidInMonth          = isValidInMonth,
            isBeforeStartingWeekday = isBeforeStartingWeekday,
            isAfterEndOfMonthDays   = isAfterEndOfMonthDays,
            dayNr                   = dayLabel,
            day                     = day,
            text                    = dayStr,
            month                   = month,
            year                    = year,
            isToday                 = isToday,
            weekDay                 = dateTable.wday,
            yearDay                 = dateTable.yday
            --weekOfYear            = tbd
        }
    end

    datePickerControl.calendarData = calendarTab
    LibAddonMenu2._calendarTab = calendarTab

    return calendarTab
end

function DatePicker:AssignCalendarData()
--df("assignCalendarData")
    local datePickerControl = self.control.datePickerControl
    local calendarData      = datePickerControl.calendarData
    if datePickerControl == nil or calendarData == nil then return end
    --Get the calendar's base date info: day, month, year
    local baseData = calendarData[-1]
--df(">day: %s, month: %s, year: %s", tostring(baseData.day), tostring(baseData.month), tostring(baseData.year))

    --Set the current month label
    if datePickerControl.currentMonthLabel ~= nil then
        datePickerControl.currentMonthLabel:SetText(monthNamesLong[tonumber(baseData.month)])
    end
    --Set the current year label
    if datePickerControl.currentYearSpinner ~= nil then
        datePickerControl.currentYearSpinner.spinner:SetValue(tonumber(baseData.year))
    end

    --Apply the build month day data to the prebuild day labels
    local calandarDaysOfMonthData = calendarData[1]
    for dayLabelNr=1, #calandarDaysOfMonthData, 1 do
        local dayLabelData = calandarDaysOfMonthData[dayLabelNr]
        local isValidDayInMonth = dayLabelData.isValidInMonth
        --dayLabelData.dayNr -> Will be set within DatePickerDropdownHelper:buildCalendarData(dd, mm, yyyy) already!
        dayLabelData.name           = string.format(dayLabelNameTemplate, tostring(dayLabelData.dayNr))
        dayLabelData.hidden         = false
        dayLabelData.mouseEnabled   = true
--df(">dayLabelNr: %s, dayNr: %s, isValidDayInMonth: %s, hidden: %s", tostring(dayLabelNr), tostring(dayLabelData.dayNr), tostring(isValidDayInMonth), tostring(dayLabelData.hidden))
        self:CreateDatePickerLabel(dayLabelData, true)
    end

    return calendarData
end

function DatePicker:UpdateDatePickerData(data)
--df("DatePicker:UpdateDatePickerData - year %s, month %s, day %s", tostring(data.yyyy), tostring(data.mm), tostring(data.dd))
    self:BuildCalendarData(data.dd, data.mm, data.yyyy)
    return self:AssignCalendarData()
end

function DatePicker:UpdateDatePickerUI(anchorTo)
--df("updateDatePickerUI")
    local datePickerControl = self.control.datePickerControl
    anchorTo = anchorTo or self.control.combobox

    datePickerControl:ClearAnchors()
    datePickerControl:SetDimensions(DEFAULT_DATEPICKER_WIDTH, DEFAULT_DATEPICKER_HEIGHT)
    datePickerControl:SetDimensionConstraints(DEFAULT_DATEPICKER_WIDTH, DEFAULT_DATEPICKER_HEIGHT, DEFAULT_DATEPICKER_WIDTH, DEFAULT_DATEPICKER_HEIGHT)
    datePickerControl:SetDrawLayer(DL_CONTROLS)
    datePickerControl:SetDrawTier(DT_PARENT)
    datePickerControl:SetDrawLevel(1)
    datePickerControl:SetMouseEnabled(true)
    datePickerControl:SetMovable(false)
    datePickerControl:SetClampedToScreen(true)
    datePickerControl:SetAnchor(TOPLEFT, anchorTo, BOTTOMLEFT, 0, 0)
end


function DatePicker:ShowDatePicker(anchorTo, data)
    anchorTo = anchorTo or self.combobox
    local datePickerControl = self.control.datePickerControl

    self:UpdateDatePickerData(data)
    self:UpdateDatePickerUI(anchorTo)

    datePickerControl:SetHidden(false)
    datePickerControl:SetMouseEnabled(true)

    setShownDatePickerControl(datePickerControl)

    --Enable the global mouse click = close the date picker TLC, if not clicked on the TLC
    registerGlobalMouseUp()
    return true
end

--Datepicker creation & show/hide
function DatePicker:CreateDatePicker()
    local selfRef = self
    --Create top level control for the date picker
    local datePickerControl = self.control.datePickerControl
    if datePickerControl ~= nil then return end
    datePickers = datePickers + 1
    datePickerControl = wm:CreateTopLevelWindow("LAMDatePickerTLC_" .. tostring(datePickers))
    self.control.datePickerControl              = datePickerControl
    datePickerControl.invokerControl            = self.control

    datePickerControl:SetHidden(true)
    self:UpdateDatePickerUI(self.combobox)

    --Backdrop background
    local datePickerBg = wm:CreateControlFromVirtual("$(parent)BG", datePickerControl, "ZO_DefaultBackdrop") --"ZO_DarkThinFrame"
    datePickerBg:SetAnchorFill()
    datePickerBg:SetDrawLayer(DL_BACKGROUND)
    datePickerBg:SetDrawTier(DT_LOW)
    datePickerBg:SetDrawLevel(1)
    datePickerBg:SetMouseEnabled(true)

    --Create the currently selected month label
    --[[
    local datePickerCurrentMonthLabel = wm:CreateControl("$(parent)CurrentMonthLabel", datePickerControl, CT_LABEL)
    datePickerControl.currentMonthLabel         = datePickerCurrentMonthLabel
    datePickerCurrentMonthLabel:SetDimensions(50, 24)
    datePickerCurrentMonthLabel:SetDimensionConstraints(50, 24, 230, 24)
    datePickerCurrentMonthLabel:SetResizeToFitDescendents(true)
    datePickerCurrentMonthLabel:SetFont(DEFAULT_DATEPICKER_HEADLINE_LABEL_FONT)
    datePickerCurrentMonthLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    datePickerCurrentMonthLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    datePickerCurrentMonthLabel:SetAnchor(TOPRIGHT, datePickerControl, TOP, 10, 5)
    datePickerCurrentMonthLabel:SetDrawLayer(DL_CONTROLS)
    datePickerCurrentMonthLabel:SetDrawTier(DT_PARENT)
    datePickerCurrentMonthLabel:SetDrawLevel(1)
    datePickerCurrentMonthLabel:SetMouseEnabled(true) --todo Maybe add a context menu to choose a month, or make a click change it to an editbox
    ]]

    --Add a dropdown to the month label
    local datePickerCurrentMonthsCombobox = wm:CreateControlFromVirtual("$(parent)MonthCombobox", datePickerControl, "ZO_ComboBox")
    datePickerControl.currentMonthCombobox = datePickerCurrentMonthsCombobox
    datePickerCurrentMonthsCombobox:SetDimensions(120, 24)
    datePickerCurrentMonthsCombobox:SetDimensionConstraints(120, 24, 120, 24)
    datePickerCurrentMonthsCombobox:SetResizeToFitDescendents(true)
    datePickerCurrentMonthsCombobox:SetAnchor(TOPRIGHT, datePickerControl, TOP, 14, 10)
    datePickerCurrentMonthsCombobox:SetDrawLayer(DL_CONTROLS)
    datePickerCurrentMonthsCombobox:SetDrawTier(DT_PARENT)
    datePickerCurrentMonthsCombobox:SetDrawLevel(1)
    datePickerCurrentMonthsCombobox:SetMouseEnabled(true)
    datePickerCurrentMonthsCombobox:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(self.control) end)
    datePickerCurrentMonthsCombobox:SetHandler("OnMouseExit", function() ZO_Options_OnMouseExit(self.control) end)

    self.control.dropdown = ZO_ComboBox_ObjectFromContainer(datePickerCurrentMonthsCombobox)
    local datePickerCurrentMonthsDropdown = self.control.dropdown
    datePickerCurrentMonthsDropdown:SetSortsItems(false) -- need to sort ourselves in order to be able to sort by value
    local function monthDropdownCallback(control, entryText, entry)
        if noDropDownCallback == true then
            noDropDownCallback = false
            return
        end
        local selfVar = entry.selfVar
        --df("Dropdown month selected %s", tostring(entry.value))
        selfVar:SetMonth(entry.value)
        selfVar:UpdateDatePickerUI()
    end
    for i = 1, #monthNamesLong do
        local entry = ZO_ComboBox:CreateItemEntry(monthNamesLong[i], monthDropdownCallback)
        entry.control = self.control
        entry.selfVar = self
        entry.value = i
        datePickerCurrentMonthsDropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
    end
    ZO_PreHook(datePickerCurrentMonthsDropdown, "ShowDropdownInternal", function()
        unregisterGlobalMouseUp()
    end)
    ZO_PreHook(datePickerCurrentMonthsDropdown, "HideDropdownInternal", function()
        registerGlobalMouseUp()
    end)

    local savedDateData = getSavedDatePickerData(self)
    local monthIndex = savedDateData.mm or self:GetToday().month
    noDropDownCallback = true
    datePickerCurrentMonthsCombobox.m_comboBox:SelectItemByIndex(monthIndex) --Select entry by SavedVars month, or current month

    datePickerControl.currentMonthDropdown = datePickerCurrentMonthsDropdown

    --Create the currently selected year spinner
    local datePickerCurrentYearSpinner = wm:CreateControlFromVirtual("$(parent)CurrentYearSpinner", datePickerControl, "ZO_EditSpinner")
    datePickerControl.currentYearSpinner        = datePickerCurrentYearSpinner
    datePickerCurrentYearSpinner:SetDimensions(70, 32)
    datePickerCurrentYearSpinner:SetDimensionConstraints(70, 32, 70, 32)
    datePickerCurrentYearSpinner:SetResizeToFitDescendents(true)
    --datePickerCurrentYearSpinner:SetAnchor(LEFT, datePickerCurrentMonthLabel, RIGHT, 10, 0)
    datePickerCurrentYearSpinner:SetAnchor(LEFT, datePickerCurrentMonthsCombobox, RIGHT, 20, 0)
    datePickerCurrentYearSpinner:SetDrawLayer(DL_CONTROLS)
    datePickerCurrentYearSpinner:SetDrawTier(DT_PARENT)
    datePickerCurrentYearSpinner:SetDrawLevel(1)
    datePickerCurrentYearSpinner:SetMouseEnabled(true) --todo Maybe add a context menu to choose a year, or make a click change it to an editbox
    datePickerCurrentYearSpinner.spinner = ZO_Spinner:New(datePickerCurrentYearSpinner, minYear, maxYear)
    datePickerCurrentYearSpinner.spinner:RegisterCallback("OnValueChanged", function(value)
        if selfRef.control.datePickerControl.currentYearSpinner.dontCallOnValueChanged == true then return end
        selfRef:OnYearSpinnerValueChanged(value)
    end)
    self.control.datePickerControl.currentYearSpinner.dontCallOnValueChanged = true
    datePickerCurrentYearSpinner.spinner:SetValue(tonumber(currentYear))
    self.control.datePickerControl.currentYearSpinner.dontCallOnValueChanged = false

    --Create the year spinner's "current year" button
    local datePickerCurrentYearButton = wm:CreateControl("$(parent)CurrentYearButton", datePickerControl, CT_BUTTON)
    datePickerControl.currentYearButton         = datePickerCurrentYearButton
    datePickerCurrentYearButton:SetDimensions(12, 12)
    datePickerCurrentYearButton:SetNormalTexture("EsoUI/Art/ActionBar/passiveAbilityFrame_round_up.dds")
    datePickerCurrentYearButton:SetPressedTexture("EsoUI/Art/ActionBar/passiveAbilityFrame_round_down.dds")
    datePickerCurrentYearButton:SetMouseOverTexture("EsoUI/Art/ActionBar/passiveAbilityFrame_round_over.dds")
    datePickerCurrentYearButton:SetDisabledTexture("EsoUI/Art/ActionBar/passiveAbilityFrame_round_up.dds")

    datePickerCurrentYearButton:SetAnchor(LEFT, datePickerCurrentYearSpinner, RIGHT, 4, 0)
    datePickerCurrentYearButton:SetMouseEnabled(true)
    datePickerCurrentYearButton:SetHandler("OnClicked", function(buttonCtrl)
        datePickerCurrentYearSpinner.spinner:SetValue(tonumber(currentYear))
    end)
    datePickerCurrentYearButton.tooltip = LAM.util.L.CURRENT_YEAR
    datePickerCurrentYearButton:SetHandler("OnMouseEnter", OnControlMouseEnter)
    datePickerCurrentYearButton:SetHandler("OnMouseExit", OnControlMouseExit)

    --Create the month left button
    local datePickerMonthMinusButton = wm:CreateControl("$(parent)MonthMinusButton", datePickerControl, CT_BUTTON)
    datePickerControl.currentMonthMinusButton   = datePickerMonthMinusButton
    datePickerMonthMinusButton:SetDimensions(20, 20)
    datePickerMonthMinusButton:SetNormalTexture("/esoui/art/buttons/leftarrow_up.dds")
    datePickerMonthMinusButton:SetPressedTexture("/esoui/art/buttons/leftarrow_down.dds")
    datePickerMonthMinusButton:SetMouseOverTexture("/esoui/art/buttons/leftarrow_over.dds")
    datePickerMonthMinusButton:SetDisabledTexture("/esoui/art/buttons/leftarrow_disabled.dds")

    datePickerMonthMinusButton:SetAnchor(TOPLEFT, datePickerControl, TOPLEFT, 4, 6)
    datePickerMonthMinusButton:SetMouseEnabled(true)
    datePickerMonthMinusButton:SetHandler("OnClicked", function(buttonCtrl)
        --selfRef:DecreaseMonth(1)
        local newMonth, currentMonth = getNewMonth(selfRef, datePickerCurrentMonthsCombobox, -1)
        if newMonth ~= currentMonth then
            datePickerCurrentMonthsCombobox.m_comboBox:SelectItemByIndex(newMonth)
            selfRef:UpdateDatePickerUI()
        end
    end)
    datePickerMonthMinusButton.tooltip = LAM.util.L.PREVIOUS_MONTH
    datePickerMonthMinusButton:SetHandler("OnMouseEnter", OnControlMouseEnter)
    datePickerMonthMinusButton:SetHandler("OnMouseExit", OnControlMouseExit)

    --Create the month right button
    local datePickerMonthPlusButton = wm:CreateControl("$(parent)MonthPlusButton", datePickerControl, CT_BUTTON)
    datePickerControl.currentMonthPlusButton    = datePickerMonthPlusButton
    datePickerMonthPlusButton:SetDimensions(20, 20)
    datePickerMonthPlusButton:SetNormalTexture("/esoui/art/buttons/rightarrow_up.dds")
    datePickerMonthPlusButton:SetPressedTexture("/esoui/art/buttons/rightarrow_down.dds")
    datePickerMonthPlusButton:SetMouseOverTexture("/esoui/art/buttons/rightarrow_over.dds")
    datePickerMonthPlusButton:SetDisabledTexture("/esoui/art/buttons/rightarrow_disabled.dds")

    datePickerMonthPlusButton:SetAnchor(TOPRIGHT, datePickerControl, TOPRIGHT, -8, 6)
    datePickerMonthPlusButton:SetMouseEnabled(true)
    datePickerMonthPlusButton:SetHandler("OnClicked", function(buttonCtrl)
        --selfRef:IncreaseMonth(1)
        local newMonth, currentMonth = getNewMonth(selfRef, datePickerCurrentMonthsCombobox, 1)
        if newMonth ~= currentMonth then
            datePickerCurrentMonthsCombobox.m_comboBox:SelectItemByIndex(newMonth)
            selfRef:UpdateDatePickerUI()
        end
    end)
    datePickerMonthPlusButton.tooltip = LAM.util.L.NEXT_MONTH
    datePickerMonthPlusButton:SetHandler("OnMouseEnter", OnControlMouseEnter)
    datePickerMonthPlusButton:SetHandler("OnMouseExit", OnControlMouseExit)

    --Create current day button
    local datePickerCurrentDayButton = wm:CreateControl("$(parent)CurrentDayButton", datePickerControl, CT_BUTTON)
    datePickerControl.currentDayButton    = datePickerCurrentDayButton
    datePickerCurrentDayButton:SetDimensions(14, 12)
    datePickerCurrentDayButton:SetNormalTexture("/esoui/art/buttons/scrollbox_uparrow_up.dds")
    datePickerCurrentDayButton:SetPressedTexture("/esoui/art/buttons/scrollbox_uparrow_down.dds")
    datePickerCurrentDayButton:SetMouseOverTexture("/esoui/art/buttons/scrollbox_uparrow_over.dds")
    datePickerCurrentDayButton:SetDisabledTexture("/esoui/art/buttons/scrollbox_uparrow_disabled.dds")

    datePickerCurrentDayButton:SetAnchor(LEFT, datePickerMonthMinusButton, RIGHT, 6, -2)
    datePickerCurrentDayButton:SetMouseEnabled(true)
    datePickerCurrentDayButton:SetHandler("OnClicked", function(buttonCtrl)
        local todayData = selfRef:SetToday()
        noDropDownCallback = true
        datePickerCurrentMonthsCombobox.m_comboBox:SelectItemByIndex(todayData.month)
    end)
    datePickerCurrentDayButton.tooltip = LAM.util.L.TODAY
    datePickerCurrentDayButton:SetHandler("OnMouseEnter", OnControlMouseEnter)
    datePickerCurrentDayButton:SetHandler("OnMouseExit", OnControlMouseExit)


    --Create the headline "Weekdays" label controls
    --Add the headline as labels
    local calendarTabHeadLine    = buildWeekDayNames()
    self.control.calendarHeadLineLabels = {}
    for weekDay=1, maxDaysInWeek, 1 do
        local weekDayName = calendarTabHeadLine[weekDay]
        local labelHeadlineData = {
            name    = "headerWeekDay_" .. tostring(weekDay),
            text    = string.format(DEFAULT_DATEPICKER_HEADLINE_LABEL_FONT_COLOR, weekDayName),
            isHeadline = true,
            headlineNr  = weekDay,
            weekDay = weekDay,
            weekDayName = weekDayName,
            wrapMode = TEXT_WRAP_MODE_ELLIPSIS,
            hidden = false,
            mouseEnabled = true,
            noOnMouseUpHandler = true,
        }
       self.control.calendarHeadLineLabels[weekDay] = self:CreateDatePickerLabel(labelHeadlineData, false)
    end

    --Create the "days of month" label controls (for all 31 days, empty and hidden for now)
    --Add the days as labels
    self.control.calendarLabels = {}
    for dayLabelsCreated=1, maxCalendarLabels, 1 do
--df(">>Creating empty day %s label", tostring(dayLabelsCreated))
        local dayLabelEmptyData = {}
        dayLabelEmptyData.dayNr         = dayLabelsCreated
        dayLabelEmptyData.hidden        = true
        dayLabelEmptyData.mouseEnabled  = false

        self.control.calendarLabels[dayLabelsCreated] = self:CreateLabelNow(dayLabelEmptyData)
    end
end


function LAMCreateControl.datepicker(parent, datepickerData, controlName)
    local control = LAM.util.CreateLabelAndContainerControl(parent, datepickerData, controlName)

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

    datepickerData.datePickerType = datepickerData.datePickerType or "normal"
    control.datePicker = DatePicker:New(LAM.util.GetTopPanel(parent), control, datepickerData)

    if datepickerData.warning ~= nil or datepickerData.requiresReload then
        control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
        control.warning:SetAnchor(RIGHT, combobox, LEFT, -5, 0)
        control.UpdateWarning = LAM.util.UpdateWarning
        control:UpdateWarning()
    end

    control.UpdateValue = UpdateValue
    control:UpdateValue()

    if datepickerData.disabled ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)
    LAM.util.RegisterForReloadIfNeeded(control)

    return control
end
