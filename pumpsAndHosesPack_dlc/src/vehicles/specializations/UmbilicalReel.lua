UmbilicalReel = {
	MAX_AMOUNT_OF_REELS = 4,
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	WIND_DIRECTION = 1,
	UNWIND_DIRECTION = -1,
	CONFIG_NAME_REEL = "umbilicalReel",
	WARNING_ATTACH_UMBILICAL_HOSE = "warning_attachUmbilical",
	WARNING_DETACH_UMBILICAL_HOSE = "warning_detachUmbilicalHose",
	WARNING_NOT_ENOUGH_CAPACITY_LEFT = "info_reelNotEnoughCapacityLeft",
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(UmbilicalHoseConnector, specializations)
	end
}

function UmbilicalReel.initSpecialization()
	g_configurationManager:addConfigurationType(UmbilicalReel.CONFIG_NAME_REEL, g_i18n:getText("configuration_reel"), nil, , , , ConfigurationUtil.SELECTOR_MULTIOPTION)

	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("Reel")
	ObjectChangeUtil.registerObjectChangeXMLPaths(schema, "vehicle.umbilicalReelConfigurations.umbilicalReelConfiguration(?)")
	UmbilicalReel.registerReelXMLPaths(schema, "vehicle.umbilicalReelConfigurations.umbilicalReelConfiguration(?).reels.reel(?)")
	UmbilicalReel.registerReelXMLPaths(schema, "vehicle.reels.reel(?)")
	schema:setXMLSpecializationType()

	local schemaSavegame = Vehicle.xmlSchemaSavegame
	local modName = g_manureModName

	schemaSavegame:register(XMLValueType.INT, ("vehicles.vehicle(?).%s.umbilicalReel#reelDirection"):format(modName), "Direction of reeling")
	schemaSavegame:register(XMLValueType.INT, ("vehicles.vehicle(?).%s.umbilicalReel.reels.reel(?)#id"):format(modName), "Id of the reel")
	schemaSavegame:register(XMLValueType.INT, ("vehicles.vehicle(?).%s.umbilicalReel.reels.reel(?).hose(?)#type"):format(modName), "The hose type of the reel")
	schemaSavegame:register(XMLValueType.FLOAT, ("vehicles.vehicle(?).%s.umbilicalReel.reels.reel(?).hose(?)#length"):format(modName), "The hose length on the reel")
	schemaSavegame:register(XMLValueType.FLOAT, ("vehicles.vehicle(?).%s.umbilicalReel.reels.reel(?).hose(?)#capacity"):format(modName), "The hose capacity on the reel")
	schemaSavegame:register(XMLValueType.COLOR, ("vehicles.vehicle(?).%s.umbilicalReel.reels.reel(?).hose(?)#color"):format(modName), "Hose color", "0.05 0.05 0.05 0")
	schemaSavegame:register(XMLValueType.FLOAT, ("vehicles.vehicle(?).%s.umbilicalReel.reels.reel(?).hose(?)#damage"):format(modName), "The hose damage")
	schemaSavegame:register(XMLValueType.BOOL, ("vehicles.vehicle(?).%s.umbilicalReel.reels.reel(?)#hasUmbilicalHose"):format(modName), "Has umbilical hose attached")
end

function UmbilicalReel.registerReelXMLPaths(schema, baseName)
	schema:register(XMLValueType.NODE_INDEX, baseName .. "#linkNode", "Link node")
	schema:register(XMLValueType.NODE_INDEX, baseName .. "#drumNode", "Drum node")
	schema:register(XMLValueType.INT, baseName .. "#capacity", "Capacity of the reel")
	schema:register(XMLValueType.BOOL, baseName .. "#hasHose", "Has initial hose on the reel")
	schema:register(XMLValueType.BOOL, baseName .. "#hasGuide", "Has a guide hose")
	schema:register(XMLValueType.BOOL, baseName .. "#folds", "If reel can fold")
	schema:register(XMLValueType.FLOAT, baseName .. ".hose#endOffset", "End hose offset", "0")
	schema:register(XMLValueType.VECTOR_3, baseName .. ".hose#offset", "Offset of the hose", "0 0 0")
	schema:register(XMLValueType.COLOR, baseName .. ".hose#color", "Color of the hose", "0.05 0.05 0.05 0")
	schema:register(XMLValueType.INT, baseName .. ".hose#coils", "Amount of round trips the hose should make")
	schema:register(XMLValueType.FLOAT, baseName .. ".hose#shift", "Shift amount of the hose")
	schema:register(XMLValueType.FLOAT, baseName .. ".hose#innerDiameter", "The inner diameter of those")
	schema:register(XMLValueType.FLOAT, baseName .. "#drumDiameter", "The diameter of the drum")
	schema:register(XMLValueType.INT, baseName .. "#connectorIndex", "The connector index to use for the reel")
