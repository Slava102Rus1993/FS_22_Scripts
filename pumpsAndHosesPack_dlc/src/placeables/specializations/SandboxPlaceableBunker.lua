SandboxPlaceableBunker = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	RAISETIME_START_ACTIVE = 0,
	RAISETIME_END_ACTIVE = 1,
	RAISETIME_END_FILL = 2,
	RAISETIME_END_DISTRIBUTE = 3
}

function SandboxPlaceableBunker.initSpecialization()
	g_storeManager:addSpecType("sandboxBunkerFillTypes", "shopListAttributeIconInput", SandboxPlaceableBunker.loadSpecValueFillTypes, SandboxPlaceableBunker.getSpecValueFillTypes, "placeable")
end

function SandboxPlaceableBunker.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(SandboxPlaceable, specializations)
end

function SandboxPlaceableBunker.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "raiseActivationTime", SandboxPlaceableBunker.raiseActivationTime)
	SpecializationUtil.registerFunction(placeableType, "setActiveAnimationsState", SandboxPlaceableBunker.setActiveAnimationsState)
	SpecializationUtil.registerFunction(placeableType, "loadFeedingPipes", SandboxPlaceableBunker.loadFeedingPipes)
	SpecializationUtil.registerFunction(placeableType, "onFeedingPipeI3DLoaded", SandboxPlaceableBunker.onFeedingPipeI3DLoaded)
	SpecializationUtil.registerFunction(placeableType, "loadRotationNodeFromXML", SandboxPlaceableBunker.loadRotationNodeFromXML)
	SpecializationUtil.registerFunction(placeableType, "loadTranslationNodeFromXML", SandboxPlaceableBunker.loadTranslationNodeFromXML)
	SpecializationUtil.registerFunction(placeableType, "updateFeedingPipes", SandboxPlaceableBunker.updateFeedingPipes)
	SpecializationUtil.registerFunction(placeableType, "updateFeedingPipeByLoadedPlaceable", SandboxPlaceableBunker.updateFeedingPipeByLoadedPlaceable)
	SpecializationUtil.registerFunction(placeableType, "updateFeedingPipeOrientationByPlaceable", SandboxPlaceableBunker.updateFeedingPipeOrientationByPlaceable)
	SpecializationUtil.registerFunction(placeableType, "finalizeFeedingPipePhysics", SandboxPlaceableBunker.finalizeFeedingPipePhysics)
end

function SandboxPlaceableBunker.registerOverwrittenFunctions(placeableType)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getSandboxRootInRange", SandboxPlaceableBunker.getSandboxRootInRange)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getUtilizationPercentage", SandboxPlaceableBunker.getUtilizationPercentage)
end

function SandboxPlaceableBunker.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", SandboxPlaceableBunker)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", SandboxPlaceableBunker)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizeSandbox", SandboxPlaceableBunker)
	SpecializationUtil.registerEventListener(placeableType, "onDelete", SandboxPlaceableBunker)
	SpecializationUtil.registerEventListener(placeableType, "onReadStream", SandboxPlaceableBunker)
	SpecializationUtil.registerEventListener(placeableType, "onWriteStream", SandboxPlaceableBunker)
	SpecializationUtil.registerEventListener(placeableType, "onUpdateSandboxPlaceable", SandboxPlaceableBunker)
	SpecializationUtil.registerEventListener(placeableType, "onSandboxPlaceableAdded", SandboxPlaceableBunker)
	SpecializationUtil.registerEventListener(placeableType, "onSandboxPlaceableRemoved", SandboxPlaceableBunker)
end

