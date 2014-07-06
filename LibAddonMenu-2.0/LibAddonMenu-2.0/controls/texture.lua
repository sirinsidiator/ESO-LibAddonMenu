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

local widgetVersion = 3
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("texture", widgetVersion) then return end

local wm = WINDOW_MANAGER

function LAMCreateControl.texture(parent, textureData, controlName)
	local control = wm:CreateTopLevelWindow(controlName or textureData.reference)
	control:SetResizeToFitDescendents(true)
	control:SetParent(parent.scroll or parent)
	
	local isHalfWidth = textureData.width == "half"
	if isHalfWidth then
		control:SetDimensionConstraints(250, 55, 250, 100)
		control:SetDimensions(250, 55)
	else
		control:SetDimensionConstraints(510, 30, 510, 100)
		control:SetDimensions(510, 30)
	end
	
	control.texture = wm:CreateControl(nil, control, CT_TEXTURE)
	local texture = control.texture
	texture:SetAnchor(CENTER)
	texture:SetDimensions(textureData.imageWidth, textureData.imageHeight)
	texture:SetTexture(textureData.image)
	
	if textureData.tooltip then
		texture:SetMouseEnabled(true)
		texture.tooltipText = textureData.tooltip
		texture:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
		texture:SetHandler("OnMouseEnter", ZO_Options_OnMouseExit)
	end

	control.panel = parent.panel or parent	--if this is in a submenu, panel is its parent
	control.data = textureData
	
	return control
end