end

function UmbilicalReel.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "setIsReelActive", UmbilicalReel.setIsReelActive)
	SpecializationUtil.registerFunction(vehicleType, "getCurrentReel", UmbilicalReel.getCurrentReel)
	SpecializationUtil.registerFunction(vehicleType, "getInteractiveReel", UmbilicalReel.getInteractiveReel)
	SpecializationUtil.registerFunction(vehicleType, "isCurrentReelActive", UmbilicalReel.isCurrentReelActive)
	SpecializationUtil.registerFunction(vehicleType, "isReelActive", UmbilicalReel.isReelActive)
	SpecializationUtil.registerFunction(vehicleType, "guardReelActiveState", UmbilicalReel.guardReelActiveState)
	SpecializationUtil.registerFunction(vehicleType, "setReelDirection", UmbilicalReel.setReelDirection)
	SpecializationUtil.registerFunction(vehicleType, "canOperateReel", UmbilicalReel.canOperateReel)
	SpecializationUtil.registerFunction(vehicleType, "addReelLength", UmbilicalReel.addReelLength)
	SpecializationUtil.registerFunction(vehicleType, "addReelHose", UmbilicalReel.addReelHose)
	SpecializationUtil.registerFunction(vehicleType, "removeReelHose", UmbilicalReel.removeReelHose)
	SpecializationUtil.registerFunction(vehicleType, "getReelDirection", UmbilicalReel.getReelDirection)
	SpecializationUtil.registerFunction(vehicleType, "isReelWinding", UmbilicalReel.isReelWinding)
	SpecializationUtil.registerFunction(vehicleType, "createUmbilicalHose", UmbilicalReel.createUmbilicalHose)
	SpecializationUtil.registerFunction(vehicleType, "finishUmbilicalHose", UmbilicalReel.finishUmbilicalHose)
	SpecializationUtil.registerFunction(vehicleType, "deleteUmbilicalHose", UmbilicalReel.deleteUmbilicalHose)
end

function UmbilicalReel.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onAttachUmbilicalHose", UmbilicalReel)
	SpecializationUtil.registerEventListener(vehicleType, "onDetachUmbilicalHose", UmbilicalReel)
end

function UmbilicalReel.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFillLevelInformation", UmbilicalReel.getFillLevelInformation)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAttachNode", UmbilicalReel.getAttachNode)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getTargetNode", UmbilicalReel.getTargetNode)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getTargetOffsetFactor", UmbilicalReel.getTargetOffsetFactor)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "canFindUmbilicalHose", UmbilicalReel.canFindUmbilicalHose)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "canUpdateUmbilicalHose", UmbilicalReel.canUpdateUmbilicalHose)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "needsUmbilicalHoseForceUpdate", UmbilicalReel.needsUmbilicalHoseForceUpdate)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "isDetachUmbilicalHoseAllowed", UmbilicalReel.isDetachUmbilicalHoseAllowed)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "doCheckSpeedLimit", UmbilicalReel.doCheckSpeedLimit)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getUseTurnedOnSchema", UmbilicalReel.getUseTurnedOnSchema)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAdditionalComponentMass", UmbilicalReel.getAdditionalComponentMass)
end

