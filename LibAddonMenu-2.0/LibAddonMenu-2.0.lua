-- LibAddonMenu-2.0 & its files © Ryan Lakanen (Seerah)         --
-- Distributed under The Artistic License 2.0 (see LICENSE)     --
------------------------------------------------------------------


local MAJOR, MINOR = "LibAddonMenu-2.0", _LAM2_VERSION_NUMBER or -1

local lam
if(not LibStub) then
    lam = {}
else
    -- Optionally register LAM with LibStub
    lam = LibStub:NewLibrary(MAJOR, MINOR)
    if not lam then
        return --the same or newer version of this lib is already loaded into memory
    end
end
LibAddonMenu2 = lam

local messages = {}
local MESSAGE_PREFIX = "[LAM2] "
local function PrintLater(msg)
    if CHAT_SYSTEM.primaryContainer then
        d(MESSAGE_PREFIX .. msg)
    else
        messages[#messages + 1] = msg
    end
end

local function FlushMessages()
    for i = 1, #messages do
        d(MESSAGE_PREFIX .. messages[i])
    end
    messages = {}
end

local logger
if LibDebugLogger then
    logger = LibDebugLogger(MAJOR)
else
    local function noop() end
    logger = setmetatable({}, { __index = function() return noop end })
end

if LAMSettingsPanelCreated and not LAMCompatibilityWarning then
    PrintLater("An old version of LibAddonMenu with compatibility issues was detected. For more information on how to proceed search for LibAddonMenu on esoui.com")
    LAMCompatibilityWarning = true
end

--UPVALUES--
local wm = WINDOW_MANAGER
local em = EVENT_MANAGER
local sm = SCENE_MANAGER
local cm = CALLBACK_MANAGER
local tconcat = table.concat
local tinsert = table.insert

local MIN_HEIGHT = 26
local HALF_WIDTH_LINE_SPACING = 2
local OPTIONS_CREATION_RUNNING = 1
local OPTIONS_CREATED = 2
local LAM_CONFIRM_DIALOG = "LAM_CONFIRM_DIALOG"
local LAM_DEFAULTS_DIALOG = "LAM_DEFAULTS"
local LAM_RELOAD_DIALOG = "LAM_RELOAD_DIALOG"

local addonsForList = {}
local addonToOptionsMap = {}
local optionsState = {}
lam.widgets = lam.widgets or {}
local widgets = lam.widgets
lam.util = lam.util or {}
local util = lam.util
lam.controlsForReload = lam.controlsForReload or {}
local controlsForReload = lam.controlsForReload

local function GetDefaultValue(default)
    if type(default) == "function" then
        return default()
    end
    return default
end

local function GetStringFromValue(value)
    if type(value) == "function" then
        return value()
    elseif type(value) == "number" then
        return GetString(value)
    end
    return value
end

local FAQ_ICON_COLOR = ZO_ColorDef:New("FFFFFF") -- white
local FAQ_ICON_MOUSE_OVER_COLOR = ZO_ColorDef:New("B8B8D3") -- dark-blue/white
local FAQ_ICON_MOUSE_OVER_ALPHA = 1
local FAQ_ICON_MOUSE_EXIT_ALPHA = 0.4
local FAQ_ICON_SIZE = 23
local FAQ_ICON_TOOTIP_TEMPLATE = "%s: %s"

local function GetColorForState(disabled)
    return disabled and ZO_DEFAULT_DISABLED_COLOR or ZO_DEFAULT_ENABLED_COLOR
end

local function CreateFAQTexture(control)
    local controlData = control.data
    if not control or not controlData then logger:Warn("CreateFAQTexture - missing or invalid control") return end
    local helpUrl = controlData and GetStringFromValue(controlData.helpUrl)
    if not helpUrl or helpUrl == "" then return end

    local faqControl = wm:CreateControl(nil, control, CT_TEXTURE)
    control.faqControl = faqControl

    faqControl:SetDrawLayer(DL_OVERLAY)
    faqControl:SetTexture("EsoUI\\Art\\miscellaneous\\help_icon.dds")
    faqControl:SetDimensions(FAQ_ICON_SIZE, FAQ_ICON_SIZE)
    faqControl:SetColor(FAQ_ICON_COLOR:UnpackRGBA())
    faqControl:SetAlpha(FAQ_ICON_MOUSE_EXIT_ALPHA)
    faqControl:SetHidden(false)

    faqControl.data = faqControl.data or {}
    faqControl.data.helpUrl = helpUrl
    faqControl.data.tooltipText = FAQ_ICON_TOOTIP_TEMPLATE:format(util.L.WEBSITE, helpUrl)

    faqControl:SetMouseEnabled(true)
    local function onMouseExitFAQ(ctrl, ...)
        ZO_Options_OnMouseExit(ctrl)
        ctrl:SetColor(FAQ_ICON_COLOR:UnpackRGBA())
        ctrl:SetAlpha(FAQ_ICON_MOUSE_EXIT_ALPHA)
    end
    faqControl:SetHandler("OnMouseUp", function(self, button, upInside)
        if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
            --As the parent control's OnMouseExit won't be called because of the popup "open website":
            --We hide the faq texture ourself
            onMouseExitFAQ(self, true)
            RequestOpenUnsafeURL(helpUrl)
        end
    end)
    faqControl:SetHandler("OnMouseEnter", function(self)
        ZO_Options_OnMouseEnter(self)
        self:SetColor(FAQ_ICON_MOUSE_OVER_COLOR:UnpackRGBA()) --light blue
        self:SetAlpha(FAQ_ICON_MOUSE_OVER_ALPHA)
    end, "LAM2_FAQTexture_OnMouseEnter")
    faqControl:SetHandler("OnMouseExit", onMouseExitFAQ, "LAM2_FAQTexture_OnMouseExit")

    return faqControl
end

local function CreateBaseControl(parent, controlData, controlName)
    local control = wm:CreateControl(controlName or controlData.reference, parent.scroll or parent, CT_CONTROL)
    control.panel = parent.panel or parent -- if this is in a submenu, panel is the submenu's parent
    control.data = controlData

    control.isHalfWidth = controlData.width == "half"
    local width = 510 -- set default width in case a custom parent object is passed
    if control.panel.GetWidth ~= nil then width = control.panel:GetWidth() - 60 end
    control:SetWidth(width)
    return control
end

local function CreateLabelAndContainerControl(parent, controlData, controlName)
    local control = CreateBaseControl(parent, controlData, controlName)
    local width = control:GetWidth()

    local container = wm:CreateControl(nil, control, CT_CONTROL)
    container:SetDimensions(width / 3, MIN_HEIGHT)
    control.container = container

    local labelContainer
    local faqTexture = CreateFAQTexture(control)
    if faqTexture then
        labelContainer = wm:CreateControl(nil, control, CT_CONTROL)
        labelContainer:SetHeight(MIN_HEIGHT)
        control.labelContainer = container
    end

    local label = wm:CreateControl(nil, labelContainer or control, CT_LABEL)
    label:SetFont("ZoFontWinH4")
    label:SetHeight(MIN_HEIGHT)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetText(GetStringFromValue(controlData.name))
    control.label = label

    local labelAnchorTarget = labelContainer or label
    if control.isHalfWidth then
        control:SetDimensions(width / 2, MIN_HEIGHT * 2 + HALF_WIDTH_LINE_SPACING)
        labelAnchorTarget:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        labelAnchorTarget:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
        container:SetAnchor(TOPRIGHT, labelAnchorTarget, BOTTOMRIGHT, 0, HALF_WIDTH_LINE_SPACING)
    else
        control:SetDimensions(width, MIN_HEIGHT)
        container:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
        labelAnchorTarget:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        labelAnchorTarget:SetAnchor(TOPRIGHT, container, TOPLEFT, 5, 0)
    end

    if faqTexture then
        faqTexture:ClearAnchors()
        faqTexture:SetAnchor(LEFT, label, RIGHT, 5, -1)
        faqTexture:SetParent(labelContainer)
        label:SetAnchor(LEFT, labelContainer, LEFT)
        label:SetDimensionConstraints(0, 0, labelContainer:GetWidth() - faqTexture:GetWidth(), 0)
    end

    control.data.tooltipText = GetStringFromValue(control.data.tooltip)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
    control:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
    return control
end

local function SetUpTooltip(control, data, tooltipData)
    if not data.tooltip then return end
    control:SetMouseEnabled(true)
    control.data = tooltipData or {tooltipText = util.GetStringFromValue(data.tooltip)}
    control:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
    control:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
end

local function GetTopPanel(panel)
    while panel.panel and panel.panel ~= panel do
        panel = panel.panel
    end
    return panel
end

local function IsSame(objA, objB)
    if #objA ~= #objB then return false end
    for i = 1, #objA do
        if objA[i] ~= objB[i] then return false end
    end
    return true
end

local function RefreshReloadUIButton()
    lam.requiresReload = false

    for i = 1, #controlsForReload do
        local reloadControl = controlsForReload[i]
        if not IsSame(reloadControl.startValue, {reloadControl.data.getFunc()}) then
            lam.requiresReload = true
            break
        end
    end

    if lam.applyButton then
        lam.applyButton:SetHidden(not lam.requiresReload)
    end
end

local function RequestRefreshIfNeeded(control)
    -- if our parent window wants to refresh controls, then fire the callback
    local panel = GetTopPanel(control)
    local panelData = panel.data
    if panelData.registerForRefresh then
        cm:FireCallbacks("LAM-RefreshPanel", control)
    end
    RefreshReloadUIButton()
end

local function RegisterForRefreshIfNeeded(control)
    -- if our parent window wants to refresh controls, then add this to the list
    local panel = GetTopPanel(control.panel)
    local panelData = panel.data
    if panelData.registerForRefresh or panelData.registerForDefaults then
        tinsert(panel.controlsToRefresh or {}, control) -- prevent errors on custom panels
    end
end

local function RegisterForReloadIfNeeded(control)
    if control.data.requiresReload then
        tinsert(controlsForReload, control)
        control.startValue = {control.data.getFunc()}
    end
end

local function GetConfirmDialog()
    if(not ESO_Dialogs[LAM_CONFIRM_DIALOG]) then
        ESO_Dialogs[LAM_CONFIRM_DIALOG] = {
            canQueue = true,
            title = {
                text = "",
            },
            mainText = {
                text = "",
            },
            buttons = {
                [1] = {
                    text = SI_DIALOG_CONFIRM,
                    callback = function(dialog) end,
                },
                [2] = {
                    text = SI_DIALOG_CANCEL,
                }
            }
        }
    end
    return ESO_Dialogs[LAM_CONFIRM_DIALOG]
end

local function ShowConfirmationDialog(title, body, callback)
    local dialog = GetConfirmDialog()
    dialog.title.text = title
    dialog.mainText.text = body
    dialog.buttons[1].callback = callback
    ZO_Dialogs_ShowDialog(LAM_CONFIRM_DIALOG)
end

local function GetDefaultsDialog()
    if(not ESO_Dialogs[LAM_DEFAULTS_DIALOG]) then
        ESO_Dialogs[LAM_DEFAULTS_DIALOG] = {
            canQueue = true,
            title = {
                text = SI_INTERFACE_OPTIONS_RESET_TO_DEFAULT_TOOLTIP,
            },
            mainText = {
                text = SI_OPTIONS_RESET_PROMPT,
            },
            buttons = {
                [1] = {
                    text = SI_OPTIONS_RESET,
                    callback = function(dialog) end,
                },
                [2] = {
                    text = SI_DIALOG_CANCEL,
                }
            }
        }
    end
    return ESO_Dialogs[LAM_DEFAULTS_DIALOG]
end

local function ShowDefaultsDialog(panel)
    local dialog = GetDefaultsDialog()
    dialog.buttons[1].callback = function()
        panel:ForceDefaults()
        RefreshReloadUIButton()
    end
    ZO_Dialogs_ShowDialog(LAM_DEFAULTS_DIALOG)
end

local function DiscardChangesOnReloadControls()
    for i = 1, #controlsForReload do
        local reloadControl = controlsForReload[i]
        if not IsSame(reloadControl.startValue, {reloadControl.data.getFunc()}) then
            reloadControl:UpdateValue(false, unpack(reloadControl.startValue))
        end
    end
    lam.requiresReload = false
    lam.applyButton:SetHidden(true)
end

local function StorePanelForReopening()
    local saveData = ZO_Ingame_SavedVariables["LAM"] or {}
    saveData.reopenPanel = lam.currentAddonPanel:GetName()
    ZO_Ingame_SavedVariables["LAM"] = saveData
end

local function RetrievePanelForReopening()
    local saveData = ZO_Ingame_SavedVariables["LAM"]
    if(saveData) then
        ZO_Ingame_SavedVariables["LAM"] = nil
        return _G[saveData.reopenPanel]
    end
end

local function HandleReloadUIPressed()
    StorePanelForReopening()
    ReloadUI()
end

local function HandleLoadDefaultsPressed()
    ShowDefaultsDialog(lam.currentAddonPanel)
end

local function GetReloadDialog()
    if(not ESO_Dialogs[LAM_RELOAD_DIALOG]) then
        ESO_Dialogs[LAM_RELOAD_DIALOG] = {
            canQueue = true,
            title = {
                text = util.L["RELOAD_DIALOG_TITLE"],
            },
            mainText = {
                text = util.L["RELOAD_DIALOG_TEXT"],
            },
            buttons = {
                [1] = {
                    text = util.L["RELOAD_DIALOG_RELOAD_BUTTON"],
                    callback = function() ReloadUI() end,
                },
                [2] = {
                    text = util.L["RELOAD_DIALOG_DISCARD_BUTTON"],
                    callback = DiscardChangesOnReloadControls,
                }
            },
            noChoiceCallback = DiscardChangesOnReloadControls,
        }
    end
    return ESO_Dialogs[LAM_CONFIRM_DIALOG]
end

local function ShowReloadDialogIfNeeded()
    if lam.requiresReload then
        local dialog = GetReloadDialog()
        ZO_Dialogs_ShowDialog(LAM_RELOAD_DIALOG)
    end
end

local function UpdateWarning(control)
    local warning
    if control.data.warning ~= nil then
        warning = util.GetStringFromValue(control.data.warning)
    end

    if control.data.requiresReload then
        if not warning then
            warning = string.format("%s", util.L["RELOAD_UI_WARNING"])
        else
            warning = string.format("%s\n\n%s", warning, util.L["RELOAD_UI_WARNING"])
        end
    end

    if not warning then
        control.warning:SetHidden(true)
    else
        control.warning.data = {tooltipText = warning}
        control.warning:SetHidden(false)
    end
end

local localization = {
    en = {
        PANEL_NAME = "Addons",
        AUTHOR = string.format("%s: <<X:1>>", GetString(SI_ADDON_MANAGER_AUTHOR)), -- "Author: <<X:1>>"
        VERSION = "Version: <<X:1>>",
        WEBSITE = "Visit Website",
        FEEDBACK = "Feedback",
        TRANSLATION = "Translation",
        DONATION = "Donate",
        PANEL_INFO_FONT = "$(CHAT_FONT)|14|soft-shadow-thin",
        RELOAD_UI_WARNING = "Changes to this setting require a UI reload in order to take effect.",
        RELOAD_DIALOG_TITLE = "UI Reload Required",
        RELOAD_DIALOG_TEXT = "Some changes require a UI reload in order to take effect. Do you want to reload now or discard the changes?",
        RELOAD_DIALOG_RELOAD_BUTTON = "Reload",
        RELOAD_DIALOG_DISCARD_BUTTON = "Discard",
    },
    it = { -- provided by JohnnyKing
        PANEL_NAME = "Addon",
        VERSION = "Versione: <<X:1>>",
        WEBSITE = "Visita il Sitoweb",
        FEEDBACK = "Feedback",
        TRANSLATION = "Traduzione",
        DONATION = "Donare",
        RELOAD_UI_WARNING = "Cambiare questa impostazione richiede un Ricarica UI al fine che faccia effetto.",
        RELOAD_DIALOG_TITLE = "Ricarica UI richiesto",
        RELOAD_DIALOG_TEXT = "Alcune modifiche richiedono un Ricarica UI al fine che facciano effetto. Sei sicuro di voler ricaricare ora o di voler annullare le modifiche?",
        RELOAD_DIALOG_RELOAD_BUTTON = "Ricarica",
        RELOAD_DIALOG_DISCARD_BUTTON = "Annulla",
    },
    fr = { -- provided by Ayantir
        PANEL_NAME = "Extensions",
        WEBSITE = "Visiter le site Web",
        FEEDBACK = "Réaction",
        TRANSLATION = "Traduction",
        DONATION = "Donner",
        RELOAD_UI_WARNING = "La modification de ce paramètre requiert un rechargement de l'UI pour qu'il soit pris en compte.",
        RELOAD_DIALOG_TITLE = "Reload UI requis",
        RELOAD_DIALOG_TEXT = "Certaines modifications requièrent un rechargement de l'UI pour qu'ils soient pris en compte. Souhaitez-vous recharger l'interface maintenant ou annuler les modifications ?",
        RELOAD_DIALOG_RELOAD_BUTTON = "Recharger",
        RELOAD_DIALOG_DISCARD_BUTTON = "Annuler",
    },
    de = { -- provided by sirinsidiator
        PANEL_NAME = "Erweiterungen",
        WEBSITE = "Webseite besuchen",
        FEEDBACK = "Feedback",
        TRANSLATION = "Übersetzung",
        DONATION = "Spende",
        RELOAD_UI_WARNING = "Änderungen an dieser Option werden erst übernommen nachdem die Benutzeroberfläche neu geladen wird.",
        RELOAD_DIALOG_TITLE = "Neuladen benötigt",
        RELOAD_DIALOG_TEXT = "Einige Änderungen werden erst übernommen nachdem die Benutzeroberfläche neu geladen wird. Wollt Ihr sie jetzt neu laden oder die Änderungen verwerfen?",
        RELOAD_DIALOG_RELOAD_BUTTON = "Neu laden",
        RELOAD_DIALOG_DISCARD_BUTTON = "Verwerfen",
    },
    ru = { -- provided by TERAB1T, updated by andy.s
        PANEL_NAME = "Дополнения",
        VERSION = "Версия: <<X:1>>",
        WEBSITE = "Посетить сайт",
        FEEDBACK = "Отзыв",
        TRANSLATION = "Перевод",
        DONATION = "Жертвовать",
        RELOAD_UI_WARNING = "Для применения этой настройки необходима перезагрузка интерфейса.",
        RELOAD_DIALOG_TITLE = "Необходима перезагрузка интерфейса",
        RELOAD_DIALOG_TEXT = "Для применения некоторых изменений необходима перезагрузка интерфейса. Перезагрузить интерфейс сейчас или отменить изменения?",
        RELOAD_DIALOG_RELOAD_BUTTON = "Перезагрузить",
        RELOAD_DIALOG_DISCARD_BUTTON = "Отменить изменения",
    },
    es = { -- provided by Morganlefai, checked by Kwisatz
        PANEL_NAME = "Configuración",
        VERSION = "Versión: <<X:1>>",
        WEBSITE = "Visita la página web",
        FEEDBACK = "Reaccion",
        TRANSLATION = "Traducción",
        DONATION = "Donar",
        RELOAD_UI_WARNING = "Cambiar este ajuste recargará la interfaz del usuario.",
        RELOAD_DIALOG_TITLE = "Requiere recargar la interfaz",
        RELOAD_DIALOG_TEXT = "Algunos cambios requieren recargar la interfaz para poder aplicarse. Quieres aplicar los cambios y recargar la interfaz?",
        RELOAD_DIALOG_RELOAD_BUTTON = "Recargar",
        RELOAD_DIALOG_DISCARD_BUTTON = "Cancelar",
    },
    jp = { -- provided by k0ta0uchi, updated by Calamath
        PANEL_NAME = "アドオン設定",
        WEBSITE = "ウェブサイトを見る",
        FEEDBACK = "フィードバック",
        TRANSLATION = "訳書",
        DONATION = "寄付",
        RELOAD_UI_WARNING = "この設定変更を有効にするには、UIのリロードが必要です。",
        RELOAD_DIALOG_TITLE = "UIのリロードが必要",
        RELOAD_DIALOG_TEXT = "一部の変更を有効にするには、UIのリロードが必要です。 今すぐリロードしますか、それとも変更内容を破棄しますか？",
        RELOAD_DIALOG_RELOAD_BUTTON = "リロード",
        RELOAD_DIALOG_DISCARD_BUTTON = "破棄",
    },
    zh = { -- provided by Jacko9et
        PANEL_NAME = GetString(SI_GAME_MENU_ADDONS),
        AUTHOR = string.format("%s: <<X:1>>", GetString(SI_ADDON_MANAGER_AUTHOR)), -- "Author: <<X:1>>"
        VERSION = "版本: <<X:1>>",
        WEBSITE = "访问网站",
        FEEDBACK = GetString(SI_CUSTOMER_SERVICE_SUBMIT_FEEDBACK),
        TRANSLATION = GetString(SI_ENCHANTING_TRANSLATION_HEADER),
        DONATION = "捐赠",
        PANEL_INFO_FONT = "$(CHAT_FONT)|14|soft-shadow-thin",
        RELOAD_UI_WARNING = "对此设置的更改需要重新加载界面才能生效。",
        RELOAD_DIALOG_TITLE = "需要重新加载界面",
        RELOAD_DIALOG_TEXT = "某些更改需要重新加载界面才能生效。您想现在重新加载还是放弃更改？",
        RELOAD_DIALOG_RELOAD_BUTTON = GetString(SI_ADDON_MANAGER_RELOAD),
        RELOAD_DIALOG_DISCARD_BUTTON = GetString(SI_CHAMPION_SYSTEM_DISCARD_CHANGES),
    },
    pl = { -- provided by EmiruTegryfon
        PANEL_NAME = "Dodatki",
        VERSION = "Wersja: <<X:1>>",
        WEBSITE = "Odwiedź stronę",
        RELOAD_UI_WARNING = "Zmiany będą widoczne po ponownym załadowaniu UI.",
        RELOAD_DIALOG_TITLE = "Wymagane przeładowanie UI",
        RELOAD_DIALOG_TEXT = "Niektóre zmiany wymagają ponownego załadowania UI. Czy chcesz teraz ponownie załadować, czy porzucić zmiany?",
        RELOAD_DIALOG_RELOAD_BUTTON = "Przeładuj",
        RELOAD_DIALOG_DISCARD_BUTTON = "Porzuć",
    },
    br = { -- provided by mlsevero & FelipeS11
        PANEL_NAME = "Addons",
        AUTHOR = string.format("%s: <<X:1>>", GetString(SI_ADDON_MANAGER_AUTHOR)), -- "Autor: <<X:1>>"
        VERSION = "Versão: <<X:1>>",
        WEBSITE = "Visite o Website",
        FEEDBACK = "Feedback",
        TRANSLATION = "Tradução",
        DONATION = "Doação",
        RELOAD_UI_WARNING = "Mudanças nessa configuração requerem o recarregamento da UI para ter efeito.",
        RELOAD_DIALOG_TITLE = "Recarregamento da UI requerida",
        RELOAD_DIALOG_TEXT = "Algumas mudanças requerem o recarregamento da UI para ter efeito. Você deseja recarregar agora ou descartar as mudanças?",
        RELOAD_DIALOG_RELOAD_BUTTON = "Recarregar",
        RELOAD_DIALOG_DISCARD_BUTTON = "Descartar",
    },
    tr = {
        PANEL_NAME= "Eklentiler",
        AUTHOR = string.format("%s: <<X:1>>", GetString(SI_ADDON_MANAGER_AUTHOR)), -- "Yazar: <<X:1>>"
        VERSION = "Sürüm: <<X:1>>",
        WEBSITE = "Web Sitesini Ziyaret Edin",
        FEEDBACK = "Geri bildirim",
        TRANSLATION = "Çeviri",
        DONATION = "Bağış",
        PANEL_INFO_FONT = "$(CHAT_FONT)|14|soft-shadow-thin",
        RELOAD_UI_WARNING = "Bu ayarda yapılan değişikliklerin etkili olması için kullanıcı arayüzünün yeniden yüklenmesi gerekir.",
        RELOAD_DIALOG_TITLE = "Kullanıcı Arayüzünün Yeniden Yüklenmesi Gerekli",
        RELOAD_DIALOG_TEXT = "Bazı değişikliklerin etkili olması için kullanıcı arayüzünün yeniden yüklenmesi gerekir. Şimdi yeniden yüklemek mi yoksa değişiklikleri iptal etmek mi istiyorsunuz?",
        RELOAD_DIALOG_RELOAD_BUTTON = "Yeniden Yükle",
        RELOAD_DIALOG_DISCARD_BUTTON = "İptal et",
    },
    ua = {
        PANEL_NAME = "Додатки",
        AUTHOR = string.format("%s: <<X:1>>", GetString(SI_ADDON_MANAGER_AUTHOR)), -- "Автор: <<X:1>>"
        VERSION = "Версія: <<X:1>>",
        WEBSITE = "Відвідати вебсайт",
        FEEDBACK = "Відгук",
        TRANSLATION = "Переклад",
        DONATION = "Підтримати",
        PANEL_INFO_FONT = "$(CHAT_FONT)|14|soft-shadow-thin",
        RELOAD_UI_WARNING = "Зміни цього параметра потребують перезавантаження інтерфейсу, аби вони набули чинності.",
        RELOAD_DIALOG_TITLE = "Необхідне перезавантаження інтерфейсу",
        RELOAD_DIALOG_TEXT = "Деякі зміни потребують перезавантаження інтерфейсу, аби вони набули чинності. Перезавантажити зараз чи бажаєте скасувати зміни?",
        RELOAD_DIALOG_RELOAD_BUTTON = "Перезавантажити",
        RELOAD_DIALOG_DISCARD_BUTTON = "Скасувати",
    },
}

do
    local EsoKR = EsoKR
    if EsoKR and EsoKR:isKorean() then
        util.L = ZO_ShallowTableCopy({ -- provided by whya5448
            PANEL_NAME = EsoKR:E("애드온"),
            AUTHOR = string.format("%s: <<X:1>>", GetString(SI_ADDON_MANAGER_AUTHOR)), -- "Author: <<X:1>>"
            VERSION = EsoKR:E("버전: <<X:1>>"),
            WEBSITE = EsoKR:E("웹사이트 방문"),
            FEEDBACK = EsoKR:E("피드백"),
            TRANSLATION = EsoKR:E("번역"),
            DONATION = EsoKR:E("기부"),
            PANEL_INFO_FONT = "EsoKR/fonts/Univers57.otf|14|soft-shadow-thin",
            RELOAD_UI_WARNING = EsoKR:E("이 설정을 변경하면 효과를 적용하기위해 UI 새로고침이 필요합니다."),
            RELOAD_DIALOG_TITLE = EsoKR:E("UI 새로고침 필요"),
            RELOAD_DIALOG_TEXT = EsoKR:E("변경된 설정 중 UI 새로고침을 필요로하는 사항이 있습니다. 지금 새로고침하시겠습니까? 아니면 변경을 취소하시겠습니까?"),
            RELOAD_DIALOG_RELOAD_BUTTON = EsoKR:E("새로고침"),
            RELOAD_DIALOG_DISCARD_BUTTON = EsoKR:E("변경취소"),
        }, localization["en"])
    else
        util.L = ZO_ShallowTableCopy(localization[GetCVar("Language.2")] or {}, localization["en"])
    end
end

util.GetTooltipText = GetStringFromValue -- deprecated, use util.GetStringFromValue instead
util.GetStringFromValue = GetStringFromValue
util.GetDefaultValue = GetDefaultValue
util.GetColorForState = GetColorForState
util.CreateBaseControl = CreateBaseControl
util.CreateLabelAndContainerControl = CreateLabelAndContainerControl
util.SetUpTooltip = SetUpTooltip
util.RequestRefreshIfNeeded = RequestRefreshIfNeeded
util.RegisterForRefreshIfNeeded = RegisterForRefreshIfNeeded
util.RegisterForReloadIfNeeded = RegisterForReloadIfNeeded
util.GetTopPanel = GetTopPanel
util.ShowConfirmationDialog = ShowConfirmationDialog
util.UpdateWarning = UpdateWarning
util.CreateFAQTexture = CreateFAQTexture

local ADDON_DATA_TYPE = 1
local RESELECTING_DURING_REBUILD = true
local USER_REQUESTED_OPEN = true


--INTERNAL FUNCTION
--scrolls ZO_ScrollList `list` to move the row corresponding to `data`
-- into view (does nothing if there is no such row in the list)
--unlike ZO_ScrollList_ScrollDataIntoView, this function accounts for
-- fading near the list's edges - it avoids the fading area by scrolling
-- a little further than the ZO function
local function ScrollDataIntoView(list, data)
    local targetIndex = data.sortIndex
    if not targetIndex then return end

    local scrollMin, scrollMax = list.scrollbar:GetMinMax()
    local scrollTop = list.scrollbar:GetValue()
    local controlHeight = list.uniformControlHeight or list.controlHeight
    local targetMin = controlHeight * (targetIndex - 1) - 64
    -- subtracting 64 ain't arbitrary, it's the maximum fading height
    -- (libraries/zo_templates/scrolltemplates.lua/UpdateScrollFade)

    if targetMin < scrollTop then
        ZO_ScrollList_ScrollAbsolute(list, zo_max(targetMin, scrollMin))
    else
        local listHeight = ZO_ScrollList_GetHeight(list)
        local targetMax = controlHeight * targetIndex + 64 - listHeight

        if targetMax > scrollTop then
            ZO_ScrollList_ScrollAbsolute(list, zo_min(targetMax, scrollMax))
        end
    end
end


--INTERNAL FUNCTION
--constructs a string pattern from the text in `searchEdit` control
-- * metacharacters are escaped, losing their special meaning
-- * whitespace matches anything (including empty substring)
--if there is nothing but whitespace, returns nil
--otherwise returns a filter function, which takes a `data` table argument
-- and returns true iff `data.filterText` matches the pattern
local function GetSearchFilterFunc(searchEdit)
    local text = searchEdit:GetText():lower()
    local pattern = text:match("(%S+.-)%s*$")

    if not pattern then -- nothing but whitespace
        return nil
    end

    -- escape metacharacters, e.g. "ESO-Datenbank.de" => "ESO%-Datenbank%.de"
    pattern = pattern:gsub("[-*+?^$().[%]%%]", "%%%0")

    -- replace whitespace with "match shortest anything"
    pattern = pattern:gsub("%s+", ".-")

    return function(data)
        return data.filterText:lower():find(pattern) ~= nil
    end
end


--INTERNAL FUNCTION
--populates `addonList` with entries from `addonsForList`
-- addonList = ZO_ScrollList control
-- filter = [optional] function(data)
local function PopulateAddonList(addonList, filter)
    local entryList = ZO_ScrollList_GetDataList(addonList)
    local numEntries = 0
    local selectedData = nil
    local selectionIsFinal = false

    ZO_ScrollList_Clear(addonList)

    for i, data in ipairs(addonsForList) do
        if not filter or filter(data) then
            local dataEntry = ZO_ScrollList_CreateDataEntry(ADDON_DATA_TYPE, data)
            numEntries = numEntries + 1
            data.sortIndex = numEntries
            entryList[numEntries] = dataEntry
            -- select the first panel passing the filter, or the currently
            -- shown panel, but only if it passes the filter as well
            if selectedData == nil or data.panel == lam.pendingAddonPanel or data.panel == lam.currentAddonPanel then
                if not selectionIsFinal then
                    selectedData = data
                end
                if data.panel == lam.pendingAddonPanel then
                    lam.pendingAddonPanel = nil
                    selectionIsFinal = true
                end
            end
        else
            data.sortIndex = nil
        end
    end

    ZO_ScrollList_Commit(addonList)

    if selectedData then
        if selectedData.panel == lam.currentAddonPanel then
            ZO_ScrollList_SelectData(addonList, selectedData, nil, RESELECTING_DURING_REBUILD)
        else
            ZO_ScrollList_SelectData(addonList, selectedData, nil)
        end
        ScrollDataIntoView(addonList, selectedData)
    end
end


--METHOD: REGISTER WIDGET--
--each widget has its version checked before loading,
--so we only have the most recent one in memory
--Usage:
-- widgetType = "string"; the type of widget being registered
-- widgetVersion = integer; the widget's version number
LAMCreateControl = LAMCreateControl or {}
local lamcc = LAMCreateControl

function lam:RegisterWidget(widgetType, widgetVersion)
    if widgets[widgetType] and widgets[widgetType] >= widgetVersion then
        return false
    else
        widgets[widgetType] = widgetVersion
        return true
    end
end

-- INTERNAL METHOD: hijacks the handlers for the actions in the OptionsWindow layer if not already done
local function InitKeybindActions()
    if not lam.keybindsInitialized then
        lam.keybindsInitialized = true
        ZO_PreHook(KEYBOARD_OPTIONS, "ApplySettings", function()
            if lam.currentPanelOpened then
                if not lam.applyButton:IsHidden() then
                    HandleReloadUIPressed()
                end
                return true
            end
        end)
        ZO_PreHook("ZO_Dialogs_ShowDialog", function(dialogName)
            if lam.currentPanelOpened and dialogName == "OPTIONS_RESET_TO_DEFAULTS" then
                if not lam.defaultButton:IsHidden() then
                    HandleLoadDefaultsPressed()
                end
                return true
            end
        end)
    end
end

-- INTERNAL METHOD: fires the LAM-PanelOpened callback if not already done
local function OpenCurrentPanel()
    if lam.currentAddonPanel and not lam.currentPanelOpened then
        lam.currentPanelOpened = true
        lam.defaultButton:SetHidden(not lam.currentAddonPanel.data.registerForDefaults)
        cm:FireCallbacks("LAM-PanelOpened", lam.currentAddonPanel)
    end
end

-- INTERNAL METHOD: fires the LAM-PanelClosed callback if not already done
local function CloseCurrentPanel()
    if lam.currentAddonPanel and lam.currentPanelOpened then
        lam.currentPanelOpened = false
        cm:FireCallbacks("LAM-PanelClosed", lam.currentAddonPanel)
    end
end

--METHOD: OPEN TO ADDON PANEL--
--opens to a specific addon's option panel
--Usage:
-- panel = userdata; the panel returned by the :RegisterOptionsPanel method
local locSettings = GetString(SI_GAME_MENU_SETTINGS)
function lam:OpenToPanel(panel)

    -- find and select the panel's row in addon list

    local addonList = lam.addonList
    local selectedData = nil

    for _, addonData in ipairs(addonsForList) do
        if addonData.panel == panel then
            selectedData = addonData
            ScrollDataIntoView(addonList, selectedData)
            lam.pendingAddonPanel = addonData.panel
            break
        end
    end

    ZO_ScrollList_SelectData(addonList, selectedData)
    ZO_ScrollList_RefreshVisible(addonList, selectedData)

    local srchEdit = LAMAddonSettingsWindow:GetNamedChild("SearchFilterEdit")
    srchEdit:Clear()

    -- note that ZO_ScrollList doesn't require `selectedData` to be actually
    -- present in the list, and that the list will only be populated once LAM
    -- "Addon Settings" menu entry is selected for the first time

    local function openAddonSettingsMenu()
        local gameMenu = ZO_GameMenu_InGame.gameMenu
        local settingsMenu = gameMenu.headerControls[locSettings]

        if settingsMenu then -- an instance of ZO_TreeNode
            local children = settingsMenu:GetChildren()
            for i = 1, (children and #children or 0) do
                local childNode = children[i]
                local data = childNode:GetData()
                if data and data.id == lam.panelId then
                    -- found LAM "Addon Settings" node, yay!
                    childNode:GetTree():SelectNode(childNode)
                    break
                end
            end
        end
    end

    if sm:GetScene("gameMenuInGame"):GetState() == SCENE_SHOWN then
        openAddonSettingsMenu()
    else
        sm:CallWhen("gameMenuInGame", SCENE_SHOWN, openAddonSettingsMenu)
        sm:Show("gameMenuInGame")
    end
end

local TwinOptionsContainer_Index = 0
local function TwinOptionsContainer(parent, leftWidget, rightWidget)
    TwinOptionsContainer_Index = TwinOptionsContainer_Index + 1
    local cParent = parent.scroll or parent
    local panel = parent.panel or cParent
    local container = wm:CreateControl("$(parent)TwinContainer" .. tostring(TwinOptionsContainer_Index),
        cParent, CT_CONTROL)
    container:SetResizeToFitDescendents(true)
    container:SetAnchor(select(2, leftWidget:GetAnchor(0) ))

    leftWidget:ClearAnchors()
    leftWidget:SetAnchor(TOPLEFT, container, TOPLEFT)
    rightWidget:SetAnchor(TOPLEFT, leftWidget, TOPRIGHT, 5, 0)

    leftWidget:SetWidth( leftWidget:GetWidth() - 2.5 ) -- fixes bad alignment with 'full' controls
    rightWidget:SetWidth( rightWidget:GetWidth() - 2.5 )

    leftWidget:SetParent(container)
    rightWidget:SetParent(container)

    container.data = {type = "container"}
    container.panel = panel
    return container
end

--INTERNAL FUNCTION
--creates controls when options panel is first shown
--controls anchoring of these controls in the panel
local function CreateOptionsControls(panel)
    local addonID = panel:GetName()
    if(optionsState[addonID] == OPTIONS_CREATED) then
        return false
    elseif(optionsState[addonID] == OPTIONS_CREATION_RUNNING) then
        return true
    end
    optionsState[addonID] = OPTIONS_CREATION_RUNNING

    local function CreationFinished()
        optionsState[addonID] = OPTIONS_CREATED
        cm:FireCallbacks("LAM-PanelControlsCreated", panel)
        OpenCurrentPanel()
    end

    cm:FireCallbacks("LAM-BeforePanelControlsCreated", panel)
    local optionsTable = addonToOptionsMap[addonID]
    if optionsTable then
        local function CreateAndAnchorWidget(parent, widgetData, offsetX, offsetY, anchorTarget, wasHalf)
            local widget
            local status, err = pcall(function() widget = LAMCreateControl[widgetData.type](parent, widgetData) end)
            if not status then
                return err or true, offsetY, anchorTarget, wasHalf
            else
                local isHalf = (widgetData.width == "half")
                if not anchorTarget then -- the first widget in a panel is just placed in the top left corner
                    widget:SetAnchor(TOPLEFT)
                    anchorTarget = widget
                elseif wasHalf and isHalf then -- when the previous widget was only half width and this one is too, we place it on the right side
                    widget.lineControl = anchorTarget
                    isHalf = false
                    offsetY = 0
                    anchorTarget = TwinOptionsContainer(parent, anchorTarget, widget)
                else -- otherwise we just put it below the previous one normally
                    widget:SetAnchor(TOPLEFT, anchorTarget, BOTTOMLEFT, 0, 15)
                    offsetY = 0
                    anchorTarget = widget
                end
                return false, offsetY, anchorTarget, isHalf
            end
        end

        local THROTTLE_TIMEOUT, THROTTLE_COUNT = 10, 20
        local fifo = {}
        local anchorOffset, lastAddedControl, wasHalf
        local CreateWidgetsInPanel, err

        local function PrepareForNextPanel()
            anchorOffset, lastAddedControl, wasHalf = 0, nil, false
        end

        local function SetupCreationCalls(parent, widgetDataTable)
            fifo[#fifo + 1] = PrepareForNextPanel
            local count = #widgetDataTable
            for i = 1, zo_ceil(count / THROTTLE_COUNT) do
                fifo[#fifo + 1] = function()
                    local startIndex = (i - 1) * THROTTLE_COUNT + 1
                    local endIndex = zo_min(i * THROTTLE_COUNT, count)
                    CreateWidgetsInPanel(parent, widgetDataTable, startIndex, endIndex)
                end
            end
            return count ~= NonContiguousCount(widgetDataTable)
        end

        CreateWidgetsInPanel = function(parent, widgetDataTable, startIndex, endIndex)
            for i=startIndex,endIndex do
                local widgetData = widgetDataTable[i]
                if not widgetData then
                    PrintLater("Skipped creation of missing entry in the settings menu of " .. addonID .. ".")
                else
                    local widgetType = widgetData.type
                    local offsetX = 0
                    local isSubmenu = (widgetType == "submenu")
                    if isSubmenu then
                        wasHalf = false
                        offsetX = 5
                    end

                    err, anchorOffset, lastAddedControl, wasHalf = CreateAndAnchorWidget(parent, widgetData, offsetX, anchorOffset, lastAddedControl, wasHalf)
                    if err then
                        PrintLater(("Could not create %s '%s' of %s."):format(widgetData.type, GetStringFromValue(widgetData.name or "unnamed"), addonID))
                        logger:Error(err)
                    end

                    if isSubmenu then
                        if SetupCreationCalls(lastAddedControl, widgetData.controls) then
                            PrintLater(("The sub menu '%s' of %s is missing some entries."):format(GetStringFromValue(widgetData.name or "unnamed"), addonID))
                        end
                    end
                end
            end
        end

        local function DoCreateSettings()
            if #fifo > 0 then
                local nextCall = table.remove(fifo, 1)
                nextCall()
                if(nextCall == PrepareForNextPanel) then
                    DoCreateSettings()
                else
                    zo_callLater(DoCreateSettings, THROTTLE_TIMEOUT)
                end
            else
                CreationFinished()
            end
        end

        if SetupCreationCalls(panel, optionsTable) then
            PrintLater(("The settings menu of %s is missing some entries."):format(addonID))
        end
        DoCreateSettings()
    else
        CreationFinished()
    end

    return true
end

--INTERNAL FUNCTION
--handles switching between panels
local function ToggleAddonPanels(panel) --called in OnShow of newly shown panel
    local currentlySelected = lam.currentAddonPanel
    if currentlySelected and currentlySelected ~= panel then
        currentlySelected:SetHidden(true)
        CloseCurrentPanel()
    end
    lam.currentAddonPanel = panel

    -- refresh visible rows to reflect panel IsHidden status
    ZO_ScrollList_RefreshVisible(lam.addonList)

    if not CreateOptionsControls(panel) then
        OpenCurrentPanel()
    end

    cm:FireCallbacks("LAM-RefreshPanel", panel)
end

local CheckSafetyAndInitialize
local function ShowSetHandlerWarning(panel, handler)
    local hint
    if(handler == "OnShow" or handler == "OnEffectivelyShown") then
        hint = "'LAM-PanelControlsCreated' or 'LAM-PanelOpened'"
    elseif(handler == "OnHide" or handler == "OnEffectivelyHidden") then
        hint = "'LAM-PanelClosed'"
    end

    if hint then
        local message = ("Setting a handler on a panel is not recommended. Use the global callback %s instead. (%s on %s)"):format(hint, handler, panel.data.name)
        PrintLater(message)
        logger:Warn(message)
    end
end

--METHOD: REGISTER ADDON PANEL
--registers your addon with LibAddonMenu and creates a panel
--Usage:
-- addonID = "string"; unique ID which will be the global name of your panel
-- panelData = table; data object for your panel - see controls\panel.lua
function lam:RegisterAddonPanel(addonID, panelData)
    CheckSafetyAndInitialize(addonID)
    if IsConsoleUI() then
        lam:registerConsoleAddonPanel(addonID, panelData)
        return
    end
    local container = lam:GetAddonPanelContainer()
    local panel = lamcc.panel(container, panelData, addonID) --addonID==global name of panel
    panel:SetHidden(true)
    panel:SetAnchorFill(container)
    panel:SetHandler("OnEffectivelyShown", ToggleAddonPanels)
    ZO_PreHook(panel, "SetHandler", ShowSetHandlerWarning)

    local function stripMarkup(str)
        return str:gsub("|[Cc]%x%x%x%x%x%x", ""):gsub("|[Rr]", "")
    end

    local filterParts = {panelData.name, nil, nil}
    -- append keywords and author separately, the may be nil
    filterParts[#filterParts + 1] = panelData.keywords
    filterParts[#filterParts + 1] = panelData.author

    local addonData = {
        panel = panel,
        name = stripMarkup(panelData.name),
        filterText = stripMarkup(tconcat(filterParts, "\t")):lower(),
    }

    tinsert(addonsForList, addonData)

    if panelData.slashCommand then
        SLASH_COMMANDS[panelData.slashCommand] = function()
            lam:OpenToPanel(panel)
        end
    end

    return panel --return for authors creating options manually
end


--METHOD: REGISTER OPTION CONTROLS
--registers the options you want shown for your addon
--these are stored in a table where each key-value pair is the order
--of the options in the panel and the data for that control, respectively
--see exampleoptions.lua for an example
--see controls\<widget>.lua for each widget type
--Usage:
-- addonID = "string"; the same string passed to :RegisterAddonPanel
-- optionsTable = table; the table containing all of the options controls and their data
function lam:RegisterOptionControls(addonID, optionsTable) --optionsTable = {sliderData, buttonData, etc}
    if IsConsoleUI() then
        lam:registerConsoleOptionControls(addonID, optionsTable)
    end
    addonToOptionsMap[addonID] = optionsTable
end

--INTERNAL FUNCTION
--creates LAM's Addon Settings entry in ZO_GameMenu
local function CreateAddonSettingsMenuEntry()
    if IsConsoleUI() then return end
    local panelData = {
        id = KEYBOARD_OPTIONS.currentPanelId,
        name = util.L["PANEL_NAME"],
    }

    KEYBOARD_OPTIONS.currentPanelId = panelData.id + 1
    KEYBOARD_OPTIONS.panelNames[panelData.id] = panelData.name
    KEYBOARD_OPTIONS.controlTable[panelData.id] = {}

    lam.panelId = panelData.id

    local addonListSorted = false

    function panelData.callback()
        sm:AddFragment(lam:GetAddonSettingsFragment())
        KEYBOARD_OPTIONS:ChangePanels(lam.panelId)

        local title = LAMAddonSettingsWindow:GetNamedChild("Title")
        title:SetText(panelData.name)

        if not addonListSorted and #addonsForList > 0 then
            local searchEdit = LAMAddonSettingsWindow:GetNamedChild("SearchFilterEdit")
            --we're about to show our list for the first time - let's sort it
            table.sort(addonsForList, function(a, b) return a.name < b.name end)
            PopulateAddonList(lam.addonList, GetSearchFilterFunc(searchEdit))
            addonListSorted = true
        end
    end

    function panelData.unselectedCallback()
        sm:RemoveFragment(lam:GetAddonSettingsFragment())
        if SetCameraOptionsPreviewModeEnabled then -- available since API version 100011
            SetCameraOptionsPreviewModeEnabled(false)
        end
    end

    ZO_GameMenu_AddSettingPanel(panelData)
end


--INTERNAL FUNCTION
--creates the left-hand menu in LAM's window
local function CreateAddonList(name, parent)
    local addonList = wm:CreateControlFromVirtual(name, parent, "ZO_ScrollList")

    local function addonListRow_OnMouseDown(control, button)
        if button == 1 then
            local data = ZO_ScrollList_GetData(control)
            ZO_ScrollList_SelectData(addonList, data, control)
        end
    end

    local function addonListRow_OnMouseEnter(control)
        ZO_ScrollList_MouseEnter(addonList, control)
    end

    local function addonListRow_OnMouseExit(control)
        ZO_ScrollList_MouseExit(addonList, control)
    end

    local function addonListRow_Select(previouslySelectedData, selectedData, reselectingDuringRebuild)
        if not reselectingDuringRebuild then
            if previouslySelectedData then
                previouslySelectedData.panel:SetHidden(true)
            end
            if selectedData then
                selectedData.panel:SetHidden(false)
                PlaySound(SOUNDS.TREE_SUBCATEGORY_CLICK)
            end
        end
    end

    local function addonListRow_Setup(control, data)
        control:SetText(data.name)
        control:SetSelected(not data.panel:IsHidden())
    end

    ZO_ScrollList_AddDataType(addonList, ADDON_DATA_TYPE, "ZO_SelectableLabel", 28, addonListRow_Setup)
    -- I don't know how to make highlights clear properly; they often
    -- get stuck and after a while the list is full of highlighted rows
    --ZO_ScrollList_EnableHighlight(addonList, "ZO_ThinListHighlight")
    ZO_ScrollList_EnableSelection(addonList, "ZO_ThinListHighlight", addonListRow_Select)

    local addonDataType = ZO_ScrollList_GetDataTypeTable(addonList, ADDON_DATA_TYPE)
    local addonListRow_CreateRaw = addonDataType.pool.m_Factory

    local function addonListRow_Create(pool)
        local control = addonListRow_CreateRaw(pool)
        control:SetHandler("OnMouseDown", addonListRow_OnMouseDown)
        --control:SetHandler("OnMouseEnter", addonListRow_OnMouseEnter)
        --control:SetHandler("OnMouseExit", addonListRow_OnMouseExit)
        control:SetHeight(28)
        control:SetFont("ZoFontHeader")
        control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        return control
    end

    addonDataType.pool.m_Factory = addonListRow_Create

    return addonList
end


--INTERNAL FUNCTION
local function CreateSearchFilterBox(name, parent)
    local boxControl = wm:CreateControl(name, parent, CT_CONTROL)

    local srchButton =  wm:CreateControl("$(parent)Button", boxControl, CT_BUTTON)
    srchButton:SetDimensions(32, 32)
    srchButton:SetAnchor(LEFT, nil, LEFT, 2, 0)
    srchButton:SetNormalTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_up.dds")
    srchButton:SetPressedTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_down.dds")
    srchButton:SetMouseOverTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_over.dds")

    local srchEdit = wm:CreateControlFromVirtual("$(parent)Edit", boxControl, "ZO_DefaultEdit")
    srchEdit:SetAnchor(LEFT, srchButton, RIGHT, 4, 1)
    srchEdit:SetAnchor(RIGHT, nil, RIGHT, -4, 1)
    srchEdit:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())

    local srchBg = wm:CreateControl("$(parent)Bg", boxControl, CT_BACKDROP)
    srchBg:SetAnchorFill()
    srchBg:SetAlpha(0)
    srchBg:SetCenterColor(0, 0, 0, 0.5)
    srchBg:SetEdgeColor(ZO_DISABLED_TEXT:UnpackRGBA())
    srchBg:SetEdgeTexture("", 1, 1, 0, 0)

    -- search backdrop should appear whenever you hover over either
    -- the magnifying glass button or the edit field (which is only
    -- visible when it contains some text), and also while the edit
    -- field has keyboard focus

    local srchActive = false
    local srchHover = false

    local function srchBgUpdateAlpha()
        if srchActive or srchEdit:HasFocus() then
            srchBg:SetAlpha(srchHover and 0.8 or 0.6)
        else
            srchBg:SetAlpha(srchHover and 0.6 or 0.0)
        end
    end

    local function srchMouseEnter(control)
        srchHover = true
        srchBgUpdateAlpha()
    end

    local function srchMouseExit(control)
        srchHover = false
        srchBgUpdateAlpha()
    end

    boxControl:SetMouseEnabled(true)
    boxControl:SetHitInsets(1, 1, -1, -1)
    boxControl:SetHandler("OnMouseEnter", srchMouseEnter)
    boxControl:SetHandler("OnMouseExit", srchMouseExit)

    srchButton:SetHandler("OnMouseEnter", srchMouseEnter)
    srchButton:SetHandler("OnMouseExit", srchMouseExit)

    local focusLostTime = 0

    srchButton:SetHandler("OnClicked", function(self)
        srchEdit:Clear()
        if GetFrameTimeMilliseconds() - focusLostTime < 100 then
            -- re-focus the edit box if it lost focus due to this
            -- button click (note that this handler may run a few
            -- frames later)
            srchEdit:TakeFocus()
        end
    end)

    srchEdit:SetHandler("OnMouseEnter", srchMouseEnter)
    srchEdit:SetHandler("OnMouseExit", srchMouseExit)
    srchEdit:SetHandler("OnFocusGained", srchBgUpdateAlpha)

    srchEdit:SetHandler("OnFocusLost", function()
        focusLostTime = GetFrameTimeMilliseconds()
        srchBgUpdateAlpha()
    end)

    srchEdit:SetHandler("OnEscape", function(self)
        self:Clear()
        self:LoseFocus()
    end)

    srchEdit:SetHandler("OnTextChanged", function(self)
        local filterFunc = GetSearchFilterFunc(self)
        if filterFunc then
            srchActive = true
            srchBg:SetEdgeColor(ZO_SECOND_CONTRAST_TEXT:UnpackRGBA())
            srchButton:SetState(BSTATE_PRESSED)
        else
            srchActive = false
            srchBg:SetEdgeColor(ZO_DISABLED_TEXT:UnpackRGBA())
            srchButton:SetState(BSTATE_NORMAL)
        end
        srchBgUpdateAlpha()
        PopulateAddonList(lam.addonList, filterFunc)
        PlaySound(SOUNDS.SPINNER_DOWN)
    end)

    return boxControl
end


--INTERNAL FUNCTION
--creates LAM's Addon Settings top-level window
local function CreateAddonSettingsWindow()
    local tlw = wm:CreateTopLevelWindow("LAMAddonSettingsWindow")
    tlw:SetHidden(true)
    tlw:SetDimensions(1010, 914) -- same height as ZO_OptionsWindow

    ZO_ReanchorControlForLeftSidePanel(tlw)

    -- create black background for the window (mimic ZO_RightFootPrintBackground)

    local bgLeft = wm:CreateControl("$(parent)BackgroundLeft", tlw, CT_TEXTURE)
    bgLeft:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds")
    bgLeft:SetDimensions(1024, 1024)
    bgLeft:SetAnchor(TOPLEFT, nil, TOPLEFT)
    bgLeft:SetDrawLayer(DL_BACKGROUND)
    bgLeft:SetExcludeFromResizeToFitExtents(true)

    local bgRight = wm:CreateControl("$(parent)BackgroundRight", tlw, CT_TEXTURE)
    bgRight:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_right.dds")
    bgRight:SetDimensions(64, 1024)
    bgRight:SetAnchor(TOPLEFT, bgLeft, TOPRIGHT)
    bgRight:SetDrawLayer(DL_BACKGROUND)
    bgRight:SetExcludeFromResizeToFitExtents(true)

    -- create gray background for addon list (mimic ZO_TreeUnderlay)

    local underlayLeft = wm:CreateControl("$(parent)UnderlayLeft", tlw, CT_TEXTURE)
    underlayLeft:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_indexArea_left.dds")
    underlayLeft:SetDimensions(256, 1024)
    underlayLeft:SetAnchor(TOPLEFT, bgLeft, TOPLEFT)
    underlayLeft:SetDrawLayer(DL_BACKGROUND)
    underlayLeft:SetExcludeFromResizeToFitExtents(true)

    local underlayRight = wm:CreateControl("$(parent)UnderlayRight", tlw, CT_TEXTURE)
    underlayRight:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_indexArea_right.dds")
    underlayRight:SetDimensions(128, 1024)
    underlayRight:SetAnchor(TOPLEFT, underlayLeft, TOPRIGHT)
    underlayRight:SetDrawLayer(DL_BACKGROUND)
    underlayRight:SetExcludeFromResizeToFitExtents(true)

    -- create title bar (mimic ZO_OptionsWindow)

    local title = wm:CreateControl("$(parent)Title", tlw, CT_LABEL)
    title:SetAnchor(TOPLEFT, nil, TOPLEFT, 65, 70)
    title:SetFont("ZoFontWinH1")
    title:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)

    local divider = wm:CreateControlFromVirtual("$(parent)Divider", tlw, "ZO_Options_Divider")
    divider:SetAnchor(TOPLEFT, nil, TOPLEFT, 65, 108)

    -- create search filter box

    local srchBox = CreateSearchFilterBox("$(parent)SearchFilter", tlw)
    srchBox:SetAnchor(TOPLEFT, nil, TOPLEFT, 63, 120)
    srchBox:SetDimensions(260, 30)

    -- create scrollable addon list

    local addonList = CreateAddonList("$(parent)AddonList", tlw)
    addonList:SetAnchor(TOPLEFT, nil, TOPLEFT, 65, 160)
    addonList:SetDimensions(285, 665)

    lam.addonList = addonList -- for easy access from elsewhere

    -- create container for option panels

    local panelContainer = wm:CreateControl("$(parent)PanelContainer", tlw, CT_CONTROL)
    panelContainer:SetAnchor(TOPLEFT, nil, TOPLEFT, 365, 120)
    panelContainer:SetDimensions(645, 675)

    local defaultButton = wm:CreateControlFromVirtual("$(parent)ResetToDefaultButton", tlw, "ZO_DialogButton")
    ZO_KeybindButtonTemplate_Setup(defaultButton, "OPTIONS_LOAD_DEFAULTS", HandleLoadDefaultsPressed, GetString(SI_OPTIONS_DEFAULTS))
    defaultButton:SetAnchor(TOPLEFT, panelContainer, BOTTOMLEFT, 0, 2)
    lam.defaultButton = defaultButton

    local applyButton = wm:CreateControlFromVirtual("$(parent)ApplyButton", tlw, "ZO_DialogButton")
    ZO_KeybindButtonTemplate_Setup(applyButton, "OPTIONS_APPLY_CHANGES", HandleReloadUIPressed, GetString(SI_ADDON_MANAGER_RELOAD))
    applyButton:SetAnchor(TOPRIGHT, panelContainer, BOTTOMRIGHT, 0, 2)
    applyButton:SetHidden(true)
    lam.applyButton = applyButton

    return tlw
end


--INITIALIZING
local safeToInitialize = false
local hasInitialized = false

local eventHandle = table.concat({MAJOR, MINOR}, "r")
local function OnLoad(_, addonName)
    -- wait for the first loaded event
    em:UnregisterForEvent(eventHandle, EVENT_ADD_ON_LOADED)
    safeToInitialize = true
end
em:RegisterForEvent(eventHandle, EVENT_ADD_ON_LOADED, OnLoad)

local function OnActivated(_, initial)
    em:UnregisterForEvent(eventHandle, EVENT_PLAYER_ACTIVATED)
    FlushMessages()

    local reopenPanel = RetrievePanelForReopening()
    if not initial and reopenPanel then
        lam:OpenToPanel(reopenPanel)
    end
end
em:RegisterForEvent(eventHandle, EVENT_PLAYER_ACTIVATED, OnActivated)

function CheckSafetyAndInitialize(addonID)
    if not safeToInitialize then
        local msg = string.format("The panel with id '%s' was registered before addon loading has completed. This might break the AddOn Settings menu.", addonID)
        PrintLater(msg)
    end
    if not hasInitialized then
        hasInitialized = true
    end
end


--TODO documentation
function lam:GetAddonPanelContainer()
    local fragment = lam:GetAddonSettingsFragment()
    local window = fragment:GetControl()
    return window:GetNamedChild("PanelContainer")
end


--TODO documentation
function lam:GetAddonSettingsFragment()
    assert(hasInitialized or safeToInitialize)
    if not LAMAddonSettingsFragment then
        local window = CreateAddonSettingsWindow()
        LAMAddonSettingsFragment = ZO_FadeSceneFragment:New(window, true, 100)
        LAMAddonSettingsFragment:RegisterCallback("StateChange", function(oldState, newState)
            if(newState == SCENE_FRAGMENT_SHOWN) then
                InitKeybindActions()
                PushActionLayerByName("OptionsWindow")
                OpenCurrentPanel()
            elseif(newState == SCENE_FRAGMENT_HIDDEN) then
                CloseCurrentPanel()
                RemoveActionLayerByName("OptionsWindow")
                ShowReloadDialogIfNeeded()
            end
        end)
        CreateAddonSettingsMenuEntry()
    end
    return LAMAddonSettingsFragment
end


------------------------------------------
-- Temporary LAM to LHAS console converter
------------------------------------------

local function addToControlTable(newOption, t)
    t.indexed[#t.indexed + 1 ] = newOption
    if newOption.label then
        t.nameMap[newOption.label] = newOption
    end
    newOption.conversionIndex = #t.indexed
end
local function LAMtoHASDropdownConverter(option, controlTable)
    local newOption = {
        type = LibHarvensAddonSettings.ST_DROPDOWN,
        label = option.name,
        default = option.default,
        -- setFunction = option.setFunc,
        getFunction = option.getFunc,
        tooltip = option.tooltip,
        disable = option.disabled,
    }

    newOption.setFunction = function(combobox, name, item) option.setFunc(item.data) end
    
    local items = {}
    local labelMap = {}
    if not option.choicesValues then
        option.choicesValues = option.choices
    end
    for i = 1, # option.choices do
        items[i] = {name = option.choices[i], data = option.choicesValues[i]}
        if option.choicesValues[i] then
            labelMap[items[i].data] = items[i].name
        end
    end
    newOption.items = items
    newOption.getFunction = function() return labelMap[option.getFunc()]  end
    addToControlTable(newOption, controlTable)
end

local function LamtoHASSubmenuConverter(optionsTable, controlTable)
    local newOption = {
        type = LibHarvensAddonSettings.ST_SECTION,
        label = optionsTable.name,
    }
    addToControlTable(newOption, controlTable)
    return lam:convertLamOptionsToHasTable(optionsTable.controls, controlTable)
end

local function LamToHASDescriptionConverter(entry, controlTable)
    
    local newOption = {
        type = LibHarvensAddonSettings.ST_LABEL,
        label = entry.title,
        default = entry.default,
        tooltip = entry.tooltip,
    }
    addToControlTable(newOption, controlTable)
    newOption = {
        type = LibHarvensAddonSettings.ST_LABEL,
        label = entry.text,
        default = entry.default,
        tooltip = entry.tooltip,
    }
    addToControlTable(newOption, controlTable)
end

local function LamToHASDividerConverter(entry, controlTable)
    newOption = {
        type = LibHarvensAddonSettings.ST_SECTION,
        label = nil,
    }
    addToControlTable(newOption, controlTable)
end

function lam:convertLamOptionsToHasTable(optionsTable, controlTable)
    local LAMtoHAS = {
        slider = LibHarvensAddonSettings.ST_SLIDER,
        header = LibHarvensAddonSettings.ST_SECTION,
        checkbox = LibHarvensAddonSettings.ST_CHECKBOX,
        colorpicker = LibHarvensAddonSettings.ST_COLOR,
        button = LibHarvensAddonSettings.ST_BUTTON,
        editbox = LibHarvensAddonSettings.ST_EDIT,
    }
    local LAMtoHASSpecial = {
        dropdown = LAMtoHASDropdownConverter,
        submenu = LamtoHASSubmenuConverter,
        description = LamToHASDescriptionConverter,
        divider = LamToHASDividerConverter,
    }
    local controlTable = controlTable or {
        indexed = {},
        nameMap = {},
    }
    
    -- LAMHASMissing = {}
    
    for i, entry in ipairs(optionsTable) do
        local newType = LAMtoHAS[entry.type]
        if newType and not entry.isPCOnly then
            local newOption = {
                type = newType,
                label = entry.name,
                default = entry.default,
                setFunction = entry.setFunc,
                getFunction = entry.getFunc,
                tooltip = entry.tooltip,
                min = entry.min,
                max = entry.max,
                step = entry.step,
                disable = entry.disabled,
                clickHandler = entry.func,
                buttonText = entry.name,
            }
            addToControlTable(newOption, controlTable)
            -- settings:AddSetting(newOption)
        elseif LAMtoHASSpecial[entry.type] then
            LAMtoHASSpecial[entry.type](entry, controlTable)
        else
           -- LHAS does not have an equivalent for:
           -- iconPicker
           -- texture
        end
    end
    return controlTable
end

lam.LHASConversion = {}
lam.LHASConversion.settingTables = {}
lam.LHASConversion.optionControls = {}

function lam:registerConsoleAddonPanel(addonID, panelData)
    if IsConsoleUI() then
        local LHA = LibHarvensAddonSettings
        local options = {
            allowDefaults = panelData.registerForDefaults, --will allow users to reset the settings to default values
            allowRefresh = panelData.registerForRefresh, --if this is true, when one of settings is changed, all other settings will be checked for state change (disable/enable)
            defaultsFunction = panelData.resetFunc,
        }

        local settings = LHA:AddAddon(panelData.name, options)
        lam.LHASConversion.settingTables[addonID] = settings
    end
end

function lam:registerConsoleOptionControls(addonID, optionsTable)
    if not IsConsoleUI() then
        return
    end
    if lam.LHASConversion.settingTables[addonID] then
        local settings = lam.LHASConversion.settingTables[addonID]
        local LHA = LibHarvensAddonSettings
        lam.LHASConversion.optionControls [addonID]= lam:convertLamOptionsToHasTable(optionsTable)
        local controlTable = lam.LHASConversion.optionControls[addonID]

        for i = 1, #controlTable.indexed do
            settings:AddSetting(controlTable.indexed[i])
        end
    end
end