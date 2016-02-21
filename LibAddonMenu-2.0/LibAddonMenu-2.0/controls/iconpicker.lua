--[[iconpickerData = {
	type = "iconpicker",
	name = "My Icon Picker",
	tooltip = "Color Picker's tooltip text.",
	choices = {"texture path 1", "texture path 2", "texture path 3"},
	choicesTooltips = {"icon tooltip 1", "icon tooltip 2", "icon tooltip 3"}, --(optional)
	getFunc = function() return db.var end,
	setFunc = function(var) db.var = var doStuff() end,
	maxColumns = 5, --(optional) number of icons in one row
	visibleRows = 4.5, --(optional) number of visible rows
	iconSize = 28, --(optional) size of the icons
	defaultColor = ZO_ColorDef:New("FFFFFF"), --(optional) default color of the icons
	width = "full",	--or "half" (optional)
	beforeShow = function(control, iconPicker) return preventShow end, --(optional)
	disabled = function() return db.someBooleanSetting end,	--or boolean (optional)
	warning = "Will need to reload the UI.",	--(optional)
	default = defaults.var,	--(optional)
	reference = "MyAddonIconPicker"	--(optional) unique global reference to control
}	]]

local widgetVersion = 3
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("iconpicker", widgetVersion) then return end

local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER
local tinsert = table.insert

local IconPickerMenu = ZO_Object:Subclass()
local iconPicker
LAM.util.GetIconPickerMenu = function()
	if not iconPicker then
		iconPicker = IconPickerMenu:New("LAMIconPicker")
		local sceneFragment = LAM:GetAddonSettingsFragment()
		ZO_PreHook(sceneFragment, "OnHidden", function()
			if not iconPicker.control:IsHidden() then
				iconPicker:Clear()
			end
		end)
	end
	return iconPicker
end

function IconPickerMenu:New(...)
	local object = ZO_Object.New(self)
	object:Initialize(...)
	return object
end

function IconPickerMenu:Initialize(name)
	local control = wm:CreateTopLevelWindow(name)
	control:SetDrawTier(DT_HIGH)
	control:SetHidden(true)
	self.control = control

	local scrollContainer = wm:CreateControlFromVirtual(name .. "ScrollContainer", control, "ZO_ScrollContainer")
	-- control:SetDimensions(control.container:GetWidth(), height) -- adjust to icon size / col count
	scrollContainer:SetAnchorFill()
	ZO_Scroll_SetUseFadeGradient(scrollContainer, false)
	ZO_Scroll_SetHideScrollbarOnDisable(scrollContainer, false)
	ZO_VerticalScrollbarBase_OnMouseExit(scrollContainer:GetNamedChild("ScrollBar")) -- scrollbar initialization seems to be broken so we force it to update the correct alpha value
	local scroll = GetControl(scrollContainer, "ScrollChild")
	self.scroll = scroll
	self.scrollContainer = scrollContainer

	local bg = wm:CreateControl(nil, scrollContainer, CT_BACKDROP)
	bg:SetAnchor(TOPLEFT, scrollContainer, TOPLEFT, 0, -3)
	bg:SetAnchor(BOTTOMRIGHT, scrollContainer, BOTTOMRIGHT, 2, 5)
	bg:SetEdgeTexture("EsoUI\\Art\\Tooltips\\UI-Border.dds", 128, 16)
	bg:SetCenterTexture("EsoUI\\Art\\Tooltips\\UI-TooltipCenter.dds")
	bg:SetInsets(16, 16, -16, -16)

	local mungeOverlay = wm:CreateControl(nil, bg, CT_TEXTURE)
	mungeOverlay:SetTexture("EsoUI/Art/Tooltips/munge_overlay.dds")
	mungeOverlay:SetDrawLevel(1)
	mungeOverlay:SetAddressMode(TEX_MODE_WRAP)
	mungeOverlay:SetAnchorFill()

	local mouseOver = wm:CreateControl(nil, scrollContainer, CT_TEXTURE)
	mouseOver:SetDrawLevel(2)
	mouseOver:SetTexture("EsoUI/Art/Buttons/minmax_mouseover.dds")
	mouseOver:SetHidden(true)

	local function IconFactory(pool)
		local icon = wm:CreateControl(name .. "Entry" .. pool:GetNextControlId(), scroll, CT_TEXTURE)
		icon:SetMouseEnabled(true)
		icon:SetDrawLevel(3)
		icon:SetHandler("OnMouseEnter", function()
			mouseOver:SetAnchor(TOPLEFT, icon, TOPLEFT, 0, 0)
			mouseOver:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 0, 0)
			mouseOver:SetHidden(false)
			if self.customOnMouseEnter then
				self.customOnMouseEnter(icon)
			else
				self:OnMouseEnter(icon)
			end
		end)
		icon:SetHandler("OnMouseExit", function()
			mouseOver:ClearAnchors()
			mouseOver:SetHidden(true)
			if self.customOnMouseExit then
				self.customOnMouseExit(icon)
			else
				self:OnMouseExit(icon)
			end
		end)
		icon:SetHandler("OnMouseUp", function(control, ...)
			PlaySound("Click")
			icon.OnSelect(icon, icon.texture)
			self:Clear()
		end)
		return icon
	end

	local function ResetFunction(icon)
		icon:ClearAnchors()
	end

	self.iconPool = ZO_ObjectPool:New(IconFactory, ResetFunction)
	self:SetMaxColumns(1)
	self.icons = {}
	self.color = ZO_DEFAULT_ENABLED_COLOR

	EVENT_MANAGER:RegisterForEvent(name .. "_OnGlobalMouseUp", EVENT_GLOBAL_MOUSE_UP, function()
		if self.refCount ~= nil then
			local moc = wm:GetMouseOverControl()
			if(moc:GetOwningWindow() ~= control) then
				self.refCount = self.refCount - 1
				if self.refCount <= 0 then
					self:Clear()
				end
			end
		end
	end)
