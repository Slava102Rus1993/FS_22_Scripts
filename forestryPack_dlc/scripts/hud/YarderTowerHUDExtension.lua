YarderTowerHUDExtension = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory
}
YarderTowerHUDExtension.GUI_ELEMENTS = YarderTowerHUDExtension.MOD_DIR .. "menu/hud/ui_elements.png"
local YarderTowerHUDExtension_mt = Class(YarderTowerHUDExtension, VehicleHUDExtension)

function YarderTowerHUDExtension.new(vehicle, uiScale, uiTextColor, uiTextSize)
	local self = VehicleHUDExtension.new(YarderTowerHUDExtension_mt, vehicle, uiScale, uiTextColor, uiTextSize)
	self.uiTextColor = uiTextColor
	_, self.textHeightHeadline = getNormalizedScreenValues(0, 17 * uiScale)
	self.textMaxWidthHeadline, _ = getNormalizedScreenValues(440 * uiScale, 0)
	local width, height = getNormalizedScreenValues(440 * uiScale, 63 * uiScale)
	self.background = Overlay.new(YarderTowerHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.background:setUVs(GuiUtils.getUVs(YarderTowerHUDExtension.UV.BACKGROUND))
	self.background:setColor(unpack(YarderTowerHUDExtension.COLOR.MAIN_COLOR))
	self:addComponentForCleanup(self.background)

	width, height = getNormalizedScreenValues(32 * uiScale, 32 * uiScale)
	self.carriageFull = Overlay.new(YarderTowerHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.carriageFull:setUVs(GuiUtils.getUVs(YarderTowerHUDExtension.UV.CARRIAGE_FULL))
	self.carriageFull:setColor(unpack(YarderTowerHUDExtension.COLOR.MAIN_COLOR))
	self:addComponentForCleanup(self.carriageFull)

	self.carriageEmpty = Overlay.new(YarderTowerHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.carriageEmpty:setUVs(GuiUtils.getUVs(YarderTowerHUDExtension.UV.CARRIAGE_EMPTY))
	self.carriageEmpty:setColor(unpack(YarderTowerHUDExtension.COLOR.MAIN_COLOR))
	self:addComponentForCleanup(self.carriageEmpty)

	width, height = getNormalizedScreenValues(25 * uiScale, 25 * uiScale)
	self.player = Overlay.new(YarderTowerHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.player:setUVs(GuiUtils.getUVs(YarderTowerHUDExtension.UV.PLAYER))
	self.player:setColor(unpack(YarderTowerHUDExtension.COLOR.MAIN_COLOR))
	self:addComponentForCleanup(self.player)

	width, height = getNormalizedScreenValues(18 * uiScale, 18 * uiScale)
	self.targetPositionMarker = Overlay.new(YarderTowerHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.targetPositionMarker:setUVs(GuiUtils.getUVs(YarderTowerHUDExtension.UV.PLAYER))
	self.targetPositionMarker:setColor(unpack(YarderTowerHUDExtension.COLOR.MAIN_COLOR))
	self:addComponentForCleanup(self.targetPositionMarker)

	local _ = nil
	_, self.borderTop = getNormalizedScreenValues(0, 30 * uiScale)
	_, self.borderBottom = getNormalizedScreenValues(0, 12 * uiScale)
	self.ropeWidth = 0.775
	self.ropeHeight = 0.8809523809523809
	self.carriagePivot = 0.7962962962962963
	self.markerPivot = 0.2777777777777778
	self.playerWidth = 0.775
	self.playerHeight = 0.15
	self.texts = {
		headline = string.format("%s - %s", g_i18n:getText("helpLine_yarder", YarderTowerHUDExtension.MOD_NAME), vehicle:getName())
	}

	return self
end

function YarderTowerHUDExtension:getPriority()
	return 1
end

function YarderTowerHUDExtension:canDraw()
	return self.vehicle:getYarderIsSetUp()
end

function YarderTowerHUDExtension:getDisplayHeight()
	return self:canDraw() and self.background.height + self.borderTop + self.borderBottom or 0
end

function YarderTowerHUDExtension:getHelpEntryCountReduction()
	return 1
end

local function renderDoubleText(x, y, textSize, text, maxWidth)
	if maxWidth ~= nil then
		while maxWidth < getTextWidth(textSize, text) do
			textSize = textSize * 0.98
		end
	end

	setTextColor(0, 0, 0, 1)
	renderText(x, y - 0.0015, textSize, text)
	setTextColor(1, 1, 1, 1)
	renderText(x, y, textSize, text)
end

function YarderTowerHUDExtension:draw(leftPosX, rightPosX, posY)
	if not self:canDraw() then
		return
	end

	local isPlayerInRange, isLoaded, playerPosition, carriagePosition, followModeState, followModeLocalPlayer, targetPosition = self.vehicle:getYarderStatusInfo()

	setTextColor(unpack(self.uiTextColor))
	setTextBold(true)
	setTextAlignment(RenderText.ALIGN_LEFT)
	renderDoubleText(leftPosX, posY + self.borderBottom + self.background.height + self.borderTop * 0.25, self.textHeightHeadline, self.texts.headline, self.textMaxWidthHeadline)
	setTextBold(false)

	local centerX = (rightPosX + leftPosX) * 0.5

	self.background:setPosition(centerX - self.background.width * 0.5, posY + self.borderBottom)
	self.background:render()

	if followModeState == YarderTower.FOLLOW_MODE_ME and followModeLocalPlayer then
		self.player:setColor(nil, , , YarderTowerHUDExtension.COLOR.MAIN_COLOR[4] * (math.sin(g_time * 0.0075) * 0.25 + 0.5))
	else
		self.player:setColor(nil, , , 1)
	end

	local ropeWidth = self.background.width * self.ropeWidth

	if targetPosition ~= nil then
		self.targetPositionMarker:setColor(nil, , , YarderTowerHUDExtension.COLOR.MAIN_COLOR[4] * (math.sin(g_time * 0.0075) * 0.25 + 0.5))

		local targetMarkerPosX = self.background.x + (self.background.width - ropeWidth) * 0.5 + ropeWidth * targetPosition - self.targetPositionMarker.width * 0.5
		local targetMarkerPosY = self.background.y + self.background.height * self.ropeHeight - self.targetPositionMarker.height * self.markerPivot

		self.targetPositionMarker:setPosition(targetMarkerPosX, targetMarkerPosY)
		self.targetPositionMarker:render()
	end

	local carriageIcon = isLoaded and self.carriageFull or self.carriageEmpty
	local carriagePosX = self.background.x + (self.background.width - ropeWidth) * 0.5 + ropeWidth * carriagePosition - carriageIcon.width * 0.5
	local carriagePosY = self.background.y + self.background.height * self.ropeHeight - carriageIcon.height * self.carriagePivot

	carriageIcon:setPosition(carriagePosX, carriagePosY)
	carriageIcon:render()

	if isPlayerInRange then
		local playerWidth = self.background.width * self.playerWidth
		local playerPosX = self.background.x + (self.background.width - playerWidth) * 0.5 + playerWidth * playerPosition - self.player.width * 0.5
		local playerPosY = self.background.y + self.background.height * self.playerHeight - self.player.height * 0.5

		self.player:setPosition(playerPosX, playerPosY)
		self.player:render()
	end

	return posY
end

YarderTowerHUDExtension.COLOR = {
	MAIN_COLOR = {
		0.0003,
		0.5647,
		0.9822,
		1
	}
}
YarderTowerHUDExtension.UV = {
	BACKGROUND = {
		8,
		47,
		440,
		63
	},
	CARRIAGE_FULL = {
		8,
		115,
		54,
		54
	},
	CARRIAGE_EMPTY = {
		67,
		115,
		54,
		54
	},
	PLAYER = {
		136,
		123,
		36,
		36
	}
}
