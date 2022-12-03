local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

TreeMarkerEvent = {}
local TreeMarkerEvent_mt = Class(TreeMarkerEvent, Event)

InitEventClass(TreeMarkerEvent, "TreeMarkerEvent")

function TreeMarkerEvent.emptyNew()
	local self = Event.new(TreeMarkerEvent_mt)

	return self
end

function TreeMarkerEvent.new(treeMarkers)
	local self = TreeMarkerEvent.emptyNew()

	assert(#treeMarkers <= 255, "Max num of treemarkers per event is 255")

	self.treeMarkers = treeMarkers

	return self
end

function TreeMarkerEvent:readStream(streamId, connection)
	local paramsX = g_currentMission.treeMarkerSystem.xTreePosCompressionParams
	local paramsY = g_currentMission.treeMarkerSystem.yTreePosCompressionParams
	self.treeMarkers = {}
	local numMarkers = streamReadUInt8(streamId)

	for i = 1, numMarkers do
		local treeMarker = {
			splitShapeId = readSplitShapeIdFromStream(streamId),
			treeMarkerTypeIndex = streamReadUInt8(streamId),
			r = streamReadUInt8(streamId) / 255,
			g = streamReadUInt8(streamId) / 255,
			b = streamReadUInt8(streamId) / 255,
			a = streamReadUInt8(streamId) / 255,
			posX = NetworkUtil.readCompressedWorldPosition(streamId, paramsX),
			posY = NetworkUtil.readCompressedWorldPosition(streamId, paramsY)
		}
		local rot = streamReadUIntN(streamId, 9)
		treeMarker.rotY = rot / 511 * math.pi * 2
		local scale = streamReadUIntN(streamId, 9)
		treeMarker.scale = scale / 511

		table.insert(self.treeMarkers, treeMarker)
	end

	self:run(connection)
end

function TreeMarkerEvent:writeStream(streamId, connection)
	local paramsX = g_currentMission.treeMarkerSystem.xTreePosCompressionParams
	local paramsY = g_currentMission.treeMarkerSystem.yTreePosCompressionParams

	streamWriteUInt8(streamId, #self.treeMarkers)

	for _, treeMarker in ipairs(self.treeMarkers) do
		writeSplitShapeIdToStream(streamId, treeMarker.splitShapeId)
		streamWriteUInt8(streamId, treeMarker.treeMarkerTypeIndex)
		streamWriteUInt8(streamId, treeMarker.r * 255)
		streamWriteUInt8(streamId, treeMarker.g * 255)
		streamWriteUInt8(streamId, treeMarker.b * 255)
		streamWriteUInt8(streamId, treeMarker.a * 255)
		NetworkUtil.writeCompressedWorldPosition(streamId, treeMarker.posX, paramsX)
		NetworkUtil.writeCompressedWorldPosition(streamId, treeMarker.posY, paramsY)

		local rot = treeMarker.rotY % (math.pi * 2)

		streamWriteUIntN(streamId, MathUtil.clamp(math.floor(rot / (math.pi * 2) * 511), 0, 511), 9)

		local scale = math.floor(treeMarker.scale * 511)

		streamWriteUIntN(streamId, scale, 9)
	end
end

function TreeMarkerEvent:run(connection)
	for _, treeMarker in ipairs(self.treeMarkers) do
		local splitShapeId = treeMarker.splitShapeId
		local treeMarkerTypeIndex = treeMarker.treeMarkerTypeIndex
		local r = treeMarker.r
		local g = treeMarker.g
		local b = treeMarker.b
		local a = treeMarker.a
		local posX = treeMarker.posX
		local posY = treeMarker.posY
		local scale = treeMarker.scale
		local rotY = treeMarker.rotY

		g_currentMission.treeMarkerSystem:addTreeMarker(splitShapeId, treeMarkerTypeIndex, r, g, b, a, posX, posY, scale, rotY, true)
	end
end
