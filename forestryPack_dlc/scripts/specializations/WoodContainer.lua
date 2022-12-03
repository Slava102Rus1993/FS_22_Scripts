local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

WoodContainer = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".woodContainer"
}

source(g_currentModDirectory .. "scripts/specializations/events/WoodContainerWrongLengthEvent.lua")

function WoodContainer.prerequisitesPresent(specializations)
	return true
end

function WoodContainer.initSpecialization()
	g_configurationManager:addConfigurationType("woodContainer", g_i18n:getText("shop_configuration"), "woodContainer", nil, , , ConfigurationUtil.SELECTOR_MULTIOPTION)

	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("WoodContainer")
	WoodContainer.registerXMLPaths(schema, "vehicle.woodContainer")
	WoodContainer.registerXMLPaths(schema, "vehicle.woodContainer.woodContainerConfigurations.woodContainerConfiguration(?)")
	schema:register(XMLValueType.INT, "vehicle.woodContainer.sounds#numLogs", "Number of logs filled in the container", 1)
	SoundManager.registerSampleXMLPaths(schema, "vehicle.woodContainer.sounds", "load")
	schema:setXMLSpecializationType()

	local schemaSavegame = Vehicle.xmlSchemaSavegame

	schemaSavegame:register(XMLValueType.FLOAT, string.format("vehicles.vehicle(?).%s#woodQualityVolume", WoodContainer.SPEC_NAME), "Volume including the quality factors")
	schemaSavegame:register(XMLValueType.FLOAT, string.format("vehicles.vehicle(?).%s#woodQualityTotalVolume", WoodContainer.SPEC_NAME), "Volume excluding the quality factors")
end

function WoodContainer.registerXMLPaths(schema, baseKey)
	schema:register(XMLValueType.FLOAT, baseKey .. "#foldMinLimit", "Min. fold anim time to fill the container", 0)
	schema:register(XMLValueType.FLOAT, baseKey .. "#foldMaxLimit", "Max. fold anim time to fill the container", 1)
	schema:register(XMLValueType.INT, baseKey .. "#fillUnitIndex", "Index of fill unit", 1)
	schema:register(XMLValueType.FLOAT, baseKey .. "#targetLength", "Optimal length of trees (has the highest value)", 12)
	schema:register(XMLValueType.NODE_INDEX, baseKey .. "#triggerNode", "Tree trigger node")
	schema:register(XMLValueType.STRING, baseKey .. ".pushAnimation#name", "Animation that is played as soon as something is loaded into the container")
	schema:register(XMLValueType.FLOAT, baseKey .. ".pushAnimation#speedScale", "Animation speed", 1)
end

function WoodContainer.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getPalletUnloadTriggerExtraSellPrice", WoodContainer.getPalletUnloadTriggerExtraSellPrice)
	SpecializationUtil.registerFunction(vehicleType, "getIsWoodContainerFillingAllowed", WoodContainer.getIsWoodContainerFillingAllowed)
	SpecializationUtil.registerFunction(vehicleType, "onWoodContainerTriggerCallback", WoodContainer.onWoodContainerTriggerCallback)
end

function WoodContainer.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getInfoBoxTitle", WoodContainer.getInfoBoxTitle)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "addFillUnitFillLevel", WoodContainer.addFillUnitFillLevel)
end

function WoodContainer.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", WoodContainer)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", WoodContainer)
	SpecializationUtil.registerEventListener(vehicleType, "onFillUnitFillLevelChanged", WoodContainer)
end

