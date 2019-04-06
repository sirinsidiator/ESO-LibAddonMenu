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
    registerForRefresh = true, --boolean (optional) (will refresh all options controls when a setting is changed and when the panel is shown)
    registerForDefaults = true, --boolean (optional) (will set all options controls back to default values)
    resetFunc = function() print("defaults reset") end, --(optional) custom function to run after settings are reset to defaults
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
local LINK_COLOR = ZO_ColorDef:New("5959D5")
local LINK_COLOR_DONATE = ZO_ColorDef:New("FFD700") --golden
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
        local websiteOnClickHandler
        local websiteType = type(panelData.website)
        if websiteType == "string" then
            websiteOnClickHandler = function() RequestOpenUnsafeURL(panelData.website) end
        elseif websiteType == "function" then
            websiteOnClickHandler = function(ctrl) panelData.website(ctrl) end
        end
        website:SetHandler("OnClicked", function(ctrl)
            websiteOnClickHandler(ctrl)
        end)
    end

    if panelData.feedback then
        control.feedback = wm:CreateControl(nil, control, CT_BUTTON)
        local feedback = control.feedback
        feedback:SetClickSound("Click")
        feedback:SetFont(LAM.util.L["PANEL_INFO_FONT"])
        feedback:SetNormalFontColor(LINK_COLOR:UnpackRGBA())
        feedback:SetMouseOverFontColor(LINK_MOUSE_OVER_COLOR:UnpackRGBA())
        if(control.website) then
            feedback:SetAnchor(TOPLEFT, control.website, TOPRIGHT, 0, 0)
            feedback:SetText(string.format("|cffffff%s|r%s", SEPARATOR, LAM.util.L["FEEDBACK"]))
        elseif(control.info) then
            feedback:SetAnchor(TOPLEFT, control.info, TOPRIGHT, 0, 0)
            feedback:SetText(string.format("|cffffff%s|r%s", SEPARATOR, LAM.util.L["DONATION"]))
        else
            feedback:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, -2)
            feedback:SetText(LAM.util.L["FEEDBACK"])
        end
        feedback:SetDimensions(feedback:GetLabelControl():GetTextDimensions())
        local feedbackOnClickHandler
        local feedbackType = type(panelData.feedback)
        if feedbackType == "string" then
            feedbackOnClickHandler = function() RequestOpenUnsafeURL(panelData.feedback) end
        elseif feedbackType == "function" then
            feedbackOnClickHandler = function(ctrl) panelData.feedback(ctrl) end
        end
        feedback:SetHandler("OnClicked", function(ctrl)
            feedbackOnClickHandler(ctrl)
        end)
    end

    if panelData.translation then
        control.translation = wm:CreateControl(nil, control, CT_BUTTON)
        local translation = control.translation
        translation:SetClickSound("Click")
        translation:SetFont(LAM.util.L["PANEL_INFO_FONT"])
        translation:SetNormalFontColor(LINK_COLOR:UnpackRGBA())
        translation:SetMouseOverFontColor(LINK_MOUSE_OVER_COLOR:UnpackRGBA())
        if(control.feedback) then
            translation:SetAnchor(TOPLEFT, control.feedback, TOPRIGHT, 0, 0)
            translation:SetText(string.format("|cffffff%s|r%s", SEPARATOR, LAM.util.L["TRANSLATION"]))
        elseif(control.info) then
            translation:SetAnchor(TOPLEFT, control.info, TOPRIGHT, 0, 0)
            translation:SetText(string.format("|cffffff%s|r%s", SEPARATOR, LAM.util.L["TRANSLATION"]))
        else
            translation:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, -2)
            translation:SetText(LAM.util.L["TRANSLATION"])
        end
        translation:SetDimensions(translation:GetLabelControl():GetTextDimensions())
        local translationOnClickHandler
        local translationType = type(panelData.translation)
        if translationType == "string" then
            translationOnClickHandler = function() RequestOpenUnsafeURL(panelData.translation) end
        elseif translationType == "function" then
            translationOnClickHandler = function(ctrl) panelData.translation(ctrl) end
        end
        translation:SetHandler("OnClicked", function(ctrl)
            translationOnClickHandler(ctrl)
        end)
    end

    if panelData.donation then
        control.donation = wm:CreateControl(nil, control, CT_BUTTON)
        local donation = control.donation
        donation:SetClickSound("Click")
        donation:SetFont(LAM.util.L["PANEL_INFO_FONT"])
        donation:SetNormalFontColor(LINK_COLOR_DONATE:UnpackRGBA())
        donation:SetMouseOverFontColor(LINK_MOUSE_OVER_COLOR:UnpackRGBA())
        if(control.translation) then
            donation:SetAnchor(TOPLEFT, control.translation, TOPRIGHT, 0, 0)
            donation:SetText(string.format("|cffffff%s|r%s", SEPARATOR, LAM.util.L["DONATION"]))
        elseif(control.feedback) then
            donation:SetAnchor(TOPLEFT, control.feedback, TOPRIGHT, 0, 0)
            donation:SetText(string.format("|cffffff%s|r%s", SEPARATOR, LAM.util.L["DONATION"]))
        elseif(control.info) then
            donation:SetAnchor(TOPLEFT, control.info, TOPRIGHT, 0, 0)
            donation:SetText(string.format("|cffffff%s|r%s", SEPARATOR, LAM.util.L["DONATION"]))
        else
            donation:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, -2)
            donation:SetText(LAM.util.L["DONATION"])
        end
        donation:SetDimensions(donation:GetLabelControl():GetTextDimensions())
        local donationOnClickHandler
        local donationType = type(panelData.donation)
        if donationType == "string" then
            donationOnClickHandler = function() RequestOpenUnsafeURL(panelData.donation) end
        elseif donationType == "function" then
            donationOnClickHandler = function(ctrl) panelData.donation(ctrl) end
        end
        donation:SetHandler("OnClicked", function(ctrl)
            donationOnClickHandler(ctrl)
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
    control.RefreshPanel = LAM.util.RequestRefreshIfNeeded
    control.data = panelData
    control.controlsToRefresh = {}

    return control
end