function UmbilicalReel:onLoad()
	self.spec_umbilicalReel = self[("spec_%s.umbilicalReel"):format(UmbilicalReel.MOD_NAME)]
	local spec = self.spec_umbilicalReel
	spec.reels = {}
	spec.activeReelId = 1
	spec.reelDirection = UmbilicalReel.WIND_DIRECTION
	spec.reelMetersPerSecond = 5
	local configurationId = Utils.getNoNil(self.configurations.umbilicalReel, 1)
	local baseKey = ("vehicle.umbilicalReelConfigurations.umbilicalReelConfiguration(%d)"):format(configurationId - 1)

	ObjectChangeUtil.updateObjectChanges(self.xmlFile, "vehicle.umbilicalReelConfigurations.umbilicalReelConfiguration", configurationId, self.components, self)

	if not self.xmlFile:hasProperty(baseKey) then
		baseKey = "vehicle"
	end

	self.xmlFile:iterate(baseKey .. ".reels.reel", function (id, key)
		local reel = UmbilicalReelDrum.new(id, self.isClient, self.isServer)

		if reel:loadFromXML(self.xmlFile, key, self.components, self.i3dMappings) then
			table.insert(spec.reels, reel)

			if reel.hasInitialHose then
				local color = {
					HoseBase.COLOR_DEFAULT_RED,
					HoseBase.COLOR_DEFAULT_GREEN,
					HoseBase.COLOR_DEFAULT_BLUE
				}

				if self.configurations.baseColor ~= nil then
					color = ConfigurationUtil.getColorByConfigId(self, "baseColor", self.configurations.baseColor)
				end

				self:addReelHose(reel.id, reel.capacity, color, true)
			end
		else
			reel:delete()
		end
	end)

	spec.dirtyFlag = self:getNextDirtyFlag()
	spec.umbilicalHoseToLoad = nil

	if #spec.reels == 0 then
		SpecializationUtil.removeEventListener(self, "onReadStream", UmbilicalReel)
		SpecializationUtil.removeEventListener(self, "onWriteStream", UmbilicalReel)
		SpecializationUtil.removeEventListener(self, "onReadUpdateStream", UmbilicalReel)
		SpecializationUtil.removeEventListener(self, "onWriteUpdateStream", UmbilicalReel)
		SpecializationUtil.removeEventListener(self, "onPostLoad", UmbilicalReel)
		SpecializationUtil.removeEventListener(self, "onUpdate", UmbilicalReel)
		SpecializationUtil.removeEventListener(self, "onUpdateTick", UmbilicalReel)
		SpecializationUtil.removeEventListener(self, "onRegisterActionEvents", UmbilicalReel)
	end
end

function UmbilicalReel:onLoadFinished(savegame)
	local spec = self.spec_umbilicalReel

	for _, reel in ipairs(spec.reels) do
		self:registerConnectorNode(reel.guideNode, reel.connectorIndex)
	end

	if savegame ~= nil and not savegame.resetVehicles then
		local key = ("%s.%s.umbilicalReel"):format(savegame.key, self:manure_getModName())
		local reelDirection = savegame.xmlFile:getValue(key .. "#reelDirection", self:getReelDirection())

		self:setReelDirection(reelDirection, true)

		local i = 0

		while true do
			local reelKey = ("%s.reels.reel(%d)"):format(key, i)

			if not savegame.xmlFile:hasProperty(reelKey) then
				break
			end

			local id = savegame.xmlFile:getValue(reelKey .. "#id")
			local reel = spec.reels[id]

			if reel ~= nil then
				reel:loadFromSavegameXMLFile(savegame.xmlFile, reelKey)

				local hasUmbilicalHose = savegame.xmlFile:getValue(reelKey .. "#hasUmbilicalHose", false)

				if hasUmbilicalHose and reel:getAmountOfHoses() > 0 then
					UmbilicalReel.setReelActiveState(self, id, true, false)

					spec.activeHose = reel:arrogateHose()
				end
			end

			i = i + 1
		end
	end
end

function UmbilicalReel:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_umbilicalReel

	if self.isServer and self.resetReelOverload ~= nil then
		self:resetReelOverload()
	end

	if #spec.reels ~= 0 then
		xmlFile:setValue(key .. "#reelDirection", self:getReelDirection())

		for i, reel in ipairs(spec.reels) do
			local reelKey = ("%s.reels.reel(%d)"):format(key, i - 1)

			reel:saveToXMLFile(xmlFile, reelKey, usedModNames)
			xmlFile:setValue(reelKey .. "#hasUmbilicalHose", self:hasUmbilicalHose(reel.connectorIndex))
		end
	end
end

function UmbilicalReel:onDelete()
	local spec = self.spec_umbilicalReel

	for _, reel in ipairs(spec.reels) do
		reel:delete()
	end
end

function UmbilicalReel:onReadStream(streamId, connection)
	if connection:getIsServer() then
		local spec = self.spec_umbilicalReel
		local isWinding = streamReadBool(streamId)
		local reelDirection = isWinding and UmbilicalReel.WIND_DIRECTION or UmbilicalReel.UNWIND_DIRECTION

		self:setReelDirection(reelDirection, true)

		for _, reel in ipairs(spec.reels) do
			reel:deleteHoses()

			local amountOfHoses = streamReadInt8(streamId)

			if amountOfHoses > 0 then
				for _ = 1, amountOfHoses do
					local length = streamReadFloat32(streamId)
					local color = NetworkHelper.readCompressedLinearColor(streamId)

					self:addReelHose(reel.id, length, color, true)
				end
			end
		end
	end
