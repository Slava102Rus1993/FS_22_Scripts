IngameMapLayoutMobile = {}
local IngameMapLayoutMobile_mt = Class(IngameMapLayoutMobile, IngameMapLayoutSquare)

function IngameMapLayoutMobile.new()
	local self = IngameMapLayoutMobile:superClass().new(IngameMapLayoutMobile_mt)
	self.mapOffsetX = 0
	self.mapOffsetY = 0
	self.playerOffsetY = 0

	return self
end

function IngameMapLayoutMobile:storeScaledValues(element, uiScale)
	local _ = nil
	self.mapPosX, self.mapPosY = element:scalePixelToScreenVector(IngameMapLayoutMobile.POSITION.MAP)
	self.mapSizeX, self.mapSizeY = element:scalePixelToScreenVector(IngameMapLayoutMobile.SIZE.MAP)
	_, self.playerOffsetY = element:scalePixelToScreenVector(IngameMapLayoutMobile.POSITION.PLAYER_OFFSET)
end

function IngameMapLayoutMobile:setPlayerPosition(x, z, yRot)
	self.playerU = x
	self.playerV = 1 - z
	self.playerRot = yRot
end

function IngameMapLayoutMobile:getMapPosition()
	local mapWidth, mapHeight = self:getMapSize()
	local mapPosX = self.mapPosX + self.mapOffsetX
	local mapPosY = self.mapPosY + self.mapOffsetY
	local playerScreenX = mapPosX + self.mapSizeX * 0.5
	local playerScreenY = mapPosY + self.mapSizeY * 0.5
	local playerU = self.playerU
	local playerV = self.playerV
	local offX = playerScreenX - playerU * mapWidth
	local offY = playerScreenY - playerV * mapHeight
	local minMapPosX = mapPosX + self.mapSizeX - mapWidth
	local minMapPosY = mapPosY + self.mapSizeY - mapHeight
	offX = math.max(math.min(offX, mapPosX), minMapPosX)
	offY = math.max(math.min(offY, mapPosY), minMapPosY)

	return offX, offY
end

function IngameMapLayoutMobile:getShowsToggleAction()
	return false
end

function IngameMapLayoutMobile:getShowsToggleActionText()
	return true
end

function IngameMapLayoutMobile:getIconZoom()
	return 1.25
end

function IngameMapLayoutMobile:getMapAlpha()
	return 0.85
end

function IngameMapLayoutMobile:setPlayer(player)
	self.mapOffsetY = player == nil and 0 or self.playerOffsetY
end

function IngameMapLayoutMobile:setOffset(x)
	self.mapOffsetX = x
end

function IngameMapLayoutMobile:drawBefore()
	set2DMaskFromTexture(self.overlayMask, true, self.mapPosX + self.mapOffsetX, self.mapPosY + self.mapOffsetY, self.mapSizeX, self.mapSizeY)
end

function IngameMapLayoutMobile:setWorldSize(worldSizeX, worldSizeZ)
	self.worldSizeFactor = 1.1
end

function IngameMapLayoutMobile:getMapObjectPosition(objectU, objectV, width, height, rot, persistent)
	local mapWidth, mapHeight = self:getMapSize()
	local mapX, mapY = self:getMapPosition()
	local mapSpacePosX = objectU * mapWidth
	local mapSpacePosY = (1 - objectV) * mapHeight
	local objectX = mapX + mapSpacePosX - width * 0.5
	local objectY = mapY + mapSpacePosY - height * 0.5
	local mapPosX = self.mapPosX + self.mapOffsetX
	local mapPosY = self.mapPosY + self.mapOffsetY

	if persistent then
		objectX = MathUtil.clamp(objectX, mapPosX - width * 0.5, mapPosX + self.mapSizeX - width * 0.5)
		objectY = MathUtil.clamp(objectY, mapPosY - height * 0.5, mapPosY + self.mapSizeY - height * 0.5)
	end

	local minX = mapPosX - width
	local maxX = mapPosX + self.mapSizeX + width
	local minY = mapPosY - height
	local maxY = mapPosY + self.mapSizeY + height

	if objectX < minX or maxX < objectX or objectY < minY or maxY < objectY then
		return 0, 0, 0, false
	end

	return objectX, objectY, rot, true
end

IngameMapLayoutMobile.SIZE = {
	MAP = {
		464,
		470
	}
}
IngameMapLayoutMobile.POSITION = {
	MAP = {
		2,
		306
	},
	PLAYER_OFFSET = {
		0,
		105
	}
}
