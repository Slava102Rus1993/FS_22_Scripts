UmbilicalReelOverload = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	DEFAULT_UNLOADING_WIDTH = 10,
	DEFAULT_UNLOADING_HEIGHT = 3,
	HOSE_PALLET_XML_PATH = "data/objects/pallets/hosePallet/hosePallet.xml",
	HOSE_PALLET_UMBILICAL_REEL_CONFIG = 1,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(UmbilicalReel, specializations)
	end,
	initSpecialization = function ()
		local schema = Vehicle.xmlSchema

		schema:setXMLSpecializationType("UmbilicalReelOverload")
		schema:register(XMLValueType.NODE_INDEX, "vehicle.reelOverload#triggerNode", "Trigger node")
		schema:register(XMLValueType.BOOL, "vehicle.reelOverload#removeIfEmpty", "Remove the reel when empty")
		schema:register(XMLValueType.FLOAT, "vehicle.reelOverload#metersPerSecond", "Meters per second to overload")
		schema:register(XMLValueType.NODE_INDEX, "vehicle.reelOverload#unloadNode", "The node to unload the reel")
		schema:register(XMLValueType.FLOAT, "vehicle.reelOverload#unloadWidth", "Width of the unloading area")
		schema:register(XMLValueType.FLOAT, "vehicle.reelOverload#unloadHeight", "Height of the unloading area")
		schema:setXMLSpecializationType()
	end
}

function UmbilicalReelOverload.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "reelInTriggerCallback", UmbilicalReelOverload.reelInTriggerCallback)
	SpecializationUtil.registerFunction(vehicleType, "getNearestReelTarget", UmbilicalReelOverload.getNearestReelTarget)
	SpecializationUtil.registerFunction(vehicleType, "addReel", UmbilicalReelOverload.addReel)
	SpecializationUtil.registerFunction(vehicleType, "removeReel", UmbilicalReelOverload.removeReel)
	SpecializationUtil.registerFunction(vehicleType, "canOverloadFrom", UmbilicalReelOverload.canOverloadFrom)
	SpecializationUtil.registerFunction(vehicleType, "setIsOverloading", UmbilicalReelOverload.setIsOverloading)
	SpecializationUtil.registerFunction(vehicleType, "isRemovedWhenEmpty", UmbilicalReelOverload.isRemovedWhenEmpty)
	SpecializationUtil.registerFunction(vehicleType, "canUnload", UmbilicalReelOverload.canUnload)
	SpecializationUtil.registerFunction(vehicleType, "unloadReel", UmbilicalReelOverload.unloadReel)
	SpecializationUtil.registerFunction(vehicleType, "overload", UmbilicalReelOverload.overload)
	SpecializationUtil.registerFunction(vehicleType, "resetReelOverload", UmbilicalReelOverload.resetReelOverload)
end

function UmbilicalReelOverload.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", UmbilicalReelOverload)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", UmbilicalReelOverload)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDelete", UmbilicalReelOverload)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", UmbilicalReelOverload)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", UmbilicalReelOverload)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", UmbilicalReelOverload)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", UmbilicalReelOverload)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", UmbilicalReelOverload)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", UmbilicalReelOverload)
end

function UmbilicalReelOverload.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "canOperateReel", UmbilicalReelOverload.canOperateReel)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "isReelActive", UmbilicalReelOverload.isReelActive)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getReelDirection", UmbilicalReelOverload.getReelDirection)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "isDetachAllowed", UmbilicalReelOverload.isDetachAllowed)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "isAttachUmbilicalHoseAllowed", UmbilicalReelOverload.isAttachUmbilicalHoseAllowed)
end

