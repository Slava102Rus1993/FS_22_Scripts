SandboxPlaceableProductionPoint = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	getSandboxProduction = function (productionPoint, name)
		if name == nil then
			name = SandboxPlaceable.TYPE_NAME[SandboxPlaceable.TYPE_FERMENTER]
		end

		if type(name) == "number" then
			name = SandboxPlaceable.TYPE_NAME[name]
		end

		if productionPoint.productionsIdToObj ~= nil then
			return productionPoint.productionsIdToObj[name]
		end

		return nil
	end,
	getPlaceableProductionPoint = function (source)
		if source.spec_sandboxPlaceableProductionPoint ~= nil and source.spec_sandboxPlaceableProductionPoint.productionPoint ~= nil then
			return source.spec_sandboxPlaceableProductionPoint.productionPoint
		end

		return nil
	end,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(PlaceableInfoTrigger, specializations) and SpecializationUtil.hasSpecialization(SandboxPlaceable, specializations)
	end
}

function SandboxPlaceableProductionPoint.initSpecialization()
	g_storeManager:addSpecType("sandboxConsumption", "constructionListAttributeIconValue", SandboxPlaceableProductionPoint.loadSpecValueSandboxConsumption, SandboxPlaceableProductionPoint.getSpecValueSandboxConsumption, "placeable")
end

function SandboxPlaceableProductionPoint.registerEvents(placeableType)
	SpecializationUtil.registerEvent(placeableType, "onOutputFillTypesChanged")
	SpecializationUtil.registerEvent(placeableType, "onProductionStatusChanged")
end

function SandboxPlaceableProductionPoint.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("ProductionPoint")
	SandboxProductionPoint.registerXMLPaths(schema, basePath .. ".productionPoint")
	schema:setXMLSpecializationType()
	schema:setXMLSpecializationType("StoreData")
	schema:register(XMLValueType.STRING, basePath .. ".storeData.specs.sandboxConsumption#fillType", "FillType to render consumption from in construction menu.")
	schema:register(XMLValueType.STRING, basePath .. ".storeData.specs.sandboxConsumption#value", "String for construction menu.")
	schema:setXMLSpecializationType()
end

function SandboxPlaceableProductionPoint.registerSavegameXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("ProductionPoint")
	SandboxProductionPoint.registerSavegameXMLPaths(schema, basePath)
	schema:setXMLSpecializationType()
end

function SandboxPlaceableProductionPoint.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "updateMergedPlaceableProductions", SandboxPlaceableProductionPoint.updateMergedPlaceableProductions)
	SpecializationUtil.registerFunction(placeableType, "updateMergedPlaceableBunkers", SandboxPlaceableProductionPoint.updateMergedPlaceableBunkers)
	SpecializationUtil.registerFunction(placeableType, "updateMergedPlaceableSilos", SandboxPlaceableProductionPoint.updateMergedPlaceableSilos)
	SpecializationUtil.registerFunction(placeableType, "updateMergedPlaceableTorchs", SandboxPlaceableProductionPoint.updateMergedPlaceableTorchs)
	SpecializationUtil.registerFunction(placeableType, "distributeAmount", SandboxPlaceableProductionPoint.distributeAmount)
	SpecializationUtil.registerFunction(placeableType, "outputsChanged", SandboxPlaceableProductionPoint.outputsChanged)
	SpecializationUtil.registerFunction(placeableType, "productionStatusChanged", SandboxPlaceableProductionPoint.productionStatusChanged)
	SpecializationUtil.registerFunction(placeableType, "getValidOutputProductionPoints", SandboxPlaceableProductionPoint.getValidOutputProductionPoints)
	SpecializationUtil.registerFunction(placeableType, "getMergedPlaceables", SandboxPlaceableProductionPoint.getMergedPlaceables)
	SpecializationUtil.registerFunction(placeableType, "updateProductionPoint", SandboxPlaceableProductionPoint.updateProductionPoint)
	SpecializationUtil.registerFunction(placeableType, "mergeProductionPointsAtSelf", SandboxPlaceableProductionPoint.mergeProductionPointsAtSelf)
	SpecializationUtil.registerFunction(placeableType, "refillAmount", SandboxPlaceableProductionPoint.refillAmount)
end

function SandboxPlaceableProductionPoint.registerOverwrittenFunctions(placeableType)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "setOwnerFarmId", SandboxPlaceableProductionPoint.setOwnerFarmId)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "canBuy", SandboxPlaceableProductionPoint.canBuy)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", SandboxPlaceableProductionPoint.updateInfo)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "collectPickObjects", SandboxPlaceableProductionPoint.collectPickObjects)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getUtilizationPercentage", SandboxPlaceableProductionPoint.getUtilizationPercentage)
end

