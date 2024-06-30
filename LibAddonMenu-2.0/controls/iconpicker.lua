---@class LAM2_IconPickerData: LAM2_LabelAndContainerControlData
---@field type "iconpicker"
---@field choices string[] ex. {"texture path 1", "texture path 2", "texture path 3"}
---@field getFunc fun(): string ex. function() return db.var end
---@field setFunc fun(string) ex. function(var) db.var = var doStuff() end
---@field choicesTooltips nil|Stringy[] ex. {"icon tooltip 1", "icon tooltip 2", "icon tooltip 3"}
---@field maxColumns nil|integer number of icons in one row ex. 5
---@field visibleRows nil|number number of visible rows ex. 4.5
---@field iconSize nil|integer size of the icons ex. 28
---@field defaultColor nil|ZO_ColorDef default color of the icons ex. ZO_ColorDef:New("FFFFFF")
---@field beforeShow nil|fun(control: LAM2_IconPicker, iconPicker: IconPickerMenu): boolean ex. function(control, iconPicker) return preventShow end
---@field disabled nil|boolean|fun(): boolean ex. function() return db.someBooleanSetting
---@field warning nil|Stringy ex. "May cause permanent awesomeness"
---@field requiresReload nil|boolean if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed.
---@field default nil|Stringy ex. defaults.var
---@field helpUrl nil|Stringy ex. "https://www.esoui.com/portal.php?id=218&a=faq"
---@field resetFunc nil|fun(iconpickerControl: LAM2_IconPicker) custom function to run after the control is reset to defaults ex. function(iconpickerControl) d("defaults reset") end


local widgetVersion = 11
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("iconpicker", widgetVersion) then return end

local wm = WINDOW_MANAGER

---@class IconPickerIcon: TextureControl
---@field color ZO_ColorDef
---@field size integer
---@field texture string
---@field tooltip string
---@field OnSelect fun(icon: IconPickerIcon, texture: string)

---@class IconPickerMenu: ZO_Object
---@field control TopLevelWindow
local IconPickerMenu = ZO_Object:Subclass()
local iconPicker
LAM.util.GetIconPickerMenu = function()
    if not iconPicker then
        iconPicker = IconPickerMenu:New("LAMIconPicker")
        local sceneFragment = LAM:GetAddonSettingsFragment()
        ZO_PreHook(sceneFragment, "OnHidden", function()
            if not iconPicker.control:IsHidden() then
                iconPicker:Clear()
            end
        end)
    end
    return iconPicker
end

function IconPickerMenu:New(...)
    local object = ZO_Object.New(self) --[[@as IconPickerMenu]]
    object:Initialize(...)
    return object
end