function UmbilicalReelOverload:onLoad()
	self.spec_umbilicalReelOverload = self[("spec_%s.umbilicalReelOverload"):format(UmbilicalReelOverload.MOD_NAME)]
	local spec = self.spec_umbilicalReelOverload
	spec.reelsInTrigger = {}
	spec.isOverloading = false
	spec.overloadingDirection = UmbilicalReel.WIND_DIRECTION
	spec.triggerNode = self.xmlFile:getValue("vehicle.reelOverload#triggerNode", nil, self.components, self.i3dMappings)
	spec.removeIfEmpty = self.xmlFile:getValue("vehicle.reelOverload#removeIfEmpty", false)
	spec.metersPerSecond = self.xmlFile:getValue("vehicle.reelOverload#metersPerSecond", 5)
	spec.unloadNode = self.xmlFile:getValue("vehicle.reelOverload#unloadNode", nil, self.components, self.i3dMappings)
	spec.unloadWidth = self.xmlFile:getValue("vehicle.reelOverload#unloadWidth", UmbilicalReelOverload.DEFAULT_UNLOADING_WIDTH)
	spec.unloadHeight = self.xmlFile:getValue("vehicle.reelOverload#unloadHeight", UmbilicalReelOverload.DEFAULT_UNLOADING_HEIGHT)
	spec.nearestReel = nil
	spec.hasReels = false

	if self.isClient and spec.triggerNode ~= nil then
		addTrigger(spec.triggerNode, "reelInTriggerCallback", self)
	end
end

function UmbilicalReelOverload:onPostLoad()
	local spec = self.spec_umbilicalReelOverload
	spec.hasReels = #self.spec_umbilicalReel.reels > 0

	if not spec.hasReels then
		SpecializationUtil.removeEventListener(self, "onReadStream", UmbilicalReelOverload)
		SpecializationUtil.removeEventListener(self, "onWriteStream", UmbilicalReelOverload)
		SpecializationUtil.removeEventListener(self, "onUpdate", UmbilicalReelOverload)
		SpecializationUtil.removeEventListener(self, "onUpdateTick", UmbilicalReelOverload)
		SpecializationUtil.removeEventListener(self, "onRegisterActionEvents", UmbilicalReelOverload)
	end
end

function UmbilicalReelOverload:onPreDelete()
	local spec = self.spec_umbilicalReelOverload

	if spec.isOverloading then
		if spec.overloadingDirection == UmbilicalReel.WIND_DIRECTION then
			self:resetReelOverload()
		else
			spec.reelTarget:resetReelOverload()
		end
	end
end

function UmbilicalReelOverload:onDelete()
	local spec = self.spec_umbilicalReelOverload

	if self.isClient and spec.triggerNode ~= nil then
		removeTrigger(spec.triggerNode)
	end

	for _, reel in ipairs(spec.reelsInTrigger) do
		reel:removeReel(self)
	end
end

function UmbilicalReelOverload:onReadStream(streamId, connection)
	if connection:getIsServer() then
		local isOverloading = streamReadBool(streamId)
		local isWinding = streamReadBool(streamId)
		local reelDirection = isWinding and UmbilicalReel.WIND_DIRECTION or UmbilicalReel.UNWIND_DIRECTION
		local hasTarget = streamReadBool(streamId)
		local target = nil

		if hasTarget then
			target = NetworkUtil.readNodeObject(streamId)
		end

		self:setIsOverloading(target, isOverloading, reelDirection, true)
	end
end

function UmbilicalReelOverload:onWriteStream(streamId, connection)
	if not connection:getIsServer() then
		local spec = self.spec_umbilicalReelOverload

		streamWriteBool(streamId, spec.isOverloading)
		streamWriteBool(streamId, spec.overloadingDirection == UmbilicalReel.WIND_DIRECTION)
		streamWriteBool(streamId, spec.reelTarget ~= nil)

		if spec.reelTarget ~= nil then
			NetworkUtil.writeNodeObject(streamId, spec.reelTarget)
		end
	end
end

