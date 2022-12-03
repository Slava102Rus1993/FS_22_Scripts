LindnerSuperCupArea = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return true
	end,
	registerFunctions = function (placeableType)
	end,
	registerXMLPaths = function (schema, basePath)
		schema:setXMLSpecializationType("LindnerSuperCupArea")
		SuperCup.registerXMLPaths(schema, basePath .. ".superCupArea")
		schema:setXMLSpecializationType()
	end,
	registerEventListeners = function (placeableType)
		SpecializationUtil.registerEventListener(placeableType, "onLoad", LindnerSuperCupArea)
		SpecializationUtil.registerEventListener(placeableType, "onDelete", LindnerSuperCupArea)
		SpecializationUtil.registerEventListener(placeableType, "onWriteStream", LindnerSuperCupArea)
		SpecializationUtil.registerEventListener(placeableType, "onReadStream", LindnerSuperCupArea)
		SpecializationUtil.registerEventListener(placeableType, "onReadUpdateStream", LindnerSuperCupArea)
		SpecializationUtil.registerEventListener(placeableType, "onWriteUpdateStream", LindnerSuperCupArea)
		SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", LindnerSuperCupArea)
		SpecializationUtil.registerEventListener(placeableType, "onUpdate", LindnerSuperCupArea)
	end
}

function LindnerSuperCupArea:onLoad(savegame)
	self.spec_superCup = self[("spec_%s.superCup"):format(LindnerSuperCupArea.MOD_NAME)]
	local spec = self.spec_superCup
	local xmlFile = self.xmlFile
	spec.superCup = SuperCup:new(g_currentMission, self.baseDirectory, self.customEnvironment, self:getOwnerFarmId(), self.rootNode, self)

	spec.superCup:loadFromXML(xmlFile, "placeable.superCupArea", self.components, self.i3dMappings)

	spec.dirtyFlag = self:getNextDirtyFlag()
end

function LindnerSuperCupArea:onDelete()
	local spec = self.spec_superCup

	if spec ~= nil then
		spec.superCup:delete()
	end
end

function LindnerSuperCupArea:onReadStream(streamId, connection)
	local spec = self.spec_superCup

	if connection:getIsServer() and spec.superCup ~= nil then
		spec.superCup:readStream(streamId, connection)
	end
end

function LindnerSuperCupArea:onWriteStream(streamId, connection)
	local spec = self.spec_superCup

	if not connection:getIsServer() and spec.superCup ~= nil then
		spec.superCup:writeStream(streamId, connection)
	end
end

function LindnerSuperCupArea:onReadUpdateStream(streamId, timestamp, connection)
	local spec = self.spec_superCup

	if connection:getIsServer() and spec.superCup ~= nil then
		spec.superCup:readUpdateStream(streamId, timestamp, connection)
	end
end

function LindnerSuperCupArea:onWriteUpdateStream(streamId, connection, dirtyMask)
	local spec = self.spec_superCup

	if not connection:getIsServer() and spec.superCup ~= nil then
		spec.superCup:writeUpdateStream(streamId, connection, dirtyMask)
	end
end

function LindnerSuperCupArea:loadFromXMLFile(xmlFile, key)
	local spec = self.spec_superCup
end

function LindnerSuperCupArea:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_superCup

	spec.superCup:saveToXMLFile(xmlFile, key .. ".superCupArea", usedModNames)
end

function LindnerSuperCupArea:onFinalizePlacement()
	self:raiseActive()
end

function LindnerSuperCupArea:onUpdate(dt)
	local spec = self.spec_superCup

	self:raiseActive()
	spec.superCup:update(dt)
	spec.superCup:draw()

	if self.isServer and spec.superCup.started then
		self:raiseDirtyFlags(spec.dirtyFlag)
	end
end
