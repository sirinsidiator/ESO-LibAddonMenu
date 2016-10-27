--[[panelData = {
    type = "panel",
    name = "Window Title", -- or string id or function returning a string
    displayName = "My Longer Window Title",  -- or string id or function returning a string (optional) (can be useful for long addon names or if you want to colorize it)
    author = "Seerah",  -- or string id or function returning a string (optional)
    version = "2.0",  -- or string id or function returning a string (optional)
    website = "http://www.esoui.com/downloads/info7-LibAddonMenu.html", -- URL of website where the addon can be updated (optional)
    keywords = "settings", -- additional keywords for search filter (it looks for matches in name..keywords..author) (optional)
    slashCommand = "/myaddon", -- will register a keybind to open to this panel (don't forget to include the slash!) (optional)
    registerForRefresh = true, --boolean (optional) (will refresh all options controls when a setting is changed and when the panel is shown)
    registerForDefaults = true, --boolean (optional) (will set all options controls back to default values)
    resetFunc = function() print("defaults reset") end, --(optional) custom function to run after settings are reset to defaults
} ]]


local widgetVersion = 13
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("panel", widgetVersion) then return end

local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER

local function RefreshPanel(control)
    local panel = LAM.util.GetTopPanel(control) --callback can be fired by a single control, by the panel showing or by a nested submenu
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
local LINK_COLOR = ZO_ColorDef:New("5959D5")
local LINK_MOUSE_OVER_COLOR = ZO_ColorDef:New("B8B8D3")

function LAMCreateControl.panel(parent, panelData, controlName)
    local control = wm:CreateControl(controlName, parent, CT_CONTROL)

    control.label = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel")
    local label = control.label
    label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 4)
    label:SetText(LAM.util.GetStringFromValue(panelData.displayName or panelData.name))

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
    end

    if panelData.website then
        control.website = wm:CreateControl(nil, control, CT_BUTTON)
        local website = control.website
        website:SetClickSound("Click")
        website:SetFont(LAM.util.L["PANEL_INFO_FONT"])
        website:SetNormalFontColor(LINK_COLOR:UnpackRGBA())
        website:SetMouseOverFontColor(LINK_MOUSE_OVER_COLOR:UnpackRGBA())
        if(control.info) then
            website:SetAnchor(TOPLEFT, control.info, TOPRIGHT, 0, 0)
            website:SetText(string.format("|cffffff%s|r%s", SEPARATOR, LAM.util.L["WEBSITE"]))
        else
            website:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, -2)
            website:SetText(LAM.util.L["WEBSITE"])
        end
        website:SetDimensions(website:GetLabelControl():GetTextDimensions())
        website:SetHandler("OnClicked", function()
            RequestOpenUnsafeURL(panelData.website)
        end)
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
    control.data = panelData
    control.controlsToRefresh = {}

    return control
end