function SandboxPlaceableBunker.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("SandboxBunker")

	local mixersPath = basePath .. ".sandboxBunker.mixers"

	schema:register(XMLValueType.FLOAT, mixersPath .. "#maxRunTime", "Max time to run if no action happens in seconds", 60)
	schema:register(XMLValueType.FLOAT, mixersPath .. "#stayOnTimeAfterFilling", "Time to stay on after filling in seconds", 0)
	schema:register(XMLValueType.FLOAT, mixersPath .. "#stayOnTimeAfterDistribution", "Time to stay on after distribution in seconds", 0)
	EffectManager.registerEffectXMLPaths(schema, mixersPath .. ".effects")
	SoundManager.registerSampleXMLPaths(schema, mixersPath .. ".sounds", "idle")
	AnimationManager.registerAnimationNodesXMLPaths(schema, mixersPath .. ".animationNodes")

	local function genereateSchematics(xmlSchema, path)
		xmlSchema:register(XMLValueType.NODE_INDEX, path .. "#linkNode", "FeedingPipe link node")
		xmlSchema:register(XMLValueType.NODE_INDEX, path .. "#node", "Node index in loaded i3d file")
		xmlSchema:register(XMLValueType.STRING, path .. "#i3dFilename", "FeedingPipe i3d filename")
		xmlSchema:register(XMLValueType.STRING, path .. "#targetType", "SandboxType of feedingPipe target", "FERMENTER")
		xmlSchema:register(XMLValueType.FLOAT, path .. "#maxTargetDistance", "Max target distance", 10)
		xmlSchema:register(XMLValueType.NODE_INDEX, path .. ".rotationNode(?)#node", "Rotation node index in loaded i3d file")
		xmlSchema:register(XMLValueType.INT, path .. ".rotationNode(?)#limitedAxis", "Limited axis")
		xmlSchema:register(XMLValueType.BOOL, path .. ".rotationNode(?)#alignToFermenterHeight", "Align z axis to fermenter height", false)
		xmlSchema:register(XMLValueType.BOOL, path .. ".rotationNode(?)#alignToWorldY", "Align z axis to world y", false)
		xmlSchema:register(XMLValueType.BOOL, path .. ".rotationNode(?)#invertZ", "Invert z axis orientation", false)
		xmlSchema:register(XMLValueType.ANGLE, path .. ".rotationNode(?)#minRot", "Min. rotation for limited axis")
		xmlSchema:register(XMLValueType.ANGLE, path .. ".rotationNode(?)#maxRot", "Max. rotation for limited axis")
		xmlSchema:register(XMLValueType.NODE_INDEX, path .. ".rotationNode(?).translationNode(?)#node", "Translation node index in loaded i3d file")
		xmlSchema:register(XMLValueType.BOOL, path .. ".rotationNode(?).translationNode(?)#translateToTargetBox", "Align part to target size box", false)
		xmlSchema:register(XMLValueType.FLOAT, path .. ".rotationNode(?).translationNode(?)#referenceDistance", "Reference distance")
		xmlSchema:register(XMLValueType.FLOAT, path .. ".rotationNode(?).translationNode(?)#minZTrans", "Min. Z Translation")
		xmlSchema:register(XMLValueType.FLOAT, path .. ".rotationNode(?).translationNode(?)#maxZTrans", "Max. Z Translation")
	end

	local feedingPipesPath = basePath .. ".sandboxBunker.feedingPipes.feedingPipe(?)"

	genereateSchematics(schema, feedingPipesPath)
	schema:setXMLSpecializationType()
	schema:setXMLSpecializationType("StoreData")
	schema:register(XMLValueType.STRING, basePath .. ".storeData.specs.sandboxBunker#showFillTypesInStore", "Boolean if fillTypes are shown in store.", false)
	schema:setXMLSpecializationType()
end

function SandboxPlaceableBunker.registerSavegameXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("SandboxBunker")
	schema:register(XMLValueType.INT, basePath .. ".feedingPipe(?)#index", "Index of feeding pipe.")
	schema:register(XMLValueType.INT, basePath .. ".feedingPipe(?)#placeableId", "Placeable id of child feeding pipe target.")
	schema:setXMLSpecializationType()
end

