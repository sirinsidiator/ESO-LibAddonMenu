--[[submenuData = {
    type = "submenu",
    name = "Submenu Title", -- or string id or function returning a string
    icon = "path/to/my/icon.dds", -- or function returning a string (optional)
    iconTextureCoords = {left, right, top, bottom}, -- or function returning a table (optional)
    tooltip = "My submenu tooltip", -- or string id or function returning a string (optional)
    controls = {sliderData, buttonData} -- used by LAM (optional)
    disabled = function() return db.someBooleanSetting end, -- or boolean (optional)
    disabledLabel = function() return db.someBooleanSetting end, -- or boolean (optional)
    reference = "MyAddonSubmenu" -- unique global reference to control (optional)
} ]]

local widgetVersion = 13
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("submenu", widgetVersion) then return end

local wm = WINDOW_MANAGER
local am = ANIMATION_MANAGER
local ICON_SIZE = 32

local GetDefaultValue = LAM.util.GetDefaultValue
local GetColorForState = LAM.util.GetColorForState

local function UpdateDisabled(control)
    local disable = GetDefaultValue(control.data.disabled)
    if disable ~= control.disabled then
        local color = GetColorForState(disable)
        if disable and control.open then
            control.open = false
            control.animation:PlayFromStart()
        end

        control.arrow:SetColor(color:UnpackRGBA())
        control.disabled = disable
    end

    local disableLabel = control.disabled or GetDefaultValue(control.data.disabledLabel)
    if disableLabel ~= control.disabledLabel then
        local color = GetColorForState(disableLabel)
        control.label:SetColor(color:UnpackRGBA())
        if(control.icon) then
            control.icon:SetDesaturation(disableLabel and 1 or 0)
        end
        control.disabledLabel = disableLabel
    end
end

local function UpdateValue(control)
    control.label:SetText(LAM.util.GetStringFromValue(control.data.name))

    if control.icon then
        control.icon:SetTexture(GetDefaultValue(control.data.icon))
        if(control.data.iconTextureCoords) then
            local coords = GetDefaultValue(control.data.iconTextureCoords)
            control.icon:SetTextureCoords(unpack(coords))
        end
    end

    if control.data.tooltip then
        control.label.data.tooltipText = LAM.util.GetStringFromValue(control.data.tooltip)
    end
end

local function AnimateSubmenu(clicked)
    local control = clicked:GetParent()
    if control.disabled then return end

    control.open = not control.open
    if control.open then
        control.animation:PlayFromStart()
    else
        control.animation:PlayFromEnd()
    end
end

function LAMCreateControl.submenu(parent, submenuData, controlName)
    local width = parent:GetWidth() - 45
    local control = wm:CreateControl(controlName or submenuData.reference, parent.scroll or parent, CT_CONTROL)
    control.panel = parent
    control.data = submenuData

    control.label = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel")
    local label = control.label
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetText(LAM.util.GetStringFromValue(submenuData.name))
    label:SetMouseEnabled(true)

    if submenuData.icon then
        control.icon = wm:CreateControl(nil, control, CT_TEXTURE)
        local icon = control.icon
        icon:SetTexture(GetDefaultValue(submenuData.icon))
        if(submenuData.iconTextureCoords) then
            local coords = GetDefaultValue(submenuData.iconTextureCoords)
            icon:SetTextureCoords(unpack(coords))
        end
        icon:SetDimensions(ICON_SIZE, ICON_SIZE)
        icon:SetAnchor(TOPLEFT, control, TOPLEFT, 5, 5)
        icon:SetMouseEnabled(true)
        icon:SetDrawLayer(DL_CONTROLS)
        label:SetAnchor(TOP, control, TOP, 0, 5, ANCHOR_CONSTRAINS_Y)
        label:SetAnchor(LEFT, icon, RIGHT, 10, 0, ANCHOR_CONSTRAINS_X)
        label:SetDimensions(width - ICON_SIZE - 5, 30)
    else
        label:SetAnchor(TOPLEFT, control, TOPLEFT, 5, 5)
        label:SetDimensions(width, 30)
    end

    if submenuData.tooltip then
        label.data = {tooltipText = LAM.util.GetStringFromValue(submenuData.tooltip)}
        label:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
        label:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
        if control.icon then
            control.icon.data = label.data
            control.icon:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
            control.icon:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
        end
    end

    control.scroll = wm:CreateControl(nil, control, CT_SCROLL)
    local scroll = control.scroll
    scroll:SetParent(control)
    scroll:SetAnchor(TOPLEFT, control.icon or label, BOTTOMLEFT, 0, 10)
    scroll:SetDimensionConstraints(width + 5, 0, width + 5, 0)

    control.bg = wm:CreateControl(nil, control.icon or label, CT_BACKDROP)
    local bg = control.bg
    bg:SetAnchor(TOPLEFT, control.icon or label, TOPLEFT, -5, -5)
    bg:SetAnchor(BOTTOMRIGHT, scroll, BOTTOMRIGHT, -7, 0)
    bg:SetEdgeTexture("EsoUI\\Art\\Tooltips\\UI-Border.dds", 128, 16)
    bg:SetCenterTexture("EsoUI\\Art\\Tooltips\\UI-TooltipCenter.dds")
    bg:SetInsets(16, 16, -16, -16)
    bg:SetDrawLayer(DL_BACKGROUND)

    control.arrow = wm:CreateControl(nil, bg, CT_TEXTURE)
    local arrow = control.arrow
    arrow:SetDimensions(28, 28)
    arrow:SetTexture("EsoUI\\Art\\Miscellaneous\\list_sortdown.dds") --list_sortup for the other way
    arrow:SetAnchor(TOPRIGHT, bg, TOPRIGHT, -5, 5)

    --figure out the cool animation later...
    control.animation = am:CreateTimeline()
    local animation = control.animation
    animation:SetPlaybackType(ANIMATION_SIZE, 0) --2nd arg = loop count

    control:SetResizeToFitDescendents(true)
    control.open = false
    label:SetHandler("OnMouseUp", AnimateSubmenu)
    if(control.icon) then
        control.icon:SetHandler("OnMouseUp", AnimateSubmenu)
    end
    animation:SetHandler("OnStop", function(self, completedPlaying)
        scroll:SetResizeToFitDescendents(control.open)
        if control.open then
            control.arrow:SetTexture("EsoUI\\Art\\Miscellaneous\\list_sortup.dds")
            scroll:SetResizeToFitPadding(5, 20)
        else
            control.arrow:SetTexture("EsoUI\\Art\\Miscellaneous\\list_sortdown.dds")
            scroll:SetResizeToFitPadding(5, 0)
            scroll:SetHeight(0)
        end
    end)

    --small strip at the bottom of the submenu that you can click to close it
    control.btmToggle = wm:CreateControl(nil, control, CT_TEXTURE)
    local btmToggle = control.btmToggle
    btmToggle:SetMouseEnabled(true)
    btmToggle:SetAnchor(BOTTOMLEFT, control.scroll, BOTTOMLEFT)
    btmToggle:SetAnchor(BOTTOMRIGHT, control.scroll, BOTTOMRIGHT)
    btmToggle:SetHeight(15)
    btmToggle:SetAlpha(0)
    btmToggle:SetHandler("OnMouseUp", AnimateSubmenu)

    control.UpdateValue = UpdateValue
    if submenuData.disabled ~= nil or submenuData.disabledLabel ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)

    return control
end