end

function UmbilicalReel:onWriteStream(streamId, connection)
	if not connection:getIsServer() then
		local spec = self.spec_umbilicalReel

		streamWriteBool(streamId, self:isReelWinding())

		for _, reel in ipairs(spec.reels) do
			local amountOfHoses = reel:getAmountOfHoses()

			streamWriteInt8(streamId, amountOfHoses)

			if amountOfHoses > 0 then
				for _, hose in ipairs(reel:getHoses()) do
					streamWriteFloat32(streamId, hose.lengthSent)
					NetworkHelper.writeCompressedLinearColor(streamId, hose.color)
				end
			end
		end
	end
end

function UmbilicalReel:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		local spec = self.spec_umbilicalReel

		if streamReadBool(streamId) then
			local hasHose = streamReadBool(streamId)

			if hasHose then
				local reel = self:getCurrentReel()
				local length = streamReadFloat32(streamId)
				local hose = reel:arrogateHose()

				if hose ~= nil and length ~= hose.length then
					self:addReelLength(reel.id, length - hose.length, self:getReelDirection())
				end
			end
		end
	end
end

function UmbilicalReel:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local spec = self.spec_umbilicalReel

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
			local reel = self:getCurrentReel()
			local hose = reel:arrogateHose()

			streamWriteBool(streamId, hose ~= nil)

			if hose ~= nil then
				streamWriteFloat32(streamId, hose.lengthSent)
			end
		end
	end
end

function UmbilicalReel:onUpdate(dt)
	local spec = self.spec_umbilicalReel

	if self.isClient then
		if spec.umbilicalHoseToLoad ~= nil then
			local umbilicalHose = NetworkUtil.getObject(spec.umbilicalHoseToLoad.objectId)

			if umbilicalHose ~= nil then
				self:finishUmbilicalHose(spec.umbilicalHoseToLoad.reelId, umbilicalHose)

				spec.umbilicalHoseToLoad = nil
			end
		end

		local reel = self:getCurrentReel()

		if not self:isReelWinding() and reel.isActive and self:hasUmbilicalHose(reel.connectorIndex) and self:getLastSpeed(true) <= 0.5 and self:getIsActiveForInput(true) and self:getIsOperating() then
			g_currentMission:showBlinkingWarning(g_i18n:getText("info_reelMoveForUnwinding"), 1000)
		end

		local actionEventOverload = spec.actionEvents[InputAction.PM_TOGGLE_REEL_STATE]

		if actionEventOverload ~= nil then
			local canShow = self:canOperateReel()

			g_inputBinding:setActionEventTextVisibility(actionEventOverload.actionEventId, canShow)
		end
	end
end

function UmbilicalReel:onUpdateTick(dt)
	local spec = self.spec_umbilicalReel

	if not self.finishedFirstUpdate then
		return
	end

	local reel = self:getCurrentReel()

	if reel ~= nil and self:isReelActive(reel) then
		local hasUmbilicalHose = self:hasUmbilicalHose(reel.connectorIndex)
		local inViolation, disableReel = self:guardReelActiveState(reel, hasUmbilicalHose)

		if inViolation then
			if disableReel then
				self:setIsReelActive(reel.id, false)
			end

			return
		end

		local isUnwinding = spec.reelDirection == UmbilicalReel.UNWIND_DIRECTION
		local movedLength = UmbilicalReel.getLastMovedDistance(self, dt, reel, hasUmbilicalHose)

		if self.isServer then
			self:addReelLength(reel.id, movedLength, spec.reelDirection)
		end

		if isUnwinding then
			if self.isServer and not hasUmbilicalHose then
				local umbilicalHose = self:createUmbilicalHose(reel.id)

				if umbilicalHose ~= nil then
					g_server:broadcastEvent(UmbilicalHoseCreateEvent.new(self, reel.id, NetworkUtil.getObjectId(umbilicalHose), nil, , self))
				else
					Logging.error("Failed to create umbilicalHose!")
				end
			end

			local umbilicalHose = self:getUmbilicalHose(reel.connectorIndex)

			if self.isServer then
				umbilicalHose:setIsFinalized(false)
				umbilicalHose:addLength(-movedLength)

				if umbilicalHose:getLength() <= spec.activeHose:getCapacity() then
					umbilicalHose:resolveControlPoints(reel.linkNode, true)
				end
			end

			if self:hasUmbilicalHoseGuide(reel.connectorIndex) then
				local point = self:getUmbilicalHoseConnectPoint(reel.connectorIndex, false)
				local guide = self:getUmbilicalHoseGuide(reel.connectorIndex)
				local length = umbilicalHose:getLastPointLength()

				if umbilicalHose:hasOnePoint() then
					-- Nothing
				end

				guide:setEndNode(point.invertNode)
			end
		elseif hasUmbilicalHose then
			local umbilicalHose = self:getUmbilicalHose(reel.connectorIndex)

			if self.isServer then
				umbilicalHose:setIsFinalized(false)
				umbilicalHose:addLength(-movedLength)
				umbilicalHose:resolveControlPoints(reel.linkNode, false)
			end

			if not umbilicalHose:hasLengthLeft() or spec.activeHose:isFull() then
				if self.isServer then
					self:deleteUmbilicalHose(reel.id)
				end
			else
				local length = umbilicalHose:getLastPointLength()
				local guide = self:getUmbilicalHoseGuide(reel.connectorIndex)
				local pointLast = self:getUmbilicalHoseConnectPoint(reel.connectorIndex, false)

				pointLast:setHoseState(not umbilicalHose:isInTailMode() and not umbilicalHose:hasOnePoint())

				if pointLast.hose ~= nil then
					-- Nothing
				end

				guide:setEndNode(pointLast.invertNode)
			end
		end
	end
