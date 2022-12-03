OnCreateObjectSystem = {}
local OnCreateObjectSystem_mt = Class(OnCreateObjectSystem)

g_xmlManager:addCreateSchemaFunction(function ()
	OnCreateObjectSystem.xmlSchemaSavegame = XMLSchema.new("onCreateObjects")
end)
g_xmlManager:addInitSchemaFunction(function ()
	local schema = OnCreateObjectSystem.xmlSchemaSavegame

	schema:register(XMLValueType.STRING, "onCreateLoadedObjects.object(?)#saveId", "SaveID of the object")
end)

function OnCreateObjectSystem.new(mission, customMt)
	local self = setmetatable({}, customMt or OnCreateObjectSystem_mt)
	self.mission = mission
	self.objects = {}
	self.objectsToSave = {}
	self.numObjectsToSave = 0

	return self
end

function OnCreateObjectSystem:delete()
end

function OnCreateObjectSystem:save(xmlFilename, usedModNames)
	local xmlFile = XMLFile.create("onCreateObjectsXMLFile", xmlFilename, "onCreateLoadedObjects", OnCreateObjectSystem.xmlSchemaSavegame)

	xmlFile:setTable("onCreateLoadedObjects.object", self.objectsToSave, function (key, object, saveId)
		xmlFile:setValue(key .. "#saveId", saveId)
		object:saveToXMLFile(xmlFile, key, usedModNames)
	end)
	xmlFile:save()
	xmlFile:delete()
end

function OnCreateObjectSystem:load(xmlFilename)
	local xmlFile = XMLFile.load("onCreateLoadedObjectsXML", xmlFilename, OnCreateObjectSystem.xmlSchemaSavegame)

	xmlFile:iterate("onCreateLoadedObjects.object", function (i, key)
		local saveId = xmlFile:getValue(key .. "#saveId")

		if saveId ~= nil then
			local object = self.objectsToSave[saveId]

			if object ~= nil then
				if object.loadFromXMLFile == nil or not object:loadFromXMLFile(xmlFile, key) then
					Logging.warning("Corrupt savegame, onCreateLoadedObject %d with saveId %s could not be loaded", i, saveId)
				end
			else
				Logging.error("Corrupt savegame, onCreateLoadedObject %d has invalid saveId '%s'", i, saveId)
			end
		end
	end)
	xmlFile:delete()
end

function OnCreateObjectSystem:add(object, saved)
	if not self.mission.isLoadingMap then
		Logging.error("OnCreateObjectSystem:add(): only allowed to add objects while loading maps")
		printCallstack()

		return
	end

	if self.mission.userManager:getNumberOfUsers() > 1 then
		Logging.error("OnCreateObjectSystem:add() is only allowed during map loading when no client is connected")
		printCallstack()

		return
	end

	if saved then
		if object.saveToXMLFile == nil then
			Logging.error("Adding onCreate loaded object so save which does not have a saveToXMLFile function")

			return
		end

		if object.saveId == nil then
			Logging.error("Adding onCreate loaded object with invalid saveId")

			return
		end

		local prevObject = self.objectsToSave[object.saveId]

		if prevObject == object then
			return
		end

		if prevObject ~= nil then
			Logging.error("Adding onCreate loaded object with duplicate saveId %s", object.saveId)

			return
		end

		self.objectsToSave[object.saveId] = object
		self.numObjectsToSave = self.numObjectsToSave + 1
	end

	table.insert(self.objects, object)
end

function OnCreateObjectSystem:remove(object)
	table.removeElement(self.objects, object)

	if object.saveId ~= nil then
		local prevObject = self.objectsToSave[object.saveId]

		if prevObject == object then
			self.objectsToSave[object.saveId] = nil
			self.numObjectsToSave = self.numObjectsToSave - 1
		end
	end
end

function OnCreateObjectSystem:getNumObjects()
	return #self.objects
end

function OnCreateObjectSystem:get(index)
	return self.objects[index]
end
