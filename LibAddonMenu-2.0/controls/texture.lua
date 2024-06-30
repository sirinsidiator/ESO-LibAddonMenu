---@class LAM2_TextureData: LAM2_LabelAndContainerControlData
---@field type "texture"
---@field image string ex. "file/path.dds"
---@field imageWidth integer max of 250 for width="half", 510 for "full" ex. 64
---@field imageHeight integer max of 100 ex. 32

-- TODO: add texture coords support?

local widgetVersion = 11
local LAM = LibAddonMenu2
if not LAM:RegisterWidget("texture", widgetVersion) then return end

local wm = WINDOW_MANAGER

local MIN_HEIGHT = 26
---@param textureData LAM2_TextureData
function LAMCreateControl.texture(parent, textureData, controlName)
    ---@class LAM2_Texture: LAM2_BaseControl
    local control = LAM.util.CreateBaseControl(parent, textureData, controlName)
    local width = control:GetWidth()
    control:SetResizeToFitDescendents(true)

    if control.isHalfWidth then --note these restrictions
        control:SetDimensionConstraints(width / 2, MIN_HEIGHT, width / 2, MIN_HEIGHT * 4)
        control:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_Y)
    else
        control:SetDimensionConstraints(width, MIN_HEIGHT, width, MIN_HEIGHT * 4)
        control:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_Y)
    end

    control.texture = wm:CreateControl(nil, control, CT_TEXTURE) --[[@as TextureControl]]
    local texture = control.texture
    texture:SetAnchor(CENTER)
    texture:SetDimensions(textureData.imageWidth, textureData.imageHeight)
    texture:SetTexture(textureData.image)
    LAM.util.SetUpTooltip(texture, textureData)

    return control
end