end

function UmbilicalReel:addReelLength(reelId, length, direction, force)
	force = force or false
	local spec = self.spec_umbilicalReel
	local reel = spec.reels[reelId]
	local hose = reel:arrogateHose()

	reel:addLength(hose, length, direction)

	if self.isServer and (hose.length ~= reel.lengthSent or force) then
		hose.lengthSent = hose.length

		self:raiseDirtyFlags(spec.dirtyFlag)
	end

	self:setMassDirty()
end

function UmbilicalReel:addReelHose(reelId, length, color, noEventSend)
	local spec = self.spec_umbilicalReel
	local reel = spec.reels[reelId]

	UmbilicalReelLengthEvent.sendEvent(self, reelId, false, noEventSend, length, color)

	local hose = reel:allocateHose(length, length)

	if self.isClient then
		reel:setColor(color)
	end

	if self.isServer then
		hose.lengthSent = length
	end

	self:setMassDirty()

	return hose
end

function UmbilicalReel:removeReelHose(reelId, noEventSend)
	local reel = self.spec_umbilicalReel.reels[reelId]

	UmbilicalReelLengthEvent.sendEvent(self, reelId, true, noEventSend)
	self:setMassDirty()

	return reel:discardHose()
end

function UmbilicalReel:getLastMovedDistance(dt, reel, hasUmbilicalHose)
	local spec = self.spec_umbilicalReel
	local reelDirection = spec.reelDirection
	local isUnwinding = reelDirection == UmbilicalReel.UNWIND_DIRECTION

	if not isUnwinding then
		if hasUmbilicalHose then
			local umbilicalHose = self:getUmbilicalHose(reel.connectorIndex)
			local umbilicalHoseDamageFactor = math.max(1 - umbilicalHose:getDamageAmount(), 0.1)
			local metersPerSecond = g_currentMission.manure.isDebug and spec.reelMetersPerSecond * 3 or spec.reelMetersPerSecond

			return UmbilicalReel.WIND_DIRECTION * metersPerSecond * umbilicalHoseDamageFactor * dt * 0.001
		end

		return 0
	end

	local lastMovedDistance = self.lastMovedDistance * 2

	return reelDirection * math.abs(lastMovedDistance)
end

function UmbilicalReel:guardReelActiveState(reel, hasUmbilicalHose)
	local spec = self.spec_umbilicalReel

	if spec.activeHose == nil then
		return true, true
	end

	local isWinding = spec.reelDirection == UmbilicalReel.WIND_DIRECTION

	if isWinding and (spec.activeHose:isFull() or reel:isFull() or not hasUmbilicalHose) then
		return true, true
	end

	local isUnwinding = spec.reelDirection == UmbilicalReel.UNWIND_DIRECTION

	if isUnwinding and (spec.activeHose:isEmpty() or reel:isEmpty()) then
		if hasUmbilicalHose then
			local umbilicalHose = self:getUmbilicalHose(reel.connectorIndex)

			umbilicalHose:setIsFinalized(true)
			self:detachUmbilicalHose(reel.connectorIndex)
		end

		return true, true
	end

	if isUnwinding and hasUmbilicalHose then
		if self:getLastSpeed() <= 0.5 then
			return true, false
		end

		local umbilicalHose = self:getUmbilicalHose(reel.connectorIndex)

		if umbilicalHose:hasConnectionOnBothEnds() then
			return true, true
		end
	end

	return false, false
