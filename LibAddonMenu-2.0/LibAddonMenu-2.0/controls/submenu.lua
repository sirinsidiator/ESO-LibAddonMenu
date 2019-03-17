--[[submenuData = {
    type = "submenu",
    name = "Submenu Title", -- or string id or function returning a string
    tooltip = "My submenu tooltip", -- -- or string id or function returning a string (optional)
    controls = {sliderData, buttonData} --(optional) used by LAM
    disabled = function() return db.someBooleanSetting end, --or boolean (optional)
    reference = "MyAddonSubmenu" --(optional) unique global reference to control
} ]]

local widgetVersion = 12
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("submenu", widgetVersion) then return end

local wm = WINDOW_MANAGER
local am = ANIMATION_MANAGER

local function IsDisabled(control)
    if type(control.data.disabled) == "function" then
        return control.data.disabled()
    else
        return control.data.disabled
    end
end

local function UpdateDisabled(control)
    local disable = IsDisabled(control)
    if disable == control.disabled then return end

    local color = ZO_DEFAULT_ENABLED_COLOR
    if disable then
        color = ZO_DEFAULT_DISABLED_COLOR

        if control.open then
            control.open = false
            control.animation:PlayFromStart()
        end
    end

    control.label:SetColor(color:UnpackRGBA())
    control.arrow:SetColor(color:UnpackRGBA())
    control.disabled = disable
end

local function UpdateValue(control)
    control.label:SetText(LAM.util.GetStringFromValue(control.data.name))
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
    label:SetAnchor(TOPLEFT, control, TOPLEFT, 5, 5)
    label:SetDimensions(width, 30)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetText(LAM.util.GetStringFromValue(submenuData.name))
    label:SetMouseEnabled(true)
    if submenuData.tooltip then
        label.data = {tooltipText = LAM.util.GetStringFromValue(submenuData.tooltip)}
        label:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
        label:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
    end

    control.scroll = wm:CreateControl(nil, control, CT_SCROLL)
    local scroll = control.scroll
    scroll:SetParent(control)
    scroll:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 10)
    scroll:SetDimensionConstraints(width + 5, 0, width + 5, 0)

    control.bg = wm:CreateControl(nil, label, CT_BACKDROP)
    local bg = control.bg
    bg:SetAnchor(TOPLEFT, label, TOPLEFT, -5, -5)
    bg:SetAnchor(BOTTOMRIGHT, scroll, BOTTOMRIGHT, -7, 0)
    bg:SetEdgeTexture("EsoUI\\Art\\Tooltips\\UI-Border.dds", 128, 16)
    bg:SetCenterTexture("EsoUI\\Art\\Tooltips\\UI-TooltipCenter.dds")
    bg:SetInsets(16, 16, -16, -16)

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
    if submenuData.disabled ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)

    return control
end
