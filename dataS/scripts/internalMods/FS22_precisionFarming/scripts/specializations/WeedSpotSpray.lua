WeedSpotSpray = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".weedSpotSpray",
	NOZZLE_UPDATES_PER_FRAME = 10,
	EFFECT_DIRECTION_OFF = {
		0,
		0
	},
	EFFECT_DIRECTION_START = {
		1,
		1
	},
	EFFECT_DIRECTION_STOP = {
		1,
		-1
	},
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Sprayer, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
	end,
	initSpecialization = function ()
		g_configurationManager:addConfigurationType("weedSpotSpray", g_i18n:getText("configuration_weedSpotSpray"), "weedSpotSpray", nil, , , ConfigurationUtil.SELECTOR_MULTIOPTION)

		local schema = Vehicle.xmlSchema

		schema:setXMLSpecializationType("WeedSpotSpray")
		ObjectChangeUtil.registerObjectChangeXMLPaths(schema, "vehicle.weedSpotSpray.weedSpotSprayConfigurations.weedSpotSprayConfiguration(?)")
		schema:register(XMLValueType.TIME, "vehicle.weedSpotSpray#effectFadeTime", "Time the effect needs to fade in an out", 0.25)
		schema:register(XMLValueType.INT, "vehicle.weedSpotSpray.nozzles(?)#foldingConfigurationIndex", "Folding configuration index to use these nozzles", 1)
		schema:register(XMLValueType.NODE_INDEX, "vehicle.weedSpotSpray.nozzles(?).nozzle(?)#node", "Nozzle Node")
		schema:register(XMLValueType.INT, "vehicle.weedSpotSpray.nozzles(?).nozzle(?)#sectionIndex", "Index of corresponding section")
		schema:register(XMLValueType.FLOAT, "vehicle.weedSpotSpray.nozzles(?).nozzle(?)#zOffset", "Offset in Z direction for detection [m]", 0.5)
		schema:setXMLSpecializationType()
	end
}

function WeedSpotSpray.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getSpotSprayCoverage", WeedSpotSpray.getSpotSprayCoverage)
	SpecializationUtil.registerFunction(vehicleType, "getIsSpotSprayEnabled", WeedSpotSpray.getIsSpotSprayEnabled)
	SpecializationUtil.registerFunction(vehicleType, "updateNozzleEffects", WeedSpotSpray.updateNozzleEffects)
end

function WeedSpotSpray.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAreEffectsVisible", WeedSpotSpray.getAreEffectsVisible)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getSprayerUsage", WeedSpotSpray.getSprayerUsage)
end

function WeedSpotSpray.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", WeedSpotSpray)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", WeedSpotSpray)
	SpecializationUtil.registerEventListener(vehicleType, "onTurnedOff", WeedSpotSpray)
	SpecializationUtil.registerEventListener(vehicleType, "onEndWorkAreaProcessing", WeedSpotSpray)
end

