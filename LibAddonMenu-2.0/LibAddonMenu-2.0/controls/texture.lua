--[[textureData = {
	type = "texture",
	image = "file/path.dds",
	imageWidth = 64,	--max of 250 for half width, 510 for full
	imageHeight = 32,	--max of 100
	tooltip = "Image's tooltip text.",	--(optional)
	width = "full",	--or "half" (optional)
	reference = "MyAddonTexture"	--(optional) unique global reference to control
}	]]

--add texture coords support?

local widgetVersion = 7
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("texture", widgetVersion) then return end

local wm = WINDOW_MANAGER

function LAMCreateControl.texture(parent, textureData, controlName)
	local control = wm:CreateControl(controlName or textureData.reference, parent.scroll or parent, CT_CONTROL)
	control:SetResizeToFitDescendents(true)

	local isHalfWidth = textureData.width == "half"
	local width = parent:GetWidth() - 20
	if isHalfWidth then
		control:SetDimensionConstraints(width / 2, 55, width / 2, 100)
		control:SetDimensions(width / 2, 55)
	else
		control:SetDimensionConstraints(width, 30, width, 100)
		control:SetDimensions(width, 30)
	end

	control.texture = wm:CreateControl(nil, control, CT_TEXTURE)
	local texture = control.texture
	texture:SetAnchor(CENTER)
	texture:SetDimensions(textureData.imageWidth, textureData.imageHeight)
	texture:SetTexture(textureData.image)

	if textureData.tooltip then
		texture:SetMouseEnabled(true)
		texture.data = {tooltipText = textureData.tooltip}
		texture:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
		texture:SetHandler("OnMouseEnter", ZO_Options_OnMouseExit)
	end

	control.panel = parent.panel or parent	--if this is in a submenu, panel is its parent
	control.data = textureData

	return control
end