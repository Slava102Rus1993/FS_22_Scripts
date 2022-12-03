ManureSeparatorPlaceable = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(PlaceablePlacement, specializations)
	end
}

function ManureSeparatorPlaceable.registerOverwrittenFunctions(placeableType)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "setOwnerFarmId", ManureSeparatorPlaceable.setOwnerFarmId)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getCanBePlacedAt", ManureSeparatorPlaceable.getCanBePlacedAt)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", ManureSeparatorPlaceable.updateInfo)
end

function ManureSeparatorPlaceable.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", ManureSeparatorPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onDelete", ManureSeparatorPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", ManureSeparatorPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onReadStream", ManureSeparatorPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onWriteStream", ManureSeparatorPlaceable)
end

function ManureSeparatorPlaceable.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("ManureSeparator")
	schema:register(XMLValueType.BOOL, basePath .. ".manureSeparator#isExtension", "Is extension and can only be placed next to storages", true)
	ManureSeparator.registerXMLPaths(schema, basePath .. ".manureSeparator")
	schema:setXMLSpecializationType()
end

function ManureSeparatorPlaceable.registerSavegameXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("ManureSeparator")
	ManureSeparator.registerSavegameXMLPaths(schema, basePath)
	schema:setXMLSpecializationType()
end

function ManureSeparatorPlaceable.initSpecialization()
	g_storeManager:addSpecType("manureSeparatorCapacity", "shopListAttributeIconCapacity", ManureSeparatorPlaceable.loadSpecValueCapacity, ManureSeparatorPlaceable.getSpecValueCapacity, "placeable")
end

function ManureSeparatorPlaceable:onLoad(savegame)
	self.spec_manureSeparator = self[("spec_%s.manureSeparator"):format(ManureSeparatorPlaceable.MOD_NAME)]
	local spec = self.spec_manureSeparator
	local separator = ManureSeparator.new(self, self.isServer, self.isClient)

	if separator:load(self.components, self.xmlFile, "placeable.manureSeparator", self.customEnvironment, self.i3dMappings, self.components[1].node) then
		spec.separator = separator
	else
		spec.separator:delete()
	end

	spec.infoFillLevel = {
		text = "",
		title = g_i18n:getText("fillType_separatedManure")
	}
end

function ManureSeparatorPlaceable:onDelete()
	local spec = self.spec_manureSeparator

	if spec == nil then
		return
	end

	if spec.separator ~= nil then
		local storageSystem = g_currentMission.storageSystem

		if storageSystem:hasStorage(spec.separator) then
			storageSystem:removeStorageFromUnloadingStations(spec.separator, spec.separator.unloadingStations)
			storageSystem:removeStorageFromLoadingStations(spec.separator, spec.separator.loadingStations)
			storageSystem:removeStorage(spec.separator)
		end

		spec.separator:delete()

		spec.separator = nil
	end
end

function ManureSeparatorPlaceable:onFinalizePlacement()
	local spec = self.spec_manureSeparator
	local storageSystem = g_currentMission.storageSystem
	local ownerFarmId = self:getOwnerFarmId()

	if spec.separator ~= nil then
		spec.separator:finalize()
		spec.separator:register(true)
		spec.separator:setOwnerFarmId(ownerFarmId, true)
		storageSystem:addStorage(spec.separator)

		local lastFoundUnloadingStations = storageSystem:getExtendableUnloadingStationsInRange(spec.separator, ownerFarmId)
		local lastFoundLoadingStations = storageSystem:getExtendableLoadingStationsInRange(spec.separator, ownerFarmId)

		storageSystem:addStorageToUnloadingStations(spec.separator, lastFoundUnloadingStations)
		storageSystem:addStorageToLoadingStations(spec.separator, lastFoundLoadingStations)
	end
end

function ManureSeparatorPlaceable:onReadStream(streamId, connection)
	local spec = self.spec_manureSeparator

	if spec.separator ~= nil then
		local objectId = NetworkUtil.readNodeObjectId(streamId)

		spec.separator:readStream(streamId, connection)
		g_client:finishRegisterObject(spec.separator, objectId)
	end
end

function ManureSeparatorPlaceable:onWriteStream(streamId, connection)
	local spec = self.spec_manureSeparator

	if spec.separator ~= nil then
		NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(spec.separator))
		spec.separator:writeStream(streamId, connection)
		g_server:registerObjectInStream(connection, spec.separator)
	end
end

function ManureSeparatorPlaceable:loadFromXMLFile(xmlFile, key)
	local spec = self.spec_manureSeparator

	if spec.separator ~= nil then
		spec.separator:loadFromXMLFile(xmlFile, key)
	end
end

function ManureSeparatorPlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_manureSeparator

	if spec.separator ~= nil then
		spec.separator:saveToXMLFile(xmlFile, key, usedModNames)
	end
end

function ManureSeparatorPlaceable:setOwnerFarmId(superFunc, farmId, noEventSend)
	superFunc(self, farmId, noEventSend)

	if self.isServer then
		local spec = self.spec_manureSeparator

		if spec.separator ~= nil then
			spec.separator:setOwnerFarmId(farmId, true)
		end
	end
end

function ManureSeparatorPlaceable:getCanBePlacedAt(superFunc, x, y, z, farmId)
	local spec = self.spec_manureSeparator

	if spec.separator == nil then
		return false
	end

	return superFunc(self, x, y, z, farmId)
end

function ManureSeparatorPlaceable:updateInfo(superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_manureSeparator

	if spec.separator == nil then
		return
	end

	local fillLevel = spec.separator:getFillLevel(spec.separator.fillTypeIndex)
	spec.infoFillLevel.text = string.format("%d l", fillLevel)

	table.insert(infoTable, spec.infoFillLevel)
end

function ManureSeparatorPlaceable.loadSpecValueCapacity(xmlFile, customEnvironment, baseDir)
	return xmlFile:getValue("placeable.manureSeparator#capacity")
end

function ManureSeparatorPlaceable.getSpecValueCapacity(storeItem, realItem)
	if storeItem.specs.manureSeparatorCapacity == nil then
		return nil
	end

	return g_i18n:formatVolume(storeItem.specs.manureSeparatorCapacity)
end
