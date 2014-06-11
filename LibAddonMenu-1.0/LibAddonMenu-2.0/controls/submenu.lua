--[[submenuData = {
	type = "submenu",
	name = "Submenu Title",
	tooltip = "My submenu tooltip",	--(optional)
	controls = {sliderData, buttonData}	--(optional) used by LAM
	reference = "MyAddonSubmenu"	--(optional) unique global reference to control
}	]]

local widgetVersion = 2
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("submenu", widgetVersion) then return end

local wm = WINDOW_MANAGER
local am = ANIMATION_MANAGER


local function AnimateSubmenu(label)
	local control = label:GetParent()
	control.open = not control.open
	
	if control.open then
		control.animation:PlayFromStart()
	else
		control.animation:PlayFromEnd()
	end
end


function LAMCreateControl.submenu(parent, submenuData, controlName)
	local control = wm:CreateTopLevelWindow(controlName or submenuData.reference)
	control:SetParent(parent.scroll)
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
	scroll:SetDimensionConstraints(525, 0, 525, 1500)

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
	
	control.data = submenuData
	
	return control
end

