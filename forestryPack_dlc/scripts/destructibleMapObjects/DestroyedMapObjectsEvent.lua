local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

DestroyedMapObjectsEvent = {}
local DestroyedMapObjectsEvent_mt = Class(DestroyedMapObjectsEvent, Event)

InitEventClass(DestroyedMapObjectsEvent, "DestroyedMapObjectsEvent")

function DestroyedMapObjectsEvent.emptyNew()
	local self = Event.new(DestroyedMapObjectsEvent_mt)

	return self
end

function DestroyedMapObjectsEvent.new(groupId, childIndicesStatus)
	local self = DestroyedMapObjectsEvent.emptyNew()
	self.groupId = groupId
	self.childIndicesStatus = childIndicesStatus

	return self
end

function DestroyedMapObjectsEvent:readStream(streamId, connection)
	self.groupId = streamReadUIntN(streamId, DestructibleMapObjectSystem.GROUP_ID_NUM_BITS)
	local numChildIndices = streamReadUIntN(streamId, DestructibleMapObjectSystem.CHILD_INDEX_NUM_BITS)
	self.childIndicesStatus = {}

	for i = 1, numChildIndices do
		self.childIndicesStatus[i] = streamReadBool(streamId)
	end

	self:run(connection)
end

function DestroyedMapObjectsEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.groupId, DestructibleMapObjectSystem.GROUP_ID_NUM_BITS)
	streamWriteUIntN(streamId, #self.childIndicesStatus, DestructibleMapObjectSystem.CHILD_INDEX_NUM_BITS)

	for _, childVisibility in ipairs(self.childIndicesStatus) do
		streamWriteBool(streamId, childVisibility)
	end
end

function DestroyedMapObjectsEvent:run(connection)
	if connection:getIsServer() and self.groupId and self.childIndicesStatus then
		for childIndex, isDestroyed in ipairs(self.childIndicesStatus) do
			if isDestroyed then
				g_currentMission.destructibleMapObjectSystem:setGroupChildIndexDestroyed(self.groupId, childIndex - 1, false, false)
			end
		end
	end
end