function UmbilicalReelOverload:onUpdate(dt)
	local spec = self.spec_umbilicalReelOverload

	if self.isClient then
		local actionEventOverload = spec.actionEvents[InputAction.PM_TOGGLE_REEL_OVERLOAD]

		if actionEventOverload ~= nil then
			local canShow = not spec.isOverloading and spec.nearestReel ~= nil
			canShow = canShow and g_currentMission.accessHandler:canFarmAccessOtherId(self:getOwnerFarmId(), spec.nearestReel:getOwnerFarmId())

			if canShow then
				g_currentMission.manure:showReelContext(spec.nearestReel:getName())
			end

			g_inputBinding:setActionEventTextVisibility(actionEventOverload.actionEventId, canShow)
			g_inputBinding:setActionEventActive(actionEventOverload.actionEventId, canShow)
		end

		local actionEventUnload = spec.actionEvents[InputAction.PM_TOGGLE_REEL_UNLOAD]

		if actionEventUnload ~= nil then
			local canUnload = self:canUnload()

			g_inputBinding:setActionEventTextVisibility(actionEventUnload.actionEventId, canUnload)
			g_inputBinding:setActionEventActive(actionEventUnload.actionEventId, canUnload)
		end
	end

	if spec.isOverloading and spec.overloadingDirection == UmbilicalReel.WIND_DIRECTION and self:canOverloadFrom(spec.reelTarget) and not g_currentMission.isSaving then
		local reel = self:getInteractiveReel()

		if self.isClient then
			local guideHose = self:getUmbilicalHoseGuide(reel.connectorIndex)

			if guideHose ~= nil then
				guideHose:scroll(reel.length)
			end
		end

		if self.isServer then
			local targetReel = spec.reelTarget:getInteractiveReel()
			local targetHose = targetReel:arrogateHose()
			local hose = reel:arrogateHose()
			local isTooFarAway = calcDistanceFrom(reel.drumNode, targetReel.drumNode) > UmbilicalHose.DEFAULT_POINT_DISTANCE * 3

			if isTooFarAway then
				self:resetReelOverload()

				return
			end

			if targetHose == nil or hose == nil or targetHose:isEmpty() and hose:isFull() then
				spec.reelTarget:setIsOverloading(self, false, UmbilicalReel.UNWIND_DIRECTION)
				spec.reelTarget:removeReelHose(targetReel.id)
				self:setIsOverloading(spec.reelTarget, false, UmbilicalReel.WIND_DIRECTION)
			else
				local delta = spec.metersPerSecond * dt * 0.001

				self:addReelLength(reel.id, delta, UmbilicalReel.WIND_DIRECTION, true)
				spec.reelTarget:addReelLength(targetReel.id, -delta, UmbilicalReel.UNWIND_DIRECTION, true)
			end
		end
	end
end

function UmbilicalReelOverload:onUpdateTick(dt)
	local spec = self.spec_umbilicalReelOverload

	if self.isClient then
		local nearestReel = nil

		if not spec.isOverloading then
			nearestReel = self:getNearestReelTarget()
		end

		if nearestReel ~= spec.nearestReel then
			spec.nearestReel = nearestReel
		end
	end

	if spec.reelTarget ~= nil then
		if spec.reelTarget.isDeleted then
			spec.reelTarget = nil
		else
			spec.reelTarget:raiseActive()
		end
	end

	if spec.isOverloading then
		self:raiseActive()
	end
end

function UmbilicalReelOverload:isRemovedWhenEmpty()
	return self.spec_umbilicalReelOverload.removeIfEmpty
end

function UmbilicalReelOverload:canOverloadFrom(from)
	local spec = self.spec_umbilicalReelOverload

	if not spec.hasReels then
		return false
	end

	if from == nil then
		return false
	end

	local targetReel = from:getInteractiveReel()

	if targetReel == nil or from:hasUmbilicalHose(targetReel.connectorIndex) then
		return false
	end

	if not spec.isOverloading and (targetReel == nil or targetReel:isEmpty()) then
		return false
	end

	local reel = self:getInteractiveReel()

	if reel == nil or self:hasUmbilicalHose(reel.connectorIndex) then
		return false
	end

	return true
