BaleCounterHUDExtension = {
	GUI_ELEMENTS = g_currentModDirectory .. "gui/ui_elements.png",
	GUI_ELEMENTS_SIZE = {
		512,
		512
	}
}
local BaleCounterHUDExtension_mt = Class(BaleCounterHUDExtension, VehicleHUDExtension)

function BaleCounterHUDExtension.new(vehicle, uiScale, uiTextColor, uiTextSize)
	local self = VehicleHUDExtension.new(BaleCounterHUDExtension_mt, vehicle, uiScale, uiTextColor, uiTextSize)
	self.spec_baleCounter = vehicle[BaleCounter.SPEC_TABLE_NAME]
	local _ = nil
	_, self.displayHeight = getNormalizedScreenValues(0, 41 * uiScale)
	self.uiTextColor = uiTextColor
	_, self.textSize = getNormalizedScreenValues(0, 20 * uiScale)
	self.sessionOverlayX, _ = getNormalizedScreenValues(27 * uiScale, 0)
	self.sessionTextX, _ = getNormalizedScreenValues(80 * uiScale, 0)
	self.lifetimeOverlayX, _ = getNormalizedScreenValues(148 * uiScale, 0)
	self.lifetimeTextX, _ = getNormalizedScreenValues(201 * uiScale, 0)
	local width, height = getNormalizedScreenValues(40 * uiScale, 40 * uiScale)
	self.sessionOverlay = Overlay.new(BaleCounterHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.sessionOverlay:setUVs(GuiUtils.getUVs(BaleCounterHUDExtension.UV.SESSION, BaleCounterHUDExtension.GUI_ELEMENTS_SIZE))
	self.sessionOverlay:setColor(1, 1, 1, 1)
	self:addComponentForCleanup(self.sessionOverlay)

	width, height = getNormalizedScreenValues(40 * uiScale, 40 * uiScale)
	self.lifetimeOverlay = Overlay.new(BaleCounterHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.lifetimeOverlay:setUVs(GuiUtils.getUVs(BaleCounterHUDExtension.UV.LIFETIME, BaleCounterHUDExtension.GUI_ELEMENTS_SIZE))
	self.lifetimeOverlay:setColor(1, 1, 1, 1)
	self:addComponentForCleanup(self.lifetimeOverlay)

	return self
end

function BaleCounterHUDExtension:getPriority()
	return 1
end

function BaleCounterHUDExtension:canDraw()
	if not self.vehicle:getIsActiveForInput(true, true) then
		return false
	end

	return true
end

function BaleCounterHUDExtension:getDisplayHeight()
	return self:canDraw() and self.displayHeight or 0
end

function BaleCounterHUDExtension:getHelpEntryCountReduction()
	return self:canDraw() and 1 or 0
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

function BaleCounterHUDExtension:draw(leftPosX, rightPosX, posY)
	if not self:canDraw() then
		return
	end

	local spec = self.spec_baleCounter

	self.sessionOverlay:setPosition(leftPosX + self.sessionOverlayX - self.sessionOverlay.width * 0.5, posY + self.displayHeight * 0.5 - self.sessionOverlay.height * 0.5)
	self.sessionOverlay:render()
	self.lifetimeOverlay:setPosition(leftPosX + self.lifetimeOverlayX - self.lifetimeOverlay.width * 0.5, posY + self.displayHeight * 0.5 - self.lifetimeOverlay.height * 0.5)
	self.lifetimeOverlay:render()
	setTextBold(true)
	setTextAlignment(RenderText.ALIGN_CENTER)
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
	renderDoubleText(leftPosX + self.sessionTextX, posY + self.displayHeight * 0.55, self.textSize, string.format("%d", spec.sessionCounter))
	renderDoubleText(leftPosX + self.lifetimeTextX, posY + self.displayHeight * 0.55, self.textSize, string.format("%d", spec.lifetimeCounter))
	setTextAlignment(RenderText.ALIGN_LEFT)
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)

	return posY
end

BaleCounterHUDExtension.COLOR = {}
BaleCounterHUDExtension.UV = {
	SESSION = {
		0,
		1,
		64,
		64
	},
	LIFETIME = {
		64,
		1,
		64,
		64
	}
}
