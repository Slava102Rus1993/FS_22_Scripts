WoodUnloadTrigger = {}

source("dataS/scripts/triggers/WoodUnloadTriggerEvent.lua")

local WoodUnloadTrigger_mt = Class(WoodUnloadTrigger, Object)

InitStaticObjectClass(WoodUnloadTrigger, "WoodUnloadTrigger", ObjectIds.OBJECT_WOOD_UNLOAD_TRIGGER)

function WoodUnloadTrigger.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.NODE_INDEX, basePath .. "#triggerNode", "Trigger node")
	schema:register(XMLValueType.NODE_INDEX, basePath .. "#activationTriggerNode", "Activation trigger node for the player")
	schema:register(XMLValueType.STRING, basePath .. "#trainSystemId", "Money will be added to the account of the current rental farm id of the train. This attribute is the map bound id of the corresponding train system.")
end

function WoodUnloadTrigger.new(isServer, isClient, customMt)
	local self = Object.new(isServer, isClient, customMt or WoodUnloadTrigger_mt)
	self.triggerNode = nil
	self.woodInTrigger = {}
	self.lastSplitShapeVolume = 0
	self.lastSplitType = nil
	self.lastSplitShapeStats = {
		numConvexes = 0,
		sizeZ = 0,
		numAttachments = 0,
		sizeY = 0,
		sizeX = 0
	}
	self.extraAttributes = {
		price = 1
	}

	return self
end

function WoodUnloadTrigger:load(components, xmlFile, xmlNode, target, i3dMappings, rootNode)
	local triggerNodeKey = xmlNode .. "#triggerNode"
	self.triggerNode = xmlFile:getValue(triggerNodeKey, nil, components, i3dMappings)

	if self.triggerNode ~= nil then
		local colMask = getCollisionMask(self.triggerNode)

		if bitAND(SplitTypeManager.COLLISIONMASK_TRIGGER, colMask) == 0 then
			Logging.xmlWarning(xmlFile, "Invalid collision mask for wood trigger '%s'. Bit 24 needs to be set!", triggerNodeKey)

			return false
		end

		addTrigger(self.triggerNode, "woodTriggerCallback", self)
	else
		return false
	end

	local activationTrigger = xmlFile:getValue(xmlNode .. "#activationTriggerNode", nil, components, i3dMappings)

	if activationTrigger ~= nil then
		if not CollisionFlag.getHasFlagSet(activationTrigger, CollisionFlag.TRIGGER_PLAYER) then
			Logging.xmlWarning(xmlFile, "Missing collision mask bit '%d'. Please add this bit to sell trigger node '%s' in 'placeable.woodSellingStation#sellTrigger'.", CollisionFlag.getBit(CollisionFlag.TRIGGER_PLAYER), getName(activationTrigger))

			return false
		end

		self.activationTrigger = activationTrigger

		if self.activationTrigger ~= nil then
			addTrigger(self.activationTrigger, "woodSellTriggerCallback", self)
		end
	end

	self.isManualSellingActive = true
	self.trainSystemId = xmlFile:getValue(xmlNode .. "#trainSystemId")
	self.trainSystem = nil

	if target ~= nil then
		self:setTarget(target)
	end

	self.activatable = PlaceableWoodSellingStationActivatable.new(self)

	return true
end

function WoodUnloadTrigger:delete()
	if self.triggerNode ~= nil and self.triggerNode ~= 0 then
		removeTrigger(self.triggerNode)

		self.triggerNode = 0
	end

	if self.activationTrigger ~= nil then
		g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
		removeTrigger(self.activationTrigger)

		self.activationTrigger = nil
	end

	WoodUnloadTrigger:superClass().delete(self)
end

function WoodUnloadTrigger:setTarget(object)
	assert(object.getIsFillTypeAllowed ~= nil)
	assert(object.getIsToolTypeAllowed ~= nil)
	assert(object.addFillUnitFillLevel ~= nil)

	self.target = object
end

function WoodUnloadTrigger:getTarget()
	return self.target
end

function WoodUnloadTrigger:processWood(farmId, noEventSend)
	if not self.isServer then
		g_client:getServerConnection():sendEvent(WoodUnloadTriggerEvent.new(self, farmId))

		return
	end

	local soldWood = false
	local totalMass = 0
	local isFull = false

	for _, nodeId in pairs(self.woodInTrigger) do
		if self:getCanProcessWood() then
			if entityExists(nodeId) then
				soldWood = true
				local volume, qualityScale, maxSize = self:calculateWoodBaseValue(nodeId)
				self.extraAttributes.price = qualityScale
				self.extraAttributes.maxSize = maxSize

				if g_currentMission:getIsServer() then
					local fillType = self:getTargetFillType(maxSize, volume)

					if self.target.getFillUnitFreeCapacity == nil or self.target:getFillUnitFreeCapacity(nil, fillType, farmId) > volume * 0.9 then
						self.target:addFillUnitFillLevel(farmId, nil, volume, fillType, ToolType.undefined, nil, self.extraAttributes)
						self:onProcessedWood(nodeId, volume, fillType)
						delete(nodeId)
					else
						isFull = true
					end
				end
			end

			if isFull then
				break
			else
				self.woodInTrigger[nodeId] = nil
			end
		end
	end

	if soldWood and g_currentMission:getIsServer() then
		g_currentMission:farmStats():updateStats("woodTonsSold", totalMass)
	end