function IconPickerMenu:Initialize(name)
    local control = wm:CreateTopLevelWindow(name)
    control:SetDrawTier(DT_HIGH)
    control:SetHidden(true)
    self.control = control

    local scrollContainer = wm:CreateControlFromVirtual(name .. "ScrollContainer", control, "ZO_ScrollContainer")
    -- control:SetDimensions(control.container:GetWidth(), height) -- adjust to icon size / col count
    scrollContainer:SetAnchorFill()
    ZO_Scroll_SetUseFadeGradient(scrollContainer, false)
    ZO_Scroll_SetHideScrollbarOnDisable(scrollContainer, false)
    ZO_VerticalScrollbarBase_OnMouseExit(scrollContainer:GetNamedChild("ScrollBar")) -- scrollbar initialization seems to be broken so we force it to update the correct alpha value
    local scroll = GetControl(scrollContainer, "ScrollChild")
    self.scroll = scroll
    self.scrollContainer = scrollContainer

    local bg = wm:CreateControl(nil, scrollContainer, CT_BACKDROP) --[[@as BackdropControl]]
    bg:SetAnchor(TOPLEFT, scrollContainer, TOPLEFT, 0, -3)
    bg:SetAnchor(BOTTOMRIGHT, scrollContainer, BOTTOMRIGHT, 2, 5)
    bg:SetEdgeTexture("EsoUI\\Art\\Tooltips\\UI-Border.dds", 128, 16)
    bg:SetCenterTexture("EsoUI\\Art\\Tooltips\\UI-TooltipCenter.dds")
    bg:SetInsets(16, 16, -16, -16)

    local mungeOverlay = wm:CreateControl(nil, bg, CT_TEXTURE) --[[@as TextureControl]]
    mungeOverlay:SetTexture("EsoUI/Art/Tooltips/munge_overlay.dds")
    mungeOverlay:SetDrawLevel(1)
    mungeOverlay:SetAddressMode(TEX_MODE_WRAP)
    mungeOverlay:SetAnchorFill()

    local mouseOver = wm:CreateControl(nil, scrollContainer, CT_TEXTURE) --[[@as TextureControl]]
    mouseOver:SetDrawLevel(2)
    mouseOver:SetTexture("EsoUI/Art/Buttons/minmax_mouseover.dds")
    mouseOver:SetHidden(true)

    local function IconFactory(pool)
        local icon = wm:CreateControl(name .. "Entry" .. pool:GetNextControlId(), scroll, CT_TEXTURE) --[[@as IconPickerIcon]]
        icon:SetMouseEnabled(true)
        icon:SetDrawLevel(3)
        icon:SetDrawLayer(DL_CONTROLS)
        icon:SetHandler("OnMouseEnter", function()
            mouseOver:SetAnchor(TOPLEFT, icon, TOPLEFT, 0, 0)
            mouseOver:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 0, 0)
            mouseOver:SetHidden(false)
            if self.customOnMouseEnter then
                self.customOnMouseEnter(icon)
            else
                self:OnMouseEnter(icon)
            end
        end)
        icon:SetHandler("OnMouseExit", function()
            mouseOver:ClearAnchors()
            mouseOver:SetHidden(true)
            if self.customOnMouseExit then
                self.customOnMouseExit(icon)
            else
                self:OnMouseExit(icon)
            end
        end)
        icon:SetHandler("OnMouseUp", function(control, ...)
            PlaySound("Click")
            icon.OnSelect(icon, icon.texture)
            self:Clear()
        end)
        return icon
    end

    local function ResetFunction(icon)
        icon:ClearAnchors()
        icon:SetHidden(true)
    end

    self.iconPool = ZO_ObjectPool:New(IconFactory, ResetFunction) --[[@as ZO_ControlPool]]
    self:SetMaxColumns(1)
    self.icons = {}
    self.color = ZO_DEFAULT_ENABLED_COLOR

    EVENT_MANAGER:RegisterForEvent(name .. "_OnGlobalMouseUp", EVENT_GLOBAL_MOUSE_UP, function()
        if self.refCount ~= nil then
            local moc = wm:GetMouseOverControl()
            if(moc:GetOwningWindow() ~= control) then
                self.refCount = self.refCount - 1
                if self.refCount <= 0 then
                    self:Clear()
                end
            end
        end
    end)
end

function IconPickerMenu:OnMouseEnter(icon)
    local tooltipText = icon.tooltip and LAM.util.GetStringFromValue(icon.tooltip)
    if tooltipText and tooltipText ~= "" then
        InitializeTooltip(InformationTooltip, icon, TOPLEFT, 0, 0, BOTTOMRIGHT)
        SetTooltipText(InformationTooltip, tooltipText)
        InformationTooltipTopLevel:BringWindowToTop()
    end
end

function IconPickerMenu:OnMouseExit(icon)
    ClearTooltip(InformationTooltip)
end

function IconPickerMenu:SetMaxColumns(value)
    self.maxCols = value ~= nil and value or 5
end

local DEFAULT_SIZE = 28
function IconPickerMenu:SetIconSize(value)
    local iconSize = DEFAULT_SIZE
    if value ~= nil then iconSize = math.max(iconSize, value) end
    self.iconSize = iconSize
end

function IconPickerMenu:SetVisibleRows(value)
    self.visibleRows = value ~= nil and value or 4.5
end

function IconPickerMenu:SetMouseHandlers(onEnter, onExit)
    self.customOnMouseEnter = onEnter
    self.customOnMouseExit = onExit
end

function IconPickerMenu:UpdateDimensions()
    local iconSize = self.iconSize
    local width = iconSize * self.maxCols + 20
    local height = iconSize * self.visibleRows
    self.control:SetDimensions(width, height)

    local icons = self.icons
    for i = 1, #icons do
        local icon = icons[i]
        icon:SetDimensions(iconSize, iconSize)
    end
end

