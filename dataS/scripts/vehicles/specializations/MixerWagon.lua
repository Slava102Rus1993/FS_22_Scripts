source("dataS/scripts/vehicles/specializations/events/MixerWagonBaleNotAcceptedEvent.lua")

MixerWagon = {
	HUD_TRIGGER_I3D_FILENAME = "data/shared/mixerWagonHUDTrigger.i3d"
}

source("dataS/scripts/gui/hud/MixerWagonHUDExtension.lua")

function MixerWagon.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Trailer, specializations) and SpecializationUtil.hasSpecialization(TurnOnVehicle, specializations)
end

function MixerWagon.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("MixerWagon")
	AnimationManager.registerAnimationNodesXMLPaths(schema, "vehicle.mixerWagon.mixAnimationNodes")
	AnimationManager.registerAnimationNodesXMLPaths(schema, "vehicle.mixerWagon.pickupAnimationNodes")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.mixerWagon.baleTriggers.baleTrigger(?)#node", "Bale trigger node")
	schema:register(XMLValueType.FLOAT, "vehicle.mixerWagon.baleTriggers.baleTrigger(?)#pickupSpeed", "Bale pickup speed in liter per second", 500)
	schema:register(XMLValueType.BOOL, "vehicle.mixerWagon.baleTriggers.baleTrigger(?)#needsSetIsTurnedOn", "Vehicle needs to be turned on to pickup bales with this trigger", false)
	schema:register(XMLValueType.BOOL, "vehicle.mixerWagon.baleTriggers.baleTrigger(?)#useEffect", "Filling effect is played while picking up a bale", false)
	schema:register(XMLValueType.TIME, "vehicle.mixerWagon#mixingTime", "Mixing time after the fill level was changed", 5)
	schema:register(XMLValueType.INT, "vehicle.mixerWagon#fillUnitIndex", "Fill unit index", 1)
	schema:register(XMLValueType.STRING, "vehicle.mixerWagon#recipe", "Recipe fill type name", "Forage")
	EffectManager.registerEffectXMLPaths(schema, "vehicle.mixerWagon.fillEffect")
	schema:setXMLSpecializationType()

	local schemaSavegame = Vehicle.xmlSchemaSavegame

	schemaSavegame:register(XMLValueType.FLOAT, "vehicles.vehicle(?).mixerWagon.fillType(?)#fillLevel", "Fill level", 0)
end

function MixerWagon.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "mixerWagonBaleTriggerCallback", MixerWagon.mixerWagonBaleTriggerCallback)
	SpecializationUtil.registerFunction(vehicleType, "onHUDTriggerCallback", MixerWagon.onHUDTriggerCallback)
	SpecializationUtil.registerFunction(vehicleType, "getIsPlayerInTrigger", MixerWagon.getIsPlayerInTrigger)
end

function MixerWagon.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "addFillUnitFillLevel", MixerWagon.addFillUnitFillLevel)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFillUnitAllowsFillType", MixerWagon.getFillUnitAllowsFillType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDischargeFillType", MixerWagon.getDischargeFillType)
end

function MixerWagon.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", MixerWagon)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", MixerWagon)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", MixerWagon)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", MixerWagon)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", MixerWagon)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", MixerWagon)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", MixerWagon)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", MixerWagon)
	SpecializationUtil.registerEventListener(vehicleType, "onTurnedOn", MixerWagon)
	SpecializationUtil.registerEventListener(vehicleType, "onTurnedOff", MixerWagon)
	SpecializationUtil.registerEventListener(vehicleType, "onFillUnitFillLevelChanged", MixerWagon)
end