end

function IconPickerMenu:OnMouseEnter(icon)
	InitializeTooltip(InformationTooltip, icon, TOPLEFT, 0, 0, BOTTOMRIGHT)
	SetTooltipText(InformationTooltip, LAM.util.GetTooltipText(icon.tooltip))
	InformationTooltipTopLevel:BringWindowToTop()
end

function IconPickerMenu:OnMouseExit(icon)
	ClearTooltip(InformationTooltip)
end

function IconPickerMenu:SetMaxColumns(value)
	self.maxCols = value ~= nil and value or 5
end

local DEFAULT_SIZE = 28
function IconPickerMenu:SetIconSize(value)
	local iconSize = DEFAULT_SIZE
	if value ~= nil then iconSize = math.max(iconSize, value) end
	self.iconSize = iconSize
end

function IconPickerMenu:SetVisibleRows(value)
	self.visibleRows = value ~= nil and value or 4.5
end

function IconPickerMenu:SetMouseHandlers(onEnter, onExit)
	self.customOnMouseEnter = onEnter
	self.customOnMouseExit = onExit
end

function IconPickerMenu:UpdateDimensions()
	local iconSize = self.iconSize
	local width = iconSize * self.maxCols + 20
	local height = iconSize * self.visibleRows
	self.control:SetDimensions(width, height)

	local icons = self.icons
	for i = 1, #icons do
		local icon = icons[i]
		icon:SetDimensions(iconSize, iconSize)
	end
end

function IconPickerMenu:UpdateAnchors()
	local iconSize = self.iconSize
	local col, maxCols = 1, self.maxCols
	local previousCol, previousRow
	local scroll = self.scroll
	local icons = self.icons

	for i = 1, #icons do
		local icon = icons[i]
		icon:ClearAnchors()
		if i == 1 then
			icon:SetAnchor(TOPLEFT, scroll, TOPLEFT, 0, 0)
			previousRow = icon
		elseif col == 1 then
			icon:SetAnchor(TOPLEFT, previousRow, BOTTOMLEFT, 0, 0)
			previousRow = icon
		else
			icon:SetAnchor(TOPLEFT, previousCol, TOPRIGHT, 0, 0)
		end
		previousCol = icon
		col = col >= maxCols and 1 or col + 1
	end
