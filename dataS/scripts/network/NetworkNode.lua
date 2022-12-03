NetworkNode = {}
local NetworkNode_mt = Class(NetworkNode)
NetworkNode.LOCAL_STREAM_ID = 0
NetworkNode.PACKET_EVENT = 1
NetworkNode.PACKET_VEHICLE = 2
NetworkNode.PACKET_PLAYER = 3
NetworkNode.PACKET_SPLITSHAPES = 4
NetworkNode.PACKET_DENSITY_MAPS = 5
NetworkNode.PACKET_TERRAIN_DEFORM = 6
NetworkNode.PACKET_VOICE_CHAT = 7
NetworkNode.PACKET_OTHERS = 8
NetworkNode.NUM_PACKETS = 8
NetworkNode.CHANNEL_MAIN = 1
NetworkNode.CHANNEL_SECONDARY = 2
NetworkNode.CHANNEL_GROUND = 3
NetworkNode.CHANNEL_CHAT = 4
NetworkNode.OBJECT_SEND_NUM_BITS = 24

function NetworkNode.new(customMt)
	local self = setmetatable({}, customMt or NetworkNode_mt)
	self.objects = {}
	self.objectIds = {}
	self.activeObjects = {}
	self.activeObjectsNextFrame = {}
	self.removedObjects = {}
	self.dirtyObjects = {}
	self.lastUploadedKBs = 0
	self.lastUploadedKBsSmooth = 0
	self.maxUploadedKBs = 0
	self.serverFPS = 60
	self.graphData = {
		[NetworkNode.PACKET_EVENT] = {
			title = "event",
			color = {
				1,
				0,
				0,
				1
			}
		},
		[NetworkNode.PACKET_VEHICLE] = {
			title = "vehicle",
			color = {
				0,
				1,
				0,
				1
			}
		},
		[NetworkNode.PACKET_PLAYER] = {
			title = "player",
			color = {
				0,
				0,
				1,
				1
			}
		},
		[NetworkNode.PACKET_SPLITSHAPES] = {
			title = "split shapes",
			color = {
				1,
				1,
				0,
				1
			}
		},
		[NetworkNode.PACKET_DENSITY_MAPS] = {
			title = "density maps",
			color = {
				0.5,
				0.5,
				0,
				1
			}
		},
		[NetworkNode.PACKET_TERRAIN_DEFORM] = {
			title = "terrain deform",
			color = {
				0.5,
				0.5,
				0.5,
				1
			}
		},
		[NetworkNode.PACKET_VOICE_CHAT] = {
			title = "voice chat",
			color = {
				1,
				0.5,
				0.5,
				1
			}
		},
		[NetworkNode.PACKET_OTHERS] = {
			title = "others",
			color = {
				0,
				1,
				1,
				1
			}
		}
	}
	self.packetGraphs = {}
	self.connectionPacketGraphs = {}
	self.packetBytes = {}

	for i = 1, NetworkNode.NUM_PACKETS do
		local showGraphLabels = i == 1
		self.packetGraphs[i] = Graph.new(80, 0.4, 0.05, 0.55, 0.8, 0, 1000, showGraphLabels, "bytes (max)")
		local color = self.graphData[i].color

		self.packetGraphs[i]:setColor(color[1], color[2], color[3], color[4])

		if showGraphLabels then
			self.packetGraphs[i]:setHorizontalLine(1000, false, 1, 1, 1, 0.2)
			self.packetGraphs[i]:setBackgroundColor(0.2, 0.2, 0.2, 0.3)
		end

		self.packetBytes[i] = {}
		self.connectionPacketGraphs[i] = {}
	end

	self.showNetworkTraffic = false
	self.showNetworkTrafficClients = false
	self.showObjects = false
	self.updateDurationTimer = 0
	self.updateDurationFrames = 0
	self.updateDurationTotalTime = 0

	return self
end

function NetworkNode:delete()
	for _, object in pairs(self.objects) do
		self:unregisterObject(object, true)
		object:delete()
	end

	self.objects = {}
	self.objectIds = {}
	self.activeObjects = {}
	self.activeObjectsNextFrame = {}
	self.removedObjects = {}
	self.dirtyObjects = {}

	for _, connections in pairs(self.connectionPacketGraphs) do
		for connection, graph in pairs(connections) do
			graph:delete()

			connections[connection] = nil
		end
	end

	for i = 1, NetworkNode.NUM_PACKETS do
		self.packetGraphs[i]:delete()
	end