function SandboxPlaceableProductionPoint.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", SandboxPlaceableProductionPoint)
	SpecializationUtil.registerEventListener(placeableType, "onPostLoad", SandboxPlaceableProductionPoint)
	SpecializationUtil.registerEventListener(placeableType, "onLoadFinished", SandboxPlaceableProductionPoint)
	SpecializationUtil.registerEventListener(placeableType, "onDelete", SandboxPlaceableProductionPoint)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", SandboxPlaceableProductionPoint)
	SpecializationUtil.registerEventListener(placeableType, "onSandboxRootChanged", SandboxPlaceableProductionPoint)
	SpecializationUtil.registerEventListener(placeableType, "onWriteStream", SandboxPlaceableProductionPoint)
	SpecializationUtil.registerEventListener(placeableType, "onReadStream", SandboxPlaceableProductionPoint)
	SpecializationUtil.registerEventListener(placeableType, "onSandboxPlaceableAdded", SandboxPlaceableProductionPoint)
	SpecializationUtil.registerEventListener(placeableType, "onSandboxPlaceableRemoved", SandboxPlaceableProductionPoint)
	SpecializationUtil.registerEventListener(placeableType, "onUpdateSandboxPlaceable", SandboxPlaceableProductionPoint)
end

function SandboxPlaceableProductionPoint.loadSpecValueSandboxConsumption(xmlFile, customEnvironment, baseDir)
	local rootName = xmlFile:getRootName()
	local fillTypeStr = xmlFile:getValue(rootName .. ".storeData.specs.sandboxConsumption#fillType")
	local valueStr = xmlFile:getValue(rootName .. ".storeData.specs.sandboxConsumption#value")

	if fillTypeStr == nil or fillTypeStr == "" or valueStr == nil or valueStr == "" then
		return nil
	end

	return ("$SANDBOX_CON$1%s$1%s"):format(fillTypeStr, valueStr)
end

function SandboxPlaceableProductionPoint.getSpecValueSandboxConsumption(storeItem, realItem)
	if storeItem.specs.sandboxConsumption == nil then
		return nil
	end

	return storeItem.specs.sandboxConsumption
end

function SandboxPlaceableProductionPoint:onLoad(savegame)
	self.spec_sandboxPlaceableProductionPoint = self[("spec_%s.sandboxPlaceableProductionPoint"):format(SandboxPlaceableProductionPoint.MOD_NAME)]
	local spec = self.spec_sandboxPlaceableProductionPoint
	local productionPoint = SandboxProductionPoint.new(self.isServer, self.isClient, self.baseDirectory)
	productionPoint.owningPlaceable = self

	if productionPoint:load(self.components, self.xmlFile, "placeable.productionPoint", self.customEnvironment, self.i3dMappings) then
		spec.productionPoint = productionPoint
	else
		productionPoint:delete()
		self:setLoadingState(Placeable.LOADING_STATE_ERROR)
	end

	spec.mergedPlaceables = {}
end

function SandboxPlaceableProductionPoint:onPostLoad(savegame)
	local spec = self.spec_sandboxPlaceableProductionPoint
	local sandboxTypeName = self:getSandboxTypeName()
	spec.productionBaseInputAmount = {}
	spec.productionOutputAmount = {}
	local production = SandboxPlaceableProductionPoint.getSandboxProduction(spec.productionPoint, sandboxTypeName)

	if production ~= nil then
		local baseInputs = production.baseInputs

		for _, input in pairs(baseInputs) do
			if input.type ~= nil then
				spec.productionBaseInputAmount[input.type] = table.copy(input, 2)
			end
		end

		local outputs = production.outputs

		for _, output in pairs(outputs) do
			if output.type ~= nil then
				spec.productionOutputAmount[output.type] = table.copy(output, 2)
			end
		end
	end
end

function SandboxPlaceableProductionPoint:onLoadFinished(savegame)
	local spec = self.spec_sandboxPlaceableProductionPoint

	if spec.productionPoint ~= nil and spec.productionPoint.onLoadFinished ~= nil then
		spec.productionPoint:onLoadFinished()
	end
end

function SandboxPlaceableProductionPoint:onDelete()
	local spec = self.spec_sandboxPlaceableProductionPoint

	if spec == nil then
		return
	end

	if spec.productionPoint ~= nil then
		spec.productionPoint:delete()

		spec.productionPoint = nil
	end
end

function SandboxPlaceableProductionPoint:onFinalizePlacement()
	local spec = self.spec_sandboxPlaceableProductionPoint

	if spec.productionPoint ~= nil then
		spec.productionPoint:register(true)
		spec.productionPoint:setOwnerFarmId(self:getOwnerFarmId())
		spec.productionPoint:findStorageExtensions()
		spec.productionPoint:updateFxState()
	end

	self:updateProductionPoint()
