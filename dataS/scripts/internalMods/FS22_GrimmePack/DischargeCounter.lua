DischargeCounter = {}
local modName = g_currentModName
local fullSpecName = modName .. ".dischargeCounter"

function DischargeCounter.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Dischargeable, specializations)
end

function DischargeCounter.initSpecialization()
	local schema = Vehicle.xmlSchema
	local schemaSavegame = Vehicle.xmlSchemaSavegame

	schema:setXMLSpecializationType("DischargeCounter")
	Dashboard.registerDashboardXMLPaths(schema, "vehicle.dischargeable.dischargeNode(?).dashboards", "dischargeCounter | targetFilled | targetFilling")
	schema:setXMLSpecializationType()
	schemaSavegame:register(XMLValueType.FLOAT, string.format("vehicles.vehicle(?).%s.dischargeNode(?)#dischargeCounter", fullSpecName), "dischargeCounter")
end

function DischargeCounter.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadDischargeNode", DischargeCounter.loadDischargeNode)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "handleDischarge", DischargeCounter.handleDischarge)
end

function DischargeCounter.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", DischargeCounter)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", DischargeCounter)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", DischargeCounter)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", DischargeCounter)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", DischargeCounter)
end

function DischargeCounter:onPostLoad(savegame)
	if savegame ~= nil and not savegame.resetVehicles then
		local spec = self.spec_dischargeable

		for i, dischargeNode in ipairs(spec.dischargeNodes) do
			dischargeNode.dischargeCounter = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key .. "." .. fullSpecName .. ".dischargeNode(" .. i - 1 .. ")#dischargeCounter"), dischargeNode.dischargeCounter)
		end
	end
end

function DischargeCounter:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_dischargeable

	for i, dischargeNode in ipairs(spec.dischargeNodes) do
		xmlFile:setValue(key .. ".dischargeNode(" .. i - 1 .. ")#dischargeCounter", dischargeNode.dischargeCounter)
	end
end

function DischargeCounter:onReadStream(streamId, connection)
	local spec = self.spec_dischargeable

	for _, dischargeNode in ipairs(spec.dischargeNodes) do
		dischargeNode.dischargeCounter = streamReadFloat32(streamId)
	end
end

function DischargeCounter:onWriteStream(streamId, connection)
	local spec = self.spec_dischargeable

	for _, dischargeNode in ipairs(spec.dischargeNodes) do
		streamWriteFloat32(streamId, dischargeNode.dischargeCounter or 0)
	end
end

function DischargeCounter:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		local spec = self.spec_dischargeable

		if streamReadBool(streamId) then
			for _, dischargeNode in ipairs(spec.dischargeNodes) do
				dischargeNode.dischargeCounter = streamReadFloat32(streamId)
			end
		end
	end
end

function DischargeCounter:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local spec = self.spec_dischargeable

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
			for _, dischargeNode in ipairs(spec.dischargeNodes) do
				streamWriteFloat32(streamId, dischargeNode.dischargeCounter or 0)
			end
		end
	end
end

function DischargeCounter:loadDischargeNode(superFunc, xmlFile, key, entry)
	if not superFunc(self, xmlFile, key, entry) then
		return false
	end

	entry.dischargeCounter = 0
	entry.targetFilled = false

	function entry.targetIsFilledFunc()
		if entry.dischargeObject ~= nil and entry.dischargeObject.getFillUnitFreeCapacity ~= nil then
			entry.targetFilled = entry.dischargeObject:getFillUnitFreeCapacity(entry.dischargeFillUnitIndex) == 0
		end

		return entry.targetFilled
	end

	function entry.targetIsFillingFunc()
		return not entry.targetIsFilledFunc()
	end

	if self.loadDashboardsFromXML ~= nil then
		self:loadDashboardsFromXML(self.xmlFile, key .. ".dashboards", {
			valueFunc = "dischargeCounter",
			valueTypeToLoad = "dischargeCounter",
			valueObject = entry
		})
		self:loadDashboardsFromXML(self.xmlFile, key .. ".dashboards", {
			valueFunc = "targetIsFilledFunc",
			valueTypeToLoad = "targetFilled",
			valueObject = entry
		})
		self:loadDashboardsFromXML(self.xmlFile, key .. ".dashboards", {
			valueFunc = "targetIsFillingFunc",
			valueTypeToLoad = "targetFilling",
			valueObject = entry
		})
	end

	return true
end

function DischargeCounter:handleDischarge(superFunc, dischargeNode, dischargedLiters, minDropReached, hasMinDropFillLevel)
	superFunc(self, dischargeNode, dischargedLiters, minDropReached, hasMinDropFillLevel)

	dischargeNode.dischargeCounter = dischargeNode.dischargeCounter - dischargedLiters

	if self.spec_dashboard ~= nil then
		self:updateDashboards(self.spec_dashboard.dashboards, 9999, true)
	end

	self:raiseDirtyFlags(self.spec_dischargeable.dirtyFlag)
end
