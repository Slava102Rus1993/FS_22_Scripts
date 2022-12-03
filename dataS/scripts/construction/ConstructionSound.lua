ConstructionSound = {}
local ConstructionSound_mt = Class(ConstructionSound)
ConstructionSound.ID = {
	NONE = 0,
	TREE = 1,
	SCULPT = 2,
	PAINT = 3,
	FOLIAGE = 4
}

function ConstructionSound.new(subclass_mt)
	local self = setmetatable({}, subclass_mt or ConstructionSound_mt)
	self.currentActiveSoundId = ConstructionSound.ID.NONE
	self.samples = self:loadSamples("dataS/constructionSoundSamples.xml")

	return self
end

function ConstructionSound:loadSamples(xmlPath)
	local samples = {}
	local xmlFile = XMLFile.load("constructionSound", xmlPath)

	if xmlFile == nil then
		return samples
	end

	for key, id in pairs(ConstructionSound.ID) do
		if id ~= ConstructionSound.ID.NONE then
			local loops = xmlFile:getInt("constructionSoundSamples." .. key .. "#loops", 0)
			local sample = g_soundManager:loadSample2DFromXML(xmlFile.handle, "constructionSoundSamples", key:lower(), "", loops, AudioGroup.GUI)

			if sample ~= nil then
				samples[id] = sample
			else
				Logging.warning("Warning: Could not load construction sound sample [%s]", key)
			end
		end
	end

	xmlFile:delete()

	return samples
end

function ConstructionSound:delete()
	for k, sample in pairs(self.samples) do
		g_soundManager:deleteSample(sample)

		self.samples[k] = nil
	end
end

function ConstructionSound:setActiveSound(soundId, pitchModifier)
	local isOneOff = false

	if soundId ~= self.currentActiveSoundId then
		if soundId == ConstructionSound.ID.NONE and not self.silenceQueued then
			self.silenceQueued = true

			return
		else
			self.silenceQueued = false
		end

		local oldSample = self.samples[self.currentActiveSoundId]
		local newSample = self.samples[soundId]
		local isOldOneOff = oldSample ~= nil and oldSample.loops == 1
		local isNewOneOff = newSample ~= nil and newSample.loops == 1

		if not isOldOneOff then
			g_soundManager:stopSample(oldSample)
		end

		g_soundManager:playSample(newSample)

		self.currentActiveSoundId = soundId
		isOneOff = isNewOneOff
	end

	local sample = self.samples[self.currentActiveSoundId]

	if sample ~= nil then
		local pitch = 1

		if pitchModifier ~= nil then
			pitch = MathUtil.smoothstep(0, 1, pitchModifier) + 0.5
		end

		sample.current.pitch = pitch
	end

	return isOneOff
end
