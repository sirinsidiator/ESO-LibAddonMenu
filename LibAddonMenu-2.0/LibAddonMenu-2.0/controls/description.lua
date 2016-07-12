--[[descriptionData = {
    type = "description",
    text = "My description text to display.", -- or string id or function returning a string
    title = "My Title", -- or string id or function returning a string (optional)
    width = "full", --or "half" (optional)
    reference = "MyAddonDescription" -- unique global reference to control (optional)
} ]]


local widgetVersion = 8
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("description", widgetVersion) then return end

local wm = WINDOW_MANAGER

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

    control.UpdateValue = UpdateValue

    LAM.util.RegisterForRefreshIfNeeded(control)

    return control

end