function WeedSpotSpray:onLoad(savegame)
	self.spec_weedSpotSpray = self["spec_" .. WeedSpotSpray.SPEC_NAME]
	local spec = self.spec_weedSpotSpray
	local baseName = "vehicle.weedSpotSpray"
	local weedSpotSprayConfigurationId = Utils.getNoNil(self.configurations.weedSpotSpray, 1)

	ObjectChangeUtil.updateObjectChanges(self.xmlFile, baseName .. ".weedSpotSprayConfigurations.weedSpotSprayConfiguration", weedSpotSprayConfigurationId, self.components, self)

	spec.effectFadeTime = self.xmlFile:getValue(baseName .. "#effectFadeTime", 0.25)
	spec.nozzleNodes = {}
	spec.nozzleNodesToDelete = {}

	self.xmlFile:iterate(baseName .. ".nozzles", function (index, nozzlesKey)
		local foldingConfigIndex = self.xmlFile:getValue(nozzlesKey .. "#foldingConfigurationIndex", 1)

		self.xmlFile:iterate(nozzlesKey .. ".nozzle", function (_, key)
			local entry = {
				node = self.xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings)
			}

			if entry.node ~= nil then
				if foldingConfigIndex == self.configurations.folding or self.configurations.folding == nil and foldingConfigIndex == 1 then
					entry.sectionIndex = self.xmlFile:getValue(key .. "#sectionIndex")
					entry.zOffset = self.xmlFile:getValue(key .. "#zOffset", 0.5)
					entry.effect = {}

					if g_precisionFarming ~= nil then
						spec.extendedWeedControl = g_precisionFarming.extendedWeedControl
						local effectNode = spec.extendedWeedControl:getClonedSprayerEffectNode()

						if effectNode ~= nil then
							link(entry.node, effectNode)
							setTranslation(effectNode, 0, 0, 0)
							setRotation(effectNode, 0, 0, 0)

							local material = g_materialManager:getMaterial(FillType.LIQUIDFERTILIZER, "sprayer", 1)

							if material ~= nil then
								setMaterial(effectNode, material, 0)
							end

							entry.effect.node = effectNode
							entry.effect.fadeCur = {
								-1,
								1
							}
							entry.effect.fadeDir = WeedSpotSpray.EFFECT_DIRECTION_OFF
							entry.effect.state = ShaderPlaneEffect.STATE_OFF

							setShaderParameter(entry.effect.node, "fadeProgress", entry.effect.fadeCur[1], entry.effect.fadeCur[2], 0, 0, false)
							setShaderParameter(entry.effect.node, "offsetUV", math.random(), math.random(), 0, 0, false)
						end
					end

					entry.lastActiveTime = -10000
					entry.isActive = false
					entry.lastIsActive = false

					table.insert(spec.nozzleNodes, entry)
				else
					spec.nozzleNodesToDelete[entry.node] = true
				end
			end
		end)
	end)

	for i = 1, #spec.nozzleNodes do
		spec.nozzleNodesToDelete[spec.nozzleNodes[i].node] = nil
	end

	for i = 1, #spec.nozzleNodesToDelete do
		if entityExists(spec.nozzleNodesToDelete[i]) then
			delete(spec.nozzleNodesToDelete[i])
		end
	end

	spec.nozzleNodesToDelete = {}
	spec.nozzleUpdateFrameDelay = math.ceil(#spec.nozzleNodes / WeedSpotSpray.NOZZLE_UPDATES_PER_FRAME)
	spec.isAvailable = #spec.nozzleNodes > 0
	spec.isEnabled = weedSpotSprayConfigurationId > 1
	spec.currentUpdateIndex = 1
	spec.effectsDirty = false
	spec.lastRegularUsage = 0
	spec.weedDetectionStates = {}
	local weedSystem = g_currentMission.weedSystem
	local replacementData = weedSystem:getHerbicideReplacements()

	if replacementData.weed ~= nil then
		for sourceState, targetState in pairs(replacementData.weed.replacements) do
			if targetState ~= 0 then
				spec.weedDetectionStates[sourceState] = true
			end
		end
	end

	spec.weedMapId, spec.weedFirstChannel, spec.weedNumChannels = g_currentMission.weedSystem:getDensityMapData()
	spec.groundTypeMapId, spec.groundTypeFirstChannel, spec.groundTypeNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
	spec.sprayTypeMapId, spec.sprayTypeFirstChannel, spec.sprayTypeNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)
end