function SandboxPlaceableBunker.loadSpecValueFillTypes(xmlFile, customEnvironment, baseDir)
	local rootName = xmlFile:getRootName()

	if not xmlFile:getValue(rootName .. ".storeData.specs.sandboxBunker#showFillTypesInStore", false) then
		return nil
	end

	local fillTypeNames = {}
	local storagePath = rootName .. ".silo.storages.storage"

	xmlFile:iterate(storagePath, function (_, storageKey)
		local fillTypesNamesString = xmlFile:getValue(storageKey .. "#fillTypes")

		if fillTypesNamesString ~= nil then
			for _, fillTypeName in pairs(string.split(fillTypesNamesString, " ")) do
				fillTypeNames[fillTypeName] = true
			end
		end
	end)

	return fillTypeNames
end

function SandboxPlaceableBunker.getSpecValueFillTypes(storeItem, realItem)
	if storeItem.specs.sandboxBunkerFillTypes == nil then
		return nil
	end

	return g_fillTypeManager:getFillTypesByNames(table.concatKeys(storeItem.specs.sandboxBunkerFillTypes, " "))
end

function SandboxPlaceableBunker:onLoad(savegame)
	self.spec_sandboxPlaceableBunker = self[("spec_%s.sandboxPlaceableBunker"):format(SandboxPlaceableBunker.MOD_NAME)]
	local spec = self.spec_sandboxPlaceableBunker
	local mixersPath = "placeable.sandboxBunker.mixers"
	spec.maxRunTime = self.xmlFile:getValue(mixersPath .. "#maxRunTime", 60) * 1000
	spec.stayOnTimeAfterFilling = self.xmlFile:getValue(mixersPath .. "#stayOnTimeAfterFilling", 0) * 1000
	spec.stayOnTimeAfterDistribution = self.xmlFile:getValue(mixersPath .. "#stayOnTimeAfterDistribution", 0) * 1000

	if self.isClient then
		spec.effects = g_effectManager:loadEffect(self.xmlFile, mixersPath .. ".effects", self.components, self, self.i3dMappings)

		g_effectManager:setFillType(spec.effects, FillType.UNKNOWN)

		spec.samples = {
			idle = g_soundManager:loadSampleFromXML(self.xmlFile, mixersPath .. ".sounds", "idle", self.baseDirectory, self.components, 0, AudioGroup.ENVIRONMENT, self.i3dMappings, self)
		}
		spec.animationNodes = g_animationManager:loadAnimations(self.xmlFile, mixersPath .. ".animationNodes", self.components, self, self.i3dMappings)
	end

	self:loadFeedingPipes(self.xmlFile, "placeable.sandboxBunker.feedingPipes")

	spec.hasActiveAnimations = false
	spec.lastActivationTime = 0
	spec.addFeedingPipePhysics = false
end

function SandboxPlaceableBunker:onFinalizePlacement()
	local spec = self.spec_sandboxPlaceableBunker

	if not self.isLoadedFromSavegame then
		spec.addFeedingPipePhysics = true
	end
end

function SandboxPlaceableBunker:onFinalizeSandbox()
	local spec = self.spec_sandboxPlaceableBunker
	spec.addFeedingPipePhysics = true

	for _, feedingPipe in pairs(spec.feedingPipes) do
		if not feedingPipe.isFinalized then
			if self.isLoadedFromSavegame then
				self:updateFeedingPipeByLoadedPlaceable(feedingPipe)
			else
				self:updateFeedingPipes(nil, feedingPipe.index)
			end
		end
	end
end

function SandboxPlaceableBunker:onDelete()
	local spec = self.spec_sandboxPlaceableBunker

	if spec == nil then
		return
	end

	if spec.sharedLoadRequestIds ~= nil then
		for _, sharedLoadRequestId in ipairs(spec.sharedLoadRequestIds) do
			g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)
		end

		spec.sharedLoadRequestIds = nil
	end

	g_effectManager:deleteEffects(spec.effects)
	g_soundManager:deleteSamples(spec.samples)
	g_animationManager:deleteAnimations(spec.animationNodes)
end

function SandboxPlaceableBunker:onReadStream(streamId, connection)
	local spec = self.spec_sandboxPlaceableBunker
	local hasActiveAnimations = streamReadBool(streamId)

	self:setActiveAnimationsState(hasActiveAnimations)
end

