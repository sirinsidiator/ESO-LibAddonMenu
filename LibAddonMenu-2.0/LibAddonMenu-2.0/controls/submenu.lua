--[[submenuData = {
	type = "submenu",
	name = "Submenu Title",
	tooltip = "My submenu tooltip",	--(optional)
	controls = {sliderData, buttonData}	--(optional) used by LAM
	reference = "MyAddonSubmenu"	--(optional) unique global reference to control
}	]]

local widgetVersion = 8
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("submenu", widgetVersion) then return end

local wm = WINDOW_MANAGER
local am = ANIMATION_MANAGER
local tinsert = table.insert


local function UpdateValue(control)
	control.label:SetText(control.data.name)
	if control.data.tooltip then
		control.label.data = {tooltipText = control.data.tooltip}
	end
end

local function AnimateSubmenu(clicked)
	local control = clicked:GetParent()
	control.open = not control.open

	if control.open then
		control.animation:PlayFromStart()
	else
		control.animation:PlayFromEnd()
	end
end

local function OnMouseEnter(control)
	control:SetColor(ZO_HIGHLIGHT_TEXT:UnpackRGBA())
	ZO_Options_OnMouseEnter(control)
end

local function OnMouseExit(control)
	if control:GetParent().open then
		control:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
	else
		control:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
	end
	ZO_Options_OnMouseExit(control)
end

function LAMCreateControl.submenu(parent, submenuData, controlName)
	local control = wm:CreateControl(controlName or submenuData.reference, parent.scroll or parent, CT_CONTROL)
	control.panel = parent
	control:SetDimensions(523, 40)

	control.label = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel")
	local label = control.label
	label:SetAnchor(TOPLEFT, control, TOPLEFT, 6, 16)
	label:SetDimensions(520, 30)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	label:SetText(submenuData.name)
	label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
	label:SetMouseEnabled(true)
	label:SetHandler("OnMouseEnter", OnMouseEnter)
	label:SetHandler("OnMouseExit", OnMouseExit)
	label.data = {tooltipText = submenuData.tooltip}

	control.scroll = wm:CreateControl(nil, control, CT_SCROLL)
	local scroll = control.scroll
	scroll:SetParent(control)
	scroll:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 10)
	scroll:SetDimensionConstraints(525, 0, 525, 2500)

	control.bg = wm:CreateControl(nil, label, CT_BACKDROP)
	local bg = control.bg
	bg:SetAnchor(TOPLEFT, label, TOPLEFT, -10, -16)
	bg:SetAnchor(BOTTOMRIGHT, scroll, BOTTOMRIGHT, -7, 0)
    bg:SetEdgeTexture("EsoUI/Art/ChatWindow/chat_BG_edge.dds", 256, 256, 16)
    bg:SetCenterTexture("EsoUI/Art/ChatWindow/chat_BG_center.dds")
	bg:SetInsets(16, 16, -16, -16)
	bg:SetEdgeColor(0, 0, 0, 0.75)
	bg:SetCenterColor(0, 0, 0, 0.75)

	control.arrow = wm:CreateControl(nil, bg, CT_TEXTURE)
	local arrow = control.arrow
	arrow:SetDimensions(32, 32)
	arrow:SetTexture("EsoUI/Art/Buttons/plus_up.dds")	--list_sortup for the other way
	arrow:SetAnchor(TOPRIGHT, bg, TOPRIGHT, -5, 10)

	--figure out the cool animation later...
	control.animation = am:CreateTimeline()
	local animation = control.animation
	animation:SetPlaybackType(ANIMATION_SIZE, 0)	--2nd arg = loop count

	control:SetResizeToFitDescendents(true)
	control.open = false
	label:SetHandler("OnMouseUp", AnimateSubmenu)
	animation:SetHandler("OnStop", function(self, completedPlaying)
			scroll:SetResizeToFitDescendents(control.open)
			if control.open then
				control.arrow:SetTexture("EsoUI/Art/Buttons/minus_up.dds")
				control.label:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
				scroll:SetResizeToFitPadding(5, 20)
			else
				control.arrow:SetTexture("EsoUI/Art/Buttons/plus_up.dds")
				control.label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
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

	control.data = submenuData

	control.UpdateValue = UpdateValue

	if control.panel.data.registerForRefresh or control.panel.data.registerForDefaults then	--if our parent window wants to refresh controls, then add this to the list
		tinsert(control.panel.controlsToRefresh, control)
	end

	return control
end
