local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

SawmillWoodTrigger = {}
local SawmillWoodTrigger_mt = Class(SawmillWoodTrigger, WoodUnloadTrigger)

InitObjectClass(SawmillWoodTrigger, "SawmillWoodTrigger")

function SawmillWoodTrigger.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".animation.clip(?)#rootNode", "Animation root node")
	schema:register(XMLValueType.STRING, basePath .. ".animation.clip(?)#name", "Animation clip name")
	schema:register(XMLValueType.STRING, basePath .. ".animation.clip(?)#filename", "Animation filename")
	schema:register(XMLValueType.FLOAT, basePath .. ".animation#speedScale", "Animation speed scale")
	schema:register(XMLValueType.INT, basePath .. ".animation#waitThresholdAnimTime", "Wait threshold until new processing can start")
	schema:register(XMLValueType.FLOAT, basePath .. "#treeTrunkMinSize", "Tree trunk min size. If tree size is lower the output will be woodchips")
	SoundManager.registerSampleXMLPaths(schema, basePath .. "sounds", "saw")
	SoundManager.registerSampleXMLPaths(schema, basePath .. "sounds", "lift")
end

WoodUnloadTrigger.registerXMLPaths = Utils.appendedFunction(WoodUnloadTrigger.registerXMLPaths, SawmillWoodTrigger.registerXMLPaths)

function SawmillWoodTrigger.new(isServer, isClient, customMt)
	local self = WoodUnloadTrigger.new(isServer, isClient, customMt or SawmillWoodTrigger_mt)
	self.nextAvailableClipIndex = nil
	self.treeTrunkMinSize = 1.5

	return self
end

function SawmillWoodTrigger:load(components, xmlFile, xmlNode, target, i3dMappings, rootNode)
	if not SawmillWoodTrigger:superClass().load(self, components, xmlFile, xmlNode, target, i3dMappings, rootNode) then
		return false
	end

	local _, baseDirectory = Utils.getModNameAndBaseDirectory(xmlFile:getFilename())
	self.animation = {
		speedScale = xmlFile:getValue(xmlNode .. ".animation#speedScale", 1),
		clips = {},
		waitThresholdAnimTime = xmlFile:getValue(xmlNode .. ".animation#waitThresholdAnimTime", 0)
	}

	xmlFile:iterate(xmlNode .. ".animation.clip", function (_, animKey)
		local clipRootNode = xmlFile:getValue(animKey .. "#rootNode", nil, components, i3dMappings)
		local clipName = xmlFile:getValue(animKey .. "#name")
		local clipFilename = xmlFile:getValue(animKey .. "#filename")

		if clipRootNode ~= nil and clipName ~= nil and clipFilename ~= nil then
			local clip = {
				rootNode = clipRootNode,
				name = clipName,
				track = 0,
				clipFilename = Utils.getFilename(clipFilename, baseDirectory)
			}
			clip.sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(clip.clipFilename, false, false, self.onSharedAnimationFileLoaded, self, clip)

			table.insert(self.animation.clips, clip)
			setVisibility(clipRootNode, false)
		end
	end)

	if self.isClient then
		self.samples = {
			lift = g_soundManager:loadSampleFromXML(xmlFile, xmlNode .. ".sounds", "lift", baseDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, self),
			saw = g_soundManager:loadSampleFromXML(xmlFile, xmlNode .. ".sounds", "saw", baseDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, self)
		}
	end

	self.treeTrunkMinSize = xmlFile:getValue(xmlNode .. "#treeTrunkMinSize", self.treeTrunkMinSize)

	return true
end

function SawmillWoodTrigger:delete()
	if self.animation ~= nil then
		for _, clip in ipairs(self.animation.clips) do
			if clip.sharedLoadRequestId ~= nil then
				g_i3DManager:releaseSharedI3DFile(clip.sharedLoadRequestId)

				clip.sharedLoadRequestId = nil
			end
		end

		self.animation.clips = {}
	end

	if self.samples ~= nil then
		g_soundManager:deleteSamples(self.samples)
	end

	SawmillWoodTrigger:superClass().delete(self)
end

