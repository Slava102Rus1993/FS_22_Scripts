ManureSeparator = {
	DEFAULT_RANGE_DISTANCE = 35
}
local ManureSeparator_mt = Class(ManureSeparator, ManureHeap)

InitObjectClass(ManureSeparator, "ManureSeparator")

function ManureSeparator.registerXMLPaths(schema, basePath)
	ManureHeap.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.FLOAT, basePath .. "#litersPerSecond", "The liters per second throughput", 1)
	schema:register(XMLValueType.FLOAT, basePath .. "#searchDistance", "The distance to search for a source", 1)
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "work")
	AnimationManager.registerAnimationNodesXMLPaths(schema, basePath .. ".animationNodes")
	ObjectChangeUtil.registerObjectChangeXMLPaths(schema, basePath .. ".objectChanges")
	EffectManager.registerEffectXMLPaths(schema, basePath .. ".effects")
end

function ManureSeparator.registerSavegameXMLPaths(schema, basePath)
	ManureHeap.registerSavegameXMLPaths(schema, basePath)
	schema:register(XMLValueType.BOOL, basePath .. "#isProcessing", "State of processing")
end

function ManureSeparator.new(object, isServer, isClient, customMt)
	local self = ManureHeap.new(isServer, isClient, customMt or ManureSeparator_mt)
	self.object = object
	self.isProcessing = false
	self.activatable = ManureSeparatorActivatable.new(self)
	self.litersPerSecond = 0
	self.sourceStorage = nil
	self.sourceVehicles = {}

	return self
end

function ManureSeparator:load(components, xmlFile, key, customEnv, i3dMappings, rootNode)
	local isLoaded = ManureSeparator:superClass().load(self, components, xmlFile, key, customEnv, i3dMappings, rootNode)

	if not isLoaded then
		return false
	end

	self.supportedFillTypes = {
		[FillType.LIQUIDMANURE] = true,
		[FillType.DIGESTATE] = true
	}
	self.sourceFillTypeIndex = FillType.LIQUIDMANURE
	self.fillTypeIndex = FillType.SEPARATED_MANURE
	self.fillTypes = {
		[self.fillTypeIndex] = true
	}
	self.fillLevels = {
		[self.fillTypeIndex] = 0
	}
	self.litersPerSecond = xmlFile:getValue(key .. "#litersPerSecond", 1)
	self.searchDistance = xmlFile:getValue(key .. "#searchDistance", ManureSeparator.DEFAULT_RANGE_DISTANCE)
	self.convertSchema = {
		[FillType.LIQUIDMANURE] = self.litersPerSecond,
		[FillType.DIGESTATE] = self.litersPerSecond * 1.8
	}

	if not self.isServer and self.isClient then
		addTrigger(self.activationTriggerNode, "onVehicleCallback", self)
	end

	if self.isClient then
		self.effects = g_effectManager:loadEffect(xmlFile, key .. ".effects", components, self, i3dMappings)

		g_effectManager:setFillType(self.effects, self.sourceFillTypeIndex)

		self.samples = {
			work = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "work", self.baseDirectory, components, 0, AudioGroup.ENVIRONMENT, i3dMappings, self)
		}
		self.animationNodes = g_animationManager:loadAnimations(xmlFile, key .. ".animationNodes", components, self, i3dMappings)
		self.changeObjects = {}

		ObjectChangeUtil.loadObjectChangeFromXML(xmlFile, key .. ".objectChanges", self.changeObjects, components, self.object)
		ObjectChangeUtil.setObjectChanges(self.changeObjects, false)
	end

	return true
end

function ManureSeparator:saveToXMLFile(xmlFile, key)
	ManureSeparator:superClass().saveToXMLFile(self, xmlFile, key)
	xmlFile:setValue(key .. "#isProcessing", self.isProcessing)
end

function ManureSeparator:loadFromXMLFile(xmlFile, key)
	if not ManureSeparator:superClass().loadFromXMLFile(self, xmlFile, key) then
		return false
	end

	local isProcessing = xmlFile:getValue(key .. "#isProcessing", self.isProcessing)

	self:setIsProcessing(isProcessing, true)

	return true
