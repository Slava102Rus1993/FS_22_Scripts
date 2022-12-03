local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

SawmillWoodCrusher = {}
local SawmillWoodCrusher_mt = Class(SawmillWoodCrusher, WoodUnloadTrigger)

InitObjectClass(SawmillWoodCrusher, "SawmillWoodCrusher")

function SawmillWoodCrusher.registerXMLPaths(schema, basePath)
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "crush")
end

WoodUnloadTrigger.registerXMLPaths = Utils.appendedFunction(WoodUnloadTrigger.registerXMLPaths, SawmillWoodCrusher.registerXMLPaths)

function SawmillWoodCrusher.new(isServer, isClient, customMt)
	local self = WoodUnloadTrigger.new(isServer, isClient, customMt or SawmillWoodCrusher_mt)
	self.crusherDirtyFlag = self:getNextDirtyFlag()
	self.isCrushing = false
	self.curshingEndTime = 0
	self.crushingDuration = 1000

	return self
end

function SawmillWoodCrusher:load(components, xmlFile, xmlNode, target, i3dMappings, rootNode)
	if not SawmillWoodCrusher:superClass().load(self, components, xmlFile, xmlNode, target, i3dMappings, rootNode) then
		return false
	end

	local _, baseDirectory = Utils.getModNameAndBaseDirectory(xmlFile:getFilename())

	if self.isClient then
		self.samples = {
			crush = g_soundManager:loadSampleFromXML(xmlFile, xmlNode .. ".sounds", "crush", baseDirectory, components, 0, AudioGroup.ENVIRONMENT, i3dMappings, self)
		}
	end

	return true
end

function SawmillWoodCrusher:delete()
	if self.samples ~= nil then
		g_soundManager:deleteSamples(self.samples)
	end

	SawmillWoodCrusher:superClass().delete(self)
end

function SawmillWoodCrusher:readStream(streamId, connection, objectId)
	SawmillWoodCrusher:superClass().readStream(self, streamId, connection, objectId)

	self.isCrushing = streamReadBool(streamId)

	self:setEffectsActive(self.isCrushing)
end

function SawmillWoodCrusher:writeStream(streamId, connection)
	SawmillWoodCrusher:superClass().writeStream(self, streamId, connection)
	streamWriteBool(streamId, self.isCrushing)
end

function SawmillWoodCrusher:readUpdateStream(streamId, timestamp, connection)
	SawmillWoodCrusher:superClass().readUpdateStream(self, streamId, timestamp, connection)

	self.isCrushing = streamReadBool(streamId)

	self:setEffectsActive(self.isCrushing)
end

function SawmillWoodCrusher:writeUpdateStream(streamId, connection, dirtyMask)
	SawmillWoodCrusher:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
	streamWriteBool(streamId, self.isCrushing)
end

function SawmillWoodCrusher:update(dt)
	SawmillWoodCrusher:superClass().update(self, dt)

	if self.isServer and self.isCrushing then
		if g_time < self.curshingEndTime then
			self:raiseActive()
		else
			self:setEffectsActive(false)

			self.isCrushing = false

			self:raiseDirtyFlags(self.crusherDirtyFlag)
		end
	end
end

function SawmillWoodCrusher:setEffectsActive(isActive)
	if self.samples ~= nil then
		if isActive then
			if not g_soundManager:getIsSamplePlaying(self.samples.crush) then
				g_soundManager:playSample(self.samples.crush)
			end
		elseif g_soundManager:getIsSamplePlaying(self.samples.crush) then
			g_soundManager:stopSample(self.samples.crush)
		end
	end
end

function SawmillWoodCrusher:getTargetFillType(maxSize, volume)
	return FillType.WOODCHIPS
end

function SawmillWoodCrusher:setOwnerFarmId(farmId, noEventSend)
	SawmillWoodCrusher:superClass().setOwnerFarmId(self, farmId, noEventSend)

	local isOwned = farmId ~= AccessHandler.EVERYONE

	setVisibility(self.activationTrigger, not isOwned)

	self.isManualSellingActive = not isOwned
end

function SawmillWoodCrusher:onProcessedWood(nodeId, volume, fillType)
	if self.isServer then
		self.curshingEndTime = g_time + self.crushingDuration

		if not self.isCrushing then
			self:setEffectsActive(true)

			self.isCrushing = true

			self:raiseDirtyFlags(self.crusherDirtyFlag)
		end

		self:raiseActive()
	end
end

function SawmillWoodCrusher:getNeedRaiseActive()
	return true
end

function SawmillWoodCrusher:calculateWoodBaseValue(nodeId)
	local volume, qualityScale, maxSize = SawmillWoodCrusher:superClass().calculateWoodBaseValue(self, nodeId)

	return volume * 2.5, qualityScale, maxSize
end
