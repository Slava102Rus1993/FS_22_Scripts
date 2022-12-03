local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

SprayCanEvent = {}
local SprayCanEvent_mt = Class(SprayCanEvent, Event)

InitEventClass(SprayCanEvent, "SprayCanEvent")

function SprayCanEvent.emptyNew()
	local self = Event.new(SprayCanEvent_mt)

	return self
end

function SprayCanEvent.new(player, treeMarkerTypeIndex, splitShapeId, x, y, z, hitX, hitY, hitZ)
	local self = SprayCanEvent.emptyNew()
	self.player = player
	self.treeMarkerTypeIndex = treeMarkerTypeIndex
	self.splitShapeId = splitShapeId
	self.x = x
	self.y = y
	self.z = z
	self.hitX = hitX
	self.hitY = hitY
	self.hitZ = hitZ

	return self
end

function SprayCanEvent:readStream(streamId, connection)
	self.player = NetworkUtil.readNodeObject(streamId)
	self.treeMarkerTypeIndex = streamReadUInt8(streamId)

	if streamReadBool(streamId) then
		self.splitShapeId = readSplitShapeIdFromStream(streamId)
		local paramsXZ = g_currentMission.treeMarkerSystem.xzWorldPosCompressionParams
		local paramsY = g_currentMission.treeMarkerSystem.yWorldPosCompressionParams
		self.x = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
		self.y = NetworkUtil.readCompressedWorldPosition(streamId, paramsY)
		self.z = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
		self.hitX = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
		self.hitY = NetworkUtil.readCompressedWorldPosition(streamId, paramsY)
		self.hitZ = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
	end

	self:run(connection)
end

function SprayCanEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.player)
	streamWriteUInt8(streamId, self.treeMarkerTypeIndex)

	if streamWriteBool(streamId, self.splitShapeId ~= nil) then
		writeSplitShapeIdToStream(streamId, self.splitShapeId)

		local paramsXZ = g_currentMission.treeMarkerSystem.xzWorldPosCompressionParams
		local paramsY = g_currentMission.treeMarkerSystem.yWorldPosCompressionParams

		NetworkUtil.writeCompressedWorldPosition(streamId, self.x, paramsXZ)
		NetworkUtil.writeCompressedWorldPosition(streamId, self.y, paramsY)
		NetworkUtil.writeCompressedWorldPosition(streamId, self.z, paramsXZ)
		NetworkUtil.writeCompressedWorldPosition(streamId, self.hitX, paramsXZ)
		NetworkUtil.writeCompressedWorldPosition(streamId, self.hitY, paramsY)
		NetworkUtil.writeCompressedWorldPosition(streamId, self.hitZ, paramsXZ)
	end
end

function SprayCanEvent:run(connection)
	if g_currentMission:getIsServer() then
		g_server:broadcastEvent(SprayCanEvent.new(self.player, self.treeMarkerTypeIndex, self.splitShapeId, self.x, self.y, self.z, self.hitX, self.hitY, self.hitZ), false)
	end

	if self.player ~= nil then
		local currentTool = self.player.baseInformation.currentHandtool

		if currentTool ~= nil and currentTool.spray ~= nil then
			currentTool:spray(self.treeMarkerTypeIndex, self.splitShapeId, self.x, self.y, self.z, self.hitX, self.hitY, self.hitZ)
		end
	end
end
