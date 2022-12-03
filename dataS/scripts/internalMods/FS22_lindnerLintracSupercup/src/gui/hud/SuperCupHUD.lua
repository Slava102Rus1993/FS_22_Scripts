SuperCupHUD = {}
local SuperCupHUD_mt = Class(SuperCupHUD)

function SuperCupHUD.new(modDirectory, gameInfoDisplay)
	local self = setmetatable({}, SuperCupHUD_mt)
	self.modDirectory = modDirectory
	self.gameInfoDisplay = gameInfoDisplay
	self.uiFilename = Utils.getFilename("resources/gui/hud_icons.png", modDirectory)
	self.atlasRefSize = {
		256,
		64
	}
	self.isActive = false
	self.timer = nil
	self.penaltyPoints = 0
	self.samples = {}

	return self
end

function SuperCupHUD:loadSamples()
	self.samples = {}
	local filename = Utils.getFilename("resources/sounds/sounds.xml", self.modDirectory)
	local xmlFile = XMLFile.load("superCupSounds", filename)

	if xmlFile == nil then
		return
	end

	self.samples.countdown = g_soundManager:loadSample2DFromXML(xmlFile.handle, "superCup.sounds", "countdown", self.modDirectory, 1, AudioGroup.ENVIRONMENT)
	self.samples.go = g_soundManager:loadSample2DFromXML(xmlFile.handle, "superCup.sounds", "go", self.modDirectory, 1, AudioGroup.ENVIRONMENT)

	xmlFile:delete()
end

function SuperCupHUD:delete()
	self:setIsActive(false)

	if self.timer ~= nil then
		self.timer:delete()
	end

	if self.ballIcon ~= nil then
		self.ballIcon:delete()
	end

	if self.timeIcon ~= nil then
		self.timeIcon:delete()
	end

	if self.separator ~= nil then
		self.separator:delete()
	end

	for _, sample in pairs(self.samples) do
		g_soundManager:deleteSample(sample)
	end
end

function SuperCupHUD:playSampleByName(name)
	local sample = self.samples[name]

	if sample ~= nil and not g_soundManager:getIsSamplePlaying(sample) then
		g_soundManager:playSample(sample)
	end
end

function SuperCupHUD:playCountdownSample()
	self:playSampleByName("countdown")
end

function SuperCupHUD:playGoSample()
	self:playSampleByName("go")
end

function SuperCupHUD:setFarmContext(farmId)
	self.farmId = farmId
end

function SuperCupHUD:loadFromXML(xmlFile, baseKey)
	self:loadSamples()

	local baseX, baseY = self.gameInfoDisplay:getPosition()
	local topRightX, topRightY = GameInfoDisplay.getBackgroundPosition(1)
	local centerX = 0.5
	local marginWidth, marginHeight = self.gameInfoDisplay:scalePixelToScreenVector(SuperCupHUD.MARGIN.BOX)
	local iconWidth, iconHeight = self.gameInfoDisplay:scalePixelToScreenVector(SuperCupHUD.SIZE.ICON)
	local marginTextWidth, marginTextHeight = self.gameInfoDisplay:scalePixelToScreenVector(SuperCupHUD.MARGIN.TEXT)
	self.textSize = self.gameInfoDisplay:scalePixelToScreenHeight(SuperCupHUD.TEXT_SIZE.COUNT)
	local centerY = topRightY - iconHeight * 0.5 + marginTextHeight
	local centerTextY = topRightY - iconHeight * 0.5 - self.textSize * 0.5 + marginTextHeight
	local x = centerX
	self.ballIcon, x = self:createIcon(self.uiFilename, x - iconWidth - marginWidth, topRightY + marginHeight, SuperCupHUD.POSITION.BALL, SuperCupHUD.SIZE.ICON, SuperCupHUD.UV.BALL)
	x = x + marginWidth + marginTextWidth
	self.ballTextX = x + iconWidth
	self.separator = self.gameInfoDisplay:createVerticalSeparator(g_baseHUDFilename, centerX, centerY)

	self.gameInfoDisplay:addChild(self.separator)

	self.timeIcon, x = self:createIcon(self.uiFilename, centerX + marginWidth, topRightY + marginHeight, SuperCupHUD.POSITION.TIMER, SuperCupHUD.SIZE.ICON, SuperCupHUD.UV.TIMER)
	self.timeTextX = x + iconWidth
	self.timeTextY = centerTextY
	self.ballTextY = centerTextY

	self:setIsActive(false)
end

function SuperCupHUD:draw()
	if not self:getCanRender() then
		return
	end

	local t = self.timer
	local time = SuperCupUtil.millisecondsToClockString(t ~= nil and t:getElapsedTime() or 0)

	self:drawTextElement({
		bold = true,
		x = self.timeTextX,
		y = self.timeTextY,
		text = time,
		textSize = self.textSize,
		textAlignment = RenderText.ALIGN_LEFT
	})
	self:drawTextElement({
		bold = true,
		x = self.ballTextX,
		y = self.ballTextY,
		text = ("%02d"):format(self.penaltyPoints),
		textSize = self.textSize
	})
end

function SuperCupHUD:getCanRender()
	return self.isActive and self.ballIcon:getVisible() and self.timeIcon:getVisible() and g_currentMission.hud:getIsVisible() and not g_gui:getIsGuiVisible()
end

function SuperCupHUD:canInteractWithFarm(farmId)
	return self.farmId == farmId
end

function SuperCupHUD:setIsActive(isActive)
	self.isActive = isActive

	if self.separator ~= nil then
		self.ballIcon:setVisible(isActive)
		self.timeIcon:setVisible(isActive)
		self.separator:setVisible(isActive)
	end
end

function SuperCupHUD:setTimer(timer)
	self.timer = timer
end

function SuperCupHUD:setPenaltyPoints(penaltyPoints)
	self.penaltyPoints = penaltyPoints
end

function SuperCupHUD:drawTextElement(textElement)
	setTextColor(unpack(textElement.color or {
		1,
		1,
		1,
		1
	}))
	setTextBold(textElement.bold or false)

	local textSize = textElement.textSize or getCorrectTextSize(0.022)

	setTextAlignment(textElement.textAlignment or RenderText.ALIGN_CENTER)
	renderText(textElement.x, textElement.y, textSize, textElement.text)
end

function SuperCupHUD:createIcon(imagePath, baseX, baseY, position, size, uvs)
	local posX, posY = self.gameInfoDisplay:scalePixelToScreenVector(position)
	local width, height = self.gameInfoDisplay:scalePixelToScreenVector(size)
	baseY = baseY - height
	local x = baseX + posX
	local iconOverlay = Overlay.new(imagePath, x, baseY + posY, width, height)

	iconOverlay:setUVs(GuiUtils.getUVs(uvs, self.atlasRefSize))

	local element = HUDElement.new(iconOverlay)

	self.gameInfoDisplay:addChild(element)
	element:setVisible(true)

	return element, x
end

SuperCupHUD.SIZE = {
	ICON = {
		52,
		52
	}
}
SuperCupHUD.MARGIN = {
	BOX = {
		0,
		0
	},
	TEXT = {
		15,
		0
	}
}
SuperCupHUD.POSITION = {
	BALL = {
		-40,
		0
	},
	TIMER = {
		10,
		0
	}
}
SuperCupHUD.UV = {
	BALL = {
		0,
		0,
		64,
		64
	},
	TIMER = {
		64,
		0,
		64,
		64
	}
}
SuperCupHUD.TEXT_SIZE = {
	COUNT = 22
}