end

function SandboxPlaceableProductionPoint:onSandboxRootChanged(rootState)
	self:updateProductionPoint()
end

function SandboxPlaceableProductionPoint:onSandboxPlaceableAdded(placeable)
	self:updateProductionPoint()
end

function SandboxPlaceableProductionPoint:onSandboxPlaceableRemoved(placeable)
	self:updateProductionPoint()
end

function SandboxPlaceableProductionPoint:onReadStream(streamId, connection)
	local spec = self.spec_sandboxPlaceableProductionPoint

	if spec.productionPoint ~= nil then
		local productionPointId = NetworkUtil.readNodeObjectId(streamId)

		spec.productionPoint:readStream(streamId, connection)
		g_client:finishRegisterObject(spec.productionPoint, productionPointId)
	end
end

function SandboxPlaceableProductionPoint:onWriteStream(streamId, connection)
	local spec = self.spec_sandboxPlaceableProductionPoint

	if spec.productionPoint ~= nil then
		NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(spec.productionPoint))
		spec.productionPoint:writeStream(streamId, connection)
		g_server:registerObjectInStream(connection, spec.productionPoint)
	end
end

function SandboxPlaceableProductionPoint:onUpdateSandboxPlaceable(dt)
	local spec = self.spec_sandboxPlaceableProductionPoint
	local minuteFactorTimescaled = spec.productionPoint.minuteFactorTimescaled
	local minuteFactorDt = dt * minuteFactorTimescaled * g_currentMission.environment.timeAdjustment
	local mergedPlaceables = self:getMergedPlaceables()

	if #mergedPlaceables > 0 then
		local farmId = self:getOwnerFarmId()

		for type, mergedPlaceable in pairs(mergedPlaceables) do
			if type == SandboxPlaceable.TYPE_FERMENTER or type == SandboxPlaceable.TYPE_POWERPLANT then
				self:updateMergedPlaceableProductions(minuteFactorDt, type, mergedPlaceable)
			elseif type == SandboxPlaceable.TYPE_BUNKER then
				local rootFermenter = mergedPlaceables[SandboxPlaceable.TYPE_FERMENTER]

				if rootFermenter ~= nil then
					local bunkerPlaceables = self:getPlaceableChildrenbyType(type)

					if #bunkerPlaceables > 0 then
						self:updateMergedPlaceableBunkers(minuteFactorDt, bunkerPlaceables, rootFermenter, farmId)
					end
				end
			elseif type == SandboxPlaceable.TYPE_SILO then
				local siloPlaceables = self:getPlaceableChildrenbyType(type)

				if #siloPlaceables > 0 then
					self:updateMergedPlaceableSilos(minuteFactorDt, siloPlaceables, mergedPlaceable, farmId)
				end
			elseif type == SandboxPlaceable.TYPE_TORCH then
				local torchPlaceables = self:getPlaceableChildrenbyType(type)

				if #torchPlaceables > 0 then
					self:updateMergedPlaceableTorchs(minuteFactorDt, torchPlaceables)
				end
			end
		end
	end
end

function SandboxPlaceableProductionPoint:updateMergedPlaceableProductions(minuteFactorDt, type, productionPlaceable)
	local productionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(productionPlaceable)

	if productionPoint ~= nil then
		local production = SandboxPlaceableProductionPoint.getSandboxProduction(productionPoint, type)

		if production ~= nil then
			for _, input in pairs(production.inputs) do
				local validOutputProductionPoints, overallFillLevel = self:getValidOutputProductionPoints(input.type, minuteFactorDt)

				if overallFillLevel > 0 then
					local targetPlaceables = self:getPlaceableChildrenbyType(type)

					if not table.hasElement(targetPlaceables, productionPlaceable) then
						table.addElement(targetPlaceables, productionPlaceable)
					end

					if input.type == FillType.METHANE then
						local targetTorchs = self:getPlaceableChildrenbyType(SandboxPlaceable.TYPE_TORCH)

						for _, torch in ipairs(targetTorchs) do
							table.addElement(targetPlaceables, torch)
						end
					end

					local function changeProductionPointAmount(targetPlaceable, maxDeltaPerPoint, fillTypeIndex)
						local amountChanged = 0
						local targetProductionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(targetPlaceable)

						if targetProductionPoint ~= nil then
							local oldFillLevel = targetProductionPoint.storage:getFillLevel(fillTypeIndex)

							targetProductionPoint.storage:setFillLevel(oldFillLevel + maxDeltaPerPoint, fillTypeIndex)

							local newFillLevel = targetProductionPoint.storage:getFillLevel(fillTypeIndex)
							amountChanged = newFillLevel - oldFillLevel
						elseif targetPlaceable:getSandboxType() == SandboxPlaceable.TYPE_TORCH and targetPlaceable.spec_sandboxPlaceableTorch.hasActiveAnimations then
							amountChanged = maxDeltaPerPoint
						end

						return amountChanged
					end

					self:distributeAmount(targetPlaceables, changeProductionPointAmount, validOutputProductionPoints, overallFillLevel, input.type, nil)

					for _, targetPlaceable in ipairs(targetPlaceables) do
						local targetProductionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(targetPlaceable)

						if targetProductionPoint ~= nil then
							targetProductionPoint:updateFxState()
						end
					end
				end
			end
		end
	end
