--[[panelData = {
    type = "panel",
    name = "Window Title", -- or string id or function returning a string
    displayName = "My Longer Window Title",  -- or string id or function returning a string (optional) (can be useful for long addon names or if you want to colorize it)
    author = "Seerah",  -- or string id or function returning a string (optional)
    version = "2.0",  -- or string id or function returning a string (optional)
    website = "http://www.esoui.com/downloads/info7-LibAddonMenu.html", -- URL of website where the addon can be updated or function (optional)
    feedback = "https://www.esoui.com/portal.php?uid=5815", -- URL of website where feedback/feature requests/bugs can be reported for the addon or function (optional)
    translation = "https://www.esoui.com/portal.php?uid=5815", -- URL of website where translation texts of the addon can be helped with or function (optional)
    donation = "http://www.esoui.com/downloads/info7-LibAddonMenu.html", -- URL of website where a donation for the addon author can be raised or function (optional)
    keywords = "settings", -- additional keywords for search filter (it looks for matches in name..keywords..author) (optional)
    slashCommand = "/myaddon", -- will register a keybind to open to this panel (don't forget to include the slash!) (optional)
    registerForRefresh = true, -- boolean will refresh all options controls when a setting is changed and when the panel is shown (optional)
    registerForDefaults = true, -- boolean will set all options controls back to default values (optional)
    resetFunc = function() print("defaults reset") end, -- custom function to run after settings are reset to defaults (optional)
} ]]


local widgetVersion = 15
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("panel", widgetVersion) then return end

local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER

local function RefreshPanel(control)
    local panel = LAM.util.GetTopPanel(control) --callback can be fired by a single control, by the panel showing or by a nested submenu
    if LAM.currentAddonPanel ~= panel or not LAM.currentPanelOpened then return end -- we refresh it later when the panel is opened

    local panelControls = panel.controlsToRefresh

    for i = 1, #panelControls do
        local updateControl = panelControls[i]
        if updateControl ~= control and updateControl.UpdateValue then
            updateControl:UpdateValue()
        end
        if updateControl.UpdateDisabled then
            updateControl:UpdateDisabled()
        end
        if updateControl.UpdateWarning then
            updateControl:UpdateWarning()
        end
    end
end

local function ForceDefaults(panel)
    local panelControls = panel.controlsToRefresh

    for i = 1, #panelControls do
        local updateControl = panelControls[i]
        if updateControl.UpdateValue and updateControl.data.default ~= nil then
            updateControl:UpdateValue(true)
        end
    end

    if panel.data.resetFunc then
        panel.data.resetFunc()
    end

    cm:FireCallbacks("LAM-RefreshPanel", panel)
end

local callbackRegistered = false
LAMCreateControl.scrollCount = LAMCreateControl.scrollCount or 1
local SEPARATOR = " - "
local COLORED_SEPARATOR = ZO_WHITE:Colorize(SEPARATOR)
local LINK_COLOR = ZO_ColorDef:New("5959D5")
local LINK_MOUSE_OVER_COLOR = ZO_ColorDef:New("B8B8D3")
local LINK_COLOR_DONATE = ZO_ColorDef:New("FFD700") -- golden
local LINK_MOUSE_OVER_COLOR_DONATE = ZO_ColorDef:New("FFF6CC")

local function CreateButtonControl(control, label, clickAction, relativeTo)
    local button = wm:CreateControl(nil, control, CT_BUTTON)
    button:SetClickSound("Click")
    button:SetFont(LAM.util.L["PANEL_INFO_FONT"])
    button:SetNormalFontColor(LINK_COLOR:UnpackRGBA())
    button:SetMouseOverFontColor(LINK_MOUSE_OVER_COLOR:UnpackRGBA())

    local OnClicked
    local actionType = type(clickAction)
    if actionType == "string" then
        OnClicked = function() RequestOpenUnsafeURL(clickAction) end
    elseif actionType == "function" then
        OnClicked = clickAction
    end
    button:SetHandler("OnClicked", OnClicked)

    if relativeTo then
        button:SetAnchor(TOPLEFT, relativeTo, TOPRIGHT, 0, 0)
        button:SetText(COLORED_SEPARATOR .. label)
    else
        button:SetAnchor(TOPLEFT, control.label, BOTTOMLEFT, 0, -2)
        button:SetText(label)
    end
    button:SetDimensions(button:GetLabelControl():GetTextDimensions())

    return button
end

function LAMCreateControl.panel(parent, panelData, controlName)
    local control = wm:CreateControl(controlName, parent, CT_CONTROL)

    control.label = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel")
    local label = control.label
    label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 4)
    label:SetText(LAM.util.GetStringFromValue(panelData.displayName or panelData.name))

    local previousInfoControl
    if panelData.author or panelData.version then
        control.info = wm:CreateControl(nil, control, CT_LABEL)
        local info = control.info
        info:SetFont(LAM.util.L["PANEL_INFO_FONT"])
        info:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, -2)

        local output = {}
        if panelData.author then
            output[#output + 1] = zo_strformat(LAM.util.L["AUTHOR"], LAM.util.GetStringFromValue(panelData.author))
        end
        if panelData.version then
            output[#output + 1] = zo_strformat(LAM.util.L["VERSION"], LAM.util.GetStringFromValue(panelData.version))
        end
        info:SetText(table.concat(output, SEPARATOR))
        previousInfoControl = info
    end

    if panelData.website then
        control.website = CreateButtonControl(control, LAM.util.L["WEBSITE"], panelData.website, previousInfoControl)
        previousInfoControl = control.website
    end

    if panelData.feedback then
        control.feedback = CreateButtonControl(control, LAM.util.L["FEEDBACK"], panelData.feedback, previousInfoControl)
        previousInfoControl = control.feedback
    end

    if panelData.translation then
        control.translation = CreateButtonControl(control, LAM.util.L["TRANSLATION"], panelData.translation, previousInfoControl)
        previousInfoControl = control.translation
    end

    if panelData.donation then
        control.donation = CreateButtonControl(control, LAM.util.L["DONATION"], panelData.donation, previousInfoControl)
        local donation = control.donation
        previousInfoControl = donation
        donation:SetNormalFontColor(LINK_COLOR_DONATE:UnpackRGBA())
        donation:SetMouseOverFontColor(LINK_MOUSE_OVER_COLOR_DONATE:UnpackRGBA())
    end

    control.container = wm:CreateControlFromVirtual("LAMAddonPanelContainer"..LAMCreateControl.scrollCount, control, "ZO_ScrollContainer")
    LAMCreateControl.scrollCount = LAMCreateControl.scrollCount + 1
    local container = control.container
    container:SetAnchor(TOPLEFT, control.info or label, BOTTOMLEFT, 0, 20)
    container:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -3, -3)
    control.scroll = GetControl(control.container, "ScrollChild")
    control.scroll:SetResizeToFitPadding(0, 20)

    if panelData.registerForRefresh and not callbackRegistered then --don't want to register our callback more than once
        cm:RegisterCallback("LAM-RefreshPanel", RefreshPanel)
        callbackRegistered = true
    end

    control.ForceDefaults = ForceDefaults
    control.RefreshPanel = LAM.util.RequestRefreshIfNeeded
    control.data = panelData
    control.controlsToRefresh = {}

    return control
end
