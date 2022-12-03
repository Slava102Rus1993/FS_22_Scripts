local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

HeapLoadTrigger = {}
local HeapLoadTrigger_mt = Class(HeapLoadTrigger, Object)

InitObjectClass(HeapLoadTrigger, "HeapLoadTrigger")

function HeapLoadTrigger.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".spawnArea(?)#startNode", "")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".spawnArea(?)#widthNode", "")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".spawnArea(?)#heightNode", "")
	schema:register(XMLValueType.FLOAT, basePath .. "#fillLitersPerSecond", "Fill liters per second")
	schema:register(XMLValueType.STRING, basePath .. "#fillType", "Supported fill type")
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "spawn")
	EffectManager.registerEffectXMLPaths(schema, basePath .. ".effectNodes")
end

LoadTrigger.registerXMLPaths = Utils.appendedFunction(LoadTrigger.registerXMLPaths, HeapLoadTrigger.registerXMLPaths)

function HeapLoadTrigger.new(isServer, isClient, customMt)
	local self = Object.new(isServer, isClient, customMt or HeapLoadTrigger_mt)
	self.isActive = true
	self.amountToTip = 0
	self.areEffectsActive = false
	self.effectsEndTime = 0
	self.effectsDuration = 5000
	self.heapLoadTriggerDirtyFlag = self:getNextDirtyFlag()

	return self
end

function HeapLoadTrigger:load(components, xmlFile, xmlNode, i3dMappings, rootNode)
	local litersPerSecond = xmlFile:getValue(xmlNode .. "#fillLitersPerSecond", 150)

	if litersPerSecond <= 0 then
		Logging.xmlError(xmlFile, "litersPerSecond may not be 0 or negative for heap load trigger '%s'", xmlNode)

		return
	end

	self.fillLitersPerMS = litersPerSecond * 1000
	self.fillLitersMax = 150
	self.spawnAreas = {}

	xmlFile:iterate(xmlNode .. ".spawnArea", function (_, areaKey)
		local startNode = xmlFile:getValue(areaKey .. "#startNode", nil, components, i3dMappings)

		if startNode == nil then
			Logging.xmlError(xmlFile, "Missing startNode for spawnArea '%s'", areaKey)

			return
		end

		local widthNode = xmlFile:getValue(areaKey .. "#widthNode", nil, components, i3dMappings)

		if widthNode == nil then
			Logging.xmlError(xmlFile, "Missing widthNode for spawnArea '%s'", areaKey)

			return
		end

		local heightNode = xmlFile:getValue(areaKey .. "#heightNode", nil, components, i3dMappings)

		if heightNode == nil then
			Logging.xmlError(xmlFile, "Missing heightNode for spawnArea '%s'", areaKey)

			return
		end

		local spawnArea = {
			lineOffset = 0,
			start = startNode,
			width = widthNode,
			height = heightNode
		}

		table.insert(self.spawnAreas, spawnArea)
	end)

	local fillTypeName = xmlFile:getString(xmlNode .. "#fillType", "woodchips")
	self.fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)

	if self.fillTypeIndex == nil then
		Logging.xmlError(xmlFile, "Invalid filltype '%s' for HeapLoadTrigger '%s'", fillTypeName, xmlNode)

		return false
	end

	self.fillTypes = {
		[self.fillTypeIndex] = true
	}
	local _, baseDirectory = Utils.getModNameAndBaseDirectory(xmlFile:getFilename())

	if self.isClient then
		self.samples = {
			spawn = g_soundManager:loadSampleFromXML(xmlFile, xmlNode .. ".sounds", "spawn", baseDirectory, components, 0, AudioGroup.ENVIRONMENT, i3dMappings, self)
		}
		self.effects = g_effectManager:loadEffect(xmlFile, xmlNode .. ".effectNodes", components, self, i3dMappings)

		g_effectManager:setFillType(self.effects, self.fillTypeIndex)
	end

	self:raiseActive()

	return true
end

function HeapLoadTrigger:delete()
	HeapLoadTrigger:superClass().delete(self)

	if self.samples ~= nil then
		g_soundManager:deleteSamples(self.samples)
	end

	if self.effects ~= nil then
		g_effectManager:deleteEffects(self.effects)
	end
