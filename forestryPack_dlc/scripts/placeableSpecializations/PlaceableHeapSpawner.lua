local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

PlaceableHeapSpawner = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".heapSpawner"
}
PlaceableHeapSpawner.SPEC = "spec_" .. PlaceableHeapSpawner.SPEC_NAME

function PlaceableHeapSpawner.prerequisitesPresent(specializations)
	return true
end

function PlaceableHeapSpawner.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableHeapSpawner)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", PlaceableHeapSpawner)
	SpecializationUtil.registerEventListener(placeableType, "onUpdateTick", PlaceableHeapSpawner)
	SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableHeapSpawner)
end

function PlaceableHeapSpawner.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("PlaceableHeapSpawner")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".heapSpawner.spawnArea(?).area#startNode", "")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".heapSpawner.spawnArea(?).area#widthNode", "")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".heapSpawner.spawnArea(?).area#heightNode", "")
	schema:register(XMLValueType.STRING, basePath .. ".heapSpawner.spawnArea(?)#fillType", "Spawn fill type")
	schema:register(XMLValueType.FLOAT, basePath .. ".heapSpawner.spawnArea(?)#litersPerHour", "Spawn liters per ingame hour")
	EffectManager.registerEffectXMLPaths(schema, basePath .. ".heapSpawner.spawnArea(?).effectNodes")
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".heapSpawner.spawnArea(?).sounds", "work")
	AnimationManager.registerAnimationNodesXMLPaths(schema, basePath .. ".heapSpawner.spawnArea(?).animationNodes")
	schema:setXMLSpecializationType()
end

function PlaceableHeapSpawner:onLoad(savegame)
	local spec = self[PlaceableHeapSpawner.SPEC]
	local key = "placeable.heapSpawner"
	spec.spawnAreas = {}

	self.xmlFile:iterate(key .. ".spawnArea", function (_, areaKey)
		local startNode = self.xmlFile:getValue(areaKey .. ".area#startNode", nil, self.components, self.i3dMappings)

		if startNode == nil then
			Logging.xmlError(self.xmlFile, "Missing startNode for spawnArea '%s'", areaKey)

			return
		end

		local widthNode = self.xmlFile:getValue(areaKey .. ".area#widthNode", nil, self.components, self.i3dMappings)

		if widthNode == nil then
			Logging.xmlError(self.xmlFile, "Missing widthNode for spawnArea '%s'", areaKey)

			return
		end

		local heightNode = self.xmlFile:getValue(areaKey .. ".area#heightNode", nil, self.components, self.i3dMappings)

		if heightNode == nil then
			Logging.xmlError(self.xmlFile, "Missing heightNode for spawnArea '%s'", areaKey)

			return
		end

		local fillTypeName = self.xmlFile:getValue(areaKey .. "#fillType", "")
		local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)

		if fillTypeIndex == nil then
			Logging.xmlError(self.xmlFile, "Missing or invalid fillType (%s) for spawnArea '%s'", fillTypeName, areaKey)

			return
		end

		local litersPerHour = self.xmlFile:getValue(areaKey .. "#litersPerHour", 150)

		if litersPerHour <= 0 then
			Logging.xmlError(self.xmlFile, "litersPerHour may not be 0 or negative for spawnArea '%s'", areaKey)

			return
		end

		local spawnArea = {
			amountToTip = 0,
			lineOffset = 0,
			start = startNode,
			width = widthNode,
			height = heightNode,
			fillTypeIndex = fillTypeIndex,
			litersPerMs = litersPerHour / 3600000
		}

		if self.isClient then
			spawnArea.effects = g_effectManager:loadEffect(self.xmlFile, areaKey .. ".effectNodes", self.components, self, self.i3dMappings)

			g_effectManager:setFillType(spawnArea.effects, fillTypeIndex)
			g_effectManager:startEffects(spawnArea.effects)

			spawnArea.samples = {
				work = g_soundManager:loadSampleFromXML(self.xmlFile, areaKey .. ".sounds", "work", self.baseDirectory, self.components, 1, AudioGroup.ENVIRONMENT, self.i3dMappings, self),
				work2 = g_soundManager:loadSampleFromXML(self.xmlFile, areaKey .. ".sounds", "work2", self.baseDirectory, self.components, 1, AudioGroup.ENVIRONMENT, self.i3dMappings, self),
				dropping = g_soundManager:loadSampleFromXML(self.xmlFile, areaKey .. ".sounds", "dropping", self.baseDirectory, self.components, 1, AudioGroup.ENVIRONMENT, self.i3dMappings, self)
			}

			g_soundManager:playSample(spawnArea.samples.work, 0)
			g_soundManager:playSample(spawnArea.samples.work2, 0)
			g_soundManager:playSample(spawnArea.samples.dropping, 0)

			spawnArea.animationNodes = g_animationManager:loadAnimations(self.xmlFile, areaKey .. ".animationNodes", self.components, self, self.i3dMappings)

			g_animationManager:startAnimations(spawnArea.animationNodes)
		end

		table.insert(spec.spawnAreas, spawnArea)
	end)
end

function PlaceableHeapSpawner:onFinalizePlacement(savegame)
	if self.isServer then
		self:raiseActive()
	end
end

function PlaceableHeapSpawner:onDelete()
	local spec = self[PlaceableHeapSpawner.SPEC]

	for _, spawnArea in ipairs(spec.spawnAreas) do
		g_effectManager:deleteEffects(spawnArea.effects)
		g_soundManager:deleteSamples(spawnArea.samples)
		g_animationManager:deleteAnimations(spawnArea.animationNodes)
	end
end

function PlaceableHeapSpawner:onUpdateTick(dt)
	if self.isServer then
		local spec = self[PlaceableHeapSpawner.SPEC]
		local scaledDt = dt * g_currentMission:getEffectiveTimeScale()

		for _, spawnArea in ipairs(spec.spawnAreas) do
			local amountToTip = scaledDt * spawnArea.litersPerMs
			spawnArea.amountToTip = spawnArea.amountToTip + amountToTip

			if g_densityMapHeightManager:getMinValidLiterValue(spawnArea.fillTypeIndex) < spawnArea.amountToTip then
				local lsx, lsy, lsz, lex, ley, lez, radius = DensityMapHeightUtil.getLineByArea(spawnArea.start, spawnArea.width, spawnArea.height, false)
				local _, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(nil, spawnArea.amountToTip, spawnArea.fillTypeIndex, lsx, lsy, lsz, lex, ley, lez, radius, radius, spawnArea.lineOffset, nil, , )
				spawnArea.lineOffset = lineOffset
				spawnArea.amountToTip = 0
			end
		end

		self:raiseActive()
	end
end