end

function UmbilicalReelOverload:setIsOverloading(target, isOverloading, overloadingDirection, noEventSend)
	local spec = self.spec_umbilicalReelOverload

	if isOverloading ~= spec.isOverloading then
		UmbilicalReelOverloadEvent.sendEvent(self, target, isOverloading, overloadingDirection, noEventSend)

		local hasTarget = isOverloading and overloadingDirection == UmbilicalReel.WIND_DIRECTION
		spec.reelTarget = target
		spec.isOverloading = isOverloading
		spec.overloadingDirection = overloadingDirection
		local reel = self:getInteractiveReel()

		UmbilicalReel.setReelActiveState(self, reel.id, isOverloading, false)

		if hasTarget then
			local targetReel = target:getInteractiveReel()
			local targetHose = targetReel:arrogateHose()

			UmbilicalReel.getReelHose(self, reel, targetHose, true, overloadingDirection)

			if not self:hasUmbilicalHoseGuide(reel.connectorIndex) then
				self:createGuide(reel.connectorIndex, targetHose:getColor(), targetReel.guideTargetNode, "hoseOverload")
			end
		else
			self:removeGuide(reel.connectorIndex)
		end

		if self.isClient then
			reel:updateReelEndHose(not isOverloading)

			local actionEvent = spec.actionEvents[InputAction.PM_TOGGLE_REEL_OVERLOAD]

			if actionEvent ~= nil then
				local directionTextKey = spec.isOverloading and "action_reelOverloadActive" or "action_reelOverloadInactive"

				g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText(directionTextKey))
			end
		end
	end
end

function UmbilicalReelOverload:getNearestReelTarget()
	local spec = self.spec_umbilicalReelOverload
	local amountInTrigger = #spec.reelsInTrigger

	if amountInTrigger > 0 then
		if amountInTrigger > 1 then
			local distance = math.huge
			local closestReel = nil

			for _, reel in ipairs(spec.reelsInTrigger) do
				local reelDistance = calcDistanceFrom(self.rootNode, reel.rootNode)

				if reelDistance < distance and g_currentMission.accessHandler:canFarmAccessOtherId(self:getOwnerFarmId(), reel:getOwnerFarmId()) then
					distance = reelDistance
					closestReel = reel
				end
			end

			return closestReel
		end

		return table.first(spec.reelsInTrigger)
	end

	return nil
end

function UmbilicalReelOverload:addReel(reel)
	local spec = self.spec_umbilicalReelOverload

	if not table.hasElement(spec.reelsInTrigger, reel) then
		table.insert(spec.reelsInTrigger, reel)
	end
end

function UmbilicalReelOverload:removeReel(reel)
	local spec = self.spec_umbilicalReelOverload

	table.removeElement(spec.reelsInTrigger, reel)
end

function UmbilicalReelOverload:reelInTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local object = g_currentMission:getNodeObject(otherId)

	if object ~= nil and object.setIsReelActive ~= nil and object ~= self then
		if onEnter then
			if self:canOverloadFrom(object) then
				self:addReel(object)
				object:addReel(self)
			end
		elseif onLeave then
			self:removeReel(object)
			object:removeReel(self)
		end
	end
end

function UmbilicalReelOverload:canUnload()
	local spec = self.spec_umbilicalReelOverload

	if spec.isOverloading then
		return false
	end

	local reel = self:getInteractiveReel()

	if reel == nil or self:hasUmbilicalHose(reel.connectorIndex) then
		return false
	end

	return not reel:isEmpty()
end