end

function SandboxPlaceableProductionPoint:updateMergedPlaceableBunkers(minuteFactorDt, bunkerPlaceables, rootFermenter, farmId)
	local overallFillLevels = {}
	local validBunkerPlaceables = {}

	for _, bunkerPlaceable in pairs(bunkerPlaceables) do
		if bunkerPlaceable.spec_silo ~= nil then
			local loadingStation = bunkerPlaceable.spec_silo.loadingStation

			if loadingStation ~= nil then
				local fillLevels = loadingStation:getAllFillLevels(farmId)

				for fillTypeIndex, fillLevel in pairs(fillLevels) do
					if fillLevel > 0 then
						if overallFillLevels[fillTypeIndex] == nil then
							overallFillLevels[fillTypeIndex] = 0
						end

						overallFillLevels[fillTypeIndex] = overallFillLevels[fillTypeIndex] + fillLevel

						table.addElement(validBunkerPlaceables, bunkerPlaceable)
					end
				end
			end
		end
	end

	for fillTypeIndex, overallFillLevel in pairs(overallFillLevels) do
		if overallFillLevel > 0 then
			local function changeFermenterAmount(targetFermenter, fillLevelAdded, targetfillTypeIndex)
				local amountChanged = 0
				local fermenterProductionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(targetFermenter)

				if fermenterProductionPoint ~= nil then
					local oldFillLevel = fermenterProductionPoint.storage:getFillLevel(targetfillTypeIndex)
					fillLevelAdded = math.min(targetFermenter:getDistibutionPerFillType(targetfillTypeIndex) * minuteFactorDt, fillLevelAdded)

					fermenterProductionPoint.storage:setFillLevel(oldFillLevel + fillLevelAdded, targetfillTypeIndex)

					local newFillLevel = fermenterProductionPoint.storage:getFillLevel(targetfillTypeIndex)
					amountChanged = newFillLevel - oldFillLevel
				end

				return amountChanged
			end

			local function changeBunkerAmount(validSource, maxDeltaPerPoint, sourcefillTypeIndex)
				local amountChanged = 0
				local loadingStation = validSource.spec_silo.loadingStation

				if loadingStation ~= nil then
					local remainingDelta = loadingStation:removeFillLevel(sourcefillTypeIndex, maxDeltaPerPoint, farmId)

					for _, sourceStorage in pairs(loadingStation.sourceStorages) do
						if sourceStorage:getFillLevel(sourcefillTypeIndex) < 0.001 then
							sourceStorage:setFillLevel(0, sourcefillTypeIndex)
						end
					end

					amountChanged = maxDeltaPerPoint - remainingDelta
				end

				if validSource.raiseActivationTime ~= nil then
					if amountChanged > 0 then
						validSource:raiseActivationTime(SandboxPlaceableBunker.RAISETIME_START_ACTIVE)
					else
						validSource:raiseActivationTime(SandboxPlaceableBunker.RAISETIME_END_DISTRIBUTE)
					end
				end

				return amountChanged
			end

			local fermenterPlaceables = self:getPlaceableChildrenbyType(SandboxPlaceable.TYPE_FERMENTER)

			if not table.hasElement(fermenterPlaceables, rootFermenter) then
				table.addElement(fermenterPlaceables, rootFermenter)
			end

			self:distributeAmount(fermenterPlaceables, changeFermenterAmount, validBunkerPlaceables, overallFillLevel, fillTypeIndex, changeBunkerAmount)
		end
	end
end