function MixerWagon:onLoad(savegame)
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.mixerWagonBaleTrigger#index", "vehicle.mixerWagon.baleTrigger#node")
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.mixerWagon.baleTrigger#index", "vehicle.mixerWagon.baleTrigger#node")
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.mixerWagonPickupStartSound", "vehicle.turnOnVehicle.sounds.start")
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.mixerWagonPickupStopSound", "vehicle.turnOnVehicle.sounds.stop")
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.mixerWagonPickupSound", "vehicle.turnOnVehicle.sounds.work")
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.mixerWagonRotatingParts.mixerWagonRotatingPart#type", "vehicle.mixerWagon.mixAnimationNodes.animationNode", "mixerWagonMix")
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.mixerWagonRotatingParts.mixerWagonRotatingPart#type", "vehicle.mixerWagon.pickupAnimationNodes.animationNode", "mixerWagonPickup")
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.mixerWagonRotatingParts.mixerWagonScroller", "vehicle.mixerWagon.pickupAnimationNodes.pickupAnimationNode")
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.mixerWagon.baleTrigger#node", "vehicle.mixerWagon.baleTriggers.baleTrigger#node")

	local spec = self.spec_mixerWagon

	if self.isClient then
		spec.mixAnimationNodes = g_animationManager:loadAnimations(self.xmlFile, "vehicle.mixerWagon.mixAnimationNodes", self.components, self, self.i3dMappings)
		spec.pickupAnimationNodes = g_animationManager:loadAnimations(self.xmlFile, "vehicle.mixerWagon.pickupAnimationNodes", self.components, self, self.i3dMappings)
		spec.fillEffects = g_effectManager:loadEffect(self.xmlFile, "vehicle.mixerWagon.fillEffect", self.components, self, self.i3dMappings)
		spec.fillEffectsFillType = FillType.UNKNOWN
		spec.fillEffectsState = false
	end

	if self.isServer then
		spec.baleTriggers = {}

		self.xmlFile:iterate("vehicle.mixerWagon.baleTriggers.baleTrigger", function (_, key)
			local baleTrigger = {
				node = self.xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings)
			}

			if baleTrigger.node ~= nil then
				addTrigger(baleTrigger.node, "mixerWagonBaleTriggerCallback", self)

				baleTrigger.pickupSpeed = self.xmlFile:getValue(key .. "#pickupSpeed", 500) / 1000
				baleTrigger.needsSetIsTurnedOn = self.xmlFile:getValue(key .. "#needsSetIsTurnedOn", false)
				baleTrigger.useEffect = self.xmlFile:getValue(key .. "#useEffect", false)
				baleTrigger.balesInTrigger = {}

				table.insert(spec.baleTriggers, baleTrigger)
			end
		end)
	end

	spec.activeTimerMax = self.xmlFile:getValue("vehicle.mixerWagon#mixingTime", 5)
	spec.activeTimer = 0
	spec.fillUnitIndex = self.xmlFile:getValue("vehicle.mixerWagon#fillUnitIndex", 1)
	local fillUnit = self:getFillUnitByIndex(spec.fillUnitIndex)

	if fillUnit ~= nil then
		fillUnit.needsSaving = false

		if fillUnit.supportedFillTypes[FillType.GRASS_WINDROW] then
			fillUnit.supportedFillTypes[FillType.GRASS_WINDROW] = nil
		end
	end

	fillUnit.synchronizeFillLevel = false
	spec.mixerWagonFillTypes = {}
	spec.fillTypeToMixerWagonFillType = {}
	local recipeFillTypeName = self.xmlFile:getValue("vehicle.mixerWagon#recipe", "")
	local recipeFillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(recipeFillTypeName)

	if recipeFillTypeIndex == nil then
		Logging.xmlError(self.xmlFile, "MixerWagon recipe '%s' not defined!", recipeFillTypeName)
	end

	local recipe = g_currentMission.animalFoodSystem:getRecipeByFillTypeIndex(recipeFillTypeIndex)

	if recipe == nil then
		Logging.xmlWarning(self.xmlFile, "MixerWagon recipe '%s' not defined!", recipeFillTypeName)
	end

	if recipe ~= nil then
		for _, ingredient in ipairs(recipe.ingredients) do
			local entry = {
				fillLevel = 0,
				fillTypes = {},
				name = ingredient.name,
				minPercentage = ingredient.minPercentage,
				maxPercentage = ingredient.maxPercentage,
				ratio = ingredient.ratio
			}

			for _, fillTypeIndex in ipairs(ingredient.fillTypes) do
				entry.fillTypes[fillTypeIndex] = true
				spec.fillTypeToMixerWagonFillType[fillTypeIndex] = entry
			end

			table.insert(spec.mixerWagonFillTypes, entry)
		end
	end

	local hudTriggerI3d, hudTriggerSharedLoadRequestId = g_i3DManager:loadSharedI3DFile(MixerWagon.HUD_TRIGGER_I3D_FILENAME, false, false)

	if hudTriggerI3d ~= 0 then
		spec.hudTrigger = getChildAt(hudTriggerI3d, 0)
		spec.hudTriggerSharedLoadRequestId = hudTriggerSharedLoadRequestId

		link(self.rootNode, spec.hudTrigger)
		addTrigger(spec.hudTrigger, "onHUDTriggerCallback", self)
		delete(hudTriggerI3d)

		spec.vehicleToNodeCount = {}
	end

	spec.dirtyFlag = self:getNextDirtyFlag()
	spec.effectDirtyFlag = self:getNextDirtyFlag()