end

function IconPickerMenu:Clear()
	self.icons = {}
	self.iconPool:ReleaseAllObjects()
	self.control:SetHidden(true)
	self.color = ZO_DEFAULT_ENABLED_COLOR
	self.refCount = nil
	self.parent = nil
	self.customOnMouseEnter = nil
	self.customOnMouseExit = nil
end

function IconPickerMenu:AddIcon(texturePath, callback, tooltip)
	local icon, key = self.iconPool:AcquireObject()
	icon:SetTexture(texturePath)
	icon:SetColor(self.color:UnpackRGBA())
	icon.texture = texturePath
	icon.tooltip = tooltip
	icon.OnSelect = callback
	self.icons[#self.icons + 1] = icon
end

function IconPickerMenu:Show(parent)
	if #self.icons == 0 then return false end
	if not self.control:IsHidden() then self:Clear() return false end
	self:UpdateDimensions()
	self:UpdateAnchors()

	local control = self.control
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, parent, BOTTOMLEFT, 0, 8)
	control:SetHidden(false)
	control:BringWindowToTop()
	self.parent = parent
	self.refCount = 2

	return true
end

function IconPickerMenu:SetColor(color)
	local icons = self.icons
	self.color = color
	for i = 1, #icons do
		local icon = icons[i]
		icon:SetColor(color:UnpackRGBA())
	end
end

-------------------------------------------------------------

local function UpdateChoices(control, choices, choicesTooltips)
	local data = control.data
	if not choices then
		choices, choicesTooltips = data.choices, data.choicesTooltips or {}
	end
	local addedChoices = {}

	local iconPicker = LAM.util.GetIconPickerMenu()
	iconPicker:Clear()
	for i = 1, #choices do
		local texture = choices[i]
		if not addedChoices[texture] then -- remove duplicates
			iconPicker:AddIcon(choices[i], function(self, texture)
				control.icon:SetTexture(texture)
				data.setFunc(texture)
				if control.panel.data.registerForRefresh then
					cm:FireCallbacks("LAM-RefreshPanel", control)
				end
			end, choicesTooltips[i])
			addedChoices[texture] = true
		end
	end
end

local function IsDisabled(control)
	if type(control.data.disabled) == "function" then
		return control.data.disabled()
	else
		return control.data.disabled
	end
end

local function SetColor(control, color)
	local icon = control.icon
	if IsDisabled(control) then
		icon:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
	else
		icon.color = color or control.data.defaultColor or ZO_DEFAULT_ENABLED_COLOR
		icon:SetColor(icon.color:UnpackRGBA())
	end

	local iconPicker = LAM.util.GetIconPickerMenu()
	if iconPicker.parent == control.container and not iconPicker.control:IsHidden() then
		iconPicker:SetColor(icon.color)
	end
end

local function UpdateDisabled(control)
	local disable = IsDisabled(control)

	control.dropdown:SetMouseEnabled(not disable)
	control.dropdownButton:SetEnabled(not disable)

	local iconPicker = LAM.util.GetIconPickerMenu()
	if iconPicker.parent == control.container and not iconPicker.control:IsHidden() then
		iconPicker:Clear()
	end

	SetColor(control)
	if disable then
		control.label:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
	else
		control.label:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
	end
end

local function UpdateValue(control, forceDefault, value)
	if forceDefault then	--if we are forcing defaults
		value = control.data.default
		control.data.setFunc(value)
		control.icon:SetTexture(value)
	elseif value then
		control.data.setFunc(value)
		--after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
		if control.panel.data.registerForRefresh then
			cm:FireCallbacks("LAM-RefreshPanel", control)
		end
	else
		value = control.data.getFunc()
		control.icon:SetTexture(value)
	end
end

