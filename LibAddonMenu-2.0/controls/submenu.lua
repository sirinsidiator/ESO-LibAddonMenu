---@alias IconTextureCoords [number, number, number, number] {left, right, top, bottom}

---@class LAM2_SubmenuData: LAM2_ControlData
---@field type "submenu"
---@field icon nil|Stringy ex. "path/to/my/icon.dds"
---@field iconTextureCoords nil|IconTextureCoords|fun(): IconTextureCoords
---@field tooltip nil|Stringy ex. "My submenu tooltip"
---@field controls nil|LAM2_ControlData[] data for sub-controls to create
---@field disabled nil|boolean|fun(): boolean ex. function() return db.someBooleanSetting end
---@field disabledLabel nil|boolean|fun(): boolean ex. function() return db.someBooleanSetting end
---@field helpUrl nil|Stringy ex. "https://www.esoui.com/portal.php?id=218&a=faq"
---@field reference nil|string a unique global reference to the created control ex. "MyAddonSubmenu"
---@field resetFunc nil|fun(submenuControl: LAM2_Submenu) custom function to run after the control is reset to defaults ex. function(submenuControl) d("defaults reset") end


local widgetVersion = 16
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("submenu", widgetVersion) then return end

local wm = WINDOW_MANAGER
local am = ANIMATION_MANAGER
local ICON_SIZE = 32

local GetDefaultValue = LAM.util.GetDefaultValue
local GetColorForState = LAM.util.GetColorForState

---@param control LAM2_Submenu
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

---@param control LAM2_Submenu
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

---@param submenuData LAM2_SubmenuData
function LAMCreateControl.submenu(parent, submenuData, controlName)
    local width = parent:GetWidth() - 45
    ---@class LAM2_Submenu: LAM2_Control
    ---@field disabled boolean
    ---@field disabledLabel boolean
    local control = wm:CreateControl(controlName or submenuData.reference, parent.scroll or parent, CT_CONTROL)
    control.panel = parent
    control.data = submenuData

    ---@class Label: LabelControl, ControlWithData
    control.label = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel")
    local label = control.label
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetText(LAM.util.GetStringFromValue(submenuData.name))
    label:SetMouseEnabled(true)
    LAM.util.SetUpTooltip(label, submenuData)

    if submenuData.icon then
        control.icon = wm:CreateControl(nil, control, CT_TEXTURE) --[[@as TextureControl]]
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
        LAM.util.SetUpTooltip(icon, submenuData, label.data)
        label:SetAnchor(TOP, control, TOP, 0, 5, ANCHOR_CONSTRAINS_Y)
        label:SetAnchor(LEFT, icon, RIGHT, 10, 0, ANCHOR_CONSTRAINS_X)
        label:SetDimensions(width - ICON_SIZE - 5, 30)
    else
        label:SetAnchor(TOPLEFT, control, TOPLEFT, 5, 5)
        label:SetDimensions(width, 30)
    end

    control.scroll = wm:CreateControl(nil, control, CT_SCROLL) --[[@as ScrollControl]]
    local scroll = control.scroll
    scroll:SetParent(control)
    scroll:SetAnchor(TOPLEFT, control.icon or label, BOTTOMLEFT, 0, 10)
    scroll:SetDimensionConstraints(width + 5, 0, width + 5, 0)

    control.bg = wm:CreateControl(nil, control.icon or label, CT_BACKDROP) --[[@as BackdropControl]]
    local bg = control.bg
    bg:SetAnchor(TOPLEFT, control.icon or label, TOPLEFT, -5, -5)
    bg:SetAnchor(BOTTOMRIGHT, scroll, BOTTOMRIGHT, -7, 0)
    bg:SetEdgeTexture("EsoUI\\Art\\Tooltips\\UI-Border.dds", 128, 16)
    bg:SetCenterTexture("EsoUI\\Art\\Tooltips\\UI-TooltipCenter.dds")
    bg:SetInsets(16, 16, -16, -16)
    bg:SetDrawLayer(DL_BACKGROUND)

    control.arrow = wm:CreateControl(nil, bg, CT_TEXTURE) --[[@as TextureControl]]
    local arrow = control.arrow
    arrow:SetDimensions(28, 28)
    arrow:SetTexture("EsoUI\\Art\\Miscellaneous\\list_sortdown.dds") --list_sortup for the other way
    arrow:SetAnchor(TOPRIGHT, bg, TOPRIGHT, -5, 5)

    local faqTexture = LAM.util.CreateFAQTexture(control)
    if faqTexture then
        faqTexture:SetAnchor(RIGHT, arrow, LEFT, 0, 0)
    end

    --figure out the cool animation later...
    control.animation = am:CreateTimeline()
    local animation = control.animation
    animation:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT, 0) --2nd arg = loop count

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
    control.btmToggle = wm:CreateControl(nil, control, CT_TEXTURE) --[[@as TextureControl]]
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