end

function MixerWagon:onPostLoad(savegame)
	if savegame ~= nil then
		local spec = self.spec_mixerWagon

		for i, entry in ipairs(spec.mixerWagonFillTypes) do
			local fillTypeKey = savegame.key .. string.format(".mixerWagon.fillType(%d)#fillLevel", i - 1)
			local fillLevel = savegame.xmlFile:getValue(fillTypeKey, 0)

			if fillLevel > 0 then
				self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, fillLevel, next(entry.fillTypes), ToolType.UNDEFINED, nil)
			end
		end
	end
end

function MixerWagon:onDelete()
	local spec = self.spec_mixerWagon

	if spec.baleTriggers ~= nil then
		for i = 1, #spec.baleTriggers do
			removeTrigger(spec.baleTriggers[i].node)
		end
	end

	g_animationManager:deleteAnimations(spec.mixAnimationNodes)
	g_animationManager:deleteAnimations(spec.pickupAnimationNodes)
	g_effectManager:deleteEffects(spec.fillEffects)

	if spec.hudTrigger ~= nil then
		removeTrigger(spec.hudTrigger)
		g_i3DManager:releaseSharedI3DFile(spec.hudTriggerSharedLoadRequestId)
	end
end

function MixerWagon:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_mixerWagon

	for i, fillType in ipairs(spec.mixerWagonFillTypes) do
		local fillTypeKey = string.format("%s.fillType(%d)", key, i - 1)

		xmlFile:setValue(fillTypeKey .. "#fillLevel", fillType.fillLevel)
	end
end

function MixerWagon:onReadStream(streamId, connection)
	local spec = self.spec_mixerWagon

	for _, entry in ipairs(spec.mixerWagonFillTypes) do
		local fillLevel = streamReadFloat32(streamId)

		if fillLevel > 0 then
			self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, fillLevel, next(entry.fillTypes), ToolType.UNDEFINED, nil)
		end
	end

	spec.fillEffectsFillType = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
end

function MixerWagon:onWriteStream(streamId, connection)
	local spec = self.spec_mixerWagon

	for _, entry in ipairs(spec.mixerWagonFillTypes) do
		streamWriteFloat32(streamId, entry.fillLevel)
	end

	streamWriteUIntN(streamId, spec.fillEffectsFillType, FillTypeManager.SEND_NUM_BITS)
end

function MixerWagon:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		local spec = self.spec_mixerWagon

		if streamReadBool(streamId) then
			for _, entry in ipairs(spec.mixerWagonFillTypes) do
				local fillLevel = streamReadFloat32(streamId)
				local delta = fillLevel - entry.fillLevel

				if delta ~= 0 then
					self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, delta, next(entry.fillTypes), ToolType.UNDEFINED, nil)
				end
			end
		end

		if streamReadBool(streamId) then
			spec.fillEffectsFillType = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
		end
	end
end

