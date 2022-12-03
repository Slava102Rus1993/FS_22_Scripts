source("dataS/scripts/gui/hud/IngameMapLayoutMobile.lua")

IngameMapMobile = {}
local IngameMapMobile_mt = Class(IngameMapMobile, IngameMap)
IngameMapMobile.STATE_HIDDEN = 3

function IngameMapMobile.new(hud, hudAtlasPath, inputDisplayManager, customMt)
	local self = IngameMap:superClass().new(nil, , customMt or IngameMapMobile_mt)
	self.overlay = self:createBackground(hudAtlasPath)
	self.hud = hud
	self.hudAtlasPath = hudAtlasPath
	self.inputDisplayManager = inputDisplayManager
	self.uiScale = 1
	self.isVisible = true
	self.mobileLayout = IngameMapLayoutMobile.new()
	self.layouts = {
		self.mobileLayout
	}
	self.fullScreenLayout = IngameMapLayoutFullscreen.new()
	self.state = 1
	self.layout = self.layouts[self.state]
	self.mapOverlay = Overlay.new(nil, 0, 0, 1, 1)
	self.mapElement = HUDElement.new(self.mapOverlay)

	self:createComponents(hudAtlasPath)

	for _, layout in ipairs(self.layouts) do
		layout:createComponents(self, hudAtlasPath)
	end

	self.filter = {
		[MapHotspot.CATEGORY_FIELD] = true,
		[MapHotspot.CATEGORY_ANIMAL] = true,
		[MapHotspot.CATEGORY_MISSION] = true,
		[MapHotspot.CATEGORY_TOUR] = true,
		[MapHotspot.CATEGORY_STEERABLE] = true,
		[MapHotspot.CATEGORY_COMBINE] = true,
		[MapHotspot.CATEGORY_TRAILER] = true,
		[MapHotspot.CATEGORY_TOOL] = true,
		[MapHotspot.CATEGORY_UNLOADING] = true,
		[MapHotspot.CATEGORY_LOADING] = true,
		[MapHotspot.CATEGORY_PRODUCTION] = true,
		[MapHotspot.CATEGORY_SHOP] = true,
		[MapHotspot.CATEGORY_OTHER] = true,
		[MapHotspot.CATEGORY_AI] = true,
		[MapHotspot.CATEGORY_PLAYER] = true
	}

	self:setWorldSize(2048, 2048)

	self.hotspots = {}
	self.selectedHotspot = nil
	self.allowToggle = true
	self.topDownCamera = nil
	self.isMapVisible = true
	self.resizeTimer = 1
	self.mapExtensionOffsetX = 0
	self.mapExtensionOffsetZ = 0
	self.mapExtensionScaleFactor = 1

	return self
end

function IngameMapMobile:loadMap(filename, worldSizeX, worldSizeZ, fieldColor, grassFieldColor)
	self.mapElement:delete()
	self:setWorldSize(worldSizeX, worldSizeZ)

	self.mapOverlay = Overlay.new(filename, 0, 0, 1, 1)
	self.mapElement = HUDElement.new(self.mapOverlay)

	self:addChild(self.mapElement)
	self:setScale(self.uiScale)
end

function IngameMapMobile:createComponents(hudAtlasPath)
	local baseX, baseY = self:getPosition()
	local width = self:getWidth()
	local height = self:getHeight()

	self:createFrame(hudAtlasPath, baseX, baseY, width, height)

	self.halfCircleElement = self:createOverlayElement(IngameMapMobile.POSITION.HALF_CIRCLE, IngameMapMobile.SIZE.HALF_CIRCLE, IngameMapMobile.UV.HALF_CIRCLE, IngameMapMobile.COLOR.RIGHT_BORDER)

	self:addChild(self.halfCircleElement)

	self.halfCircleIconElement = self:createOverlayElement(IngameMapMobile.POSITION.HALF_CIRCLE_ICON, IngameMapMobile.SIZE.HALF_CIRCLE_ICON, IngameMapMobile.UV.HALF_CIRCLE_ICON, IngameMapMobile.COLOR.MAP_ICON)

	self:addChild(self.halfCircleIconElement)

	self.rightBorderElement = self:createOverlayElement(IngameMapMobile.POSITION.RIGHT_BORDER, IngameMapMobile.SIZE.RIGHT_BORDER, HUDElement.UV.FILL, IngameMapMobile.COLOR.RIGHT_BORDER)

	self:addChild(self.rightBorderElement)

	self.slideButtonDown = self.hud:addTouchButton(self.halfCircleElement.overlay, 1, 0.4, self.onSlideMapDown, self, TouchHandler.TRIGGER_DOWN)
	self.slideButtonAlways = self.hud:addTouchButton(self.halfCircleElement.overlay, 1, 0.4, self.onSlideMapAlways, self, TouchHandler.TRIGGER_ALWAYS)
	self.slideButtonUp = self.hud:addTouchButton(self.halfCircleElement.overlay, 1, 0.4, self.onSlideMapUp, self, TouchHandler.TRIGGER_UP)

	g_touchHandler:setAreaPressedSizeGain(self.slideButtonDown, 3.5)
	g_touchHandler:setAreaPressedSizeGain(self.slideButtonAlways, 3.5)
	g_touchHandler:setAreaPressedSizeGain(self.slideButtonUp, 3.5)

	self.buttonElement = self.halfCircleElement