function SandboxPlaceableProductionPoint:updateMergedPlaceableSilos(minuteFactorDt, targetSilos, siloPlaceable, farmId)
	local targetFillTypes = {}

	for _, targetSilo in pairs(targetSilos) do
		if targetSilo.spec_silo ~= nil then
			local unloadingStation = siloPlaceable.spec_silo.unloadingStation

			if unloadingStation ~= nil then
				for fillTypeIndex, _ in pairs(unloadingStation:getSupportedFillTypes()) do
					targetFillTypes[fillTypeIndex] = true
				end
			end
		end
	end

	for targetFillType, _ in pairs(targetFillTypes) do
		local validOutputProductionPoints, overallFillLevel = self:getValidOutputProductionPoints(targetFillType, minuteFactorDt)

		if overallFillLevel > 0 then
			local function changeSiloAmount(targetPlaceable, maxDeltaPerPoint, fillTypeIndex)
				local amountChanged = 0
				local unloadingStation = targetPlaceable.spec_silo.unloadingStation

				if unloadingStation ~= nil then
					for _, unloadTrigger in ipairs(unloadingStation.unloadTriggers) do
						local applied = unloadTrigger:addFillUnitFillLevel(farmId, nil, maxDeltaPerPoint, fillTypeIndex)
						maxDeltaPerPoint = math.max(maxDeltaPerPoint - applied, 0)
						amountChanged = amountChanged + applied
					end

					if maxDeltaPerPoint > 0 then
						amountChanged = amountChanged + unloadingStation:addFillLevelFromTool(farmId, maxDeltaPerPoint, fillTypeIndex)
					end
				end

				return amountChanged
			end

			self:distributeAmount(targetSilos, changeSiloAmount, validOutputProductionPoints, overallFillLevel, targetFillType, nil)
		end
	end
end

function SandboxPlaceableProductionPoint:updateMergedPlaceableTorchs(minuteFactorDt, torchPlaceables, farmId)
	local spec = self.spec_sandboxPlaceableProductionPoint

	if spec.mergedPlaceables ~= nil then
		local root = self:isSandboxRoot() and self or self:getSandboxRootPlaceable()
		local rootProductionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(root)
		local fermenterProduction = SandboxPlaceableProductionPoint.getSandboxProduction(rootProductionPoint, nil)
		local runTorchs = false

		if fermenterProduction.status == ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
			runTorchs = true
		elseif fermenterProduction.status == ProductionPoint.PROD_STATUS.RUNNING then
			local mergedPowerplant = spec.mergedPlaceables[SandboxPlaceable.TYPE_POWERPLANT]

			if mergedPowerplant ~= nil then
				local percentage = mergedPowerplant:getUtilizationPercentage()
				runTorchs = percentage > 1
			else
				runTorchs = true
			end
		end

		if runTorchs then
			for _, torchPlaceable in pairs(torchPlaceables) do
				torchPlaceable:raiseActivationTime(SandboxPlaceableTorch.RAISETIME_START_ACTIVE)
			end
		end
	end
end

function SandboxPlaceableProductionPoint:distributeAmount(targets, targetFunction, validSources, overallFillLevel, fillTypeIndex, sourceFunction)
	if not self.isServer then
		return
	end

	local numPrios = {}

	for prio = SandboxPlaceable.PRIORITY_HIGH, SandboxPlaceable.PRIORITY_FATAL, -1 do
		numPrios[prio] = 0

		for _, placeable in ipairs(self:getPlaceableChildrenbyPriority(prio)) do
			if table.hasElement(targets, placeable) then
				numPrios[prio] = numPrios[prio] + 1
			end
		end

		if prio == self:getSandboxPriority() and table.hasElement(targets, self) then
			numPrios[prio] = numPrios[prio] + 1
		end
	end

	local fillLevelAdded = 0

	for prio = SandboxPlaceable.PRIORITY_HIGH, SandboxPlaceable.PRIORITY_FATAL, -1 do
		if numPrios[prio] > 0 then
			local prioFillLevelAdded = 0
			local maxDeltaPerPoint = (overallFillLevel - fillLevelAdded) / numPrios[prio]

			for _, targetPlaceable in ipairs(targets) do
				if overallFillLevel - fillLevelAdded <= 0 or fillLevelAdded > 0 and prio == SandboxPlaceable.PRIORITY_FATAL then
					break
				end

				if prio == targetPlaceable:getSandboxPriority() then
					prioFillLevelAdded = prioFillLevelAdded + targetFunction(targetPlaceable, maxDeltaPerPoint, fillTypeIndex)
				end
			end

			if prioFillLevelAdded > 0 then
				fillLevelAdded = fillLevelAdded + prioFillLevelAdded

				for _, validSource in ipairs(validSources) do
					if sourceFunction ~= nil then
						prioFillLevelAdded = prioFillLevelAdded - sourceFunction(validSource, prioFillLevelAdded, fillTypeIndex)
					else
						local oldFillLevel = validSource.storage:getFillLevel(fillTypeIndex)

						validSource.storage:setFillLevel(oldFillLevel - math.min(oldFillLevel, prioFillLevelAdded), fillTypeIndex)

						local newFillLevel = validSource.storage:getFillLevel(fillTypeIndex)
						prioFillLevelAdded = prioFillLevelAdded - (newFillLevel - oldFillLevel)
					end

					if prioFillLevelAdded <= 0 then
						break
					end
				end
			end
		end
	end

	if fillLevelAdded > 0 then
		local spec = self.spec_sandboxPlaceableProductionPoint
		local productionPoint = spec.productionPoint

		if productionPoint ~= nil then
			productionPoint:updateDynamicInputs()
			productionPoint:updateDynamicOutputAmounts()
		end
	end
