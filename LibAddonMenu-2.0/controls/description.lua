--[[descriptionData = {
    type = "description",
    text = "My description text to display.", -- or string id or function returning a string
    title = "My Title", -- or string id or function returning a string (optional)
    width = "full", -- or "half" (optional)
    disabled = function() return db.someBooleanSetting end, -- or boolean (optional)
    enableLinks = nil, -- or true for default tooltips, or function OnLinkClicked handler (optional)
                       -- see: https://wiki.esoui.com/UI_XML#OnLinkClicked
    helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
    reference = "MyAddonDescription" -- unique global reference to control (optional)
} ]]


local widgetVersion = 11
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("description", widgetVersion) then return end

local wm = WINDOW_MANAGER

local GetDefaultValue = LAM.util.GetDefaultValue
local GetColorForState = LAM.util.GetColorForState

local function OnLinkClicked(control, linkData, linkText, button)
    ZO_LinkHandler_OnLinkClicked(linkText, button) 
end

local function UpdateDisabled(control)
    local disable = GetDefaultValue(control.data.disabled)
    if disable ~= control.disabled then
        local color = GetColorForState(disable)
        control.desc:SetColor(color:UnpackRGBA())
        if control.title then
            control.title:SetColor(color:UnpackRGBA())
        end
        control.disabled = disable
    end
end

local function UpdateValue(control)
    if control.title then
        control.title:SetText(LAM.util.GetStringFromValue(control.data.title))
    end
    control.desc:SetText(LAM.util.GetStringFromValue(control.data.text))
end

function LAMCreateControl.description(parent, descriptionData, controlName)
    local control = LAM.util.CreateBaseControl(parent, descriptionData, controlName)
    local isHalfWidth = control.isHalfWidth
    local width = control:GetWidth()
    control:SetResizeToFitDescendents(true)

    if isHalfWidth then
        control:SetDimensionConstraints(width / 2, 0, width / 2, 0)
    else
        control:SetDimensionConstraints(width, 0, width, 0)
    end

    control.desc = wm:CreateControl(nil, control, CT_LABEL)
    local desc = control.desc
    desc:SetVerticalAlignment(TEXT_ALIGN_TOP)
    desc:SetFont("ZoFontGame")
    desc:SetText(LAM.util.GetStringFromValue(descriptionData.text))
    desc:SetWidth(isHalfWidth and width / 2 or width)

    if descriptionData.title then
        control.title = wm:CreateControl(nil, control, CT_LABEL)
        local title = control.title
        title:SetWidth(isHalfWidth and width / 2 or width)
        title:SetAnchor(TOPLEFT, control, TOPLEFT)
        title:SetFont("ZoFontWinH4")
        title:SetText(LAM.util.GetStringFromValue(descriptionData.title))
        desc:SetAnchor(TOPLEFT, title, BOTTOMLEFT)
    else
        desc:SetAnchor(TOPLEFT)
    end
    
    if descriptionData.enableLinks then
        desc:SetMouseEnabled(true)
        desc:SetLinkEnabled(true)
        if type(descriptionData.enableLinks) == "function" then
            desc:SetHandler("OnLinkClicked", descriptionData.enableLinks)
        else
            desc:SetHandler("OnLinkClicked", OnLinkClicked)
        end
    end

    control.UpdateValue = UpdateValue
    if descriptionData.disabled ~= nil then
        control.UpdateDisabled = UpdateDisabled
        control:UpdateDisabled()
    end

    LAM.util.RegisterForRefreshIfNeeded(control)

    return control

end