function SandboxPlaceableBunker:onWriteStream(streamId, connection)
	local spec = self.spec_sandboxPlaceableBunker

	streamWriteBool(streamId, spec.hasActiveAnimations)
end

function SandboxPlaceableBunker:loadFromXMLFile(xmlFile, key)
	local spec = self.spec_sandboxPlaceableBunker

	if spec.targetPlaceableIdsToLoad == nil then
		spec.targetPlaceableIdsToLoad = {}
	end

	xmlFile:iterate(key .. ".feedingPipe", function (indexI, feedingPipeKey)
		local index = xmlFile:getValue(feedingPipeKey .. "#index")

		if spec.targetPlaceableIdsToLoad[index] == nil then
			local placeableId = xmlFile:getValue(feedingPipeKey .. "#placeableId")

			if placeableId ~= nil then
				spec.targetPlaceableIdsToLoad[index] = placeableId
			else
				Logging.xmlWarning(xmlFile, "Unknown placeable id '%s', ignoring it!", placeableId)
			end
		else
			Logging.xmlWarning(xmlFile, "Loading feeding pipe with invalid index '%s' from savegame, ignoring it!", index)
		end
	end)
end

function SandboxPlaceableBunker:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_sandboxPlaceableBunker

	for k, feedingPipe in pairs(spec.feedingPipes) do
		if feedingPipe.targetPlaceable ~= nil and feedingPipe.targetPlaceable.currentSavegameId ~= nil then
			local feedingPipeKey = string.format("%s.feedingPipe(%i)", key, k - 1)

			xmlFile:setValue(feedingPipeKey .. "#index", k)
			xmlFile:setValue(feedingPipeKey .. "#placeableId", feedingPipe.targetPlaceable.currentSavegameId)
		end
	end
end

function SandboxPlaceableBunker:onUpdateSandboxPlaceable(dt)
	local spec = self.spec_sandboxPlaceableBunker

	if self.isServer then
		if spec.lastActivationTime > 0 then
			local hasFill = false

			for _, fillLevel in pairs(self:getFillLevels()) do
				if fillLevel > 0 then
					hasFill = true

					break
				end
			end

			if spec.lastActivationTime < g_currentMission.time or not hasFill then
				self:raiseActivationTime(SandboxPlaceableBunker.RAISETIME_END_ACTIVE)
			elseif not spec.hasActiveAnimations then
				self:setActiveAnimationsState(true)
			end
		elseif spec.hasActiveAnimations then
			self:setActiveAnimationsState(false)
		end
	end

	for _, feedingPipe in pairs(spec.feedingPipes) do
		if not feedingPipe.isFinalized then
			if feedingPipe.targetPlaceable == nil then
				if spec.targetPlaceableIdsToLoad ~= nil and spec.targetPlaceableIdsToLoad[feedingPipe.index] ~= nil then
					self:updateFeedingPipeByLoadedPlaceable(feedingPipe)
				else
					self:updateFeedingPipes(nil, feedingPipe.index)
				end
			end

			self:finalizeFeedingPipePhysics(feedingPipe)
		end
	end
end

function SandboxPlaceableBunker:onSandboxPlaceableAdded(placeable)
	local spec = self.spec_sandboxPlaceableBunker
	local sandboxRoot = self:getSandboxRootPlaceable()

	if sandboxRoot ~= nil and not self.isLoadedFromSavegame then
		for _, feedingPipe in pairs(spec.feedingPipes) do
			if feedingPipe.targetPlaceable == nil then
				self:updateFeedingPipes(sandboxRoot, feedingPipe.index)
			end
		end
	end
end

function SandboxPlaceableBunker:onSandboxPlaceableRemoved(placeable)
	local spec = self.spec_sandboxPlaceableBunker
	local feedingPipe = spec.feedingPipeByPlaceable[placeable]

	if feedingPipe ~= nil then
		self:updateFeedingPipeOrientationByPlaceable(feedingPipe, nil)
	end
end