end

function IngameMapMobile:getHeight()
	return self.overlay.height
end

function IngameMapMobile:setPlayer(player)
	self.player = player

	self.mobileLayout:setPlayer(player)
end

function IngameMapMobile:onSlideMapDown(posX, posY)
	self.startTouchPosX = posX
	self.startPosX = self:getPosition()
end

function IngameMapMobile:onSlideMapAlways(posX, posY)
	self.currentOffsetX = posX - self.startTouchPosX
	local position = MathUtil.clamp(self.startPosX + self.currentOffsetX, self.mapHideWidth, 0)

	self:setPosition(position, nil)
end

function IngameMapMobile:onSlideMapUp(posX, posY)
	if self.currentOffsetX ~= 0 then
		local curX = self:getPosition()
		self.resizeTimer = 1 - curX / self.mapHideWidth

		self:toggleSize(self.startTouchPosX - posX > 0, true)

		self.currentOffsetX = 0
	else
		self:toggleSize()
	end
end

function IngameMapMobile:createOverlayElement(pos, size, uvs, color)
	local baseX, baseY = self:getPosition()
	local posX, posY = getNormalizedScreenValues(unpack(pos))
	local sizeX, sizeY = getNormalizedScreenValues(unpack(size))

	log(self.hudAtlasPath)

	local overlay = Overlay.new(self.hudAtlasPath, baseX + posX, baseY + posY, sizeX, sizeY)

	overlay:setUVs(GuiUtils.getUVs(uvs))
	overlay:setColor(unpack(color))

	return HUDElement.new(overlay)
end

function IngameMapMobile:storeScaledValues(uiScale)
	IngameMapMobile:superClass().storeScaledValues(self, uiScale)

	self.mapWidth, self.mapHeight = self:scalePixelToScreenVector(IngameMapMobile.SIZE.MAP)
	self.mapSizeX, self.mapSizeY = self:scalePixelToScreenVector(IngameMapMobile.SIZE.MAP)
	self.mapOffsetX, self.mapOffsetY = self:scalePixelToScreenVector(IngameMapMobile.POSITION.MAP)
	self.mapHideWidth = self:scalePixelToScreenVector(IngameMapMobile.SIZE.MAP_HIDE_WIDTH)
	self.mapToFrameDiffY = self:scalePixelToScreenHeight(IngameMapMobile.SIZE.SELF[2] - IngameMapMobile.SIZE.MAP[2])
	self.mapToFrameDiffX = self:scalePixelToScreenWidth(IngameMapMobile.SIZE.SELF[1] - IngameMapMobile.SIZE.MAP[1])
end

function IngameMapMobile:resetSettings()
	IngameMapMobile:superClass().resetSettings(self)

	if self.overlay == nil then
		return
	end

	if not self.isMapVisible then
		self:setPosition(self.mapHideWidth * (1 - self.resizeTimer), nil)
	end
end

function IngameMapMobile:update(dt)
	IngameMapMobile:superClass().update(self, dt)

	if self.resizeDir ~= 0 then
		local deltaTime = dt

		if not self.isVisible then
			deltaTime = self.resizeTime * 2
		end

		self.resizeTimer = MathUtil.clamp(self.resizeTimer + deltaTime / 1000 * self.resizeDir, 0, 1)

		self:setPosition(self.mapHideWidth * (1 - self.resizeTimer), nil)

		if self.resizeTimer == 0 or self.resizeTimer == 1 then
			self.resizeDir = 0
		end
	end
end

function IngameMapMobile:draw()
	if self.resizeDir ~= 0 or self.resizeTimer > 0 then
		IngameMapMobile:superClass().draw(self)
	end

	if self.overlay.visible then
		self.mapFrameElement:draw()
		self.halfCircleElement:draw()
		self.halfCircleIconElement:draw()
		self.rightBorderElement:draw()
	end
end

