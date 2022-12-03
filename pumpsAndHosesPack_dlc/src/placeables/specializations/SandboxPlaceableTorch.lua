SandboxPlaceableTorch = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	RAISETIME_START_ACTIVE = 0,
	RAISETIME_END_ACTIVE = 1,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(SandboxPlaceable, specializations)
	end
}

function SandboxPlaceableTorch.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "raiseActivationTime", SandboxPlaceableTorch.raiseActivationTime)
	SpecializationUtil.registerFunction(placeableType, "setActiveAnimationsState", SandboxPlaceableTorch.setActiveAnimationsState)
	SpecializationUtil.registerFunction(placeableType, "loadExhaustEffects", SandboxPlaceableTorch.loadExhaustEffects)
	SpecializationUtil.registerFunction(placeableType, "onExhaustEffectI3DLoaded", SandboxPlaceableTorch.onExhaustEffectI3DLoaded)
	SpecializationUtil.registerFunction(placeableType, "getSupportedFillTypes", SandboxPlaceableTorch.getSupportedFillTypes)
end

function SandboxPlaceableTorch.registerOverwrittenFunctions(placeableType)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getUtilizationPercentage", SandboxPlaceableTorch.getUtilizationPercentage)
end

function SandboxPlaceableTorch.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", SandboxPlaceableTorch)
	SpecializationUtil.registerEventListener(placeableType, "onDelete", SandboxPlaceableTorch)
	SpecializationUtil.registerEventListener(placeableType, "onReadStream", SandboxPlaceableTorch)
	SpecializationUtil.registerEventListener(placeableType, "onWriteStream", SandboxPlaceableTorch)
	SpecializationUtil.registerEventListener(placeableType, "onUpdateSandboxPlaceable", SandboxPlaceableTorch)
end

function SandboxPlaceableTorch.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("SandboxTorch")

	local torchPath = basePath .. ".sandboxTorch"

	schema:register(XMLValueType.FLOAT, torchPath .. "#maxRunTime", "Max time to run if no action happens in seconds", 60)
	schema:register(XMLValueType.FLOAT, torchPath .. "#fermenterPercentageToRun", "Percentage of fillTypes in fermenter to start torch", 0.99)
	schema:register(XMLValueType.NODE_INDEX, torchPath .. ".exhaustEffects.exhaustEffect(?)#node", "Effect link node")
	schema:register(XMLValueType.STRING, torchPath .. ".exhaustEffects.exhaustEffect(?)#filename", "Effect i3d filename")
	schema:register(XMLValueType.VECTOR_4, torchPath .. ".exhaustEffects.exhaustEffect(?)#shaderValues", "Shader color", "0.0384 0.0359 0.0627 1")
	schema:register(XMLValueType.FLOAT, torchPath .. ".exhaustEffects.exhaustEffect(?)#sizeScale", "Exhaust size scale", "1")
	EffectManager.registerEffectXMLPaths(schema, torchPath .. ".effects")
	SoundManager.registerSampleXMLPaths(schema, torchPath .. ".sounds", "idle")
	AnimationManager.registerAnimationNodesXMLPaths(schema, torchPath .. ".animationNodes")
	schema:register(XMLValueType.STRING, torchPath .. "#fillTypeCategories", "Fill type categories")
	schema:register(XMLValueType.STRING, torchPath .. "#fillTypes", "List of supported fill types")
	schema:setXMLSpecializationType()
end