function SawmillWoodTrigger:onSharedAnimationFileLoaded(node, failedReason, args)
	if node ~= 0 and node ~= nil then
		if not self.isDeleted then
			local clip = args
			local animNode = getChildAt(node, 0)

			cloneAnimCharacterSet(animNode, getParent(clip.rootNode))

			local characterSet = getAnimCharacterSet(clip.rootNode)

			if characterSet ~= 0 then
				local clipIndex = getAnimClipIndex(characterSet, clip.name)

				if clipIndex ~= -1 then
					assignAnimTrackClip(characterSet, clip.track, clipIndex)
					setAnimTrackLoopState(characterSet, clip.track, false)

					clip.duration = getAnimClipDuration(characterSet, clipIndex)
					clip.characterSet = characterSet

					setAnimTrackSpeedScale(characterSet, clipIndex, self.animation.speedScale)
				else
					Logging.error("Animation clip with name '%s' does not exist in '%s'", clip.name, clip.clipFilename or self.xmlFilename)
				end
			else
				Logging.error("Animation characterset does not exist in '%s'", clip.clipFilename or self.xmlFilename)
			end
		end

		delete(node)
	end
end

function SawmillWoodTrigger:playAnimation(clipIndex)
	if self.animation ~= nil then
		local clip = self.animation.clips[clipIndex]

		if clip ~= nil and clip.characterSet ~= nil then
			setAnimTrackTime(clip.characterSet, clip.track, 0, true)
			enableAnimTrack(clip.characterSet, clip.track)
			setVisibility(clip.rootNode, true)

			if self.samples ~= nil then
				g_soundManager:playSample(self.samples.lift)
			end
		end
	end
end

function SawmillWoodTrigger:update(dt)
	if self.animation ~= nil then
		local minAnimTime = math.huge
		local nextAvailableClipIndex = nil

		for k, clip in ipairs(self.animation.clips) do
			if clip.characterSet ~= nil then
				if isAnimTrackEnabled(clip.characterSet, clip.track) then
					local animTime = getAnimTrackTime(clip.characterSet, clip.track)
					minAnimTime = math.min(minAnimTime, animTime)

					if clip.duration < animTime then
						disableAnimTrack(clip.characterSet, clip.track)
						setVisibility(clip.rootNode, false)

						if self.samples ~= nil then
							g_soundManager:playSample(self.samples.saw)
						end
					end
				elseif nextAvailableClipIndex == nil then
					nextAvailableClipIndex = k
				end
			end
		end

		if minAnimTime < self.animation.waitThresholdAnimTime then
			nextAvailableClipIndex = nil
		end

		self.nextAvailableClipIndex = nextAvailableClipIndex
	end

	self:raiseActive()
	SawmillWoodTrigger:superClass().update(self, dt)
end

function SawmillWoodTrigger:getTargetFillType(maxSize, volume)
	if maxSize < self.treeTrunkMinSize then
		return FillType.WOODCHIPS
	end

	return SawmillWoodTrigger:superClass().getTargetFillType(self, maxSize, volume)
end

function SawmillWoodTrigger:getCanProcessWood()
	local ownerFarmId = self:getOwnerFarmId()

	if ownerFarmId == AccessHandler.EVERYONE then
		return true
	end

	return self.nextAvailableClipIndex ~= nil
end

function SawmillWoodTrigger:onProcessedWood(nodeId, volume, fillType)
	if fillType == FillType.WOOD and self.nextAvailableClipIndex ~= nil then
		g_server:broadcastEvent(SawmillWoodTriggerStartAnimationEvent.new(self, self.nextAvailableClipIndex), true)

		self.nextAvailableClipIndex = nil
	end
end

function SawmillWoodTrigger:setOwnerFarmId(farmId, noEventSend)
	SawmillWoodTrigger:superClass().setOwnerFarmId(self, farmId, noEventSend)

	local isOwned = farmId ~= AccessHandler.EVERYONE

	setVisibility(self.activationTrigger, not isOwned)

	self.isManualSellingActive = not isOwned
end

function SawmillWoodTrigger:getNeedRaiseActive()
	return true
end
