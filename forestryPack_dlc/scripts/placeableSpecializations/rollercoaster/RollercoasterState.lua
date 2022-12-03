local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

RollercoasterState = {}
local RollercoasterState_mt = Class(RollercoasterState)

function RollercoasterState.registerXMLPaths(schema, basePath)
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "active")
end

function RollercoasterState.new(rollercoaster, customMt)
	local self = setmetatable({}, customMt or RollercoasterState_mt)
	self.rollercoaster = rollercoaster
	self.isClient = rollercoaster.isClient
	self.isServer = rollercoaster.isServer
	self.dirtyFlag = rollercoaster:getNextDirtyFlag()
	self.isSoundPlaying = false

	return self
end

function RollercoasterState:load(xmlFile, key)
	self.name = xmlFile:getValue(key .. "#name", ""):upper()
	self.samples = {}
	local baseDirecory = self.rollercoaster.baseDirectory
	self.components = self.rollercoaster.components
	self.i3dMappings = self.rollercoaster.i3dMappings
	self.samples.active = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "active", baseDirecory, self.components, 0, AudioGroup.ENVIRONMENT, self.i3dMappings, self)
end

function RollercoasterState:delete()
	if self.samples ~= nil then
		g_soundManager:deleteSamples(self.samples)
	end
end

function RollercoasterState:saveToXMLFile(xmlFile, key, usedModNames)
end

function RollercoasterState:loadFromXMLFile(xmlFile, key)
end

function RollercoasterState:onReadStream(streamId, connection)
end

function RollercoasterState:onWriteStream(streamId, connection)
end

function RollercoasterState:onReadUpdateStream(streamId, timestamp, connection)
end

function RollercoasterState:onWriteUpdateStream(streamId, connection, dirtyMask)
end

function RollercoasterState:update(dt)
	if self.isClient and self.samples.active ~= nil then
		if self:getPlaySound() then
			if not self.isSoundPlaying then
				g_soundManager:playSample(self.samples.active)

				self.isSoundPlaying = true
			end
		elseif self.isSoundPlaying then
			g_soundManager:stopSample(self.samples.active)

			self.isSoundPlaying = false
		end
	end
end

function RollercoasterState:activate()
	self.isSoundPlaying = false
end

function RollercoasterState:deactivate()
	if self.isClient and self.samples.active ~= nil then
		g_soundManager:stopSample(self.samples.active)
	end
end

function RollercoasterState:isDone()
	return true
end

function RollercoasterState:raiseActive()
	return true
end

function RollercoasterState:getPlaySound()
	return true
end