function MixerWagon:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local spec = self.spec_mixerWagon

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
			for _, entry in ipairs(spec.mixerWagonFillTypes) do
				streamWriteFloat32(streamId, entry.fillLevel)
			end
		end

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.effectDirtyFlag) ~= 0) then
			streamWriteUIntN(streamId, spec.fillEffectsFillType, FillTypeManager.SEND_NUM_BITS)
		end
	end
end

function MixerWagon:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_mixerWagon
	local tipState = self:getTipState()
	local isTurnedOn = self:getIsTurnedOn()
	local isDischarging = tipState == Trailer.TIPSTATE_OPENING or tipState == Trailer.TIPSTATE_OPEN

	if self:getIsPowered() and (spec.activeTimer > 0 or isTurnedOn or isDischarging) then
		spec.activeTimer = spec.activeTimer - dt

		g_animationManager:startAnimations(spec.mixAnimationNodes)
	else
		g_animationManager:stopAnimations(spec.mixAnimationNodes)
	end

	if self.isServer then
		local fillEffectsFillType = FillType.UNKNOWN

		if self:getFillUnitFreeCapacity(spec.fillUnitIndex) > 0 then
			for i = 1, #spec.baleTriggers do
				local baleTrigger = spec.baleTriggers[i]

				if not baleTrigger.needsSetIsTurnedOn or self:getIsTurnedOn() then
					for bale, _ in pairs(baleTrigger.balesInTrigger) do
						local baleFillLevel = bale:getFillLevel()
						local deltaFillLevel = math.min(baleTrigger.pickupSpeed * dt, baleFillLevel)
						local fillType = bale:getFillType()
						deltaFillLevel = self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, deltaFillLevel, fillType, ToolType.BALE, nil)
						baleFillLevel = baleFillLevel - deltaFillLevel

						bale:setFillLevel(baleFillLevel)

						if baleFillLevel < 0.01 then
							bale:delete()

							baleTrigger.balesInTrigger[bale] = nil
						end

						if baleTrigger.useEffect then
							fillEffectsFillType = fillType
						end
					end
				end
			end
		end

		if fillEffectsFillType == FillType.UNKNOWN and self.getIsShovelEffectState ~= nil then
			local state, fillType = self:getIsShovelEffectState()

			if state then
				fillEffectsFillType = fillType
			end
		end

		if spec.fillEffectsFillType ~= fillEffectsFillType then
			spec.fillEffectsFillType = fillEffectsFillType

			self:raiseDirtyFlags(spec.effectDirtyFlag)
		end
	end

	if self.isClient then
		local state = spec.fillEffectsFillType ~= FillType.UNKNOWN

		if state ~= spec.fillEffectsState then
			if state then
				g_effectManager:setFillType(spec.fillEffects, spec.fillEffectsFillType)
				g_effectManager:startEffects(spec.fillEffects)
			else
				g_effectManager:stopEffects(spec.fillEffects)
			end

			spec.fillEffectsState = state
		end
	end
end

function MixerWagon:mixerWagonBaleTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if otherActorId ~= 0 then
		local bale = g_currentMission:getNodeObject(otherActorId)

		if bale ~= nil and bale:isa(Bale) then
			local spec = self.spec_mixerWagon

			if self:getFillUnitSupportsFillType(spec.fillUnitIndex, bale:getFillType()) then
				for i = 1, #spec.baleTriggers do
					local baleTrigger = spec.baleTriggers[i]

					if baleTrigger.node == triggerId then
						if onEnter then
							baleTrigger.balesInTrigger[bale] = (baleTrigger.balesInTrigger[bale] or 0) + 1
						elseif onLeave then
							baleTrigger.balesInTrigger[bale] = (baleTrigger.balesInTrigger[bale] or 1) - 1

							if baleTrigger.balesInTrigger[bale] == 0 then
								baleTrigger.balesInTrigger[bale] = nil
							end
						end
					end
				end
			elseif onEnter and otherActorId == bale.nodeId then
				g_currentMission:broadcastEventToFarm(MixerWagonBaleNotAcceptedEvent.new(), self:getOwnerFarmId(), true)
			end
		end
	end