end

function ManureSeparator:findClosestStorage()
	if self.sourceStorage ~= nil then
		self.sourceStorage:removeDeleteListener(self, "onStorageDeleted")
	end

	local storage, fillTypeIndex = self:getClosestStorageByFillType()

	if storage ~= nil and fillTypeIndex ~= nil then
		self.sourceStorage = storage
		self.sourceFillTypeIndex = fillTypeIndex

		storage:addDeleteListener(self, "onStorageDeleted")
	end
end

function ManureSeparator:onVehicleCallback(triggerId, otherId, onEnter, onLeave, onStay)
	local vehicle = g_currentMission:getNodeObject(otherId)
	local isPlayer = g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode

	if onEnter then
		if isPlayer then
			if g_currentMission.player.farmId ~= self:getOwnerFarmId() then
				return
			end

			g_currentMission.activatableObjectsSystem:addActivatable(self.activatable)
			self:findClosestStorage()
		end

		if vehicle ~= nil and vehicle.spec_manureSeparator == nil and vehicle.addFillUnitTrigger ~= nil and vehicle.removeFillUnitTrigger ~= nil then
			if vehicle:getOwnerFarmId() ~= self:getOwnerFarmId() then
				return
			end

			for fillTypeIndex, _ in pairs(self.supportedFillTypes) do
				local fillUnitIndex = vehicle:getFirstValidFillUnitToFill(fillTypeIndex, true)

				if fillUnitIndex ~= nil and vehicle:getFillUnitFillLevel(fillUnitIndex) > 0 then
					self.sourceFillTypeIndex = fillTypeIndex

					table.addElement(self.sourceVehicles, vehicle)
					vehicle:addDeleteListener(self, "onVehicleDeleted")

					break
				end
			end
		end
	elseif onLeave then
		g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)

		if vehicle ~= nil then
			vehicle:removeDeleteListener(self, "onVehicleDeleted")
			table.removeElement(self.sourceVehicles, vehicle)
		end
	end

	if onEnter and vehicle ~= nil or isPlayer then
		self:raiseActive()
	end
end

function ManureSeparator:delete()
	g_soundManager:deleteSamples(self.samples)
	g_animationManager:deleteAnimations(self.animationNodes)
	g_effectManager:deleteEffects(self.effects)
	g_messageCenter:unsubscribe(MessageType.MINUTE_CHANGED, self)
	g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
	ManureSeparator:superClass().delete(self)
end

function ManureSeparator:finalize()
	ManureSeparator:superClass().finalize(self)
	g_messageCenter:subscribe(MessageType.MINUTE_CHANGED, self.minuteChanged, self)
end

function ManureSeparator:minuteChanged()
	if self.isProcessing and self.isServer then
		if #self.sourceVehicles == 0 and self.sourceStorage == nil and g_dedicatedServer ~= nil then
			self:findClosestStorage()
		end

		if not self:canProcessManure() then
			self:setIsProcessing(false)

			return
		end

		local delta = self.convertSchema[self.sourceFillTypeIndex] * 60
		local percentageToSolid = math.random(12, 30) * 0.01
		local solidDelta = delta * percentageToSolid
		local liquidDelta = delta * 0.9 * (1 - percentageToSolid)

		if #self.sourceVehicles == 0 and self.sourceStorage ~= nil then
			local storage = self.sourceStorage

			if storage:getFillLevel(self.sourceFillTypeIndex) == 0 then
				self:setIsProcessing(false)

				return
			end

			local sourcePreviousFillLevel = storage.fillLevels[self.sourceFillTypeIndex]

			storage:setFillLevel(sourcePreviousFillLevel - liquidDelta, self.sourceFillTypeIndex)
			storage:raiseActive()
		else
			local vehicle = table.first(self.sourceVehicles)
			local fillUnitIndex = vehicle:getFirstValidFillUnitToFill(self.sourceFillTypeIndex, true)

			if fillUnitIndex == nil or vehicle:getFillUnitFillLevel(fillUnitIndex) == 0 then
				self:setIsProcessing(false)

				return
			end

			vehicle:addFillUnitFillLevel(vehicle:getOwnerFarmId(), fillUnitIndex, -liquidDelta, self.sourceFillTypeIndex, ToolType.TRIGGER, nil)
			vehicle:raiseActive()
		end

		local previousFillLevel = self.fillLevels[self.fillTypeIndex]

		self:setFillLevel(previousFillLevel + solidDelta, self.fillTypeIndex)
		self:raiseActive()
	end