end

function SandboxPlaceableProductionPoint:outputsChanged(outputs, state)
	SpecializationUtil.raiseEvent(self, "onOutputFillTypesChanged", outputs, state)
end

function SandboxPlaceableProductionPoint:productionStatusChanged(production, status)
	SpecializationUtil.raiseEvent(self, "onProductionStatusChanged", production, status)
end

function SandboxPlaceableProductionPoint:getValidOutputProductionPoints(fillTypeId, minuteFactorDt)
	local productionPoints = {}
	local overallFillLevel = 0

	if fillTypeId ~= nil then
		local placeables = self:getSandboxPlaceables()
		local root = self:isSandboxRoot() and self or self:getSandboxRootPlaceable()
		local rootProductionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(root)

		for _, placeable in ipairs(placeables) do
			local productionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(placeable)

			if productionPoint ~= nil then
				local fillTypeDistributed = false

				if rootProductionPoint ~= nil then
					fillTypeDistributed = rootProductionPoint.outputFillTypeIdsAutoDistribution[fillTypeId]
				end

				if fillTypeDistributed and productionPoint.outputFillTypeIds[fillTypeId] then
					local moveablefillLevel = math.min(placeable:getDistibutionPerFillType(fillTypeId) * minuteFactorDt, productionPoint:getFillLevel(fillTypeId))

					if moveablefillLevel > 0 then
						table.addElement(productionPoints, productionPoint)

						overallFillLevel = overallFillLevel + moveablefillLevel
					end
				end
			end
		end
	end

	return productionPoints, overallFillLevel
end

function SandboxPlaceableProductionPoint:loadFromXMLFile(xmlFile, key)
	local spec = self.spec_sandboxPlaceableProductionPoint

	if spec.productionPoint ~= nil then
		spec.productionPoint:loadFromXMLFile(xmlFile, key)
	end
end

function SandboxPlaceableProductionPoint:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_sandboxPlaceableProductionPoint

	if spec.productionPoint ~= nil then
		spec.productionPoint:saveToXMLFile(xmlFile, key, usedModNames)
	end
end

function SandboxPlaceableProductionPoint:getMergedPlaceables()
	local spec = self.spec_sandboxPlaceableProductionPoint

	return spec.mergedPlaceables
end

function SandboxPlaceableProductionPoint:updateProductionPoint()
	local spec = self.spec_sandboxPlaceableProductionPoint

	if self:isSandboxRoot() then
		table.clear(spec.mergedPlaceables)

		if self:getSandboxType() == SandboxPlaceable.TYPE_FERMENTER then
			self:mergeProductionPointsAtSelf(self)

			spec.mergedPlaceables[SandboxPlaceable.TYPE_FERMENTER] = self
		end

		local children = self:getPlaceableChildren()

		for _, child in ipairs(children) do
			local sandboxType = child:getSandboxType()

			if spec.mergedPlaceables[sandboxType] == nil then
				if child.mergeProductionPointsAtSelf ~= nil then
					child:mergeProductionPointsAtSelf(self)
				end

				spec.mergedPlaceables[sandboxType] = child
			end
		end
	else
		local sandboxRoot = self:getSandboxRootPlaceable()

		if sandboxRoot ~= nil then
			sandboxRoot:updateProductionPoint()
		end
	end

	local productionPoint = spec.productionPoint

	if productionPoint ~= nil then
		productionPoint:updateDynamicInputs()
		productionPoint:updateDynamicOutputAmounts()
	end
end