function SandboxPlaceableBunker:raiseActivationTime(mode)
	local spec = self.spec_sandboxPlaceableBunker

	if self.isServer and mode ~= nil then
		if mode == SandboxPlaceableBunker.RAISETIME_START_ACTIVE then
			spec.lastActivationTime = g_currentMission.time + spec.maxRunTime
		elseif mode == SandboxPlaceableBunker.RAISETIME_END_DISTRIBUTE then
			spec.lastActivationTime = g_currentMission.time + spec.stayOnTimeAfterDistribution
		elseif mode == SandboxPlaceableBunker.RAISETIME_END_FILL then
			spec.lastActivationTime = g_currentMission.time + spec.stayOnTimeAfterFilling
		else
			spec.lastActivationTime = 0
		end
	end
end

function SandboxPlaceableBunker:setActiveAnimationsState(state)
	local spec = self.spec_sandboxPlaceableBunker

	if state ~= spec.hasActiveAnimations then
		if self.isClient then
			if state then
				g_animationManager:startAnimations(spec.animationNodes)
				g_effectManager:startEffects(spec.effects)
				g_soundManager:playSample(spec.samples.idle)
			else
				g_animationManager:stopAnimations(spec.animationNodes)
				g_effectManager:stopEffects(spec.effects)
				g_soundManager:stopSample(spec.samples.idle)
			end
		end

		spec.hasActiveAnimations = state

		if self.isServer then
			g_server:broadcastEvent(SandboxPlaceableActiveAnimationsEvent.new(self, spec.hasActiveAnimations), nil, , self)
		end
	end
end

function SandboxPlaceableBunker:loadFeedingPipes(xmlFile, key)
	local spec = self.spec_sandboxPlaceableBunker
	spec.feedingPipes = {}
	spec.feedingPipeByPlaceable = {}
	spec.sharedLoadRequestIds = {}

	xmlFile:iterate(key .. ".feedingPipe", function (index, keyI)
		local linkNode = xmlFile:getValue(keyI .. "#linkNode", nil, self.components, self.i3dMappings)
		local i3dFilename = xmlFile:getValue(keyI .. "#i3dFilename")
		local targetTypeName = xmlFile:getValue(keyI .. "#targetType", "FERMENTER")
		targetTypeName = "TYPE_" .. targetTypeName:upper()
		local targetType = SandboxPlaceable[targetTypeName]

		if targetType == nil then
			Logging.xmlWarning(xmlFile, "Unable to resolve type '%s' for target sandbox placeable '%s'", targetTypeName, keyI)
		end

		if i3dFilename ~= nil and linkNode ~= nil and targetType ~= nil then
			i3dFilename = Utils.getFilename(i3dFilename, self.baseDirectory)
			local arguments = {
				xmlFile = xmlFile,
				key = keyI,
				linkNode = linkNode,
				i3dFilename = i3dFilename,
				targetType = targetType
			}
			local sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(i3dFilename, false, false, self.onFeedingPipeI3DLoaded, self, arguments)

			table.insert(spec.sharedLoadRequestIds, sharedLoadRequestId)
		end
	end)
end

function SandboxPlaceableBunker:onFeedingPipeI3DLoaded(i3dNode, failedReason, args)
	local spec = self.spec_sandboxPlaceableBunker

	if i3dNode ~= 0 then
		local xmlFile = args.xmlFile
		local key = args.key
		local node = xmlFile:getValue(key .. "#node", "0", i3dNode)

		if node ~= nil and node ~= 0 then
			local feedingPipe = {
				node = args.linkNode,
				rootNode = node,
				i3dFilename = args.i3dFilename,
				targetType = args.targetType,
				rotationNodes = {}
			}

			xmlFile:iterate(key .. ".rotationNode", function (_, rotationNodeKey)
				local rotationNode = {}

				if self:loadRotationNodeFromXML(xmlFile, rotationNodeKey, rotationNode, node, i3dNode) then
					rotationNode.translationNodes = {}

					xmlFile:iterate(rotationNodeKey .. ".translationNode", function (_, translationNodeKey)
						local translationNode = {}

						if self:loadTranslationNodeFromXML(xmlFile, translationNodeKey, translationNode, rotationNode, node, i3dNode) then
							table.insert(rotationNode.translationNodes, translationNode)
						else
							Logging.xmlWarning(xmlFile, "Could not load translationNode for '%s'", translationNodeKey)

							return false
						end
					end)
					table.insert(feedingPipe.rotationNodes, rotationNode)
				else
					Logging.xmlWarning(xmlFile, "Could not load rotationNode for '%s'", rotationNodeKey)

					return false
				end
			end)

			feedingPipe.maxTargetDistance = xmlFile:getValue(key .. "#maxTargetDistance", 10)
			feedingPipe.index = #spec.feedingPipes + 1
			feedingPipe.isFinalized = false

			link(feedingPipe.node, feedingPipe.rootNode)
			table.insert(spec.feedingPipes, feedingPipe)

			if not self.isLoadedFromSavegame then
				self:updateFeedingPipes(nil, feedingPipe.index)
			end
		end

		delete(i3dNode)
	end