end

function HeapLoadTrigger:readStream(streamId, connection, objectId)
	HeapLoadTrigger:superClass().readStream(self, streamId, connection, objectId)

	local areEffectsActive = streamReadBool(streamId)

	self:setEffectsActive(areEffectsActive)
end

function HeapLoadTrigger:writeStream(streamId, connection)
	HeapLoadTrigger:superClass().writeStream(self, streamId, connection)
	streamWriteBool(streamId, self.areEffectsActive)
end

function HeapLoadTrigger:readUpdateStream(streamId, timestamp, connection)
	HeapLoadTrigger:superClass().readUpdateStream(self, streamId, timestamp, connection)

	local areEffectsActive = streamReadBool(streamId)

	self:setEffectsActive(areEffectsActive)
end

function HeapLoadTrigger:writeUpdateStream(streamId, connection, dirtyMask)
	HeapLoadTrigger:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
	streamWriteBool(streamId, self.areEffectsActive)
end

function HeapLoadTrigger:setSource(object)
	assert(object.getSupportedFillTypes ~= nil)
	assert(object.getAllFillLevels ~= nil)
	assert(object.addFillLevelToFillableObject ~= nil)
	assert(object.getIsFillAllowedToFarm ~= nil)

	self.source = object
end

function HeapLoadTrigger:setIsActive(isActive)
	self.isActive = isActive

	if isActive then
		self:raiseActive()
	end
end

function HeapLoadTrigger:update(dt)
	if self.isServer then
		if self.isActive then
			local litersPerMs = self.fillLitersPerMS
			local farmId = self.ownerFarmId
			local fillLevel = self.source:getFillLevel(self.fillTypeIndex, farmId)
			self.amountToTip = math.min(self.amountToTip + litersPerMs * dt, fillLevel, self.fillLitersMax)

			if g_densityMapHeightManager:getMinValidLiterValue(self.fillTypeIndex) < self.amountToTip then
				self:setEffectsActive(true)

				self.effectsEndTime = g_time + self.effectsDuration

				for _, spawnArea in ipairs(self.spawnAreas) do
					if g_densityMapHeightManager:getMinValidLiterValue(self.fillTypeIndex) < self.amountToTip then
						local lsx, lsy, lsz, lex, ley, lez, radius = DensityMapHeightUtil.getLineByArea(spawnArea.start, spawnArea.width, spawnArea.height, false)
						local dropped, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(nil, self.amountToTip, self.fillTypeIndex, lsx, lsy, lsz, lex, ley, lez, radius, radius, spawnArea.lineOffset, nil, , )
						spawnArea.lineOffset = lineOffset
						self.amountToTip = math.max(self.amountToTip - dropped, 0)

						self.source:removeFillLevel(self.fillTypeIndex, dropped, farmId)

						if self.amountToTip == 0 then
							break
						end
					end
				end
			end

			self:raiseActive()
		end

		if self.areEffectsActive then
			if g_time < self.effectsEndTime then
				self:raiseActive()
			else
				self:setEffectsActive(false)
			end
		end
	end
end

function HeapLoadTrigger:setEffectsActive(isActive)
	if self.areEffectsActive ~= isActive then
		self.areEffectsActive = isActive

		if self.isServer then
			self:raiseDirtyFlags(self.heapLoadTriggerDirtyFlag)
		end

		if self.samples ~= nil then
			if isActive then
				if not g_soundManager:getIsSamplePlaying(self.samples.spawn) then
					g_soundManager:playSample(self.samples.spawn)
				end
			elseif g_soundManager:getIsSamplePlaying(self.samples.spawn) then
				g_soundManager:stopSample(self.samples.spawn)
			end
		end

		if self.effects ~= nil then
			if isActive then
				g_effectManager:startEffects(self.effects)
			else
				g_effectManager:stopEffects(self.effects)
			end
		end
	end
end

function HeapLoadTrigger:getCurrentFillType()
	return self.fillTypeIndex
end

function HeapLoadTrigger:getIsFillTypeSupported(fillTypeIndex)
	return self.fillTypeIndex == fillTypeIndex
end

function HeapLoadTrigger:getSupportAILoading()
	return false
end