function SandboxPlaceableProductionPoint:mergeProductionPointsAtSelf(rootSandbox)
	local spec = self.spec_sandboxPlaceableProductionPoint
	local productionPoint = spec.productionPoint

	if productionPoint ~= nil then
		for _, storage in pairs(productionPoint.loadingStation.sourceStorages) do
			if storage ~= productionPoint.storage then
				productionPoint.loadingStation:removeSourceStorage(storage)
			end
		end

		for _, storage in pairs(productionPoint.unloadingStation.targetStorages) do
			if storage ~= productionPoint.storage then
				productionPoint.unloadingStation:removeTargetStorage(storage)
			end
		end

		local sandboxTypeName = self:getSandboxTypeName()
		local production = SandboxPlaceableProductionPoint.getSandboxProduction(productionPoint, sandboxTypeName)

		if production ~= nil then
			for _, input in ipairs(production.baseInputs) do
				input.amount = spec.productionBaseInputAmount[input.type] ~= nil and spec.productionBaseInputAmount[input.type].amount or 0

				if production.useDynamicOutput then
					for outputFillType, _ in pairs(input.outputAmounts) do
						input.outputAmounts[outputFillType] = spec.productionBaseInputAmount[input.type].outputAmounts[outputFillType]
					end
				end
			end

			for _, output in ipairs(production.outputs) do
				output.amount = spec.productionOutputAmount[output.type] ~= nil and spec.productionOutputAmount[output.type].amount or 0
			end

			local children = rootSandbox:getPlaceableChildren()

			for _, child in ipairs(children) do
				if child ~= self and child:getSandboxType() == self:getSandboxType() then
					local childProductionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(child)

					if childProductionPoint ~= nil then
						local childProduction = SandboxPlaceableProductionPoint.getSandboxProduction(childProductionPoint, sandboxTypeName)

						if childProduction ~= nil then
							for _, input in ipairs(childProduction.baseInputs) do
								local inputAdded = false

								if not productionPoint.inputFillTypeIds[input.type] then
									productionPoint.inputFillTypeIds[input.type] = true
								end

								for _, rootInput in ipairs(production.baseInputs) do
									if input.type == rootInput.type then
										rootInput.amount = rootInput.amount + input.amount

										if production.useDynamicOutput then
											for outputFillType, amount in pairs(input.outputAmounts) do
												if rootInput.outputAmounts[outputFillType] == nil then
													rootInput.outputAmounts[outputFillType] = amount
												else
													rootInput.outputAmounts[outputFillType] = rootInput.outputAmounts[outputFillType] + amount
												end
											end
										end

										inputAdded = true
									end
								end

								if not inputAdded then
									table.addElement(production.baseInputs, input)
								end
							end

							for _, output in ipairs(childProduction.outputs) do
								local outputAdded = false

								if not productionPoint.outputFillTypeIds[output.type] and not output.sellDirectly then
									productionPoint.outputFillTypeIds[output.type] = true
								elseif productionPoint.soldFillTypesToPayOut[output.type] == nil then
									productionPoint.soldFillTypesToPayOut[output.type] = 0
								end

								for _, rootOutput in ipairs(production.outputs) do
									if output.type == rootOutput.type then
										rootOutput.amount = rootOutput.amount + output.amount
										outputAdded = true
									end
								end

								if not outputAdded then
									table.addElement(production.outputs, output)
								end
							end
						end

						productionPoint.loadingStation:addSourceStorage(childProductionPoint.storage)
						productionPoint.unloadingStation:addTargetStorage(childProductionPoint.storage)
					end
				end
			end
		end
	end
end

function SandboxPlaceableProductionPoint:refillAmount(fillTypeIndex, amount, price)
	if fillTypeIndex == nil or amount == nil or price == nil or not self:isSandboxRoot() then
		return
	end

	if not self.isServer then
		g_client:getServerConnection():sendEvent(PlaceableSiloRefillEvent.new(self, fillTypeIndex, amount, price))

		return
	end

	local targetPlaceables = self:getPlaceableChildrenbyType(SandboxPlaceable.TYPE_FERMENTER)

	if not table.hasElement(targetPlaceables, self) then
		table.addElement(targetPlaceables, self)
	end

	for _, targetPlaceable in ipairs(targetPlaceables) do
		local targetProductionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(targetPlaceable)

		if targetProductionPoint ~= nil then
			local storage = targetProductionPoint.storage
			local freeCapacity = storage:getFreeCapacity(fillTypeIndex)

			if freeCapacity > 0 then
				local moved = math.min(amount, freeCapacity)
				local fillLevel = storage:getFillLevel(fillTypeIndex)

				storage:setFillLevel(fillLevel + moved, fillTypeIndex)

				amount = amount - moved
			end

			if amount <= 0.001 then
				break
			end
		end
	end

	if self.isServer then
		g_currentMission:addMoney(-price, self:getOwnerFarmId(), MoneyType.BOUGHT_MATERIALS, true)
	end

	g_currentMission:showMoneyChange(MoneyType.BOUGHT_MATERIALS)
end

function SandboxPlaceableProductionPoint:setOwnerFarmId(superFunc, farmId, noEventSend)
	superFunc(self, farmId, noEventSend)

	local spec = self.spec_sandboxPlaceableProductionPoint

	if spec.productionPoint ~= nil then
		spec.productionPoint:setOwnerFarmId(farmId)
	end
end

function SandboxPlaceableProductionPoint:canBuy(superFunc)
	if not g_currentMission.productionChainManager:getHasFreeSlots() then
		return false, g_i18n:getText("warning_maxNumOfProdPointsReached")
	end

	return superFunc(self)