function WoodContainer:onLoad(savegame)
	self.spec_woodContainer = self["spec_" .. WoodContainer.SPEC_NAME]
	local spec = self.spec_woodContainer
	local configurationId = Utils.getNoNil(self.configurations.woodContainer, 1)
	local configKey = string.format("vehicle.woodContainer.woodContainerConfigurations.woodContainerConfiguration(%d)", configurationId - 1)

	if not self.xmlFile:hasProperty(configKey) then
		configKey = "vehicle.woodContainer"
	end

	spec.foldMinLimit = self.xmlFile:getValue(configKey .. "#foldMinLimit", 0)
	spec.foldMaxLimit = self.xmlFile:getValue(configKey .. "#foldMaxLimit", 1)
	spec.fillUnitIndex = self.xmlFile:getValue(configKey .. "#fillUnitIndex", 1)
	spec.targetLength = self.xmlFile:getValue(configKey .. "#targetLength", 12)
	spec.triggerNode = self.xmlFile:getValue(configKey .. "#triggerNode", nil, self.components, self.i3dMappings)

	if self.isServer and spec.triggerNode ~= nil then
		addTrigger(spec.triggerNode, "onWoodContainerTriggerCallback", self)
	end

	spec.woodQualityVolume = 0
	spec.woodQualityTotalVolume = 0
	spec.pushAnimation = {
		name = self.xmlFile:getValue(configKey .. ".pushAnimation#name"),
		speedScale = self.xmlFile:getValue(configKey .. ".pushAnimation#speedScale", 1)
	}
	spec.samples = {}

	if self.isClient then
		spec.soundNumLogs = self.xmlFile:getValue("vehicle.woodContainer.sounds#numLogs", 1)
		spec.soundLastNumLogs = 0
		spec.samples.load = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.woodContainer.sounds", "load", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
	end

	spec.texts = {
		warningTransportTreesCannotBeLoaded = g_i18n:getText("warning_transportTreesCannotBeLoaded"),
		warningWoodContainerWrongLength = g_i18n:getText("warning_woodContainerWrongLength")
	}

	if savegame ~= nil then
		spec.woodQualityVolume = savegame.xmlFile:getValue(string.format("%s.%s#woodQualityVolume", savegame.key, WoodContainer.SPEC_NAME), spec.woodQualityVolume)
		spec.woodQualityTotalVolume = savegame.xmlFile:getValue(string.format("%s.%s#woodQualityTotalVolume", savegame.key, WoodContainer.SPEC_NAME), spec.woodQualityTotalVolume)
	end
end

function WoodContainer:onDelete()
	local spec = self.spec_woodContainer

	if spec.triggerNode ~= nil then
		removeTrigger(spec.triggerNode)
	end

	if spec.samples ~= nil then
		g_soundManager:deleteSamples(spec.samples)
	end
end

function WoodContainer:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_woodContainer

	xmlFile:setValue(key .. "#woodQualityVolume", spec.woodQualityVolume)
	xmlFile:setValue(key .. "#woodQualityTotalVolume", spec.woodQualityTotalVolume)
end

function WoodContainer:onFillUnitFillLevelChanged(fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, appliedDelta)
	local spec = self.spec_woodContainer

	if fillUnitIndex == spec.fillUnitIndex then
		if self.isClient and fillLevelDelta > 0 then
			local fillLevel = self:getFillUnitFillLevelPercentage(fillUnitIndex)
			local numLogs = math.ceil(fillLevel * (spec.soundNumLogs - 1))

			if numLogs ~= spec.soundLastNumLogs then
				if not g_soundManager:getIsSamplePlaying(spec.samples.load) then
					g_soundManager:playSample(spec.samples.load)
				end

				spec.soundLastNumLogs = numLogs
			end
		end

		if spec.pushAnimation.name ~= nil then
			local fillLevel = self:getFillUnitFillLevelPercentage(fillUnitIndex)
			local animTime = self:getAnimationTime(spec.pushAnimation.name)

			if fillLevel > 0 and animTime == 0 then
				self:playAnimation(spec.pushAnimation.name, spec.pushAnimation.speedScale, self:getAnimationTime(spec.pushAnimation.name), true)
			elseif fillLevel == 0 and animTime ~= 0 then
				self:playAnimation(spec.pushAnimation.name, -spec.pushAnimation.speedScale, self:getAnimationTime(spec.pushAnimation.name), true)
			end
		end
	end