local MIN_HEIGHT = 26
local HALF_WIDTH_LINE_SPACING = 2
local function SetIconSize(control, size)
	local icon = control.icon
	icon.size = size
	icon:SetDimensions(size, size)

	local height = size + 4
	control.dropdown:SetDimensions(size + 20, height)
	height = math.max(height, MIN_HEIGHT)
	control.container:SetHeight(height)
	if control.lineControl then
		control.lineControl:SetHeight(MIN_HEIGHT + size + HALF_WIDTH_LINE_SPACING)
	else
		control:SetHeight(height)
	end

	local iconPicker = LAM.util.GetIconPickerMenu()
	if iconPicker.parent == control.container and not iconPicker.control:IsHidden() then
		iconPicker:SetIconSize(size)
		iconPicker:UpdateDimensions()
		iconPicker:UpdateAnchors()
	end
end

function LAMCreateControl.iconpicker(parent, iconpickerData, controlName)
	local control = LAM.util.CreateLabelAndContainerControl(parent, iconpickerData, controlName)

	local function ShowIconPicker()
		local iconPicker = LAM.util.GetIconPickerMenu()
		if iconPicker.parent == control.container then
			iconPicker:Clear()
		else
			iconPicker:SetMaxColumns(iconpickerData.maxColumns)
			iconPicker:SetVisibleRows(iconpickerData.visibleRows)
			iconPicker:SetIconSize(control.icon.size)
			UpdateChoices(control)
			iconPicker:SetColor(control.icon.color)
			if iconpickerData.beforeShow then
				if iconpickerData.beforeShow(control, iconPicker) then
					iconPicker:Clear()
					return
				end
			end
			iconPicker:Show(control.container)
		end
	end

	local iconSize = iconpickerData.iconSize ~= nil and iconpickerData.iconSize or DEFAULT_SIZE
	control.dropdown = wm:CreateControl(nil, control.container, CT_CONTROL)
	local dropdown = control.dropdown
	dropdown:SetAnchor(LEFT, control.container, LEFT, 0, 0)
	dropdown:SetMouseEnabled(true)
	dropdown:SetHandler("OnMouseUp", ShowIconPicker)
	dropdown:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(control) end)
	dropdown:SetHandler("OnMouseExit", function() ZO_Options_OnMouseExit(control) end)

	control.icon = wm:CreateControl(nil, dropdown, CT_TEXTURE)
	local icon = control.icon
	icon:SetAnchor(LEFT, dropdown, LEFT, 3, 0)
	icon:SetDrawLevel(2)

	local dropdownButton = wm:CreateControlFromVirtual(nil, dropdown, "ZO_DropdownButton")
	dropdownButton:SetDimensions(16, 16)
	dropdownButton:SetHandler("OnClicked", ShowIconPicker)
	dropdownButton:SetAnchor(RIGHT, dropdown, RIGHT, -3, 0)
	control.dropdownButton = dropdownButton

	control.bg = wm:CreateControl(nil, dropdown, CT_BACKDROP)
	local bg = control.bg
	bg:SetAnchor(TOPLEFT, dropdown, TOPLEFT, 0, -3)
	bg:SetAnchor(BOTTOMRIGHT, dropdown, BOTTOMRIGHT, 2, 5)
	bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
	bg:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
	bg:SetInsets(16, 16, -16, -16)
	local mungeOverlay = wm:CreateControl(nil, bg, CT_TEXTURE)
	mungeOverlay:SetTexture("EsoUI/Art/Tooltips/munge_overlay.dds")
	mungeOverlay:SetDrawLevel(1)
	mungeOverlay:SetAddressMode(TEX_MODE_WRAP)
	mungeOverlay:SetAnchorFill()

	if iconpickerData.warning then
		control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
		control.warning:SetAnchor(RIGHT, control.container, LEFT, -5, 0)
		control.warning.data = {tooltipText = iconpickerData.warning}
	end

	if iconpickerData.disabled ~= nil then
		control.UpdateDisabled = UpdateDisabled
		control:UpdateDisabled()
	end

	control.UpdateChoices = UpdateChoices
	control.UpdateValue = UpdateValue
	control:UpdateValue()
	control.SetColor = SetColor
	control:SetColor()
	control.SetIconSize = SetIconSize
	control:SetIconSize(iconSize)

	if control.panel.data.registerForRefresh or control.panel.data.registerForDefaults then	--if our parent window wants to refresh controls, then add this to the list
		tinsert(control.panel.controlsToRefresh, control)
	end

	return control
end