end

function ManureSeparator:canProcessManure()
	local vehicle = table.first(self.sourceVehicles)

	if vehicle ~= nil then
		local fillUnitIndex = vehicle:getFirstValidFillUnitToFill(self.sourceFillTypeIndex, true)

		return fillUnitIndex ~= nil and vehicle:getFillUnitFillLevel(fillUnitIndex) > 0
	end

	if self.sourceStorage ~= nil then
		return self.sourceStorage:getFillLevel(self.sourceFillTypeIndex) > 0
	end

	return false
end

function ManureSeparator:toggleProcessingState()
	local isProcessing = not self.isProcessing

	self:setIsProcessing(isProcessing)
end

function ManureSeparator:setIsProcessing(isProcessing, noEventSend)
	ManureSeparatorProcessingEvent.sendEvent(self, isProcessing, noEventSend)

	self.isProcessing = isProcessing

	self:raiseActive()

	if self.isClient then
		g_effectManager:setFillType(self.effects, self.sourceFillTypeIndex)
		ObjectChangeUtil.setObjectChanges(self.changeObjects, isProcessing)

		if isProcessing then
			g_soundManager:playSample(self.samples.work)
			g_animationManager:startAnimations(self.animationNodes)
			g_effectManager:startEffects(self.effects)
		else
			g_soundManager:stopSample(self.samples.work)
			g_animationManager:stopAnimations(self.animationNodes)
			g_effectManager:stopEffects(self.effects)
		end
	end
end

function ManureSeparator:getClosestStorageByFillType()
	local closestStorage = nil
	local closestDistance = math.huge
	local fillType = nil

	for _, storage in pairs(g_currentMission.storageSystem:getStorages()) do
		if storage ~= self then
			for fillTypeIndex, _ in pairs(self.supportedFillTypes) do
				if storage:getIsFillTypeSupported(fillTypeIndex) and storage:getFillLevel(fillTypeIndex) > 0 then
					local distance = calcDistanceFrom(self.rootNode, storage.rootNode)

					if distance < self.searchDistance and distance < closestDistance then
						closestDistance = distance
						closestStorage = storage
						fillType = fillTypeIndex
					end
				end
			end
		end
	end

	return closestStorage, fillType
end

function ManureSeparator:onStorageDeleted(storage)
	if self.sourceStorage == storage then
		self.sourceStorage = nil

		if self.isServer and self.isProcessing then
			self:setIsProcessing(false)
		end
	end
end

function ManureSeparator:onVehicleDeleted(vehicle)
	if table.hasElement(self.sourceVehicles, vehicle) then
		table.removeElement(self.sourceVehicles, vehicle)

		if self.isServer and self.isProcessing then
			self:setIsProcessing(false)
		end
	end
end

ManureSeparatorActivatable = {}
local ManureSeparatorActivatable_mt = Class(ManureSeparatorActivatable)

function ManureSeparatorActivatable.new(separator)
	local self = setmetatable({}, ManureSeparatorActivatable_mt)
	self.separator = separator

	self:setActivationText()

	return self
end

function ManureSeparatorActivatable:getIsActivatable()
	self:setActivationText()

	return true
end

function ManureSeparatorActivatable:run()
	if self.separator:canProcessManure() then
		self.separator:toggleProcessingState()
	else
		g_currentMission:showBlinkingWarning(g_i18n:getText("infohud_storageIsEmpty"))
	end

	self:setActivationText()
end

function ManureSeparatorActivatable:setActivationText()
	self.activateText = self.separator.isProcessing and g_i18n:getText("action_disableSeparator") or g_i18n:getText("action_enableSeparator")
end