function WeedSpotSpray:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_weedSpotSpray

	if spec.isAvailable then
		local sprayFillType = self.spec_sprayer.workAreaParameters.sprayFillType

		if spec.isEnabled then
			if self:getIsTurnedOn() then
				for i = 1, WeedSpotSpray.NOZZLE_UPDATES_PER_FRAME do
					local nozzleNode = spec.nozzleNodes[spec.currentUpdateIndex]

					if sprayFillType == FillType.HERBICIDE then
						local x, y, z = localToWorld(nozzleNode.node, 0, 0, nozzleNode.zOffset)
						local densityBits = getDensityAtWorldPos(spec.weedMapId, x, y, z)
						local weedState = bitAND(bitShiftRight(densityBits, spec.weedFirstChannel), 2^spec.weedNumChannels - 1)

						if spec.weedDetectionStates[weedState] then
							nozzleNode.lastActiveTime = g_time + spec.nozzleUpdateFrameDelay * dt * 1.5
							spec.effectsDirty = true
						end
					else
						local x, y, z = localToWorld(nozzleNode.node, 0, 0, nozzleNode.zOffset * 2)
						local densityBits = getDensityAtWorldPos(spec.sprayTypeMapId, x, y, z)
						local sprayType = bitAND(bitShiftRight(densityBits, spec.sprayTypeFirstChannel), 2^spec.sprayTypeNumChannels - 1)
						local densityBitsGround = getDensityAtWorldPos(spec.groundTypeMapId, x, y, z)
						local groundType = bitAND(bitShiftRight(densityBitsGround, spec.groundTypeFirstChannel), 2^spec.groundTypeNumChannels - 1)

						if groundType ~= 0 and sprayType ~= FieldSprayType.FERTILIZER then
							nozzleNode.lastActiveTime = g_time + spec.nozzleUpdateFrameDelay * dt * 1.5
							spec.effectsDirty = true
						end
					end

					spec.currentUpdateIndex = spec.currentUpdateIndex + 1

					if spec.currentUpdateIndex > #spec.nozzleNodes then
						spec.currentUpdateIndex = 1
					end
				end
			end

			self:updateNozzleEffects(dt, false)
		else
			self:updateNozzleEffects(dt, true, sprayFillType == FillType.UNKNOWN)
		end
	end
end

function WeedSpotSpray:onTurnedOff()
	local spec = self.spec_weedSpotSpray

	for i = 1, #spec.nozzleNodes do
		local nozzleNode = spec.nozzleNodes[i]
		nozzleNode.isActive = false
		nozzleNode.lastActiveTime = -1000
	end

	spec.effectsDirty = true
end

function WeedSpotSpray:onEndWorkAreaProcessing(dt)
	if self:getLastSpeed() > 0.5 then
		local specSprayer = self.spec_sprayer

		if self.isServer and specSprayer.workAreaParameters.isActive then
			local sprayFillType = specSprayer.workAreaParameters.sprayFillType

			if sprayFillType == FillType.HERBICIDE then
				local sprayVehicle = specSprayer.workAreaParameters.sprayVehicle
				local usage = specSprayer.workAreaParameters.usage

				if sprayVehicle ~= nil or self:getIsAIActive() then
					local farmlandStatistics, _, farmlandId = self:getPFStatisticInfo()

					if farmlandStatistics ~= nil and farmlandId ~= nil then
						farmlandStatistics:updateStatistic(farmlandId, "usedHerbicide", usage)
						farmlandStatistics:updateStatistic(farmlandId, "usedHerbicideRegular", self.spec_weedSpotSpray.lastRegularUsage)
					end
				end
			end
		end
	end
end

function WeedSpotSpray:getAreEffectsVisible(superFunc)
	if self.spec_weedSpotSpray.isAvailable then
		return false
	end

	return superFunc(self)
end

function WeedSpotSpray:getSprayerUsage(superFunc, fillType, dt)
	local spec = self.spec_weedSpotSpray

	if spec.isAvailable and spec.isEnabled then
		local usage = superFunc(self, fillType, dt)
		spec.lastRegularUsage = usage

		return usage * self:getSpotSprayCoverage()
	else
		local usage = superFunc(self, fillType, dt)
		spec.lastRegularUsage = usage

		return usage
	end
end

function WeedSpotSpray:getSpotSprayCoverage()
	local spec = self.spec_weedSpotSpray

	if spec.isAvailable and spec.isEnabled then
		local numActiveNozzles = 0

		for i = 1, #spec.nozzleNodes do
			if spec.nozzleNodes[i].isActive then
				numActiveNozzles = numActiveNozzles + 1
			end
		end

		return numActiveNozzles / #spec.nozzleNodes
	end

	return 1
