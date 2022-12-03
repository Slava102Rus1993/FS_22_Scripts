I3DShapeContainer = class("I3DShapeContainer")
I3DShapeContainer.DEFAULT_KEY = "DEFAULT"

function I3DShapeContainer:construct(i3DManager, modDirectory)
	self.i3DManager = i3DManager
	self.modDirectory = modDirectory
	self.container = {}
	self.containerByName = {}
	self.sharedIds = {}
end

function I3DShapeContainer:delete()
	for _, sharedId in ipairs(self.sharedIds) do
		if sharedId ~= nil then
			self.i3DManager:releaseSharedI3DFile(sharedId)
		end
	end

	for _, entry in ipairs(self.container) do
		entry:delete()
	end

	self.container = {}
	self.containerByName = {}
	self.sharedIds = {}
end

function I3DShapeContainer:loadByXML(filename)
	local xmlFileFilename = Utils.getFilename(filename, self.modDirectory)
	local xmlFile = XMLFile.load("I3DShapeContainer", xmlFileFilename)

	if xmlFile == nil then
		log("Error: failed to load i3d shape container!")

		return false
	end

	self:loadFromXML(xmlFile, "i3dCacheShapes")
	xmlFile:delete()

	return true
end

function I3DShapeContainer:loadFromXML(xmlFile, baseKey)
	self:loadI3DCacheShapeFromXML(xmlFile, baseKey)
	xmlFile:iterate(baseKey .. ".i3dCacheRoot", function (_, key)
		local filename = xmlFile:getString(key .. "#filename")

		self:loadI3DCacheShapeFromXML(xmlFile, key, filename)
	end)

	return self.container
end

function I3DShapeContainer:loadI3DCacheShapeFromXML(xmlFile, baseKey, rootFilename)
	xmlFile:iterate(baseKey .. ".i3dCacheShape", function (_, key)
		local name = xmlFile:getString(key .. "#name")
		local filename = xmlFile:getString(key .. "#filename", rootFilename)
		local node = xmlFile:getString(key .. "#node", "0")

		self:load(name, filename, node, self.loadedShape)
	end)
end

function I3DShapeContainer:load(key, path, nodeIndex, callback)
	callback = callback or self.loadedShape
	local i3dFilename = Utils.getFilename(path, self.modDirectory)
	local sharedId = self.i3DManager:loadSharedI3DFileAsync(i3dFilename, false, false, callback, self, {
		key,
		nodeIndex,
		i3dFilename
	})

	table.insert(self.sharedIds, sharedId)
end

function I3DShapeContainer:loadedShape(i3dNode, _, args)
	local key, nodeIndex, filename = unpack(args)

	if i3dNode ~= 0 then
		local node = I3DUtil.indexToObject(i3dNode, nodeIndex)

		unlink(node)

		local entry = I3DCacheEntry(node, filename)

		self:registerCacheEntry(key, entry)
		delete(i3dNode)
	end
end

function I3DShapeContainer:registerCacheEntry(key, entry)
	key = key:upper()

	if self.containerByName[key] ~= nil then
		log(("Error: I3DShapeContainer cache key %s already exists!"):format(key))

		return
	end

	table.insert(self.container, entry)

	self.containerByName[key] = entry
end

function I3DShapeContainer:hasDefaultEntry()
	return self.containerByName[I3DShapeContainer.DEFAULT_KEY] ~= nil
end

function I3DShapeContainer:isPerformingRoundTrip(key)
	if key == I3DShapeContainer.DEFAULT_KEY then
		return not self:hasDefaultEntry()
	end

	return false
end

function I3DShapeContainer:getByKeyOrDefault(key)
	if self:isPerformingRoundTrip(key) then
		log(("Error: can't find cache for key: %s!"):format(key))

		return nil
	end

	key = key or I3DShapeContainer.DEFAULT_KEY
	local entry = self.containerByName[key:upper()]

	if entry ~= nil then
		return entry
	end

	return self:getByKeyOrDefault(I3DShapeContainer.DEFAULT_KEY)
end