end

function MixerWagon:addFillUnitFillLevel(superFunc, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData)
	local spec = self.spec_mixerWagon

	if fillUnitIndex ~= spec.fillUnitIndex then
		return superFunc(self, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData)
	end

	local oldFillLevel = self:getFillUnitFillLevel(fillUnitIndex)
	local mixerWagonFillType = spec.fillTypeToMixerWagonFillType[fillTypeIndex]

	if fillTypeIndex == FillType.FORAGE and fillLevelDelta > 0 then
		for _, entry in pairs(spec.mixerWagonFillTypes) do
			local delta = fillLevelDelta * entry.ratio

			self:addFillUnitFillLevel(farmId, fillUnitIndex, delta, next(entry.fillTypes), toolType, fillPositionData)
		end

		return fillLevelDelta
	end

	if mixerWagonFillType == nil then
		if fillLevelDelta < 0 and oldFillLevel > 0 then
			fillLevelDelta = math.max(fillLevelDelta, -oldFillLevel)
			local newFillLevel = 0

			for _, entry in pairs(spec.mixerWagonFillTypes) do
				local entryDelta = fillLevelDelta * entry.fillLevel / oldFillLevel
				entry.fillLevel = math.max(entry.fillLevel + entryDelta, 0)
				newFillLevel = newFillLevel + entry.fillLevel
			end

			if newFillLevel < 0.1 then
				for _, entry in pairs(spec.mixerWagonFillTypes) do
					entry.fillLevel = 0
				end

				fillLevelDelta = -oldFillLevel
			end

			self:raiseDirtyFlags(spec.dirtyFlag)

			local ret = superFunc(self, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData)

			return ret
		end

		return 0
	end

	local capacity = self:getFillUnitCapacity(fillUnitIndex)
	local free = capacity - oldFillLevel

	if fillLevelDelta > 0 then
		mixerWagonFillType.fillLevel = mixerWagonFillType.fillLevel + math.min(free, fillLevelDelta)

		if self:getIsSynchronized() then
			spec.activeTimer = spec.activeTimerMax
		end
	else
		mixerWagonFillType.fillLevel = math.max(0, mixerWagonFillType.fillLevel + fillLevelDelta)
	end

	local newFillLevel = 0

	for _, fillType in pairs(spec.mixerWagonFillTypes) do
		newFillLevel = newFillLevel + fillType.fillLevel
	end

	newFillLevel = MathUtil.clamp(newFillLevel, 0, self:getFillUnitCapacity(fillUnitIndex))
	local newFillType = FillType.UNKNOWN
	local isSingleFilled = false
	local isForageOk = false

	for _, fillType in pairs(spec.mixerWagonFillTypes) do
		if newFillLevel == fillType.fillLevel then
			isSingleFilled = true
			newFillType = next(mixerWagonFillType.fillTypes)

			break
		end
	end

	if not isSingleFilled then
		isForageOk = true

		for _, fillType in pairs(spec.mixerWagonFillTypes) do
			if fillType.fillLevel < fillType.minPercentage * newFillLevel - 0.01 or fillType.fillLevel > fillType.maxPercentage * newFillLevel + 0.01 then
				isForageOk = false

				break
			end
		end
	end

	if isForageOk then
		newFillType = FillType.FORAGE
	elseif not isSingleFilled then
		newFillType = FillType.FORAGE_MIXING
	end

	self:raiseDirtyFlags(spec.dirtyFlag)
	self:setFillUnitFillType(fillUnitIndex, newFillType)

	return superFunc(self, farmId, fillUnitIndex, newFillLevel - oldFillLevel, newFillType, toolType, fillPositionData)
end

function MixerWagon:getFillUnitAllowsFillType(superFunc, fillUnitIndex, fillTypeIndex)
	local spec = self.spec_mixerWagon

	if spec.fillUnitIndex == fillUnitIndex then
		local mixerWagonFillType = spec.fillTypeToMixerWagonFillType[fillTypeIndex]

		if mixerWagonFillType ~= nil then
			return true
		end
	end

	return superFunc(self, fillUnitIndex, fillTypeIndex)