function SandboxPlaceableTorch:onLoad(savegame)
	self.spec_sandboxPlaceableTorch = self[("spec_%s.sandboxPlaceableTorch"):format(SandboxPlaceableTorch.MOD_NAME)]
	local spec = self.spec_sandboxPlaceableTorch
	local torchPath = "placeable.sandboxTorch"
	spec.maxRunTime = self.xmlFile:getValue(torchPath .. "#maxRunTime", 60) * 1000
	spec.fermenterPercentageToRun = self.xmlFile:getValue(torchPath .. "#fermenterPercentageToRun", 0.99)
	spec.supportedFillTypes = {}
	local fillTypes = g_fillTypeManager:getFillTypesFromXML(self.xmlFile, torchPath .. "#fillTypeCategories", torchPath .. "#fillTypes", true)

	if fillTypes ~= nil then
		for _, fillType in pairs(fillTypes) do
			spec.supportedFillTypes[fillType] = true
		end
	end

	if self.isClient then
		self:loadExhaustEffects(self.xmlFile, torchPath)

		spec.effects = g_effectManager:loadEffect(self.xmlFile, torchPath .. ".effects", self.components, self, self.i3dMappings)

		g_effectManager:setFillType(spec.effects, FillType.UNKNOWN)

		spec.samples = {
			idle = g_soundManager:loadSampleFromXML(self.xmlFile, torchPath .. ".sounds", "idle", self.baseDirectory, self.components, 0, AudioGroup.ENVIRONMENT, self.i3dMappings, self)
		}
		spec.animationNodes = g_animationManager:loadAnimations(self.xmlFile, torchPath .. ".animationNodes", self.components, self, self.i3dMappings)
	end

	spec.hasActiveAnimations = false
	spec.lastActivationTime = 0
	spec.lastUtilizationTime = 0
	spec.showChangedUtilizationText = true
end

function SandboxPlaceableTorch:onDelete()
	local spec = self.spec_sandboxPlaceableTorch

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

function SandboxPlaceableTorch:onReadStream(streamId, connection)
	local spec = self.spec_sandboxPlaceableTorch
	local hasActiveAnimations = streamReadBool(streamId)

	self:setActiveAnimationsState(hasActiveAnimations)
end

function SandboxPlaceableTorch:onWriteStream(streamId, connection)
	local spec = self.spec_sandboxPlaceableTorch

	streamWriteBool(streamId, spec.hasActiveAnimations)
end

function SandboxPlaceableTorch:onUpdateSandboxPlaceable(dt)
	local spec = self.spec_sandboxPlaceableTorch

	if spec.lastActivationTime > 0 then
		if spec.lastActivationTime < g_currentMission.time then
			self:raiseActivationTime(SandboxPlaceableTorch.RAISETIME_END_ACTIVE)
		elseif not spec.hasActiveAnimations then
			self:setActiveAnimationsState(true)
		end
	elseif spec.hasActiveAnimations then
		self:setActiveAnimationsState(false)
	end
end

function SandboxPlaceableTorch:raiseActivationTime(mode)
	local spec = self.spec_sandboxPlaceableTorch

	if mode ~= nil then
		if mode == SandboxPlaceableTorch.RAISETIME_START_ACTIVE then
			spec.lastActivationTime = g_currentMission.time + spec.maxRunTime
		else
			spec.lastActivationTime = 0
		end
	end
end

function SandboxPlaceableTorch:setActiveAnimationsState(state)
	local spec = self.spec_sandboxPlaceableTorch

	if state ~= spec.hasActiveAnimations then
		if self.isClient then
			if state then
				if spec.exhaustEffects ~= nil then
					for _, effect in pairs(spec.exhaustEffects) do
						setVisibility(effect.effectNode, true)
						setShaderParameter(effect.effectNode, "param", 0, 0, 0, effect.sizeScale, false)

						local color = effect.shaderValues

						setShaderParameter(effect.effectNode, "exhaustColor", color[1], color[2], color[3], color[4], false)
					end
				end

				g_animationManager:startAnimations(spec.animationNodes)
				g_effectManager:startEffects(spec.effects)
				g_soundManager:playSample(spec.samples.idle)

				local text = g_i18n:getText("notification_methaneTorchActive")

				g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, text)
			else
				if spec.exhaustEffects ~= nil then
					for _, effect in pairs(spec.exhaustEffects) do
						setVisibility(effect.effectNode, false)
					end
				end

				g_animationManager:stopAnimations(spec.animationNodes)
				g_effectManager:stopEffects(spec.effects)
				g_soundManager:stopSample(spec.samples.idle)

				local text = g_i18n:getText("notification_methaneTorchInactive")

				g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, text)
			end
		end

		spec.hasActiveAnimations = state

		if self.isServer then
			g_server:broadcastEvent(SandboxPlaceableActiveAnimationsEvent.new(self, spec.hasActiveAnimations), nil, , self)
		end
	end
end

