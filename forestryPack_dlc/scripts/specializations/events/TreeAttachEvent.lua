local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

TreeAttachEvent = {}
local TreeAttachEvent_mt = Class(TreeAttachEvent, Event)

InitEventClass(TreeAttachEvent, "TreeAttachEvent")

function TreeAttachEvent.emptyNew()
	local self = Event.new(TreeAttachEvent_mt)

	return self
end

function TreeAttachEvent.new(object, splitShapeId, x, y, z, ropeIndex)
	local self = TreeAttachEvent.emptyNew()
	self.object = object
	self.splitShapeId = splitShapeId
	self.x = x
	self.y = y
	self.z = z
	self.ropeIndex = ropeIndex

	return self
end

function TreeAttachEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.splitShapeId = readSplitShapeIdFromStream(streamId)
	self.x = streamReadFloat32(streamId)
	self.y = streamReadFloat32(streamId)
	self.z = streamReadFloat32(streamId)

	if streamReadBool(streamId) then
		self.ropeIndex = streamReadUIntN(streamId, 4)
	end

	self:run(connection)
end

function TreeAttachEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	writeSplitShapeIdToStream(streamId, self.splitShapeId)
	streamWriteFloat32(streamId, self.x)
	streamWriteFloat32(streamId, self.y)
	streamWriteFloat32(streamId, self.z)

	if streamWriteBool(streamId, self.ropeIndex ~= nil) then
		streamWriteUIntN(streamId, self.ropeIndex, 4)
	end
end

function TreeAttachEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() then
		if self.object.attachTreeToCarriage ~= nil then
			self.object:attachTreeToCarriage(self.splitShapeId, self.x, self.y, self.z, self.ropeIndex, true)
		elseif self.object.attachTreeToWinch ~= nil then
			self.object:attachTreeToWinch(self.splitShapeId, self.x, self.y, self.z, self.ropeIndex, nil, true)
		end
	end
end

function TreeAttachEvent.sendEvent(vehicle, splitShapeId, x, y, z, ropeIndex, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(TreeAttachEvent.new(vehicle, splitShapeId, x, y, z, ropeIndex), nil, , vehicle)
		else
			g_client:getServerConnection():sendEvent(TreeAttachEvent.new(vehicle, splitShapeId, x, y, z, ropeIndex))
		end
	end
end