end

function WoodContainer:getPalletUnloadTriggerExtraSellPrice()
	return self:getPrice()
end

function WoodContainer:getIsWoodContainerFillingAllowed()
	if self.spec_foldable ~= nil then
		local spec = self.spec_woodContainer
		local foldAnimTime = self:getFoldAnimTime()

		if foldAnimTime < spec.foldMinLimit or spec.foldMaxLimit < foldAnimTime then
			return false
		end
	end

	return true
end

function WoodContainer:getInfoBoxTitle(superFunc)
	return g_i18n:getText("storeItem_shippingContainer", self.customEnvironment)
end

function WoodContainer:addFillUnitFillLevel(superFunc, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData)
	local delta = superFunc(self, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData)

	if fillLevelDelta < 0 then
		local spec = self.spec_woodContainer

		if spec.woodQualityTotalVolume > 0 then
			delta = delta * spec.woodQualityVolume / spec.woodQualityTotalVolume
		end
	end

	return delta
end

function WoodContainer:onWoodContainerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if self:getIsWoodContainerFillingAllowed() and otherId ~= 0 then
		local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(otherId))

		if splitType ~= nil and splitType.pricePerLiter > 0 then
			if not splitType.name:contains("TRANSPORT") then
				local spec = self.spec_woodContainer
				local liter, qualityScale, length = WoodContainer.getSplitShapeInfo(otherId, spec.targetLength)

				if liter > 0 and qualityScale > 0 and self:getFillUnitFreeCapacity(spec.fillUnitIndex) > 0 then
					spec.woodQualityVolume = spec.woodQualityVolume + liter * qualityScale * splitType.pricePerLiter
					spec.woodQualityTotalVolume = spec.woodQualityTotalVolume + liter

					self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, liter, FillType.WOOD, ToolType.UNDEFINED, nil)
					delete(otherId)

					if math.abs(spec.targetLength - length) > 1 then
						g_server:broadcastEvent(WoodContainerWrongLengthEvent.new(self), true, nil, self)
					end
				end
			else
				g_currentMission:showBlinkingWarning(self.spec_woodContainer.texts.warningTransportTreesCannotBeLoaded, 2000)
			end
		end
	end
end

function WoodContainer.getSplitShapeInfo(objectId, targetLength)
	local volume = getVolume(objectId)
	local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(objectId))
	local sizeX, sizeY, sizeZ, numConvexes, numAttachments = getSplitShapeStats(objectId)
	local qualityScale = 1
	local lengthScale = 1
	local defoliageScale = 1
	local maxSize = 0

	if sizeX ~= nil and volume > 0 then
		local bvVolume = sizeX * sizeY * sizeZ
		local volumeRatio = bvVolume / volume
		local volumeQuality = 1 - math.sqrt(MathUtil.clamp((volumeRatio - 3) / 7, 0, 1)) * 0.95
		local convexityQuality = 1 - MathUtil.clamp((numConvexes - 2) / 4, 0, 1) * 0.5
		maxSize = math.max(sizeX, sizeY, sizeZ)
		lengthScale = 0.5 + (1 - math.min(math.max(math.abs(targetLength - maxSize) - 1, 0), 5) / 5) * 0.5
		local minQuality = math.min(convexityQuality, volumeQuality)
		local maxQuality = math.max(convexityQuality, volumeQuality)
		qualityScale = minQuality + (maxQuality - minQuality) * 0.3
		defoliageScale = 1 - math.min(numAttachments / 15, 1) * 0.8
	end

	qualityScale = MathUtil.lerp(1, qualityScale, g_currentMission.missionInfo.economicDifficulty / 3)
	defoliageScale = MathUtil.lerp(1, defoliageScale, g_currentMission.missionInfo.economicDifficulty / 3)

	return volume * splitType.volumeToLiter, qualityScale * defoliageScale * lengthScale, maxSize
end