function SandboxPlaceableTorch:loadExhaustEffects(xmlFile, key)
	local spec = self.spec_sandboxPlaceableTorch
	spec.exhaustEffects = {}
	spec.sharedLoadRequestIds = {}

	xmlFile:iterate(key .. ".exhaustEffects.exhaustEffect", function (index, keyI)
		local linkNode = xmlFile:getValue(keyI .. "#node", nil, self.components, self.i3dMappings)
		local filename = xmlFile:getValue(keyI .. "#filename")

		if filename ~= nil and linkNode ~= nil then
			filename = Utils.getFilename(filename, self.baseDirectory)
			local arguments = {
				xmlFile = xmlFile,
				key = keyI,
				linkNode = linkNode,
				filename = filename
			}
			local sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(filename, false, false, self.onExhaustEffectI3DLoaded, self, arguments)

			table.insert(spec.sharedLoadRequestIds, sharedLoadRequestId)
		end
	end)
end

function SandboxPlaceableTorch:onExhaustEffectI3DLoaded(i3dNode, failedReason, args)
	local spec = self.spec_sandboxPlaceableTorch

	if i3dNode ~= 0 then
		local node = getChildAt(i3dNode, 0)

		if getHasShaderParameter(node, "param") then
			local xmlFile = args.xmlFile
			local key = args.key
			local effect = {
				effectNode = node,
				node = args.linkNode,
				filename = args.filename
			}

			link(effect.node, effect.effectNode)
			setVisibility(effect.effectNode, false)
			delete(i3dNode)

			effect.shaderValues = xmlFile:getValue(key .. "#shaderValues", "0.0384 0.0359 0.0627 1", true)
			effect.sizeScale = xmlFile:getValue(key .. "#sizeScale", "1")

			table.insert(spec.exhaustEffects, effect)
		end
	end
end

function SandboxPlaceableTorch:getSupportedFillTypes()
	return self.spec_sandboxPlaceableTorch.supportedFillTypes
end

function SandboxPlaceableTorch:getUtilizationPercentage(superFunc)
	local root = self:isSandboxRoot() and self or self:getSandboxRootPlaceable()
	local mergedPlaceables = root:getMergedPlaceables()

	if mergedPlaceables ~= nil then
		local spec = self.spec_sandboxPlaceableTorch
		local mergedPowerplant = mergedPlaceables[SandboxPlaceable.TYPE_POWERPLANT]

		if mergedPowerplant ~= nil then
			local percentage = mergedPowerplant:getUtilizationPercentage()

			if percentage > 1 or spec.hasActiveAnimations then
				if not spec.hasActiveAnimations then
					spec.showChangedUtilizationText = false
				elseif spec.lastUtilizationTime < g_currentMission.time then
					spec.showChangedUtilizationText = not spec.showChangedUtilizationText
					spec.lastUtilizationTime = g_currentMission.time + 4000
				end

				percentage = math.max(percentage - 1, 0)
				local text = spec.showChangedUtilizationText and g_i18n:getText("notification_methaneTorchActive") or g_i18n:getText("notification_methaneTorchBurning"):format(percentage * 100)

				return percentage, text, SandboxPlaceable.UTILIZATION_STATE.RUNNING_LIMIT
			else
				local text = g_i18n:getText("notification_methaneTorchInactive")

				return 0, text, SandboxPlaceable.UTILIZATION_STATE.RUNNING_PERFECT
			end
		else
			local rootProductionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(root)
			local fermenterProduction = SandboxPlaceableProductionPoint.getSandboxProduction(rootProductionPoint, nil)

			if fermenterProduction ~= nil and fermenterProduction.status == ProductionPoint.PROD_STATUS.RUNNING then
				if spec.lastUtilizationTime < g_currentMission.time then
					spec.showChangedUtilizationText = not spec.showChangedUtilizationText
					spec.lastUtilizationTime = g_currentMission.time + 4000
				end

				local text = spec.showChangedUtilizationText and g_i18n:getText("notification_methaneTorchActive") or g_i18n:getText("notification_methaneTorchBurning"):format(100)

				return 1, text, SandboxPlaceable.UTILIZATION_STATE.RUNNING_BAD
			else
				local text = g_i18n:getText("notification_methaneTorchInactive")

				return 0, text, SandboxPlaceable.UTILIZATION_STATE.RUNNING_PERFECT
			end
		end
	end

	return superFunc(self)
end