end

function WoodUnloadTrigger:getTargetFillType(maxSize, volume)
	return FillType.WOOD
end

function WoodUnloadTrigger:getCanProcessWood()
	return true
end

function WoodUnloadTrigger:onProcessedWood(nodeId, volume, fillType)
end

function WoodUnloadTrigger:calculateWoodBaseValue(objectId)
	local volume = getVolume(objectId)
	local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(objectId))
	local sizeX, sizeY, sizeZ, numConvexes, numAttachments = getSplitShapeStats(objectId)

	return self:calculateWoodBaseValueForData(volume, splitType, sizeX, sizeY, sizeZ, numConvexes, numAttachments)
end

function WoodUnloadTrigger:calculateWoodBaseValueForData(volume, splitType, sizeX, sizeY, sizeZ, numConvexes, numAttachments)
	local qualityScale = 1
	local lengthScale = 1
	local defoliageScale = 1
	local maxSize = 0

	if sizeX ~= nil and volume > 0 then
		local bvVolume = sizeX * sizeY * sizeZ
		local volumeRatio = bvVolume / volume
		local volumeQuality = 1 - math.sqrt(MathUtil.clamp((volumeRatio - 3) / 7, 0, 1)) * 0.95
		local convexityQuality = 1 - MathUtil.clamp((numConvexes - 2) / 4, 0, 1) * 0.95
		maxSize = math.max(sizeX, sizeY, sizeZ)

		if maxSize < 11 then
			lengthScale = 0.6 + math.min(math.max((maxSize - 1) / 5, 0), 1) * 0.6
		else
			lengthScale = 1.2 - math.min(math.max((maxSize - 11) / 8, 0), 1) * 0.6
		end

		local minQuality = math.min(convexityQuality, volumeQuality)
		local maxQuality = math.max(convexityQuality, volumeQuality)
		qualityScale = minQuality + (maxQuality - minQuality) * 0.3
		defoliageScale = 1 - math.min(numAttachments / 15, 1) * 0.8
	end

	qualityScale = MathUtil.lerp(1, qualityScale, g_currentMission.missionInfo.economicDifficulty / 3)
	defoliageScale = MathUtil.lerp(1, defoliageScale, g_currentMission.missionInfo.economicDifficulty / 3)

	return volume * splitType.volumeToLiter, splitType.pricePerLiter * qualityScale * defoliageScale * lengthScale, maxSize
end

function WoodUnloadTrigger:update(dt)
	WoodUnloadTrigger:superClass().update(self, dt)

	if self.isServer then
		local farmId = self.target:getOwnerFarmId()

		if self.trainSystemId ~= nil then
			if self.trainSystem == nil then
				for _, trainSystem in pairs(g_currentMission.trainSystems) do
					if trainSystem.mapBoundId == self.trainSystemId then
						self.trainSystem = trainSystem

						break
					end
				end
			end

			if self.trainSystem ~= nil then
				farmId = self.trainSystem.spec_trainSystem.lastRentFarmId
			end
		end

		if farmId ~= FarmManager.SPECTATOR_FARM_ID then
			self:processWood(farmId)
		end
	end
end

function WoodUnloadTrigger:woodTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if otherId ~= 0 then
		local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(otherId))

		if splitType ~= nil and splitType.pricePerLiter > 0 then
			if onEnter then
				self.woodInTrigger[otherId] = otherId

				if self:getNeedRaiseActive() then
					self:raiseActive()
				end
			else
				self.woodInTrigger[otherId] = nil
			end
		end
	end
end

function WoodUnloadTrigger:getNeedRaiseActive()
	return self.trainSystemId ~= nil
end

function WoodUnloadTrigger:getWoodLogs()
	return self.woodInTrigger
end

function WoodUnloadTrigger:woodSellTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if (onEnter or onLeave) and g_currentMission.player ~= nil and otherActorId == g_currentMission.player.rootNode then
		if onEnter then
			if self.isManualSellingActive then
				g_currentMission.activatableObjectsSystem:addActivatable(self.activatable)
			end
		else
			g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
		end
	end
end

PlaceableWoodSellingStationActivatable = {}
local PlaceableWoodSellingStationActivatable_mt = Class(PlaceableWoodSellingStationActivatable)

function PlaceableWoodSellingStationActivatable.new(woodUnloadTrigger)
	local self = setmetatable({}, PlaceableWoodSellingStationActivatable_mt)
	self.woodUnloadTrigger = woodUnloadTrigger
	self.activateText = g_i18n:getText("action_sellWood")

	return self
end

function PlaceableWoodSellingStationActivatable:getIsActivatable()
	return g_currentMission.controlPlayer and g_currentMission:getFarmId() ~= FarmManager.SPECTATOR_FARM_ID
end

function PlaceableWoodSellingStationActivatable:run()
	self.woodUnloadTrigger:processWood(g_currentMission:getFarmId())
end

function PlaceableWoodSellingStationActivatable:getDistance(x, y, z)
	if self.woodUnloadTrigger.activationTrigger ~= nil then
		local tx, ty, tz = getWorldTranslation(self.woodUnloadTrigger.activationTrigger)

		return MathUtil.vector3Length(x - tx, y - ty, z - tz)
	end

	return math.huge
end