end

function UmbilicalReel:canOperateReel()
	local reel = self:getInteractiveReel()

	if reel == nil then
		return false
	end

	local umbilicalHose = self:getUmbilicalHose(reel.connectorIndex)
	local hasUmbilicalHose = umbilicalHose ~= nil

	if self:isReelWinding() then
		if not hasUmbilicalHose then
			return false
		end

		if reel.isActive or reel:isFull() then
			return false
		end

		if reel:getFreeCapacity() < umbilicalHose:getLength() then
			return false
		end

		return not umbilicalHose:hasConnectionOnBothEnds()
	end

	return not hasUmbilicalHose and not reel:isEmpty()
end

function UmbilicalReel:setIsReelActive(reelId, isActive, force, noEventSend)
	force = force or false
	local spec = self.spec_umbilicalReel
	local reel = spec.reels[reelId]

	if isActive ~= reel.isActive or force then
		UmbilicalReelActiveEvent.sendEvent(self, reelId, isActive, force, noEventSend)
		UmbilicalReel.setReelActiveState(self, reelId, isActive, true)

		if isActive then
			local umbilicalHose = self:getUmbilicalHose(reel.connectorIndex)
			spec.activeHose = UmbilicalReel.getReelHose(self, reel, umbilicalHose, true, self:getReelDirection())
		else
			spec.activeHose = nil
		end
	end
end

function UmbilicalReel:setReelActiveState(reelId, isActive, deleteHose)
	local spec = self.spec_umbilicalReel
	local reel = spec.reels[reelId]
	local previousReel = spec.reels[spec.activeReelId]

	previousReel:setIsActive(false, deleteHose)

	spec.activeReelId = reelId

	reel:setIsActive(isActive, deleteHose)
end

function UmbilicalReel:getReelHose(reel, sourceHose, allocateCapacity, windDirection)
	allocateCapacity = allocateCapacity or false

	if windDirection == UmbilicalReel.WIND_DIRECTION then
		local hose = reel:allocateHose(allocateCapacity and sourceHose:getLength() or nil)

		if self.isClient then
			reel:setColor(sourceHose:getColor())
		end

		hose:setDamageAmount(sourceHose:getDamageAmount())

		return hose
	end

	return reel:arrogateHose()
end

function UmbilicalReel:getCurrentReel()
	local spec = self.spec_umbilicalReel

	return spec.reels[spec.activeReelId]
end

function UmbilicalReel:getInteractiveReel()
	local spec = self.spec_umbilicalReel

	if #spec.reels == 0 then
		return nil
	end

	local high = 2
	local medium = 1
	local low = 0
	local reels = {}

	for i = 1, #spec.reels do
		local reel = spec.reels[i]
		local priority = low

		if reel.folds and self.getFoldAnimTime ~= nil and self:getFoldAnimTime() > 0 then
			priority = medium
		end

		if reel.isActive then
			priority = high
		end

		table.insert(reels, {
			priority = priority,
			reel = reel
		})
	end

	table.sort(reels, function (a, b)
		return b.reel.id < a.reel.id and b.priority < a.priority
	end)

	return table.first(reels).reel
end

function UmbilicalReel:isCurrentReelActive()
	local reel = self:getCurrentReel()

	if reel == nil then
		return false
	end

	return self:isReelActive(reel)
end

function UmbilicalReel:isReelActive(reel)
	return reel.isActive
end

function UmbilicalReel:isReelWinding()
	return self.spec_umbilicalReel.reelDirection == UmbilicalReel.WIND_DIRECTION
end

function UmbilicalReel:getReelDirection()
	return self.spec_umbilicalReel.reelDirection
end

