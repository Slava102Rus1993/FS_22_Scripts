MobileManureSeparator = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations)
	end,
	registerEventListeners = function (vehicleType)
		SpecializationUtil.registerEventListener(vehicleType, "onLoad", MobileManureSeparator)
		SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", MobileManureSeparator)
		SpecializationUtil.registerEventListener(vehicleType, "onDelete", MobileManureSeparator)
		SpecializationUtil.registerEventListener(vehicleType, "onReadStream", MobileManureSeparator)
		SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", MobileManureSeparator)
		SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", MobileManureSeparator)
		SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", MobileManureSeparator)
	end
}

function MobileManureSeparator.initSpecialization()
	local schema = Vehicle.xmlSchema

	MobileManureSeparator.registerXMLPaths(schema, "vehicle.manureSeparator")

	local schemaSavegame = Vehicle.xmlSchemaSavegame
	local modName = g_manureModName

	MobileManureSeparator.registerSavegameXMLPaths(schemaSavegame, ("vehicles.vehicle(?).%s.manureSeparator"):format(modName))
end

function MobileManureSeparator.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("ManureSeparator")
	ManureSeparator.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.BOOL, basePath .. "#isExtension", "Is extension and can only be placed next to storages", true)
	schema:setXMLSpecializationType()
end

function MobileManureSeparator.registerSavegameXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("ManureSeparator")
	ManureSeparator.registerSavegameXMLPaths(schema, basePath)
	schema:setXMLSpecializationType()
end

function MobileManureSeparator:onLoad(savegame)
	self.spec_manureSeparator = self[("spec_%s.manureSeparator"):format(MobileManureSeparator.MOD_NAME)]
	local spec = self.spec_manureSeparator
	local separator = ManureSeparator.new(self, self.isServer, self.isClient)

	if separator:load(self.components, self.xmlFile, "vehicle.manureSeparator", self.customEnvironment, self.i3dMappings, self.components[1].node) then
		spec.separator = separator
	else
		spec.separator:delete()
	end
end

function MobileManureSeparator:onPostLoad(savegame)
	local spec = self.spec_manureSeparator
	local ownerFarmId = self:getOwnerFarmId()

	if spec.separator ~= nil then
		spec.separator:finalize()
		spec.separator:register(true)
		spec.separator:setOwnerFarmId(ownerFarmId, true)
	end
end

function MobileManureSeparator:onDelete()
	local spec = self.spec_manureSeparator

	if spec.separator ~= nil then
		spec.separator:delete()

		spec.separator = nil
	end
end

function MobileManureSeparator:onReadStream(streamId, connection)
	local spec = self.spec_manureSeparator

	if spec.separator ~= nil then
		local objectId = NetworkUtil.readNodeObjectId(streamId)

		spec.separator:readStream(streamId, connection)
		g_client:finishRegisterObject(spec.separator, objectId)
	end
end

function MobileManureSeparator:onWriteStream(streamId, connection)
	local spec = self.spec_manureSeparator

	if spec.separator ~= nil then
		NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(spec.separator))
		spec.separator:writeStream(streamId, connection)
		g_server:registerObjectInStream(connection, spec.separator)
	end
end

function MobileManureSeparator:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_manureSeparator

	if spec.separator ~= nil then
		spec.separator:saveToXMLFile(xmlFile, key, usedModNames)
	end
end

function MobileManureSeparator:onEnterVehicle()
	local spec = self.spec_manureSeparator

	if spec.separator ~= nil then
		g_currentMission.activatableObjectsSystem:addActivatable(spec.separator.activatable)
	end
end

function MobileManureSeparator:onLeaveVehicle()
	local spec = self.spec_manureSeparator

	if spec.separator ~= nil then
		g_currentMission.activatableObjectsSystem:removeActivatable(spec.separator.activatable)
	end
end
