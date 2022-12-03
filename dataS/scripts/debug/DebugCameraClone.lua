DebugCameraClone = {
	MAX_CAMERAS = 16
}
local DebugCameraClone_mt = Class(DebugCameraClone, Object)

InitStaticObjectClass(DebugCameraClone, "DebugCameraClone", ObjectIds.OBJECT_DEBUG_CAMERA_CLONE)

function DebugCameraClone.new(isServer, isClient, customMt)
	local self = Object.new(isServer, isClient, customMt or DebugCameraClone_mt)

	if isServer then
		self.cameras = {}

		for i = 0, DebugCameraClone.MAX_CAMERAS + 1 do
			local data = {
				farClip = 5000,
				z = 0,
				qx = 0,
				qw = 1,
				nearClip = 0.1,
				y = 0,
				qz = 0,
				qy = 0,
				x = 0,
				fovY = math.rad(60)
			}
			self.cameras[i] = data
		end
	end

	self.interpolatorPosition = InterpolatorPosition.new(0, 0, 0)
	self.interpolatorQuaternion = InterpolatorQuaternion.new(0, 0, 0, 1)
	self.interpolatorTime = InterpolationTime.new(1.2)
	self.fovY = math.rad(60)
	self.nearClip = 0.1
	self.farClip = 5000
	self.dirtyFlag = self:getNextDirtyFlag()
	self.camera = createCamera("DebugCameraClone", math.rad(60), 1, 10000)
	self.cameraIndex = tonumber(StartParams.getValue("debugCameraCloneIndex"))
	self.connectionToCameraIndex = {}
	self.lastCamera = getCamera()

	addConsoleCommand("gsDebugCameraCloneSetIndex", "Sets the camera clone index", "consoleCommandSetCameraCloneIndex", self)

	return self
end

function DebugCameraClone:delete()
	removeConsoleCommand("gsDebugCameraCloneSetIndex")
end

function DebugCameraClone:readUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		if streamReadBool(streamId) then
			local x = streamReadFloat32(streamId)
			local y = streamReadFloat32(streamId)
			local z = streamReadFloat32(streamId)
			local qx = streamReadFloat32(streamId)
			local qy = streamReadFloat32(streamId)
			local qz = streamReadFloat32(streamId)
			local qw = streamReadFloat32(streamId)
			local fovY = streamReadFloat32(streamId)
			local nearClip = streamReadFloat32(streamId)
			local farClip = streamReadFloat32(streamId)

			self.interpolatorPosition:setTargetPosition(x, y, z)
			self.interpolatorQuaternion:setTargetQuaternion(qx, qy, qz, qw)
			self.interpolatorTime:startNewPhaseNetwork()

			self.fovY = fovY
			self.nearClip = nearClip
			self.farClip = farClip
		end
	else
		local clientIndex = 1

		for index, clientStreamId in ipairs(g_server.clients) do
			if clientStreamId == streamId then
				clientIndex = index

				break
			end
		end

		if streamReadBool(streamId) then
			self.connectionToCameraIndex[connection] = streamReadUIntN(streamId, 5)
		else
			self.connectionToCameraIndex[connection] = nil
		end

		local data = self.cameras[clientIndex]
		data.x = streamReadFloat32(streamId)
		data.y = streamReadFloat32(streamId)
		data.z = streamReadFloat32(streamId)
		data.qx = streamReadFloat32(streamId)
		data.qy = streamReadFloat32(streamId)
		data.qz = streamReadFloat32(streamId)
		data.qw = streamReadFloat32(streamId)
		data.fovY = streamReadFloat32(streamId)
		data.nearClip = streamReadFloat32(streamId)
		data.farClip = streamReadFloat32(streamId)
	end
end

function DebugCameraClone:writeUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local cameraIndex = self.connectionToCameraIndex[connection]
		local data = self.cameras[cameraIndex]

		if streamWriteBool(streamId, data ~= nil) then
			streamWriteFloat32(streamId, data.x)
			streamWriteFloat32(streamId, data.y)
			streamWriteFloat32(streamId, data.z)
			streamWriteFloat32(streamId, data.qx)
			streamWriteFloat32(streamId, data.qy)
			streamWriteFloat32(streamId, data.qz)
			streamWriteFloat32(streamId, data.qw)
			streamWriteFloat32(streamId, data.fovY)
			streamWriteFloat32(streamId, data.nearClip)
			streamWriteFloat32(streamId, data.farClip)
		end
	else
		local camera = getCamera()
		local x, y, z = getWorldTranslation(camera)
		local qx, qy, qz, qw = getWorldQuaternion(camera)
		local fovY = getFovY(camera)
		local nearClip = getNearClip(camera)
		local farClip = getFarClip(camera)

		if streamWriteBool(streamId, self.cameraIndex ~= nil) then
			streamWriteUIntN(streamId, self.cameraIndex, 5)
		end

		streamWriteFloat32(streamId, x)
		streamWriteFloat32(streamId, y)
		streamWriteFloat32(streamId, z)
		streamWriteFloat32(streamId, qx)
		streamWriteFloat32(streamId, qy)
		streamWriteFloat32(streamId, qz)
		streamWriteFloat32(streamId, qw)
		streamWriteFloat32(streamId, fovY)
		streamWriteFloat32(streamId, nearClip)
		streamWriteFloat32(streamId, farClip)
	end
end

function DebugCameraClone:update(dt)
	self:raiseDirtyFlags(self.dirtyFlag)
	self:raiseActive()

	if self.isServer then
		local data = self.cameras[0]
		local camera = getCamera()
		data.x, data.y, data.z = getWorldTranslation(camera)
		data.qx, data.qy, data.qz, data.qw = getWorldQuaternion(camera)
		data.fovY = getFovY(camera)
		data.nearClip = getNearClip(camera)
		data.farClip = getFarClip(camera)
	end

	local camera = getCamera()

	if camera ~= self.camera then
		self.lastCamera = camera
	end

	if self.cameraIndex ~= nil then
		self.interpolatorTime:update(dt)

		local interpolationAlpha = self.interpolatorTime:getAlpha()
		local x, y, z = self.interpolatorPosition:getInterpolatedValues(interpolationAlpha)
		local qx, qy, qz, qw = self.interpolatorQuaternion:getInterpolatedValues(interpolationAlpha)

		setWorldTranslation(self.camera, x, y, z)
		setWorldQuaternion(self.camera, qx, qy, qz, qw)
		setFovY(self.camera, self.fovY)
		setNearClip(self.camera, self.nearClip)
		setFarClip(self.camera, self.farClip)
		setCamera(self.camera)
	end

	local x, _, z = getWorldTranslation(getCamera())

	for _, player in pairs(g_currentMission.players) do
		if player ~= g_currentMission.player then
			local a, _, c = getWorldTranslation(player.graphicsRootNode)
			local distance = MathUtil.vector2Length(x - a, z - c)
			local shouldHide = self.cameraIndex ~= nil and distance < 1

			setVisibility(player.graphicsRootNode, not shouldHide)
		end
	end
end

function DebugCameraClone:consoleCommandSetCameraCloneIndex(index)
	index = tonumber(index)

	if index ~= nil and (index < 0 or DebugCameraClone.MAX_CAMERAS < index) then
		index = nil
	end

	self.cameraIndex = index

	if self.lastCamera ~= nil and entityExists(self.lastCamera) then
		setCamera(self.lastCamera)
	end
end
