UmbilicalPumpHUD = {}
local UmbilicalPumpHUD_mt = Class(UmbilicalPumpHUD, VehicleHUDExtension)

function UmbilicalPumpHUD.new(vehicle, uiScale, uiTextColor, uiTextSize)
	local self = VehicleHUDExtension.new(UmbilicalPumpHUD_mt, vehicle, uiScale, uiTextColor, uiTextSize)
	self.conditionBar = self:createBar(g_baseHUDFilename, 0, 0)

	self:addComponentForCleanup(self.conditionBar)

	local _, displayHeight = getNormalizedScreenValues(0, 80 * uiScale)
	local _, iconHeight = getNormalizedScreenValues(0, 35 * uiScale)
	self.iconHeight = iconHeight
	self.displayHeight = displayHeight
	self.validVehicle = nil

	return self
end

function UmbilicalPumpHUD:delete()
	UmbilicalPumpHUD:superClass().delete(self)
end

function UmbilicalPumpHUD:getPriority()
	return 2
end

function UmbilicalPumpHUD:canDraw()
	self.validVehicle = self:getValidVehicle()

	return self.validVehicle ~= nil
end

function UmbilicalPumpHUD:isVehicleValid(vehicle)
	return SpecializationUtil.hasSpecialization(UmbilicalPump, vehicle.specializations) or SpecializationUtil.hasSpecialization(UmbilicalSprayer, vehicle.specializations)
end

function UmbilicalPumpHUD:getValidVehicle()
	local vehicleList = self.vehicle.rootVehicle.childVehicles

	for i = 1, #vehicleList do
		local childVehicle = vehicleList[i]

		if self:isVehicleValid(childVehicle) then
			local pumpVehicle = childVehicle

			if childVehicle.spec_umbilicalPump == nil then
				pumpVehicle = childVehicle.spec_umbilicalSprayer.pumpObject
			end

			if pumpVehicle ~= nil then
				return pumpVehicle
			end
		end
	end

	return nil
end

function UmbilicalPumpHUD:getDisplayHeight()
	return self:canDraw() and (self.displayHeight or 0)
end

function UmbilicalPumpHUD:getHelpEntryCountReduction()
	return 0
end

function UmbilicalPumpHUD:draw(leftPosX, rightPosX, posY)
	if not self:canDraw() then
		return
	end

	local pumpVehicle = self.validVehicle
	local spec = pumpVehicle.spec_umbilicalPump

	setTextColor(unpack(self.uiTextColor))
	setTextBold(true)
	setTextAlignment(RenderText.ALIGN_LEFT)

	local text = string.format("Umbilical pump (%s)", pumpVehicle:getName())
	local heightOffset = self.uiTextSize * 1.5

	renderText(leftPosX, posY + self.displayHeight - heightOffset, self.uiTextSize, text)
	setTextBold(false)

	local lps = spec.characteristics.litersPerSecond * math.max(spec.characteristics.currentLoad * spec.characteristics.condition, 0.01)
	local lpsCondition = lps / spec.characteristics.litersPerSecond
	local conditionColor = UmbilicalPumpHUD.COLOR.CONDITION_GAUGE

	if lpsCondition < 0.2 then
		conditionColor = UmbilicalPumpHUD.COLOR.CONDITION_GAUGE_LOW or conditionColor
	end

	if lpsCondition < 0.85 then
		conditionColor = UmbilicalPumpHUD.COLOR.CONDITION_GAUGE_MEDIUM or conditionColor
	end

	self.conditionBar:setBarColor(conditionColor[1], conditionColor[2], conditionColor[3])

	if spec.pumpIsActive then
		self:drawBar(self.conditionBar, lpsCondition, g_i18n:getText("ui_condition"), leftPosX, rightPosX, posY)
	end

	local fromObject, fromFillUnitIndex = pumpVehicle:getPumpFromOrSelfObject()
	local sourceName = g_i18n:getText("warning_noPumpSourceFoundNear")
	local fromFillLevel = 0

	if fromObject ~= nil then
		if spec.sourceIsTrigger then
			fromFillLevel = fromObject.source:getFillLevel(fromFillUnitIndex, pumpVehicle:getOwnerFarmId())
			sourceName = fromObject.source:getName()
		else
			fromFillLevel = fromObject:getFillUnitFillLevel(fromFillUnitIndex)
			sourceName = fromObject:getName()
		end
	end

	renderText(leftPosX, posY + self.displayHeight - heightOffset - self.iconHeight, self.uiTextSize, ("%s (%dL)"):format(sourceName, fromFillLevel or 0))

	return posY
end

function UmbilicalPumpHUD:drawBar(bar, value, prefix, leftPosX, rightPosX, posY)
	local heightOffset = self.uiTextSize * 1.5
	local barWidth = bar:getWidth()
	local barHeight = bar:getHeight()
	local loadHeaderHeight = posY + self.displayHeight - heightOffset

	setTextAlignment(RenderText.ALIGN_RIGHT)
	renderText(rightPosX, loadHeaderHeight + barHeight * 0.5, self.uiTextSize, string.format("%s %d%%", prefix, value * 100))
	setTextAlignment(RenderText.ALIGN_LEFT)
	bar:setPosition(rightPosX - barWidth, posY + self.displayHeight - self.iconHeight)
	bar:setValue(value)
	bar:draw()

	return self.iconHeight
end

function UmbilicalPumpHUD:createBar(hudAtlasPath, baseX, baseY)
	local width, height = getNormalizedScreenValues(unpack(UmbilicalPumpHUD.SIZE.LOAD_GAUGE))
	local posX, posY = getNormalizedScreenValues(0, 0)
	local element = HUDRoundedBarElement.new(hudAtlasPath, baseX + posX, baseY + posY, width, height, true)

	element:setBarColor(unpack(UmbilicalPumpHUD.COLOR.LOAD_GAUGE))

	return element
end

UmbilicalPumpHUD.COLOR = {
	LOAD_GAUGE = {
		0.0003,
		0.5647,
		0.9822
	},
	CONDITION_GAUGE = {
		0.4423,
		0.6724,
		0.0093
	},
	CONDITION_GAUGE_MEDIUM = {
		1,
		0.4233,
		0
	},
	CONDITION_GAUGE_LOW = {
		1,
		0.1233,
		0
	}
}
UmbilicalPumpHUD.SIZE = {
	LOAD_GAUGE = {
		150,
		12
	}
}
