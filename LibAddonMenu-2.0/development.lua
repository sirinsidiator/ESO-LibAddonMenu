-- this file is only used for the github version to prevent accidental bundling of a copy with r999.
-- see https://github.com/sirinsidiator/ESO-LibAddonMenu/issues/46
_LAM2_VERSION_NUMBER = 999

local debugging = false
SLASH_COMMANDS["/lamdebug"] = function()
    if(debugging) then return end
    debugging = true

    local cm = CALLBACK_MANAGER
    local LAM = LibAddonMenu2

    local function GetPanelName(control)
        local panel = LAM.util.GetTopPanel(control)
        return panel.label:GetText()
    end

    local CALLBACKS = {
        "LAM-RefreshPanel",
        "LAM-PanelOpened",
        "LAM-PanelClosed",
        "LAM-PanelControlsCreated",
    }

    for i = 1, #CALLBACKS do
        local callbackName = CALLBACKS[i]
        cm:RegisterCallback(callbackName, function(control) df("[LAM] %s: %s", callbackName, GetPanelName(control)) end)
    end

    d("[LAM] Debug hooks enabled")
end