end

function SandboxPlaceableProductionPoint:updateInfo(superFunc, infoTable)
	local root = self:isSandboxRoot() and self or self:getSandboxRootPlaceable()

	if root ~= nil then
		if root.spec_sandboxPlaceableProductionPoint ~= nil then
			root.spec_sandboxPlaceableProductionPoint.productionPoint:updateInfo(function ()
				return nil
			end, infoTable)
		end
	else
		superFunc(self, infoTable)
	end
end

function SandboxPlaceableProductionPoint:collectPickObjects(superFunc, node)
	local spec = self.spec_sandboxPlaceableProductionPoint

	if spec.productionPoint.loadingStation ~= nil then
		for i = 1, #spec.productionPoint.loadingStation.loadTriggers do
			local loadTrigger = spec.productionPoint.loadingStation.loadTriggers[i]

			if node == loadTrigger.triggerNode then
				return
			end
		end
	end

	for i = 1, #spec.productionPoint.unloadingStation.unloadTriggers do
		local unloadTrigger = spec.productionPoint.unloadingStation.unloadTriggers[i]

		if node == unloadTrigger.exactFillRootNode then
			return
		end
	end

	superFunc(self, node)
end

function SandboxPlaceableProductionPoint:getUtilizationPercentage(superFunc)
	local root = self:isSandboxRoot() and self or self:getSandboxRootPlaceable()

	if root == nil then
		return superFunc(self)
	end

	local spec = self.spec_sandboxPlaceableProductionPoint
	local percentage = 0
	local message, productionState = nil
	local type = self:getSandboxType()

	if type == SandboxPlaceable.TYPE_FERMENTER then
		local overallInputAmount = {}
		local overallFillLevels = {}
		local production = SandboxPlaceableProductionPoint.getSandboxProduction(spec.productionPoint, self:getSandboxTypeName())
		productionState = production.status

		for _, baseInput in ipairs(production.baseInputs) do
			local amount = 1

			for _, input in ipairs(production.inputs) do
				if baseInput.type == input.type then
					amount = input.amount

					break
				end
			end

			overallInputAmount[baseInput.type] = amount
			local fillLevel = spec.productionPoint:getFillLevel(baseInput.type)

			if fillLevel > 0 then
				if overallFillLevels[baseInput.type] == nil then
					overallFillLevels[baseInput.type] = 0
				end

				overallFillLevels[baseInput.type] = overallFillLevels[baseInput.type] + fillLevel
			end
		end

		local validCount = 0

		for fillTypeIndex in pairs(overallInputAmount) do
			if overallFillLevels[fillTypeIndex] == nil or overallFillLevels[fillTypeIndex] == 0 then
				validCount = validCount + 1
			end
		end

		if validCount > 0 then
			message = g_i18n:getText("sandboxUtilization_notAllIngredientsAreUsed")
		end

		for fillTypeIndex, fillLevel in pairs(overallFillLevels) do
			if overallInputAmount[fillTypeIndex] ~= nil then
				percentage = percentage + math.min(fillLevel / overallInputAmount[fillTypeIndex], 1)
				validCount = validCount + 1
			end
		end

		if validCount > 0 then
			percentage = percentage / validCount
		end
	else
		for inputType, value in pairs(spec.productionPoint.inputFillTypeIds) do
			if value then
				local inputAmount = 0
				local production = SandboxPlaceableProductionPoint.getSandboxProduction(spec.productionPoint, self:getSandboxTypeName())

				for _, input in ipairs(production.inputs) do
					if inputType == input.type then
						inputAmount = inputAmount + input.amount
					end
				end

				if inputAmount > 0 then
					productionState = production.status
					local outputAmount = 0
					local mergedPlaceables = root:getMergedPlaceables()

					for sandboxType, mergedPlaceable in pairs(mergedPlaceables) do
						if sandboxType ~= type and mergedPlaceable.spec_sandboxPlaceableProductionPoint ~= nil then
							local mergedSpec = mergedPlaceable.spec_sandboxPlaceableProductionPoint
							production = SandboxPlaceableProductionPoint.getSandboxProduction(mergedSpec.productionPoint, SandboxPlaceable.TYPE_NAME[sandboxType])

							for _, output in ipairs(production.outputs) do
								if inputType == output.type then
									outputAmount = outputAmount + output.amount
								end
							end
						end
					end

					if outputAmount > 0 then
						percentage = outputAmount / inputAmount
					end
				end
			end
		end
	end

	local forced = productionState ~= ProductionPoint.PROD_STATUS.RUNNING and SandboxPlaceable.UTILIZATION_STATE.RUNNING_NOT or nil

	return percentage, message, forced
end