end

function WeedSpotSpray:getIsSpotSprayEnabled()
	local spec = self.spec_weedSpotSpray

	return spec.isAvailable and spec.isEnabled
end

function WeedSpotSpray:updateNozzleEffects(dt, useSectionState, forceTurnOff)
	local spec = self.spec_weedSpotSpray
	local sections = nil

	if self.spec_variableWorkWidth ~= nil then
		sections = self.spec_variableWorkWidth.sections
	end

	local speed = self:getLastSpeed()
	local keepEffectsDirty = false

	for i = 1, #spec.nozzleNodes do
		local nozzleNode = spec.nozzleNodes[i]
		local fadeSpeedScale = 1

		if not useSectionState then
			nozzleNode.isActive = g_time - nozzleNode.lastActiveTime < 0 and speed > 0.5
		else
			if sections ~= nil and nozzleNode.sectionIndex ~= nil and sections[nozzleNode.sectionIndex] ~= nil then
				local section = sections[nozzleNode.sectionIndex]
				nozzleNode.isActive = section.isActive
			else
				nozzleNode.isActive = true
			end

			nozzleNode.isActive = nozzleNode.isActive and Sprayer.getAreEffectsVisible(self)
			fadeSpeedScale = 3
		end

		nozzleNode.isActive = nozzleNode.isActive and not forceTurnOff

		if nozzleNode.lastIsActive ~= nozzleNode.isActive then
			spec.effectsDirty = true
		end

		if spec.effectsDirty then
			local effect = nozzleNode.effect

			if effect.node ~= nil then
				if nozzleNode.lastIsActive ~= nozzleNode.isActive then
					if nozzleNode.isActive then
						if effect.state ~= ShaderPlaneEffect.STATE_ON and effect.state ~= ShaderPlaneEffect.STATE_TURNING_ON then
							effect.state = ShaderPlaneEffect.STATE_TURNING_ON
							effect.fadeDir = WeedSpotSpray.EFFECT_DIRECTION_START
							effect.fadeCur[1] = -1
							effect.fadeCur[2] = 1
						end
					elseif effect.state ~= ShaderPlaneEffect.STATE_OFF and effect.state ~= ShaderPlaneEffect.STATE_TURNING_OFF then
						effect.state = ShaderPlaneEffect.STATE_TURNING_OFF
						effect.fadeDir = WeedSpotSpray.EFFECT_DIRECTION_STOP
					end
				end

				if effect.state == ShaderPlaneEffect.STATE_TURNING_OFF or effect.state == ShaderPlaneEffect.STATE_TURNING_ON then
					effect.fadeCur[1] = math.max(math.min(effect.fadeCur[1] + effect.fadeDir[1] * dt / (spec.effectFadeTime * fadeSpeedScale), 1), -1)
					effect.fadeCur[2] = math.max(math.min(effect.fadeCur[2] + effect.fadeDir[2] * dt / (spec.effectFadeTime * fadeSpeedScale), 1), -1)

					setShaderParameter(effect.node, "fadeProgress", effect.fadeCur[1], effect.fadeCur[2], 0, 0, false)

					if effect.state == ShaderPlaneEffect.STATE_TURNING_OFF then
						if effect.fadeCur[1] == 1 and effect.fadeCur[2] == -1 then
							effect.state = ShaderPlaneEffect.STATE_OFF
						end
					elseif effect.state == ShaderPlaneEffect.STATE_TURNING_ON and effect.fadeCur[1] == 1 and effect.fadeCur[2] == 1 then
						effect.state = ShaderPlaneEffect.STATE_ON
					end

					keepEffectsDirty = true
				end
			end
		end

		nozzleNode.lastIsActive = nozzleNode.isActive
	end

	if spec.effectsDirty and not keepEffectsDirty then
		spec.effectsDirty = false
	end
end
