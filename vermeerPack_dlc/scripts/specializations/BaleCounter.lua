local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_vermeerPack" then
	return
end

BaleCounter = {
	SEND_NUM_BITS = 16,
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".baleCounter",
	SPEC_TABLE_NAME = "spec_" .. g_currentModName .. ".baleCounter"
}

source(g_currentModDirectory .. "scripts/specializations/events/BaleCounterResetEvent.lua")
source(g_currentModDirectory .. "scripts/hud/BaleCounterHUDExtension.lua")
VehicleHUDExtension.registerHUDExtension(BaleCounter, BaleCounterHUDExtension)

function BaleCounter.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Baler, specializations)
end

function BaleCounter.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("BaleCounter")
	Dashboard.registerDashboardXMLPaths(schema, "vehicle.baleCounter.dashboards", "sessionCounter lifetimeCounter")
	schema:setXMLSpecializationType()

	local schemaSavegame = Vehicle.xmlSchemaSavegame
	local baseKey = "vehicles.vehicle(?)." .. BaleCounter.SPEC_NAME

	schemaSavegame:register(XMLValueType.INT, baseKey .. "#sessionCounter", "Session counter")
	schemaSavegame:register(XMLValueType.INT, baseKey .. "#lifetimeCounter", "Lifetime counter")
end

function BaleCounter.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "doBaleCounterReset", BaleCounter.doBaleCounterReset)
end

function BaleCounter.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "dropBale", BaleCounter.dropBale)
end

function BaleCounter.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", BaleCounter)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", BaleCounter)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", BaleCounter)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", BaleCounter)
end

function BaleCounter:onLoad(savegame)
	local spec = self[BaleCounter.SPEC_TABLE_NAME]
	spec.sessionCounter = 0
	spec.lifetimeCounter = 0

	if savegame ~= nil and not savegame.resetVehicles then
		local key = savegame.key .. "." .. BaleCounter.SPEC_NAME
		spec.sessionCounter = savegame.xmlFile:getValue(key .. "#sessionCounter", spec.sessionCounter)
		spec.lifetimeCounter = savegame.xmlFile:getValue(key .. "#lifetimeCounter", spec.lifetimeCounter)
	end

	if self.loadDashboardsFromXML ~= nil then
		self:loadDashboardsFromXML(self.xmlFile, "vehicle.baleCounter.dashboards", {
			valueFunc = "sessionCounter",
			valueTypeToLoad = "sessionCounter",
			valueObject = spec
		})
		self:loadDashboardsFromXML(self.xmlFile, "vehicle.baleCounter.dashboards", {
			valueFunc = "lifetimeCounter",
			valueTypeToLoad = "lifetimeCounter",
			valueObject = spec
		})
	end
end

function BaleCounter:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self[BaleCounter.SPEC_TABLE_NAME]

	xmlFile:setValue(key .. "#sessionCounter", spec.sessionCounter)
	xmlFile:setValue(key .. "#lifetimeCounter", spec.lifetimeCounter)
end

function BaleCounter:onReadStream(streamId, connection)
	local spec = self[BaleCounter.SPEC_TABLE_NAME]
	spec.sessionCounter = streamReadUIntN(streamId, BaleCounter.SEND_NUM_BITS)
	spec.lifetimeCounter = streamReadUIntN(streamId, BaleCounter.SEND_NUM_BITS)
end

function BaleCounter:onWriteStream(streamId, connection)
	local spec = self[BaleCounter.SPEC_TABLE_NAME]

	streamWriteUIntN(streamId, spec.sessionCounter, BaleCounter.SEND_NUM_BITS)
	streamWriteUIntN(streamId, spec.lifetimeCounter, BaleCounter.SEND_NUM_BITS)
end

function BaleCounter:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self[BaleCounter.SPEC_TABLE_NAME]

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInputIgnoreSelection then
			local _, actionEventId = self:addPoweredActionEvent(spec.actionEvents, InputAction.BALE_COUNTER_RESET, self, BaleCounter.actionEventResetCounter, false, true, false, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
		end
	end
end

function BaleCounter:actionEventResetCounter(actionName, inputValue, callbackState, isAnalog)
	self:doBaleCounterReset()
end

function BaleCounter:doBaleCounterReset(noEventSend)
	local spec = self[BaleCounter.SPEC_TABLE_NAME]
	spec.sessionCounter = 0

	BaleCounterResetEvent.sendEvent(self, noEventSend)
end

function BaleCounter:dropBale(superFunc, baleIndex)
	superFunc(self, baleIndex)

	local spec = self[BaleCounter.SPEC_TABLE_NAME]
	spec.sessionCounter = spec.sessionCounter + 1
	spec.lifetimeCounter = spec.lifetimeCounter + 1
end