end

function SandboxPlaceableBunker:loadRotationNodeFromXML(xmlFile, rotationNodeKey, rotationNode, rootNode, i3dNode)
	local node = xmlFile:getValue(rotationNodeKey .. "#node", rootNode, i3dNode)

	if node == nil or node == 0 then
		return false
	end

	rotationNode.node = node
	rotationNode.invertZ = xmlFile:getValue(rotationNodeKey .. "#invertZ", false)
	rotationNode.alignToFermenterHeight = xmlFile:getValue(rotationNodeKey .. "#alignToFermenterHeight", false)
	rotationNode.alignToWorldY = xmlFile:getValue(rotationNodeKey .. "#alignToWorldY", false)
	rotationNode.limitedAxis = xmlFile:getValue(rotationNodeKey .. "#limitedAxis")
	local minRot = xmlFile:getValue(rotationNodeKey .. "#minRot")
	local maxRot = xmlFile:getValue(rotationNodeKey .. "#maxRot")

	if minRot ~= nil and maxRot ~= nil then
		if rotationNode.limitedAxis ~= nil then
			rotationNode.minRot = MathUtil.getValidLimit(minRot)
			rotationNode.maxRot = MathUtil.getValidLimit(maxRot)
		else
			Logging.xmlWarning(xmlFile, "minRot/maxRot requires the use of limitedAxis in '%s'", rotationNodeKey)
		end
	end

	return true
end

function SandboxPlaceableBunker:loadTranslationNodeFromXML(xmlFile, translationNodeKey, translationNode, rotationNode, rootNode, i3dNode)
	local node = xmlFile:getValue(translationNodeKey .. "#node", rootNode, i3dNode)

	if node == nil or node == 0 then
		return false
	end

	translationNode.node = node
	translationNode.translateToTargetBox = xmlFile:getValue(translationNodeKey .. "#translateToTargetBox", false)
	local x, y, z = getTranslation(node)
	translationNode.startPos = {
		x,
		y,
		z
	}
	translationNode.lastZ = z
	local _, _, refZ = worldToLocal(node, getWorldTranslation(rotationNode.node))
	translationNode.referenceDistance = xmlFile:getValue(translationNodeKey .. "#referenceDistance", refZ)
	translationNode.minZTrans = xmlFile:getValue(translationNodeKey .. "#minZTrans")
	translationNode.maxZTrans = xmlFile:getValue(translationNodeKey .. "#maxZTrans")

	return true
end