function UmbilicalReel:setReelDirection(direction, noEventSend)
	local spec = self.spec_umbilicalReel

	if spec.reelDirection ~= direction then
		UmbilicalReelDirectionEvent.sendEvent(self, direction, noEventSend)

		spec.reelDirection = direction
		local isUnwinding = spec.reelDirection == UmbilicalReel.UNWIND_DIRECTION
		local actionEvent = spec.actionEvents[InputAction.PM_TOGGLE_REEL_DIRECTION]

		if actionEvent ~= nil then
			local directionTextKey = isUnwinding and "info_directionWinding" or "info_directionUnwinding"
			local directionText = g_i18n:getText(directionTextKey)

			g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("action_directionChange"):format(directionText))
		end

		local actionToggleEvent = spec.actionEvents[InputAction.PM_TOGGLE_REEL_STATE]

		if actionToggleEvent ~= nil then
			local directionTextKey = isUnwinding and "info_directionUnwinding" or "info_directionWinding"
			local directionText = g_i18n:getText(directionTextKey)

			g_inputBinding:setActionEventText(actionToggleEvent.actionEventId, g_i18n:getText("action_activateReel"):format(directionText))
		end
	end
end

function UmbilicalReel:onAttachUmbilicalHose(umbilicalHose, type, connectorId)
	local reel = self:getCurrentReel()

	if reel ~= nil and reel.connectorIndex == connectorId then
		reel:updateReelEndHose(false)
	end
end

function UmbilicalReel:onDetachUmbilicalHose(umbilicalHose, connectorId)
	local reel = self:getCurrentReel()

	if reel ~= nil and reel.connectorIndex == connectorId and not reel:isEmpty() then
		reel:updateReelEndHose(true)
	end
end

function UmbilicalReel:createUmbilicalHose(reelId, objectId)
	local spec = self.spec_umbilicalReel
	local umbilicalHose = nil

	if self.isServer then
		umbilicalHose = g_currentMission.manure:createUmbilicalHose()

		umbilicalHose:setOwnerFarmId(self:getOwnerFarmId(), true)
		umbilicalHose:register()
		self:finishUmbilicalHose(reelId, umbilicalHose)
	end

	if not self.isServer and objectId ~= nil then
		umbilicalHose = NetworkUtil.getObject(objectId)

		if umbilicalHose ~= nil then
			self:finishUmbilicalHose(reelId, umbilicalHose)
		else
			spec.umbilicalHoseToLoad = {
				reelId = reelId,
				objectId = objectId
			}
		end
	end

	return umbilicalHose
end

function UmbilicalReel:finishUmbilicalHose(reelId, umbilicalHose)
	local spec = self.spec_umbilicalReel
	local reel = spec.reels[reelId]

	if self.isServer then
		umbilicalHose:addControlPoint(reel.linkNode, false)
	end

	umbilicalHose:setCapacity(spec.activeHose:getCapacity())
	umbilicalHose:setColor(spec.activeHose:getColor())
	umbilicalHose:setDamageAmount(spec.activeHose:getDamageAmount())
	self:attachUmbilicalHose(umbilicalHose, reel.connectorIndex, UmbilicalHoseOrchestrator.TYPE_TAIL, true, true)
end

function UmbilicalReel:deleteUmbilicalHose(reelId)
	local spec = self.spec_umbilicalReel
	local reel = spec.reels[reelId]
	local deleteUmbilical = true

	self:detachUmbilicalHose(reel.connectorIndex, deleteUmbilical)
end

function UmbilicalReel:canFindUmbilicalHose()
	return not self:isCurrentReelActive()
end

function UmbilicalReel:canUpdateUmbilicalHose(superFunc)
	if self:isCurrentReelActive() then
		return self:isReelWinding()
	end

	return superFunc(self)
end

function UmbilicalReel:needsUmbilicalHoseForceUpdate(superFunc)
	if self:isCurrentReelActive() then
		return self:isReelWinding()
	end

	return superFunc(self)
end

function UmbilicalReel:isDetachUmbilicalHoseAllowed(superFunc)
	return not self:isCurrentReelActive() and superFunc(self)
end

function UmbilicalReel:getAttachNode(superFunc, connectorId)
	local reel = self:getInteractiveReel()

	if reel ~= nil and reel.connectorIndex == connectorId then
		return reel.guideNode
	end

	return superFunc(self, connectorId)
end

function UmbilicalReel:getTargetNode(superFunc, connectorId)
	local reel = self:getCurrentReel()

	if reel ~= nil and reel.connectorIndex == connectorId then
		return reel.guideTargetNode
	end

	return superFunc(self, connectorId)
end

function UmbilicalReel:getTargetOffsetFactor(superFunc)
	local reel = self:getCurrentReel()

	if reel ~= nil and reel.isActive then
		-- Nothing
	end

	return 0
end

function UmbilicalReel:doCheckSpeedLimit(superFunc)
	return superFunc(self) or self:isCurrentReelActive()
end

function UmbilicalReel:getUseTurnedOnSchema(superFunc)
	return superFunc(self) or self:isCurrentReelActive()
