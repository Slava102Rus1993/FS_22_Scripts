DensityMapSyncer = {}
local DensityMapSyncer_mt = Class(DensityMapSyncer)

function DensityMapSyncer.new(terrainRootNode, cellSizeInPixels, customMt)
	local self = setmetatable({}, customMt or DensityMapSyncer_mt)
	self.cellSize = cellSizeInPixels
	self.updateListeners = {}
	self.densityMapSizes = {}
	self.syncerId = createDensityMapSyncer("DensityMapSyncer", terrainRootNode, self.cellSize)

	return self
end

function DensityMapSyncer:delete()
	if self.syncerId ~= nil then
		delete(self.syncerId)
	end
end

function DensityMapSyncer:addDensityMap(densityMapId)
	if self.syncerId ~= nil then
		addDensityMapSyncerDensityMap(self.syncerId, densityMapId)
	end
end

function DensityMapSyncer:addConnection(streamId)
	if self.syncerId ~= nil then
		addDensityMapSyncerConnection(self.syncerId, streamId)
	end
end

function DensityMapSyncer:removeConnection(streamId)
	if self.syncerId ~= nil then
		removeDensityMapSyncerConnection(self.syncerId, streamId)
	end
end

function DensityMapSyncer:writeUpdateStream(connection, maxPacketSize, x, y, z, viewCoeff, networkDebug)
	if self.syncerId ~= nil then
		local densityStreamOffsetStart = streamGetWriteOffset(connection.streamId)

		if networkDebug then
			streamWriteInt32(connection.streamId, 0)
		end

		writeDensityMapSyncerServerUpdateToStream(self.syncerId, connection.streamId, connection.streamId, x, y, z, viewCoeff, maxPacketSize, connection.lastSeqSent)

		local densityStreamOffsetEnd = streamGetWriteOffset(connection.streamId)
		local densityPacketSize = densityStreamOffsetEnd - densityStreamOffsetStart

		g_server:addPacketSize(connection, NetworkNode.PACKET_DENSITY_MAPS, densityPacketSize / 8)

		if networkDebug then
			streamSetWriteOffset(connection.streamId, densityStreamOffsetStart)
			streamWriteInt32(connection.streamId, densityStreamOffsetEnd - (densityStreamOffsetStart + 32))
			streamSetWriteOffset(connection.streamId, densityStreamOffsetEnd)
		end

		return densityPacketSize
	end

	return 0
end

function DensityMapSyncer:readUpdateStream(connection, networkDebug)
	if self.syncerId ~= nil then
		local startOffset = 0
		local numBits = 0

		if networkDebug then
			startOffset = streamGetReadOffset(connection.streamId)
			numBits = streamReadInt32(connection.streamId)
		end

		readDensityMapSyncerServerUpdateFromStream(self.syncerId, connection.streamId, g_clientInterpDelay, g_packetPhysicsNetworkTime, g_client.tickDuration)

		if networkDebug then
			g_client:checkObjectUpdateDebugReadSize(connection.streamId, numBits, startOffset, "densitymapsyncer")
		end
	end
end

function DensityMapSyncer:onPacketLost(connection, packetId)
	if self.syncerId ~= nil then
		setDensityMapSyncerLostPacket(self.syncerId, connection.streamId, packetId)
	end
end

function DensityMapSyncer:activateFruitUpdateCallback(fruitTypeIndex)
	local desc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)

	if desc.terrainDataPlaneId == nil then
		return nil
	end

	local densityMapId = desc.foliageTransformGroupId

	if self.updateListeners[densityMapId] == nil then
		self.updateListeners[densityMapId] = {}
		self.densityMapSizes[densityMapId] = getDensityMapSize(desc.terrainDataPlaneId)

		setDensityMapSyncerCellChangedCallback(self.syncerId, densityMapId, "onCellUpdate", self)
	end

	return densityMapId
end

function DensityMapSyncer:onCellUpdate(densityMapId, cellX, cellZ)
	local densityMapListeners = self.updateListeners[densityMapId]

	if densityMapListeners == nil then
		return
	end

	local cellId = self:getCellId(densityMapId, cellX, cellZ)
	local listeners = densityMapListeners[cellId]

	if listeners ~= nil then
		for listener, _ in pairs(listeners) do
			listener:onDensityMapSyncerUpdate(densityMapId, cellX, cellZ, cellId)
		end
	end
end

function DensityMapSyncer:getCellId(densityMapId, cellX, cellZ)
	local densityMapSize = self.densityMapSizes[densityMapId]
	local numCellsPerRow = densityMapSize / self.cellSize

	return cellX * numCellsPerRow + cellZ
end

function DensityMapSyncer:addCellUpdateListener(listener, densityMapId, cellX, cellZ)
	local cellId = self:getCellId(densityMapId, cellX, cellZ)
	local densityMapListeners = self.updateListeners[densityMapId]

	if densityMapListeners == nil then
		return nil
	end

	local listeners = densityMapListeners[cellId]

	if listeners == nil then
		listeners = {}
		densityMapListeners[cellId] = listeners

		setEnableDensityMapSyncerCellChangedCallback(self.syncerId, densityMapId, cellX, cellZ, true)
	end

	if listeners[listener] == nil then
		listeners[listener] = 0
	end

	listeners[listener] = listeners[listener] + 1

	return cellId
end

function DensityMapSyncer:removeCellUpdateListener(listener, densityMapId, cellX, cellZ)
	local cellId = self:getCellId(densityMapId, cellX, cellZ)
	local densityMapListeners = self.updateListeners[densityMapId]

	if densityMapListeners == nil then
		return false
	end

	local listeners = densityMapListeners[cellId]

	if listeners == nil then
		return false
	end

	if listeners[listener] == nil then
		return false
	end

	listeners[listener] = listeners[listener] - 1

	if listeners[listener] == 0 then
		listeners[listener] = nil
	end

	if next(listeners) == nil then
		densityMapListeners[cellId] = nil

		setEnableDensityMapSyncerCellChangedCallback(self.syncerId, densityMapId, cellX, cellZ, false)
	end

	return true
end

function DensityMapSyncer:getFruitCellIndicesAtWorldPosition(fruitTypeIndex, x, z)
	local desc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)

	if desc.terrainDataPlaneId == nil then
		return nil
	end

	local densityMapId = desc.terrainDataPlaneId
	local cellX, cellZ = getDensityMapSyncerCellIndicesAtWorldPosition(self.syncerId, densityMapId, x, z)

	return cellX, cellZ
end