function IconPickerMenu:UpdateAnchors()
    local iconSize = self.iconSize
    local col, maxCols = 1, self.maxCols
    local previousCol, previousRow
    local scroll = self.scroll
    local icons = self.icons

    for i = 1, #icons do
        local icon = icons[i]
        icon:ClearAnchors()
        if i == 1 then
            icon:SetAnchor(TOPLEFT, scroll, TOPLEFT, 0, 0)
            previousRow = icon
        elseif col == 1 then
            icon:SetAnchor(TOPLEFT, previousRow, BOTTOMLEFT, 0, 0)
            previousRow = icon
        else
            icon:SetAnchor(TOPLEFT, previousCol, TOPRIGHT, 0, 0)
        end
        previousCol = icon
        col = col >= maxCols and 1 or col + 1
    end
end

function IconPickerMenu:Clear()
    self.icons = {}
    self.iconPool:ReleaseAllObjects()
    self.control:SetHidden(true)
    self.color = ZO_DEFAULT_ENABLED_COLOR
    self.refCount = nil
    self.parent = nil
    self.customOnMouseEnter = nil
    self.customOnMouseExit = nil
end

function IconPickerMenu:AddIcon(texturePath, callback, tooltip)
    local icon, key = self.iconPool:AcquireObject() --[[@as IconPickerIcon]]
    icon:SetHidden(false)
    icon:SetTexture(texturePath)
    icon:SetColor(self.color:UnpackRGBA())
    icon.texture = texturePath
    icon.tooltip = tooltip
    icon.OnSelect = callback
    self.icons[#self.icons + 1] = icon
end

function IconPickerMenu:Show(parent)
    if #self.icons == 0 then return false end
    if not self.control:IsHidden() then self:Clear() return false end
    self:UpdateDimensions()
    self:UpdateAnchors()

    local control = self.control
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, parent, BOTTOMLEFT, 0, 8)
    control:SetHidden(false)
    control:BringWindowToTop()
    self.parent = parent
    self.refCount = 2

    return true
end

function IconPickerMenu:SetColor(color)
    local icons = self.icons
    self.color = color
    for i = 1, #icons do
        local icon = icons[i]
        icon:SetColor(color:UnpackRGBA())
    end
end

-------------------------------------------------------------

local function UpdateChoices(control, choices, choicesTooltips)
    local data = control.data
    if not choices then
        choices, choicesTooltips = data.choices, data.choicesTooltips or {}
    end
    local addedChoices = {}

    local iconPicker = LAM.util.GetIconPickerMenu()
    iconPicker:Clear()
    for i = 1, #choices do
        local texture = choices[i]
        if not addedChoices[texture] then -- remove duplicates
            iconPicker:AddIcon(choices[i], function(self, texture)
                control.icon:SetTexture(texture)
                data.setFunc(texture)
                LAM.util.RequestRefreshIfNeeded(control)
            end, LAM.util.GetStringFromValue(choicesTooltips[i]))
            addedChoices[texture] = true
        end
    end
end

local function IsDisabled(control)
    if type(control.data.disabled) == "function" then
        return control.data.disabled()
    else
        return control.data.disabled
    end
end

local function SetColor(control, color)
    local icon = control.icon
    if IsDisabled(control) then
        icon:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
    else
        icon.color = color or control.data.defaultColor or ZO_DEFAULT_ENABLED_COLOR
        icon:SetColor(icon.color:UnpackRGBA())
    end

    local iconPicker = LAM.util.GetIconPickerMenu()
    if iconPicker.parent == control.container and not iconPicker.control:IsHidden() then
        iconPicker:SetColor(icon.color)
    end
end

local function UpdateDisabled(control)
    local disable = IsDisabled(control)

    control.dropdown:SetMouseEnabled(not disable)
    control.dropdownButton:SetEnabled(not disable)

    local iconPicker = LAM.util.GetIconPickerMenu()
    if iconPicker.parent == control.container and not iconPicker.control:IsHidden() then
        iconPicker:Clear()
    end

    SetColor(control, control.icon.color)
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
        control.icon:SetTexture(value)
    elseif value then
        control.data.setFunc(value)
        --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
        LAM.util.RequestRefreshIfNeeded(control)
    else
        value = control.data.getFunc()
        control.icon:SetTexture(value)
    end
end