function UmbilicalReelOverload:unloadReel()
	if not self.isServer then
		g_client:getServerConnection():sendEvent(UmbilicalReelUnloadEvent.new(self))
	else
		local reel = self:getInteractiveReel()

		if reel == nil then
			return
		end

		if reel:isEmpty() then
			return
		end

		local spec = self.spec_umbilicalReelOverload
		local places = {}
		local usedPlaces = {}

		local function getPlace(node, width, height)
			local place = {}
			place.startX, place.startY, place.startZ = localToWorld(node, width * 0.5, 0, height)
			place.rotX, place.rotY, place.rotZ = getWorldRotation(node)
			place.dirX, place.dirY, place.dirZ = localDirectionToWorld(node, 1, 0, 0)
			place.dirPerpX, place.dirPerpY, place.dirPerpZ = localDirectionToWorld(node, 0, 0, 1)
			place.maxHeight = math.huge
			place.maxLength = math.huge
			place.maxWidth = math.huge
			place.yOffset = 1
			place.width = width

			return place
		end

		table.insert(places, getPlace(spec.unloadNode or reel.linkNode, spec.unloadWidth, spec.unloadHeight))

		local numOfPalletsToSpawn = reel:getAmountOfHoses()

		local function asyncCallback(_, pallet, vehicleLoadState)
			if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_OK then
				local palletReel = pallet:getCurrentReel()
				local hose = reel:arrogateHose()

				pallet:addReelHose(palletReel.id, hose:getLength(), hose:getColor())
				self:removeReelHose(reel.id)
			end
		end

		local palletFilename = Utils.getFilename(UmbilicalReelOverload.HOSE_PALLET_XML_PATH, self.baseDirectory)
		local size = StoreItemUtil.getSizeValues(palletFilename, "vehicle", 0, {})

		for _ = 1, numOfPalletsToSpawn do
			local x, y, z, place, width = PlacementUtil.getPlace(places, size, usedPlaces, true, true, true)

			if x == nil then
				return
			end

			PlacementUtil.markPlaceUsed(usedPlaces, place, width)

			local location = {
				x = x,
				y = y,
				z = z,
				yRot = place.rotY
			}
			local configurations = {
				[UmbilicalReel.CONFIG_NAME_REEL] = UmbilicalReelOverload.HOSE_PALLET_UMBILICAL_REEL_CONFIG
			}

			VehicleLoadingUtil.loadVehicle(palletFilename, location, true, 0, Vehicle.PROPERTY_STATE_OWNED, self:getOwnerFarmId(), configurations, nil, asyncCallback, nil)
		end
	end
end

function UmbilicalReelOverload:overload(from, noEventSend)
	UmbilicalReelInstantOverloadEvent.sendEvent(self, from, noEventSend)

	local fromReel = from:getInteractiveReel()
	local toReel = self:getInteractiveReel()
	local targetHose = fromReel:arrogateHose()
	local length = targetHose:getLength()

	self:addReelHose(toReel.id, length, targetHose:getColor(), true)
	from:removeReelHose(fromReel.id, true)

	if self.isServer and from:isRemovedWhenEmpty() and fromReel:isEmpty() then
		from:raiseActive()
		g_currentMission:removeVehicle(from)
	end
end

function UmbilicalReelOverload:resetReelOverload()
	if not self.isServer then
		return
	end

	local spec = self.spec_umbilicalReelOverload
	local hasTarget = spec.isOverloading and spec.overloadingDirection == UmbilicalReel.WIND_DIRECTION

	if hasTarget then
		local target = spec.reelTarget
		local reel = self:getInteractiveReel()
		local targetReel = spec.reelTarget:getInteractiveReel()

		target:setIsOverloading(self, false, UmbilicalReel.UNWIND_DIRECTION)
		self:setIsOverloading(target, false, UmbilicalReel.WIND_DIRECTION)

		local removedHose = self:removeReelHose(reel.id)
		local removedTargetHose = target:removeReelHose(targetReel.id)

		target:addReelHose(targetReel.id, removedHose:getLength() + removedTargetHose:getLength(), removedTargetHose:getColor())
	end
end

