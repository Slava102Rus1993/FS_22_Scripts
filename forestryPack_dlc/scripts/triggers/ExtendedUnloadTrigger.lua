ExtendedUnloadTrigger = {}
local ExtendedUnloadTrigger_mt = Class(ExtendedUnloadTrigger, UnloadTrigger)

InitObjectClass(ExtendedUnloadTrigger, "ExtendedUnloadTrigger")

function ExtendedUnloadTrigger.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.STRING, basePath .. ".woodTrigger(?)#class", "Name of wood trigger class")
	WoodUnloadTrigger.registerXMLPaths(schema, basePath .. ".woodTrigger(?)")
end

UnloadTrigger.registerXMLPaths = Utils.appendedFunction(UnloadTrigger.registerXMLPaths, ExtendedUnloadTrigger.registerXMLPaths)

function ExtendedUnloadTrigger.new(isServer, isClient, customMt)
	local self = UnloadTrigger.new(isServer, isClient, customMt or ExtendedUnloadTrigger_mt)

	return self
end

function ExtendedUnloadTrigger:load(components, xmlFile, xmlNode, target, extraAttributes, i3dMappings)
	local baleTriggerKey = xmlNode .. ".baleTrigger"

	if xmlFile:hasProperty(baleTriggerKey) then
		local className = xmlFile:getValue(baleTriggerKey .. "#class", "BaleUnloadTrigger")
		local class = ClassUtil.getClassObject(className)

		if class == nil then
			Logging.xmlError(xmlFile, "BaleTrigger class '%s' not defined", className, baleTriggerKey)

			return false
		end

		self.baleTrigger = class.new(self.isServer, self.isClient)

		if self.baleTrigger:load(components, xmlFile, baleTriggerKey, self, i3dMappings) then
			self.baleTrigger:setTarget(self)
			self.baleTrigger:register(true)
		else
			self.baleTrigger = nil
		end
	end

	self.woodTriggers = {}

	xmlFile:iterate(xmlNode .. ".woodTrigger", function (index, woodTriggerKey)
		local className = xmlFile:getValue(woodTriggerKey .. "#class", "WoodUnloadTrigger")
		local class = ClassUtil.getClassObject(className)

		if class == nil then
			Logging.xmlError(xmlFile, "WoodTrigger class '%s' not defined", className, woodTriggerKey)

			return false
		end

		local woodTrigger = class.new(self.isServer, self.isClient)

		if woodTrigger:load(components, xmlFile, woodTriggerKey, self, i3dMappings) then
			woodTrigger:setTarget(self)
			woodTrigger:register(true)
			table.insert(self.woodTriggers, woodTrigger)
		end
	end)

	self.exactFillRootNode = xmlFile:getValue(xmlNode .. "#exactFillRootNode", nil, components, i3dMappings)

	if self.exactFillRootNode ~= nil then
		if not CollisionFlag.getHasFlagSet(self.exactFillRootNode, CollisionFlag.FILLABLE) then
			Logging.xmlWarning(xmlFile, "Missing collision mask bit '%d'. Please add this bit to exact fill root node '%s' of unloadTrigger", CollisionFlag.getBit(CollisionFlag.FILLABLE), I3DUtil.getNodePath(self.exactFillRootNode))

			return false
		end

		g_currentMission:addNodeObject(self.exactFillRootNode, self)
	end

	self.aiNode = xmlFile:getValue(xmlNode .. "#aiNode", nil, components, i3dMappings)
	self.supportsAIUnloading = self.aiNode ~= nil
	local priceScale = xmlFile:getValue(xmlNode .. "#priceScale", nil)

	if priceScale ~= nil then
		self.extraAttributes = {
			priceScale = priceScale
		}
	end

	xmlFile:iterate(xmlNode .. ".fillTypeConversion", function (index, fillTypeConversionPath)
		local fillTypeIndexIncoming = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(fillTypeConversionPath .. "#incomingFillType"))

		if fillTypeIndexIncoming ~= nil then
			local fillTypeIndexOutgoing = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(fillTypeConversionPath .. "#outgoingFillType"))

			if fillTypeIndexOutgoing ~= nil then
				local ratio = MathUtil.clamp(xmlFile:getValue(fillTypeConversionPath .. "#ratio", 1), 0.01, 10000)
				self.fillTypeConversions[fillTypeIndexIncoming] = {
					outgoingFillType = fillTypeIndexOutgoing,
					ratio = ratio
				}
			end
		end
	end)

	if target ~= nil then
		self:setTarget(target)
	end

	self:loadFillTypes(xmlFile, xmlNode)
	self:loadAcceptedToolType(xmlFile, xmlNode)
	self:loadAvoidFillTypes(xmlFile, xmlNode)

	self.isEnabled = true
	self.extraAttributes = extraAttributes or self.extraAttributes

	return true
end

function ExtendedUnloadTrigger:delete()
	for i = 1, #self.woodTriggers do
		self.woodTriggers[i]:delete()
	end

	ExtendedUnloadTrigger:superClass().delete(self)
end

function ExtendedUnloadTrigger:readStream(streamId, connection)
	ExtendedUnloadTrigger:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then
		if self.baleTrigger ~= nil then
			local baleTriggerId = NetworkUtil.readNodeObjectId(streamId)

			self.baleTrigger:readStream(streamId, connection)
			g_client:finishRegisterObject(self.baleTrigger, baleTriggerId)
		end

		for i = 1, #self.woodTriggers do
			local woodTriggerId = NetworkUtil.readNodeObjectId(streamId)

			self.woodTriggers[i]:readStream(streamId, connection)
			g_client:finishRegisterObject(self.woodTriggers[i], woodTriggerId)
		end
	end
end

function ExtendedUnloadTrigger:writeStream(streamId, connection)
	ExtendedUnloadTrigger:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		if self.baleTrigger ~= nil then
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.baleTrigger))
			self.baleTrigger:writeStream(streamId, connection)
			g_server:registerObjectInStream(connection, self.baleTrigger)
		end

		for i = 1, #self.woodTriggers do
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.woodTriggers[i]))
			self.woodTriggers[i]:writeStream(streamId, connection)
			g_server:registerObjectInStream(connection, self.woodTriggers[i])
		end
	end
end

function ExtendedUnloadTrigger:setOwnerFarmId(farmId, noEventSend)
	ExtendedUnloadTrigger:superClass().setOwnerFarmId(self, farmId, noEventSend)

	if self.baleTrigger ~= nil then
		self.baleTrigger:setOwnerFarmId(farmId, true)
	end

	for i = 1, #self.woodTriggers do
		self.woodTriggers[i]:setOwnerFarmId(farmId, true)
	end
end
