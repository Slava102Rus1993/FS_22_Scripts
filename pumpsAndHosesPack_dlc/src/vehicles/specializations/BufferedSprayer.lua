BufferedSprayer = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	BUFFERED_SPRAYER_XML_KEY = "vehicle.sprayer.bufferBenefits",
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Sprayer, specializations)
	end
}

function BufferedSprayer.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:register(XMLValueType.FLOAT, BufferedSprayer.BUFFERED_SPRAYER_XML_KEY .. "#speed", "Additional speed to speed limit while using buffer", 3)
	schema:register(XMLValueType.FLOAT, BufferedSprayer.BUFFERED_SPRAYER_XML_KEY .. "#maxSpeedLimit", "Max speed limit while using buffer", 20)
	schema:register(XMLValueType.FLOAT, BufferedSprayer.BUFFERED_SPRAYER_XML_KEY .. "#maxSpeedLimitDoubleAmount", "Max speed limit while using buffer with double amount", 13)
	schema:setXMLSpecializationType()
end

function BufferedSprayer.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "hasBufferObject", BufferedSprayer.hasBufferObject)
	SpecializationUtil.registerFunction(vehicleType, "isBufferObjectSprayVehicle", BufferedSprayer.isBufferObjectSprayVehicle)
	SpecializationUtil.registerFunction(vehicleType, "getBufferObject", BufferedSprayer.getBufferObject)
	SpecializationUtil.registerFunction(vehicleType, "setBufferObject", BufferedSprayer.setBufferObject)
	SpecializationUtil.registerFunction(vehicleType, "getFirstValidBufferFillUnit", BufferedSprayer.getFirstValidBufferFillUnit)
end

function BufferedSprayer.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", BufferedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", BufferedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onEndWorkAreaProcessing", BufferedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDetach", BufferedSprayer)
end

function BufferedSprayer.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getRawSpeedLimit", BufferedSprayer.getRawSpeedLimit)
end

function BufferedSprayer:onLoad(savegame)
	self.spec_bufferedSprayer = self[("spec_%s.bufferedSprayer"):format(BufferedSprayer.MOD_NAME)]
	local spec = self.spec_bufferedSprayer
	spec.bufferObject = nil
	spec.bufferFillUnitIndex = nil
	spec.bufferBenefits = {
		speedLimit = self.speedLimit,
		speedLimitSent = self.speedLimit,
		speed = self.xmlFile:getValue(BufferedSprayer.BUFFERED_SPRAYER_XML_KEY .. "#speed", 3),
		maxSpeedLimit = self.xmlFile:getValue(BufferedSprayer.BUFFERED_SPRAYER_XML_KEY .. "#maxSpeedLimit", 20),
		maxSpeedLimitDoubleAmount = self.xmlFile:getValue(BufferedSprayer.BUFFERED_SPRAYER_XML_KEY .. "#maxSpeedLimitDoubleAmount", 13)
	}
	spec.bufferSearchWaitTimer = 0
	spec.bufferSearchWaitTimeOffset = 1000
	spec.dirtyFlag = self:getNextDirtyFlag()
end

function BufferedSprayer:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		local isDirty = streamReadBool(streamId)

		if isDirty then
			local spec = self.spec_bufferedSprayer
			spec.bufferBenefits.speedLimit = streamReadFloat32(streamId)
		end
	end
end

function BufferedSprayer:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local spec = self.spec_bufferedSprayer

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
			streamWriteFloat32(streamId, spec.bufferBenefits.speedLimit)
		end
	end
end

function BufferedSprayer:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_bufferedSprayer

	if self.isServer and isActiveForInputIgnoreSelection and spec.bufferSearchWaitTimer <= g_currentMission.time then
		local bufferObject, bufferFillUnitIndex = self:getBufferObject()

		if bufferObject == nil then
			bufferObject, bufferFillUnitIndex = self:getFirstValidBufferFillUnit()

			if bufferObject ~= nil then
				self:setBufferObject(bufferObject, bufferFillUnitIndex)
			end
		end

		if bufferObject ~= nil then
			if bufferObject:getFillUnitFillLevel(bufferFillUnitIndex) <= 0 or bufferObject ~= self:getFirstValidBufferFillUnit() then
				self:setBufferObject(nil, )
			end
		else
			spec.bufferSearchWaitTimer = g_currentMission.time + spec.bufferSearchWaitTimeOffset
		end
	end
end