function SandboxPlaceableBunker:updateFeedingPipes(sandboxRoot, forcedIndex)
	local spec = self.spec_sandboxPlaceableBunker
	sandboxRoot = sandboxRoot or self:getSandboxRootPlaceable()
	local canBePlaced = true

	for index, feedingPipe in ipairs(spec.feedingPipes) do
		if forcedIndex == nil or forcedIndex == index then
			local nearestDistance = feedingPipe.maxTargetDistance
			local nearestTarget = nil

			if sandboxRoot ~= nil then
				local targetPlaceables = sandboxRoot:getPlaceableChildrenbyType(feedingPipe.targetType)

				if feedingPipe.targetType == SandboxPlaceable.TYPE_FERMENTER and not table.hasElement(targetPlaceables, sandboxRoot) then
					table.addElement(targetPlaceables, sandboxRoot)
				end

				for _, placeable in ipairs(targetPlaceables) do
					local refNode = placeable.rootNode
					local fermenterSize = 0

					if placeable.getFeedingPipeParams ~= nil then
						refNode, fermenterSize = placeable:getFeedingPipeParams()
					end

					local distance = math.max(calcDistanceFrom(feedingPipe.rootNode, refNode) - fermenterSize / 2, 0)

					if distance <= nearestDistance then
						nearestDistance = distance
						nearestTarget = placeable
					end
				end
			end

			canBePlaced = canBePlaced and nearestTarget ~= nil

			self:updateFeedingPipeOrientationByPlaceable(feedingPipe, nearestTarget)
		end
	end

	if canBePlaced then
		-- Nothing
	end

	return canBePlaced, g_i18n:getText("warning_noFeedingPipeTargetFound")
end

function SandboxPlaceableBunker:updateFeedingPipeByLoadedPlaceable(feedingPipe)
	local spec = self.spec_sandboxPlaceableBunker

	if spec.targetPlaceableIdsToLoad ~= nil and spec.targetPlaceableIdsToLoad[feedingPipe.index] ~= nil then
		local targetPlaceable = g_currentMission.placeableSystem:getPlaceableBySavegameId(spec.targetPlaceableIdsToLoad[feedingPipe.index])

		self:updateFeedingPipeOrientationByPlaceable(feedingPipe, targetPlaceable)

		spec.targetPlaceableIdsToLoad[feedingPipe.index] = nil

		return true
	end

	return false
end

function SandboxPlaceableBunker:updateFeedingPipeOrientationByPlaceable(feedingPipe, targetPlaceable)
	local spec = self.spec_sandboxPlaceableBunker

	setVisibility(feedingPipe.rootNode, targetPlaceable ~= nil)

	feedingPipe.targetPlaceable = targetPlaceable

	if targetPlaceable ~= nil then
		spec.feedingPipeByPlaceable[targetPlaceable] = feedingPipe
		local refNode = targetPlaceable.rootNode
		local fermenterSize = 0

		if targetPlaceable.getFeedingPipeParams ~= nil then
			refNode, fermenterSize = targetPlaceable:getFeedingPipeParams()
		end

		local refX, refY, refZ = getWorldTranslation(refNode)

		for _, rotationNode in ipairs(feedingPipe.rotationNodes) do
			local dirX = 0
			local dirY = 0
			local dirZ = 0

			if rotationNode.alignToWorldY then
				dirX, dirY, dirZ = localDirectionToWorld(getRootNode(), 0, 1, 0)
			elseif rotationNode.alignToFermenterHeight then
				local x, y, z = getWorldTranslation(rotationNode.node)
				local fDirX = x - refX
				local fDirY = y - refY
				local fDirZ = z - refZ
				fDirX, fDirY, fDirZ = MathUtil.vector3Normalize(fDirX, fDirY, fDirZ)
				refX = refX + fDirX * fermenterSize / 2
				refZ = refZ + fDirZ * fermenterSize / 2
				dirX = refX - x
				dirY = refY - y
				dirZ = refZ - z
			else
				local x, y, z = getWorldTranslation(rotationNode.node)
				dirX = refX - x
				dirY = refY - y
				dirZ = refZ - z
			end

			if dirX ~= 0 or dirY ~= 0 or dirZ ~= 0 then
				local upX, upY, upZ = localDirectionToWorld(getParent(rotationNode.node), 0, 1, 0)

				if rotationNode.invertZ then
					dirX = -dirX
					dirY = -dirY
					dirZ = -dirZ
				end

				I3DUtil.setWorldDirection(rotationNode.node, dirX, dirY, dirZ, upX, upY, upZ, rotationNode.limitedAxis, rotationNode.minRot, rotationNode.maxRot)
			end

			for _, translationNode in ipairs(rotationNode.translationNodes) do
				if translationNode.translateToTargetBox then
					local setTrans = false
					local _, _, dist = worldToLocal(rotationNode.node, refX, refY, refZ)
					local offset = 0

					if not rotationNode.alignToFermenterHeight then
						local rootDx, rootDy, rootDz = localDirectionToWorld(refNode, 0, 1, 0)
						dirX, dirY, dirZ = localDirectionToWorld(translationNode.node, 0, 1, 0)
						local cosAngle = MathUtil.dotProduct(rootDx, rootDy, rootDz, dirX, dirY, dirZ)
						offset = fermenterSize / (2 * cosAngle)
					end

					local newZ = dist - offset - translationNode.referenceDistance

					if translationNode.minZTrans ~= nil then
						newZ = math.max(translationNode.minZTrans, newZ)
					end

					if translationNode.maxZTrans ~= nil then
						newZ = math.min(translationNode.maxZTrans, newZ)
					end

					if math.abs(newZ - translationNode.lastZ) > 0.001 then
						setTrans = true
					end

					if setTrans then
						setTranslation(translationNode.node, translationNode.startPos[1], translationNode.startPos[2], newZ)

						translationNode.lastZ = newZ
					end
				end
			end
		end
	else
		table.removeElement(spec.feedingPipeByPlaceable, feedingPipe)
	end