local MIN_HEIGHT = 26
local HALF_WIDTH_LINE_SPACING = 2
local function SetIconSize(control, size)
    local icon = control.icon
    icon.size = size
    icon:SetDimensions(size, size)

    local height = size + 4
    control.dropdown:SetDimensions(size + 20, height)
    height = math.max(height, MIN_HEIGHT)
    control.container:SetHeight(height)
    if control.lineControl then
        control.lineControl:SetHeight(MIN_HEIGHT + size + HALF_WIDTH_LINE_SPACING)
    else
        control:SetHeight(height)
    end

    local iconPicker = LAM.util.GetIconPickerMenu()
    if iconPicker.parent == control.container and not iconPicker.control:IsHidden() then
        iconPicker:SetIconSize(size)
        iconPicker:UpdateDimensions()
        iconPicker:UpdateAnchors()
    end
end

---@param iconpickerData LAM2_IconPickerData
function LAMCreateControl.iconpicker(parent, iconpickerData, controlName)
    ---@class LAM2_IconPicker: LAM2_LabelAndContainerControl
    local control = LAM.util.CreateLabelAndContainerControl(parent, iconpickerData, controlName)

    local function ShowIconPicker()
        local iconPicker = LAM.util.GetIconPickerMenu()
        if iconPicker.parent == control.container then
            iconPicker:Clear()
        else
            iconPicker:SetMaxColumns(iconpickerData.maxColumns)
            iconPicker:SetVisibleRows(iconpickerData.visibleRows)
            iconPicker:SetIconSize(control.icon.size)
            UpdateChoices(control)
            iconPicker:SetColor(control.icon.color)
            if iconpickerData.beforeShow then
                if iconpickerData.beforeShow(control, iconPicker) then
                    iconPicker:Clear()
                    return
                end
            end
            iconPicker:Show(control.container)
        end
    end

    local iconSize = iconpickerData.iconSize ~= nil and iconpickerData.iconSize or DEFAULT_SIZE
    control.dropdown = wm:CreateControl(nil, control.container, CT_CONTROL)
    local dropdown = control.dropdown
    dropdown:SetAnchor(LEFT, control.container, LEFT, 0, 0)
    dropdown:SetMouseEnabled(true)
    dropdown:SetHandler("OnMouseUp", ShowIconPicker)
    dropdown:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(control) end)
    dropdown:SetHandler("OnMouseExit", function() ZO_Options_OnMouseExit(control) end)

    control.icon = wm:CreateControl(nil, dropdown, CT_TEXTURE) --[[@as IconPickerIcon]]
    local icon = control.icon
    icon:SetAnchor(LEFT, dropdown, LEFT, 3, 0)
    icon:SetDrawLevel(2)

    local dropdownButton = wm:CreateControlFromVirtual(nil, dropdown, "ZO_DropdownButton")
    dropdownButton:SetDimensions(16, 16)
    dropdownButton:SetHandler("OnClicked", ShowIconPicker)
    dropdownButton:SetAnchor(RIGHT, dropdown, RIGHT, -3, 0)
    control.dropdownButton = dropdownButton

    control.bg = wm:CreateControl(nil, dropdown, CT_BACKDROP) --[[@as BackdropControl]]
    local bg = control.bg
    bg:SetAnchor(TOPLEFT, dropdown, TOPLEFT, 0, -3)
    bg:SetAnchor(BOTTOMRIGHT, dropdown, BOTTOMRIGHT, 2, 5)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    bg:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
    bg:SetInsets(16, 16, -16, -16)
    local mungeOverlay = wm:CreateControl(nil, bg, CT_TEXTURE) --[[@as TextureControl]]
    mungeOverlay:SetTexture("EsoUI/Art/Tooltips/munge_overlay.dds")
    mungeOverlay:SetDrawLevel(1)
    mungeOverlay:SetAddressMode(TEX_MODE_WRAP)
    mungeOverlay:SetAnchorFill()

    if iconpickerData.warning ~= nil or iconpickerData.requiresReload then
        control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
        control.warning:SetAnchor(RIGHT, control.container, LEFT, -5, 0)
        control.UpdateWarning = LAM.util.UpdateWarning
        control:UpdateWarning()
    end

    control.UpdateChoices = UpdateChoices
    control.UpdateValue = UpdateValue
    control:UpdateValue()
    control.SetColor = SetColor
    control:SetColor()
    control.SetIconSize = SetIconSize
    control:SetIconSize(iconSize)

    if iconpickerData.disabled ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)
    LAM.util.RegisterForReloadIfNeeded(control)

    return control
end