function BufferedSprayer:onEndWorkAreaProcessing(dt, hasProcessed)
	local spec = self.spec_bufferedSprayer
	local spec_sprayer = self.spec_sprayer
	local workAreaParameters = spec_sprayer.workAreaParameters

	if self.isServer and workAreaParameters ~= nil and (workAreaParameters.isActive or hasProcessed) then
		local bufferObject, bufferFillUnitIndex = self:getBufferObject()
		local sprayerDoubledAmountActive = self:getSprayerDoubledAmountActive(workAreaParameters.sprayType)
		local sprayFillType = workAreaParameters.sprayFillType

		if bufferObject ~= nil and bufferObject ~= workAreaParameters.sprayVehicle and bufferObject:getFillUnitFillLevel(bufferFillUnitIndex) > 0 and bufferObject:getFillUnitFillType(bufferFillUnitIndex) == sprayFillType then
			local absMaxSpeed = sprayerDoubledAmountActive and spec.bufferBenefits.maxSpeedLimitDoubleAmount or spec.bufferBenefits.maxSpeedLimit
			local curSpeedLimit = sprayerDoubledAmountActive and spec_sprayer.doubledAmountSpeed or self.speedLimit
			spec.bufferBenefits.speedLimit = math.min(curSpeedLimit + spec.bufferBenefits.speed, absMaxSpeed)
			local usagePerKmH = workAreaParameters.usage / self.speedLimit
			local bufferUsage = math.max(usagePerKmH * (self.speedLimit + spec.bufferBenefits.speed) - workAreaParameters.usage, 0)

			bufferObject:addFillUnitFillLevel(self:getOwnerFarmId(), bufferFillUnitIndex, -bufferUsage, sprayFillType, ToolType.UNDEFINED, nil)

			local stats = g_currentMission:farmStats(self:getLastTouchedFarmlandFarmId())

			stats:updateStats("sprayUsage", bufferUsage)
		else
			spec.bufferBenefits.speedLimit = self.speedLimit
		end

		if spec.bufferBenefits.speedLimit ~= spec.bufferBenefits.speedLimitSent then
			spec.bufferBenefits.speedLimitSent = spec.bufferBenefits.speedLimit

			self:raiseDirtyFlags(spec.dirtyFlag)
		end
	end
end

function BufferedSprayer:onPreDetach()
	if self.isServer then
		self:setBufferObject(nil, )
	end
end

function BufferedSprayer:hasBufferObject()
	local spec = self.spec_bufferedSprayer
	local spec_sprayer = self.spec_sprayer

	return spec ~= nil and spec.bufferObject ~= nil and spec.bufferObject ~= spec_sprayer.workAreaParameters.sprayVehicle
end

function BufferedSprayer:isBufferObjectSprayVehicle()
	local spec = self.spec_bufferedSprayer

	if spec.bufferObject ~= nil and spec.bufferFillUnitIndex ~= nil then
		return spec.bufferObject:getFillUnitFillLevel(spec.bufferFillUnitIndex) > 0
	end

	return false
end

function BufferedSprayer:getBufferObject()
	local spec = self.spec_bufferedSprayer

	return spec.bufferObject, spec.bufferFillUnitIndex
end

function BufferedSprayer:setBufferObject(object, fillUnitIndex)
	local spec = self.spec_bufferedSprayer
	spec.bufferObject = object
	spec.bufferFillUnitIndex = fillUnitIndex
end

function BufferedSprayer:getFirstValidBufferFillUnit()
	local function getFillUnitBuffer(object)
		if object.getFillUnitBuffer ~= nil then
			local bufferFillUnitIndex = object:getFillUnitBuffer()

			if bufferFillUnitIndex ~= nil and object:getFillUnitFillLevel(bufferFillUnitIndex) > 0 then
				return object, bufferFillUnitIndex
			end
		end

		return nil, 
	end

	local bufferObject, bufferFillUnitIndex = getFillUnitBuffer(self)

	if bufferObject ~= nil then
		return bufferObject, bufferFillUnitIndex
	end

	local rootVehicle = self:getRootVehicle()

	for _, vehicle in pairs(rootVehicle:getChildVehicles()) do
		local vehicleBufferObject, vehicleBufferFillUnitIndex = getFillUnitBuffer(vehicle)

		if vehicleBufferObject ~= nil then
			return vehicleBufferObject, vehicleBufferFillUnitIndex
		end
	end

	return nil, 
end

function BufferedSprayer:getRawSpeedLimit(superFunc)
	local spec = self.spec_bufferedSprayer

	if self:hasBufferObject() then
		return spec.bufferBenefits.speedLimit
	end

	return superFunc(self)
end