end

function NetworkNode:setNetworkListener(listener)
	self.networkListener = listener
end

function NetworkNode:keyEvent(unicode, sym, modifier, isDown)
end

function NetworkNode:mouseEvent(posX, posY, isDown, isUp, button)
end

function NetworkNode:update(dt)
end

function NetworkNode:updateActiveObjects(dt)
	for id, object in pairs(self.removedObjects) do
		self.activeObjects[id] = nil
		self.activeObjectsNextFrame[id] = nil
		self.removedObjects[id] = nil
	end

	if self.showObjects then
		for _, object in pairs(self.activeObjects) do
			local startTime = getTimeSec()

			if object.recieveUpdates then
				object:update(dt)
			end

			object.profilerUpdateCounter = (object.profilerUpdateCounter or 0) + getTimeSec() - startTime
		end

		self.updateDurationTimer = self.updateDurationTimer + dt
		self.updateDurationFrames = self.updateDurationFrames + 1

		if self.updateDurationTimer >= 1000 then
			self.updateDurationTotalTime = 0

			for _, object in pairs(self.activeObjects) do
				object.profilerUpdateTime = object.profilerUpdateCounter * 1000 / self.updateDurationFrames
				object.profilerUpdateCounter = 0
				self.updateDurationTotalTime = self.updateDurationTotalTime + object.profilerUpdateTime
			end

			self.updateDurationTimer = 0
			self.updateDurationFrames = 0
		end
	else
		for _, object in pairs(self.activeObjects) do
			if object.recieveUpdates then
				object:update(dt)
			end
		end
	end
end

function NetworkNode:updateActiveObjectsTick(dt)
	for i = #self.dirtyObjects, 1, -1 do
		self.dirtyObjects[i] = nil
	end

	for serverId, object in pairs(self.activeObjects) do
		if object.recieveUpdates then
			object:updateTick(dt)
		end

		if object.dirtyMask ~= 0 then
			object.lastServerId = serverId

			table.insert(self.dirtyObjects, object)
		end

		local id = self:getObjectId(object)
		self.activeObjects[id] = nil

		if object.recieveUpdates and self.activeObjectsNextFrame[id] == nil then
			object:updateEnd(dt)
		end
	end

	local oldObject = self.activeObjects
	self.activeObjects = self.activeObjectsNextFrame
	self.activeObjectsNextFrame = oldObject

	return self.dirtyObjects
end

function NetworkNode:drawConnectionNetworkStats(connection, posX, posY, textSize)
	if connection.streamId == NetworkNode.LOCAL_STREAM_ID then
		return false
	end

	local ping, download, upload, packetLoss = netGetConnectionStats(connection.streamId)

	if ping == nil then
		packetLoss = 0
		upload = 0
		download = 0
		ping = 0
	end

	if connection.pingSmooth == nil then
		connection.packetLossSmooth = packetLoss
		connection.uploadSmooth = upload
		connection.downloadSmooth = download
		connection.pingSmooth = ping
	end

	connection.pingSmooth = connection.pingSmooth + (ping - connection.pingSmooth) * 0.2
	connection.downloadSmooth = connection.downloadSmooth + (download - connection.downloadSmooth) * 0.2
	connection.uploadSmooth = connection.uploadSmooth + (upload - connection.uploadSmooth) * 0.2
	connection.packetLossSmooth = connection.packetLossSmooth + (packetLoss - connection.packetLossSmooth) * 0.2
	packetLoss = connection.packetLossSmooth
	upload = connection.uploadSmooth
	download = connection.downloadSmooth
	ping = connection.pingSmooth
	local refTextSize = getCorrectTextSize(0.01)

	renderText(posX, posY, textSize, string.format("%dms", ping))
	renderText(posX + 0.016 * textSize / refTextSize, posY, textSize, string.format("w:%2d", connection.lastSeqSent - connection.highestAckedSeq))
	renderText(posX + 0.029 * textSize / refTextSize, posY, textSize, string.format("d:%4.2fkb/s", download / 1024))
	renderText(posX + 0.061 * textSize / refTextSize, posY, textSize, string.format("u:%4.2fkb/s", upload / 1024))
	renderText(posX + 0.093 * textSize / refTextSize, posY, textSize, string.format("loss:%4.2f%%", packetLoss * 100))
	renderText(posX + 0.126 * textSize / refTextSize, posY, textSize, string.format("comp:%.2f%%", 1 / connection.compressionRatio * 100))

	return true
