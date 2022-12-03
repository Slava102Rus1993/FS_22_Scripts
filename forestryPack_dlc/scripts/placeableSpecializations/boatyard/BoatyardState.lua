local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

BoatyardState = {}
local BoatyardState_mt = Class(BoatyardState)

function BoatyardState.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.INT, basePath .. ".animatedObject(?)#index", "Animated object index")
	schema:register(XMLValueType.INT, basePath .. ".animatedObject(?)#direction", "Animated object direction")
	schema:register(XMLValueType.INT, basePath .. ".animatedObject(?)#time", "Animated object time")
	schema:register(XMLValueType.BOOL, basePath .. ".animatedObject(?)#reset", "Animated object reset on state deactivate")
	schema:register(XMLValueType.STRING, basePath .. ".meshVisibility(?)#meshId", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".meshVisibility(?)#progress", "")
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "active")
end

function BoatyardState.new(boatyard, customMt)
	local self = setmetatable({}, customMt or BoatyardState_mt)
	self.boatyard = boatyard
	self.dirtyFlag = boatyard:getNextDirtyFlag()
	self.spline = boatyard[PlaceableBoatyard.SPEC].spline
	self.splineLength = getSplineLength(self.spline)
	self.isSoundPlaying = false

	return self
end

function BoatyardState:load(xmlFile, key)
	self.meshObjects = {}

	xmlFile:iterate(key .. ".meshVisibility", function (_, meshVisibilityKey)
		local meshId = xmlFile:getValue(meshVisibilityKey .. "#meshId")
		local progress = xmlFile:getValue(meshVisibilityKey .. "#progress")

		table.insert(self.meshObjects, {
			meshId = meshId,
			progress = progress
		})
	end)

	self.samples = {}
	local baseDirectory = self.boatyard.baseDirectory
	local components = self.boatyard.components
	local i3dMappings = self.boatyard.i3dMappings
	self.samples.active = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "active", baseDirectory, components, 0, AudioGroup.ENVIRONMENT, i3dMappings, self)
end

function BoatyardState:delete()
	if self.samples ~= nil then
		g_soundManager:deleteSamples(self.samples)
	end
end

function BoatyardState:saveToXMLFile(xmlFile, key, usedModNames)
end

function BoatyardState:loadFromXMLFile(xmlFile, key)
end

function BoatyardState:onReadStream(streamId, connection)
end

function BoatyardState:onWriteStream(streamId, connection)
end

function BoatyardState:onReadUpdateStream(streamId, timestamp, connection)
end

function BoatyardState:onWriteUpdateStream(streamId, connection, dirtyMask)
end

function BoatyardState:update(dt)
	if self.boatyard.isClient and self.samples.active ~= nil then
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

function BoatyardState:activate()
	for _, mesh in ipairs(self.meshObjects) do
		self.boatyard:setMeshProgress(mesh.meshId, mesh.progress)
	end

	self.isSoundPlaying = false
end

function BoatyardState:deactivate()
	if self.boatyard.isClient and self.samples.active ~= nil then
		g_soundManager:stopSample(self.samples.active)
	end
end

function BoatyardState:isDone()
	return true
end

function BoatyardState:raiseActive()
	return true
end

function BoatyardState:getPlaySound()
	return true
end