end

function UmbilicalReel:getFillLevelInformation(superFunc, display)
	local spec = self.spec_umbilicalReel
	local identity = {
		length = 0,
		capacity = 0
	}
	local info = table.reduce(spec.reels, identity, function (result, reel)
		return {
			length = result.length + reel:getLength(),
			capacity = result.capacity + reel:getCapacity()
		}
	end)

	display:addFillLevel(FillType.UMBILICAL_HOSE, info.length, info.capacity)
	superFunc(self, display)
end

function UmbilicalReel:getAdditionalComponentMass(superFunc, component)
	local additionalMass = superFunc(self, component)
	local spec = self.spec_umbilicalReel

	if component.node == self.components[1].node then
		local reelMass = table.reduce(spec.reels, 0, function (result, reel)
			return result + reel:getWeight()
		end)
		additionalMass = additionalMass + reelMass
	end

	return additionalMass
end

function UmbilicalReel:actionEventActiveReel(...)
	if self:canOperateReel() then
		local reel = self:getInteractiveReel()

		self:setIsReelActive(reel.id, not reel.isActive)
	else
		local warning = nil
		local reel = self:getInteractiveReel()
		local umbilicalHose = self:getUmbilicalHose(reel.connectorIndex)

		if self:isReelWinding() then
			if umbilicalHose == nil then
				warning = UmbilicalReel.WARNING_ATTACH_UMBILICAL_HOSE
			elseif reel:isFull() or reel:getFreeCapacity() < umbilicalHose:getLength() then
				warning = UmbilicalReel.WARNING_NOT_ENOUGH_CAPACITY_LEFT
			elseif umbilicalHose:hasConnectionOnBothEnds() then
				warning = UmbilicalReel.WARNING_DETACH_UMBILICAL_HOSE
			end
		elseif umbilicalHose ~= nil then
			warning = UmbilicalReel.WARNING_DETACH_UMBILICAL_HOSE
		elseif reel:isEmpty() then
			warning = UmbilicalReel.WARNING_NOT_ENOUGH_CAPACITY_LEFT
		end

		if warning ~= nil then
			g_currentMission:showBlinkingWarning(g_i18n:getText(warning))
		end
	end
end

function UmbilicalReel:actionEventToggleDirection(...)
	local spec = self.spec_umbilicalReel
	local reel = self:getInteractiveReel()
	local isWinding = self:isReelWinding()
	local umbilicalHose = self:getUmbilicalHose(reel.connectorIndex)

	if not isWinding and umbilicalHose ~= nil and (not umbilicalHose:hasControlPoints() or umbilicalHose:hasOnePoint()) then
		return
	end

	if isWinding and umbilicalHose ~= nil and umbilicalHose:hasOnePoint() then
		return
	end

	self:setReelDirection(-spec.reelDirection)
end

function UmbilicalReel:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_umbilicalReel

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInput and #spec.reels > 0 then
			local _, actionEventToggle = self:addActionEvent(spec.actionEvents, InputAction.PM_TOGGLE_REEL_STATE, self, UmbilicalReel.actionEventActiveReel, false, true, false, true, nil, , true)
			local isUnwinding = spec.reelDirection == UmbilicalReel.UNWIND_DIRECTION
			local windText = g_i18n:getText("info_directionWinding")
			local unwindText = g_i18n:getText("info_directionUnwinding")
			local activateText = isUnwinding and unwindText or windText

			g_inputBinding:setActionEventText(actionEventToggle, g_i18n:getText("action_activateReel"):format(activateText))
			g_inputBinding:setActionEventActive(actionEventToggle, true)
			g_inputBinding:setActionEventTextVisibility(actionEventToggle, true)
			g_inputBinding:setActionEventTextPriority(actionEventToggle, GS_PRIO_NORMAL)

			local _, actionEventDirection = self:addActionEvent(spec.actionEvents, InputAction.PM_TOGGLE_REEL_DIRECTION, self, UmbilicalReel.actionEventToggleDirection, false, true, false, true, nil, , true)
			local directionText = isUnwinding and windText or unwindText

			g_inputBinding:setActionEventText(actionEventDirection, g_i18n:getText("action_directionChange"):format(directionText))
			g_inputBinding:setActionEventActive(actionEventDirection, true)
			g_inputBinding:setActionEventTextVisibility(actionEventDirection, true)
			g_inputBinding:setActionEventTextPriority(actionEventDirection, GS_PRIO_NORMAL)
		end
	end
end
