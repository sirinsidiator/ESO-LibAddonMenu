--[[submenuData = {
	type = "submenu",
	name = "Submenu Title",
	tooltip = "My submenu tooltip",	--(optional)
	controls = {sliderData, buttonData}	--(optional) used by LAM
	reference = "MyAddonSubmenu"	--(optional) unique global reference to control
}	]]

local widgetVersion = 5
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("submenu", widgetVersion) then return end

local wm = WINDOW_MANAGER
local am = ANIMATION_MANAGER
local tinsert = table.insert


local function UpdateValue(control)
	control.label:SetText(control.data.name)
	if control.data.tooltip then
		control.label.tooltipText = control.data.tooltip
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


function LAMCreateControl.submenu(parent, submenuData, controlName)
	local control = wm:CreateTopLevelWindow(controlName or submenuData.reference)
	control:SetParent(parent.scroll or parent)
	control.panel = parent
	control:SetDimensions(523, 40)
	
	control.label = wm:CreateControlFromVirtual(nil, control, "ZO_Options_SectionTitleLabel")
	local label = control.label
	label:SetAnchor(TOPLEFT, control, TOPLEFT, 5, 5)
	label:SetDimensions(520, 30)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	label:SetText(submenuData.name)
	label:SetMouseEnabled(true)
	if submenuData.tooltip then
		label.tooltipText = submenuData.tooltip
		label:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
		label:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
	end
	
	control.scroll = wm:CreateControl(nil, control, CT_SCROLL)
	local scroll = control.scroll
	scroll:SetParent(control)
	scroll:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 10)
	scroll:SetDimensionConstraints(525, 0, 525, 2500)

	control.bg = wm:CreateControl(nil, label, CT_BACKDROP)
	local bg = control.bg
	bg:SetAnchor(TOPLEFT, label, TOPLEFT, -5, -5)
	bg:SetAnchor(BOTTOMRIGHT, scroll, BOTTOMRIGHT, -7, 0)
	bg:SetEdgeTexture("EsoUI\\Art\\Tooltips\\UI-Border.dds", 128, 16)
	bg:SetCenterTexture("EsoUI\\Art\\Tooltips\\UI-TooltipCenter.dds")
	bg:SetInsets(16, 16, -16, -16)
	
	control.arrow = wm:CreateControl(nil, bg, CT_TEXTURE)
	local arrow = control.arrow
	arrow:SetDimensions(28, 28)
	arrow:SetTexture("EsoUI\\Art\\Miscellaneous\\list_sortdown.dds")	--list_sortup for the other way
	arrow:SetAnchor(TOPRIGHT, bg, TOPRIGHT, -5, 5)
	
	--figure out the cool animation later...
	control.animation = am:CreateTimeline()
	local animation = control.animation
	animation:SetPlaybackType(ANIMATION_SIZE, 0)	--2nd arg = loop count
	--animation:SetDuration(1)
	--animation:SetEasingFunction(ZO_LinearEase)	--is this needed?
	--animation:SetHeightStartAndEnd(40, 80)	--SetStartAndEndHeight
	--animation:SetStartAndEndHeight(40, 80)	--SetStartAndEndHeight
	--animation:SetAnimatedControl(control)
	
	control:SetResizeToFitDescendents(true)
	control.open = false
	label:SetHandler("OnMouseUp", AnimateSubmenu)
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