function UmbilicalReelOverload:canOperateReel(superFunc)
	local spec = self.spec_umbilicalReelOverload

	if spec.isOverloading then
		return false
	end

	return superFunc(self)
end

function UmbilicalReelOverload:isReelActive(superFunc, reel)
	local spec = self.spec_umbilicalReelOverload

	if spec.isOverloading then
		return false
	end

	return superFunc(self, reel)
end

function UmbilicalReelOverload:getReelDirection(superFunc)
	local spec = self.spec_umbilicalReelOverload

	if spec.isOverloading then
		return spec.overloadingDirection
	end

	return superFunc(self)
end

function UmbilicalReelOverload:isAttachUmbilicalHoseAllowed(superFunc, umbilicalHose)
	local spec = self.spec_umbilicalReelOverload

	if spec.isOverloading then
		return false
	end

	return superFunc(self, umbilicalHose)
end

function UmbilicalReelOverload:isDetachAllowed(superFunc)
	local spec = self.spec_umbilicalReelOverload

	if spec.isOverloading then
		return false
	end

	return superFunc(self)
end

function UmbilicalReelOverload:actionEventOverload(...)
	local spec = self.spec_umbilicalReelOverload
	local nearestReel = spec.nearestReel

	if nearestReel ~= nil then
		if spec.isOverloading then
			g_currentMission:showBlinkingWarning(g_i18n:getText("info_reelAlreadyOverloading"))

			return
		end

		if not g_currentMission.accessHandler:canFarmAccessOtherId(self:getOwnerFarmId(), nearestReel:getOwnerFarmId()) then
			return
		end

		local targetReel = nearestReel:getInteractiveReel()
		local targetHose = targetReel:arrogateHose()
		local reel = self:getInteractiveReel()

		if targetReel:isEmpty() then
			g_currentMission:showBlinkingWarning(g_i18n:getText("info_reelEmpty"))

			return
		end

		if reel:getFreeCapacity() < targetHose:getLength() then
			g_currentMission:showBlinkingWarning(g_i18n:getText("info_reelNotEnoughCapacityLeft"))

			return
		end

		if self:hasUmbilicalHose(reel.connectorIndex) or nearestReel:hasUmbilicalHose(targetReel.connectorIndex) then
			return
		end

		local instantOverload = nearestReel:isRemovedWhenEmpty()

		if instantOverload then
			self:overload(nearestReel)
		else
			local nextOverloadingState = not spec.isOverloading

			self:setIsOverloading(nearestReel, nextOverloadingState, UmbilicalReel.WIND_DIRECTION)
			nearestReel:setIsOverloading(self, nextOverloadingState, UmbilicalReel.UNWIND_DIRECTION)
		end
	end
end

function UmbilicalReelOverload:actionEventUnload(...)
	if self:canUnload() then
		self:unloadReel()
	end
end

function UmbilicalReelOverload:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_umbilicalReelOverload

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInput and spec.hasReels then
			local _, actionEventOverloadId = self:addActionEvent(spec.actionEvents, InputAction.PM_TOGGLE_REEL_OVERLOAD, self, UmbilicalReelOverload.actionEventOverload, false, true, false, true, nil, , true)
			local directionTextKey = spec.isOverloading and "action_reelOverloadActive" or "action_reelOverloadInactive"

			g_inputBinding:setActionEventText(actionEventOverloadId, g_i18n:getText(directionTextKey))
			g_inputBinding:setActionEventTextVisibility(actionEventOverloadId, false)
			g_inputBinding:setActionEventTextPriority(actionEventOverloadId, GS_PRIO_VERY_HIGH)

			local _, actionEventUnloadId = self:addActionEvent(spec.actionEvents, InputAction.PM_TOGGLE_REEL_UNLOAD, self, UmbilicalReelOverload.actionEventUnload, false, true, false, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventUnloadId, GS_PRIO_NORMAL)
			g_inputBinding:setActionEventTextVisibility(actionEventUnloadId, self:canUnload())
		end
	end
end