end

function MixerWagon:getDischargeFillType(superFunc, dischargeNode)
	local spec = self.spec_mixerWagon
	local fillUnitIndex = dischargeNode.fillUnitIndex

	if fillUnitIndex == spec.fillUnitIndex then
		local currentFillType = self:getFillUnitFillType(fillUnitIndex)
		local fillLevel = self:getFillUnitFillLevel(fillUnitIndex)

		if currentFillType == FillType.FORAGE_MIXING and fillLevel > 0 then
			for _, entry in pairs(spec.mixerWagonFillTypes) do
				if entry.fillLevel > 0 then
					currentFillType = next(entry.fillTypes)

					break
				end
			end
		end

		return currentFillType, 1
	end

	return superFunc(self, dischargeNode)
end

function MixerWagon:onFillUnitFillLevelChanged(fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, appliedDelta)
	local spec = self.spec_mixerWagon

	if spec.fillUnitIndex == fillUnitIndex then
		local fillLevel = self:getFillUnitFillLevel(fillUnitIndex)

		if fillLevel == 0 then
			for _, entry in pairs(spec.mixerWagonFillTypes) do
				entry.fillLevel = 0
			end
		end
	end
end

function MixerWagon:onTurnedOn()
	if self.isClient then
		local spec = self.spec_mixerWagon

		g_animationManager:startAnimations(spec.pickupAnimationNodes)
	end
end

function MixerWagon:onTurnedOff()
	if self.isClient then
		local spec = self.spec_mixerWagon

		g_animationManager:stopAnimations(spec.pickupAnimationNodes)
	end
end

function MixerWagon:onHUDTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local object = g_currentMission.nodeToObject[otherActorId]

	if object ~= nil and object:isa(Vehicle) and not SpecializationUtil.hasSpecialization(Enterable, object.specializations) then
		return
	elseif g_currentMission.player ~= nil and otherActorId == g_currentMission.player.rootNode then
		object = g_currentMission.player.rootNode
	end

	if object ~= nil and object ~= self then
		local spec = self.spec_mixerWagon

		if onEnter then
			if not g_currentMission.accessHandler:canPlayerAccess(self) then
				return
			end

			spec.vehicleToNodeCount[object] = (spec.vehicleToNodeCount[object] or 0) + 1
		elseif onLeave then
			spec.vehicleToNodeCount[object] = (spec.vehicleToNodeCount[object] or 0) - 1
		end

		if spec.vehicleToNodeCount[object] == 1 then
			g_currentMission.hud.inputHelp:addExtraExtensionVehicleNodeId(self.rootNode)
		elseif spec.vehicleToNodeCount[object] <= 0 then
			g_currentMission.hud.inputHelp:removeExtraExtensionVehicleNodeId(self.rootNode)

			spec.vehicleToNodeCount[object] = nil
		end
	end
end

function MixerWagon:getIsPlayerInTrigger()
	local spec = self.spec_mixerWagon

	if g_currentMission.controlPlayer and g_currentMission.player ~= nil then
		return spec.vehicleToNodeCount[g_currentMission.player.rootNode] ~= nil
	elseif g_currentMission.controlledVehicle ~= nil then
		return spec.vehicleToNodeCount[g_currentMission.controlledVehicle] ~= nil
	end

	return false
end

function MixerWagon:updateDebugValues(values)
	local spec = self.spec_mixerWagon

	table.insert(values, {
		name = "Forage isOK",
		value = tostring(self:getFillUnitFillType(spec.fillUnitIndex) == FillType.FORAGE)
	})

	for _, mixerWagonFillType in ipairs(spec.mixerWagonFillTypes) do
		local fillTypes = ""

		for fillTypeIndex, _ in pairs(mixerWagonFillType.fillTypes) do
			fillTypes = fillTypes .. " " .. tostring(g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex))
		end

		table.insert(values, {
			name = fillTypes,
			value = mixerWagonFillType.fillLevel
		})
	end
end