function IngameMapMobile:toggleSize(state, force)
	IngameMapMobile:superClass().toggleSize(self, 1, force)

	if state == nil then
		state = not self.isMapVisible
	end

	self.isMapVisible = state

	if state then
		self.resizeDir = -1
	else
		self.resizeDir = 1
	end
end

function IngameMapMobile:setPosition(x, y)
	IngameMapMobile:superClass().setPosition(self, x, y)
	self.mobileLayout:setOffset(x or 0)
end

function IngameMapMobile:getBackgroundPosition()
	local widthOffset, _ = getNormalizedScreenValues(unpack(IngameMapMobile.SIZE.MAP_HIDE_WIDTH))
	local _, height = getNormalizedScreenValues(unpack(IngameMapMobile.SIZE.SELF))
	local _, heightOffset = getNormalizedScreenValues(unpack(IngameMapMobile.POSITION.SELF))

	if self.player ~= nil then
		local _, heightOffsetPlayer = getNormalizedScreenValues(unpack(IngameMapMobile.POSITION.SELF_PLAYER_OFFSET))
		heightOffset = heightOffset + heightOffsetPlayer
	end

	local x, y = GuiUtils.alignToScreenPixels(widthOffset, heightOffset - height * 0.5)

	return x, y
end

function IngameMapMobile:createBackground()
	local width, height = getNormalizedScreenValues(unpack(IngameMapMobile.SIZE.SELF))
	local posX, posY = self:getBackgroundPosition()

	return Overlay.new(nil, posX, posY, width, height)
end

function IngameMapMobile:createFrame(hudAtlasPath, baseX, baseY, width, height)
	local frame = HUDFrameElement.new(hudAtlasPath, baseX, baseY, width, height, nil, false, IngameMapMobile.FRAME_THICKNESS)

	frame:setFrameColor(unpack(IngameMapMobile.COLOR.FRAME))

	self.mapFrameElement = frame

	self:addChild(frame)
end

function IngameMapMobile:drawPlayersCoordinates()
end

IngameMapMobile.MIN_MAP_WIDTH = 464
IngameMapMobile.MIN_MAP_HEIGHT = 470
IngameMapMobile.FRAME_THICKNESS = 2
IngameMapMobile.SIZE = {
	MAP = {
		IngameMapMobile.MIN_MAP_WIDTH,
		IngameMapMobile.MIN_MAP_HEIGHT
	},
	SELF = {
		IngameMapMobile.MIN_MAP_WIDTH + IngameMapMobile.FRAME_THICKNESS * 2,
		IngameMapMobile.MIN_MAP_HEIGHT + IngameMapMobile.FRAME_THICKNESS
	},
	RIGHT_BORDER = {
		4,
		IngameMapMobile.MIN_MAP_HEIGHT + IngameMapMobile.FRAME_THICKNESS
	},
	HALF_CIRCLE = {
		83,
		165
	},
	HALF_CIRCLE_ICON = {
		48,
		96
	},
	MAP_HIDE_WIDTH = {
		-IngameMapMobile.MIN_MAP_WIDTH - IngameMapMobile.FRAME_THICKNESS * 2 - 4,
		0
	}
}
IngameMapMobile.POSITION = {
	SELF = {
		0,
		540
	},
	SELF_PLAYER_OFFSET = {
		0,
		106
	},
	MAP = {
		IngameMapMobile.FRAME_THICKNESS,
		IngameMapMobile.FRAME_THICKNESS
	},
	RIGHT_BORDER = {
		IngameMapMobile.FRAME_THICKNESS + IngameMapMobile.MIN_MAP_WIDTH,
		0
	},
	HALF_CIRCLE = {
		IngameMapMobile.SIZE.RIGHT_BORDER[1] + IngameMapMobile.MIN_MAP_WIDTH - 4,
		IngameMapMobile.MIN_MAP_HEIGHT / 2 - IngameMapMobile.SIZE.HALF_CIRCLE[2] / 2
	},
	HALF_CIRCLE_ICON = {
		IngameMapMobile.SIZE.RIGHT_BORDER[1] + IngameMapMobile.MIN_MAP_WIDTH + 8,
		IngameMapMobile.MIN_MAP_HEIGHT / 2 - IngameMapMobile.SIZE.HALF_CIRCLE_ICON[2] / 2
	}
}
IngameMapMobile.UV = {
	HALF_CIRCLE = {
		97,
		576,
		95,
		192
	},
	HALF_CIRCLE_ICON = {
		600,
		240,
		48,
		96
	}
}
IngameMapMobile.COLOR = {
	RIGHT_BORDER = {
		0.0227,
		0.5346,
		0.8519,
		1
	},
	MAP_ICON = {
		1,
		1,
		1,
		1
	},
	FRAME = {
		0.098039,
		0.098039,
		0.098039,
		1
	}
}