end

function NetworkNode:getObjectPacketType(object)
	if object == nil then
		return NetworkNode.PACKET_OTHERS
	elseif object:isa(Vehicle) then
		return NetworkNode.PACKET_VEHICLE
	elseif object:isa(Player) then
		return NetworkNode.PACKET_PLAYER
	else
		return NetworkNode.PACKET_OTHERS
	end
end

function NetworkNode:getPacketTypeName(packetType)
	for key, value in pairs(Network) do
		if value == packetType then
			return key
		end
	end

	return "TYPE_UNKNOWN"
end

function NetworkNode:checkObjectUpdateDebugReadSize(streamId, numBits, startOffset, name, object)
	local endOffset = streamGetReadOffset(streamId)
	local readNumBits = endOffset - (startOffset + 32)

	if readNumBits ~= numBits then
		local objectInfo = ""

		if object ~= nil then
			objectInfo = ": " .. object.className

			if object.configFileName ~= nil then
				objectInfo = objectInfo .. " (" .. object.configFileName .. ")"
			end
		end

		print("Error: Not all bits read in object " .. name .. " (" .. readNumBits .. " vs " .. numBits .. ")" .. objectInfo)
	end
end

function NetworkNode:addPacketSize(connection, packetType, packetSizeInBytes)
	if self.showNetworkTraffic or self.showNetworkTrafficClients then
		self.packetBytes[packetType][connection] = (self.packetBytes[packetType][connection] or 0) + packetSizeInBytes
	end
end

function NetworkNode:updatePacketStats(dt)
	if self.showNetworkTraffic or self.showNetworkTrafficClients then
		local packetBytesSum = 0
		local connectionSum = {}

		for i = 1, NetworkNode.NUM_PACKETS do
			local connections = self.packetBytes[i]
			local totalPacketBytes = 0

			for connection, bytes in pairs(connections) do
				if self.clientConnections ~= nil and self.clientConnections[connection.streamId] == nil then
					connections[connection] = nil

					if self.connectionPacketGraphs[i][connection] ~= nil then
						self.connectionPacketGraphs[i][connection]:delete()

						self.connectionPacketGraphs[i][connection] = nil
					end
				end

				if connections[connection] ~= nil then
					if self.connectionPacketGraphs[i][connection] == nil then
						local showGraphLabels = i == 1
						self.connectionPacketGraphs[i][connection] = Graph.new(80, 0, 0, 0.15, 0.25, 0, 7500, showGraphLabels, "bytes", nil, , , getCorrectTextSize(0.008))
						local color = self.graphData[i].color

						self.connectionPacketGraphs[i][connection]:setColor(color[1], color[2], color[3], color[4])

						if showGraphLabels then
							self.connectionPacketGraphs[i][connection]:setHorizontalLine(1000, false, 1, 1, 1, 0.3)
							self.connectionPacketGraphs[i][connection]:setBackgroundColor(0.2, 0.2, 0.2, 0.3)
						end
					end

					if connectionSum[connection] == nil then
						connectionSum[connection] = 0
					end

					self.connectionPacketGraphs[i][connection]:addValue(connectionSum[connection] + bytes, connectionSum[connection])

					connectionSum[connection] = connectionSum[connection] + bytes
					connections[connection] = 0
					totalPacketBytes = totalPacketBytes + bytes
				end
			end

			self.packetGraphs[i]:addValue(packetBytesSum + totalPacketBytes, packetBytesSum)

			packetBytesSum = packetBytesSum + totalPacketBytes
		end

		for i = 1, NetworkNode.NUM_PACKETS do
			self.packetGraphs[i].maxValue = math.max(self.packetGraphs[i].maxValue, packetBytesSum)
		end

		self.lastUploadedKBs = packetBytesSum / 1024 * 1000 / dt
	end