end

function SandboxPlaceableBunker:finalizeFeedingPipePhysics(feedingPipe)
	local spec = self.spec_sandboxPlaceableBunker

	if spec.addFeedingPipePhysics then
		feedingPipe.isFinalized = getVisibility(feedingPipe.rootNode)

		if feedingPipe.isFinalized then
			addToPhysics(feedingPipe.rootNode)
		else
			removeFromPhysics(feedingPipe.rootNode)
		end
	end
end

function SandboxPlaceableBunker:getSandboxRootInRange(superFunc, x, y, z, farmId)
	local canBePlaced, errorMessage, rootPlaceable = superFunc(self, x, y, z, farmId)

	if canBePlaced then
		canBePlaced, errorMessage = self:updateFeedingPipes(rootPlaceable)
	end

	return canBePlaced, errorMessage, rootPlaceable
end

function SandboxPlaceableBunker:getUtilizationPercentage(superFunc)
	local spec = self.spec_sandboxPlaceableBunker
	local rootPlaceable = self:getSandboxRootPlaceable()

	if rootPlaceable ~= nil then
		local fermenterPlaceables = rootPlaceable:getPlaceableChildrenbyType(SandboxPlaceable.TYPE_FERMENTER)

		if not table.hasElement(fermenterPlaceables, rootPlaceable) then
			table.addElement(fermenterPlaceables, rootPlaceable)
		end

		local overallFillLevels = {}
		local overallCapacity = 0
		local bunkerPlaceables = rootPlaceable:getPlaceableChildrenbyType(SandboxPlaceable.TYPE_BUNKER)

		for _, bunkerPlaceable in pairs(bunkerPlaceables) do
			if bunkerPlaceable.spec_silo ~= nil then
				local storages = bunkerPlaceable.spec_silo.storages

				for _, storage in ipairs(storages) do
					overallCapacity = overallCapacity + storage:getCapacity(fillTypeIndex)
				end

				local loadingStation = bunkerPlaceable.spec_silo.loadingStation

				if loadingStation ~= nil then
					local fillLevels = loadingStation:getAllFillLevels(self:getOwnerFarmId())

					for fillTypeIndex, fillLevel in pairs(fillLevels) do
						if fillLevel > 0 then
							if overallFillLevels[fillTypeIndex] == nil then
								overallFillLevels[fillTypeIndex] = 0
							end

							overallFillLevels[fillTypeIndex] = overallFillLevels[fillTypeIndex] + fillLevel
						end
					end
				end
			end
		end

		local percentage = 0
		local message = nil
		local overallFillLevel = 0

		for _, fillLevel in pairs(overallFillLevels) do
			overallFillLevel = overallFillLevel + fillLevel
		end

		percentage = overallFillLevel / overallCapacity

		return percentage, message
	end

	return superFunc(self)
end