end

function NetworkNode:drawGraphLabels(x, y, textSize)
	for i = 1, NetworkNode.NUM_PACKETS do
		local data = self.graphData[i]

		setTextColor(unpack(data.color))
		renderText(x, y + (i - 1) * textSize, textSize, data.title)
	end

	setTextColor(1, 1, 1, 1)
end

function NetworkNode:draw()
	if self.showNetworkTraffic then
		local smoothAlpha = 0.8
		self.lastUploadedKBsSmooth = self.lastUploadedKBsSmooth * smoothAlpha + self.lastUploadedKBs * (1 - smoothAlpha)

		setTextColor(1, 1, 1, 1)
		setTextBold(false)
		setTextAlignment(RenderText.ALIGN_LEFT)
		renderText(0.01, 0.8, getCorrectTextSize(0.015), string.format("Game Data Upload %.2fkb/s ", self.lastUploadedKBsSmooth))

		local alpha = MathUtil.clamp(self.serverFPS / 60, 0, 1)
		local r = 1 - alpha
		local g = alpha

		setTextColor(r, g, 0, 1)
		renderText(0.01, 0.82, getCorrectTextSize(0.015), string.format("Server: %d FPS", self.serverFPS))
		setTextColor(1, 1, 1, 1)

		local x = self.packetGraphs[1].left - 0.15
		local y = self.packetGraphs[1].bottom

		self:drawGraphLabels(x, y, getCorrectTextSize(0.02))

		for i = 1, NetworkNode.NUM_PACKETS do
			self.packetGraphs[i]:draw()
		end

		local textSize = getCorrectTextSize(0.014)

		if self.clientConnections ~= nil then
			local i = 1

			for _, connection in pairs(self.clientConnections) do
				local posY = 0.78 - i * textSize * 1.1

				if self:drawConnectionNetworkStats(connection, 0.01, posY, textSize) then
					local user = g_currentMission.userManager:getUserByConnection(connection)

					if user ~= nil then
						renderText(0.255, posY, textSize, user:getNickname())
					end

					i = i + 1
				end
			end
		elseif self.serverConnection ~= nil then
			self:drawConnectionNetworkStats(self.serverConnection, 0.01, 0.8 - textSize * 1.1, textSize)
		end
	end

	if self.showNetworkTrafficClients and self.clientConnections ~= nil then
		local connections = self.clientConnections
		local startPosX = 0.04
		local posX = startPosX
		local posY = 0.7
		local textSize = getCorrectTextSize(0.01)

		for _, connection in pairs(connections) do
			local hasGraph = false

			for packetType = 1, NetworkNode.NUM_PACKETS do
				local graph = self.connectionPacketGraphs[packetType][connection]

				if graph ~= nil then
					graph.left = posX
					graph.bottom = posY + 0.015
					graph.showLabels = packetType == 1 and posX == startPosX

					self.connectionPacketGraphs[packetType][connection]:draw()

					hasGraph = true
				end
			end

			if hasGraph then
				self:drawConnectionNetworkStats(connection, posX, posY, textSize)

				local user = g_currentMission.userManager:getUserByConnection(connection)

				if user ~= nil then
					renderText(posX, posY - 0.011, textSize, user:getNickname())
				end

				posX = posX + 0.16

				if posX + 0.16 > 1 then
					posX = startPosX
					posY = posY - 0.32
				end
			end
		end

		self:drawGraphLabels(0.8, 0.1, getCorrectTextSize(0.02))
	end

	if self.showObjects then
		setTextBold(false)
		setTextAlignment(RenderText.ALIGN_LEFT)

		local count = 0

		for id, object in pairs(self.activeObjects) do
			count = count + 1
			object.serverId = self.objectIds[object] or 0
		end

		local allObjects = {}

		for _, object in pairs(self.objects) do
			object.serverId = self.objectIds[object] or 0
			object.debugClassName = object.debugClassName or tostring(ClassUtil.getClassNameByObject(object))

			table.insert(allObjects, object)
		end

		local sortByClassName = self.debugSortByClassName

		table.sort(allObjects, function (a, b)
			if sortByClassName and a.debugClassName ~= b.debugClassName then
				return a.debugClassName < b.debugClassName
			end

			return a.serverId < b.serverId
		end)

		local posX = 0.015
		local posY = 0.96
		local offsetX = 1 / g_screenWidth
		local offsetY = -1 / g_screenHeight
		local title = string.format("Registered Objects: %d | Objects in update-loop: %d | Update time: %.3f ms", #allObjects, count, self.updateDurationTotalTime)

		setTextColor(0, 0, 0, 1)
		renderText(posX + offsetX, 0.98 + offsetY, 0.013, title)
		setTextColor(1, 1, 1, 1)
		renderText(posX, 0.98, 0.013, title)

		for _, object in ipairs(allObjects) do
			local path = object.configFileName or object.xmlFilename

			if path ~= nil then
				path = Utils.getFilenameFromPath(path)
			end

			local serverId = tostring(object.serverId)
			local text = string.format(" - %s - %s", object.debugClassName, tostring(path))
			local isActive = self.activeObjects[object.serverId] ~= nil
			local activeR = 0.1254
			local activeG = 0.7647

			if object.profilerUpdateTime ~= nil then
				text = string.format("%s (%.3f ms)", text, object.profilerUpdateTime)
				local alpha = MathUtil.clamp(object.profilerUpdateTime / 1, 0, 1)
				activeG = 1 - alpha
				activeR = alpha
			end

			setTextBold(isActive)
			setTextColor(0, 0, 0, 1)
			renderText(posX + offsetX, posY + offsetY, 0.01, text)
			setTextAlignment(RenderText.ALIGN_RIGHT)
			renderText(posX + offsetX, posY + offsetY, 0.01, serverId)

			if isActive then
				setTextColor(activeR, activeG, 0, 1)
			else
				setTextColor(1, 1, 1, 1)
			end

			renderText(posX, posY, 0.01, serverId)
			setTextAlignment(RenderText.ALIGN_LEFT)
			renderText(posX, posY, 0.01, text)

			posY = posY - 0.011

			if posY < 0 then
				posX = posX + 0.14
				posY = 0.96
			end
		end

		setTextBold(false)
		setTextColor(1, 1, 1, 1)
	end
end

function NetworkNode:packetReceived(packetType, timestamp, streamId)
end

function NetworkNode:getObject(id)
	return self.objects[id]
end

function NetworkNode:getObjectId(object)
	return self.objectIds[object]
end

function NetworkNode:addObject(object, id)
	self.objects[id] = object
	self.objectIds[object] = id

	self:addObjectToUpdateLoop(object)

	if self.networkListener ~= nil then
		self.networkListener:onObjectCreated(object)
	end
end

function NetworkNode:removeObject(object, id)
	self:removeObjectFromUpdateLoop(object)

	if self.networkListener ~= nil then
		self.networkListener:onObjectDeleted(object)
	end

	self.objects[id] = nil
	self.objectIds[object] = nil
end

function NetworkNode:addObjectToUpdateLoop(object)
	if object.isRegistered then
		local id = self:getObjectId(object)

		if id ~= nil then
			self.activeObjects[id] = object
			self.activeObjectsNextFrame[id] = object
		end
	end
end

function NetworkNode:removeObjectFromUpdateLoop(object)
	local id = self:getObjectId(object)

	if id ~= nil then
		self.removedObjects[id] = object
		self.activeObjects[id] = nil
		self.activeObjectsNextFrame[id] = nil
	end
end

function NetworkNode:registerObject(object, alreadySent)
end

function NetworkNode:unregisterObject(object, alreadySent)
end

function NetworkNode:consoleCommandToggleNetworkShowObjects(sortByClassName)
	self.showObjects = not self.showObjects
	self.debugSortByClassName = string.lower(sortByClassName or "true") == "true"

	return "NetworkShowObjects = " .. tostring(self.showObjects)
end

function NetworkNode:consoleCommandToggleShowNetworkTraffic()
	self.showNetworkTraffic = not self.showNetworkTraffic

	return "ShowNetworkTraffic = " .. tostring(self.showNetworkTraffic)
end

function NetworkNode:consoleCommandToggleShowNetworkTrafficClients()
	self.showNetworkTrafficClients = not self.showNetworkTrafficClients

	return "ShowNetworkTrafficClients = " .. tostring(self.showNetworkTrafficClients)
end
