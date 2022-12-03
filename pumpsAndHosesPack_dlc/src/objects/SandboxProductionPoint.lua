SandboxProductionPoint = {}

local function registerProductionPointOutputMode(name, value)
	name = name:upper()

	if ProductionPoint.OUTPUT_MODE[name] == nil then
		if value == nil then
			value = 0

			for _, mode in pairs(ProductionPoint.OUTPUT_MODE) do
				if value < mode then
					value = mode
				end
			end

			value = value + 1
		end

		ProductionPoint.OUTPUT_MODE[name] = value

		if value >= 2^ProductionPoint.OUTPUT_MODE_NUM_BITS - 1 then
			ProductionPoint.OUTPUT_MODE_NUM_BITS = ProductionPoint.OUTPUT_MODE_NUM_BITS + 1
		end
	end
end

registerProductionPointOutputMode("AUTO_DISTRIBUTION")

local SandboxProductionPoint_mt = Class(SandboxProductionPoint, ProductionPoint)

function SandboxProductionPoint.registerXMLPaths(schema, basePath)
	ProductionPoint.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?).inputs.input(?)#isRequired", "Is this fillType required to start the production", true)
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?).inputs.input(?).outputAmount(?)#fillType", "Output fill type for modification", true)
	schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?).inputs.input(?).outputAmount(?)#active", "Output amount to add if input is active", true)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".exhaustEffects.exhaustEffect(?)#node", "Effect link node")
	schema:register(XMLValueType.STRING, basePath .. ".exhaustEffects.exhaustEffect(?)#filename", "Effect i3d filename")
	schema:register(XMLValueType.VECTOR_4, basePath .. ".exhaustEffects.exhaustEffect(?)#shaderValues", "Shader color", "0.0384 0.0359 0.0627 1")
	schema:register(XMLValueType.FLOAT, basePath .. ".exhaustEffects.exhaustEffect(?)#sizeScale", "Exhaust size scale", "1")
end

function SandboxProductionPoint.registerSavegameXMLPaths(schema, basePath)
	ProductionPoint.registerSavegameXMLPaths(schema, basePath)
	schema:register(XMLValueType.STRING, basePath .. ".autoDistributionFillType(?)", "FillType currently configured to be automatic distributed")
end

function SandboxProductionPoint.new(isServer, isClient, baseDirectory, customMt)
	local self = ProductionPoint.new(isServer, isClient, baseDirectory, customMt or SandboxProductionPoint_mt)

	return self
end

function SandboxProductionPoint:load(components, xmlFile, key, customEnv, i3dMappings)
	local loaded = SandboxProductionPoint:superClass().load(self, components, xmlFile, key, customEnv, i3dMappings)

	if loaded then
		xmlFile:iterate(key .. ".productions.production", function (index, productionKey)
			local id = xmlFile:getValue(productionKey .. "#id")
			local production = self.productionsIdToObj[id]

			if production ~= nil then
				production.useDynamicOutput = false
				production.dirtyFlagInputs = self:getNextDirtyFlag()
				production.dirtyFlagOutputs = self:getNextDirtyFlag()

				xmlFile:iterate(productionKey .. ".inputs.input", function (inputIndex, inputKey)
					local fillTypeString = xmlFile:getValue(inputKey .. "#fillType")
					local fillType = g_fillTypeManager:getFillTypeIndexByName(fillTypeString)

					for _, input in ipairs(production.inputs) do
						if fillType == input.type then
							input.isRequired = xmlFile:getValue(inputKey .. "#isRequired", true)
							input.outputAmounts = {}

							xmlFile:iterate(inputKey .. ".outputAmount", function (outputAmountIndex, outputAmountKey)
								local outputFillTypeString = xmlFile:getValue(outputAmountKey .. "#fillType")
								local outputFillType = g_fillTypeManager:getFillTypeIndexByName(outputFillTypeString)

								if outputFillType == nil then
									Logging.xmlError(xmlFile, "Unable to load output fillType '%s' for '%s'", outputFillTypeString, outputAmountKey)
								else
									input.outputAmounts[outputFillType] = xmlFile:getValue(outputAmountKey .. "#active", 0)
									production.useDynamicOutput = true
								end
							end)
						end
					end
				end)

				production.baseInputs = table.copy(production.inputs, math.huge)
			end
		end)

		self.outputFillTypeIdsAutoDistribution = {}
	end

	if self.isClient then
		self:loadExhaustEffects(xmlFile, key, components, i3dMappings)
	end

	return loaded
end

function SandboxProductionPoint:onLoadFinished()
	if not self.owningPlaceable.isLoadedFromSavegame then
		for typeId in pairs(self.outputFillTypeIds) do
			self:setOutputDistributionMode(typeId, ProductionPoint.OUTPUT_MODE.AUTO_DISTRIBUTION)
		end
	end
end

function SandboxProductionPoint:delete()
	if self.sharedLoadRequestIds ~= nil then
		for _, sharedLoadRequestId in ipairs(self.sharedLoadRequestIds) do
			g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)
		end

		self.sharedLoadRequestIds = nil
	end

	SandboxProductionPoint:superClass().delete(self)
end

function SandboxProductionPoint:loadFromXMLFile(xmlFile, key)
	local success = SandboxProductionPoint:superClass().loadFromXMLFile(self, xmlFile, key)

	if success then
		xmlFile:iterate(key .. ".autoDistributionFillType", function (index, autoDistributionKey)
			local fillType = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(autoDistributionKey))

			if fillType then
				self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.AUTO_DISTRIBUTION)
			end
		end)
	end

	return success
end

function SandboxProductionPoint:saveToXMLFile(xmlFile, key, usedModNames)
	SandboxProductionPoint:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)
	xmlFile:setTable(key .. ".autoDistributionFillType", self.outputFillTypeIdsAutoDistribution, function (fillTypeKey, _, fillTypeId)
		local fillType = g_fillTypeManager:getFillTypeNameByIndex(fillTypeId)

		xmlFile:setValue(fillTypeKey, fillType)
	end)
end

function SandboxProductionPoint:readStream(streamId, connection)
	SandboxProductionPoint:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then
		for _, production in ipairs(self.productions) do
			table.clear(production.inputs)

			local numInputs = streamReadInt8(streamId)

			for i = 1, numInputs do
				local amount = streamReadFloat32(streamId)
				local type = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)

				table.addElement(production.inputs, {
					amount = amount,
					type = type
				})
			end

			self:updateInputArrayByProductionInputs(production)

			local numOutputs = streamReadInt8(streamId)

			for i = 1, numOutputs do
				local amount = streamReadFloat32(streamId)
				local type = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)

				for _, output in ipairs(production.outputs) do
					if type == output.type then
						output.amount = amount
					end
				end
			end

			self:updateOutputArrayByProductionOutputs(production)
		end

		for i = 1, streamReadUInt8(streamId) do
			self:setOutputDistributionMode(streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS), ProductionPoint.OUTPUT_MODE.AUTO_DISTRIBUTION)
		end
	end
end

function SandboxProductionPoint:writeStream(streamId, connection)
	SandboxProductionPoint:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		for _, production in ipairs(self.productions) do
			streamWriteInt8(streamId, table.size(production.inputs))

			for _, input in ipairs(production.inputs) do
				streamWriteFloat32(streamId, input.amount)
				streamWriteUIntN(streamId, input.type, FillTypeManager.SEND_NUM_BITS)
			end

			streamWriteInt8(streamId, table.size(production.outputs))

			for _, output in ipairs(production.outputs) do
				streamWriteFloat32(streamId, output.amount)
				streamWriteUIntN(streamId, output.type, FillTypeManager.SEND_NUM_BITS)
			end
		end

		streamWriteUInt8(streamId, table.size(self.outputFillTypeIdsAutoDistribution))

		for autoDistFillTypeId in pairs(self.outputFillTypeIdsAutoDistribution) do
			streamWriteUIntN(streamId, autoDistFillTypeId, FillTypeManager.SEND_NUM_BITS)
		end
	end
end

function SandboxProductionPoint:readUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		for _, production in ipairs(self.productions) do
			if streamReadBool(streamId) then
				table.clear(production.inputs)

				local numInputs = streamReadInt8(streamId)

				for i = 1, numInputs do
					local amount = streamReadFloat32(streamId)
					local type = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)

					table.addElement(production.inputs, {
						amount = amount,
						type = type
					})
				end

				self:updateInputArrayByProductionInputs(production)
			end

			if streamReadBool(streamId) then
				local numOutputs = streamReadInt8(streamId)

				for i = 1, numOutputs do
					local amount = streamReadFloat32(streamId)
					local type = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)

					for _, output in ipairs(production.outputs) do
						if type == output.type then
							output.amount = amount
						end
					end
				end

				self:updateOutputArrayByProductionOutputs(production)
			end
		end
	end
end

function SandboxProductionPoint:writeUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		for _, production in ipairs(self.productions) do
			if streamWriteBool(streamId, bitAND(dirtyMask, production.dirtyFlagInputs) ~= 0) then
				streamWriteInt8(streamId, table.size(production.inputs))

				for _, input in ipairs(production.inputs) do
					streamWriteFloat32(streamId, input.amount)
					streamWriteUIntN(streamId, input.type, FillTypeManager.SEND_NUM_BITS)
				end
			end

			if streamWriteBool(streamId, bitAND(dirtyMask, production.dirtyFlagOutputs) ~= 0) then
				streamWriteInt8(streamId, table.size(production.outputs))

				for _, output in ipairs(production.outputs) do
					streamWriteFloat32(streamId, output.amount)
					streamWriteUIntN(streamId, output.type, FillTypeManager.SEND_NUM_BITS)
				end
			end
		end
	end
end

function SandboxProductionPoint:updateProduction()
	if self.lastUpdatedTime == nil then
		self.lastUpdatedTime = g_time

		return
	end

	local dt = MathUtil.clamp(g_time - self.lastUpdatedTime, 0, 30000)

	SandboxProductionPoint:superClass().updateProduction(self)
	SpecializationUtil.raiseEvent(self.owningPlaceable, "onUpdateSandboxPlaceable", dt)
end

function SandboxProductionPoint:updateDynamicInputs()
	for _, production in ipairs(self.productions) do
		table.clear(production.inputs)

		for _, baseInput in ipairs(production.baseInputs) do
			local validFillLevel = self:getFillLevel(baseInput.type) > 0

			if validFillLevel or baseInput.isRequired then
				table.addElement(production.inputs, table.copy(baseInput, 2))
			end
		end

		if production.inputsSent == nil then
			production.inputsSent = {}
		end

		local raise = false

		for _, input in ipairs(production.inputs) do
			local found = false

			for _, inputSent in ipairs(production.inputsSent) do
				if input.type == inputSent.type then
					found = true

					if input.amount ~= inputSent.amount then
						raise = true

						break
					end
				end
			end

			if not found then
				raise = true

				break
			end
		end

		if raise then
			production.inputsSent = table.copy(production.inputs, math.huge)

			self:updateInputArrayByProductionInputs(production)
			self:raiseDirtyFlags(production.dirtyFlagInputs)
		end
	end
end

function SandboxProductionPoint:updateFxState()
	if self.isClient then
		local fxActive = false
		local root = self.owningPlaceable:isSandboxRoot() and self.owningPlaceable or self.owningPlaceable:getSandboxRootPlaceable()

		if root ~= nil then
			local mergedPlaceables = root:getMergedPlaceables()
			local type = self.owningPlaceable:getSandboxType()
			local mergedPlaceable = mergedPlaceables[type]

			if mergedPlaceable ~= nil then
				local mergedProductionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(mergedPlaceable)
				fxActive = #mergedProductionPoint.activeProductions > 0
			end
		end

		if fxActive then
			if g_soundManager:getIsSamplePlaying(self.samples.idle) then
				g_soundManager:stopSample(self.samples.idle)
			end

			if not g_soundManager:getIsSamplePlaying(self.samples.active) then
				g_soundManager:playSample(self.samples.active)
			end

			g_animationManager:startAnimations(self.animationNodes)
			g_effectManager:startEffects(self.effects)

			if self.exhaustEffects ~= nil then
				for _, effect in pairs(self.exhaustEffects) do
					setVisibility(effect.effectNode, true)
					setShaderParameter(effect.effectNode, "param", 0, 0, 0, effect.sizeScale, false)

					local color = effect.shaderValues

					setShaderParameter(effect.effectNode, "exhaustColor", color[1], color[2], color[3], color[4], false)
				end
			end
		else
			if not g_soundManager:getIsSamplePlaying(self.samples.idle) then
				g_soundManager:playSample(self.samples.idle)
			end

			if g_soundManager:getIsSamplePlaying(self.samples.active) then
				g_soundManager:stopSample(self.samples.active)
			end

			g_animationManager:stopAnimations(self.animationNodes)
			g_effectManager:stopEffects(self.effects)

			if self.exhaustEffects ~= nil then
				for _, effect in pairs(self.exhaustEffects) do
					setVisibility(effect.effectNode, false)
				end
			end
		end
	end
end

function SandboxProductionPoint:updateInputArrayByProductionInputs(production)
	for _, input in ipairs(production.inputs) do
		if input.amount <= 0 and self.inputFillTypeIds[input.type] then
			self.inputFillTypeIds[input.type] = false
		end
	end

	table.clear(self.inputFillTypeIdsArray)

	for fillType, value in pairs(self.inputFillTypeIds) do
		if value then
			table.addElement(self.inputFillTypeIdsArray, fillType)
		end
	end
end

function SandboxProductionPoint:updateDynamicOutputAmounts()
	for _, production in ipairs(self.productions) do
		local raise = false

		for _, output in ipairs(production.outputs) do
			if output.amountSent == nil then
				output.amountSent = 0
			end

			if production.useDynamicOutput then
				output.amount = 0

				for _, input in pairs(production.inputs) do
					if input.outputAmounts[output.type] ~= nil and input.outputAmounts[output.type] ~= nil and input.outputAmounts[output.type] > 0 then
						output.amount = output.amount + input.outputAmounts[output.type]
					end
				end

				if output.amount ~= output.amountSent then
					output.amountSent = output.amount
					raise = true
				end
			end
		end

		if raise then
			self:updateOutputArrayByProductionOutputs(production)
			self:raiseDirtyFlags(production.dirtyFlagOutputs)
		end
	end
end

function SandboxProductionPoint:updateOutputArrayByProductionOutputs(production)
	for _, output in ipairs(production.outputs) do
		if output.amount <= 0 and self.outputFillTypeIds[output.type] then
			self.outputFillTypeIds[output.type] = false
		end
	end

	table.clear(self.outputFillTypeIdsArray)

	for fillType, value in pairs(self.outputFillTypeIds) do
		if value then
			table.addElement(self.outputFillTypeIdsArray, fillType)
		end
	end
end

function SandboxProductionPoint:setOutputDistributionMode(outputFillTypeId, mode, noEventSend)
	mode = tonumber(mode)
	self.outputFillTypeIdsDirectSell[outputFillTypeId] = nil
	self.outputFillTypeIdsAutoDeliver[outputFillTypeId] = nil
	self.outputFillTypeIdsAutoDistribution[outputFillTypeId] = nil

	if mode == ProductionPoint.OUTPUT_MODE.AUTO_DISTRIBUTION then
		self.outputFillTypeIdsAutoDistribution[outputFillTypeId] = true

		ProductionPointOutputModeEvent.sendEvent(self, outputFillTypeId, mode, noEventSend)
	else
		SandboxProductionPoint:superClass().setOutputDistributionMode(self, outputFillTypeId, mode, noEventSend)
	end
end

function SandboxProductionPoint:getOutputDistributionMode(outputFillTypeId)
	if self.outputFillTypeIdsAutoDistribution[outputFillTypeId] ~= nil then
		return ProductionPoint.OUTPUT_MODE.AUTO_DISTRIBUTION
	end

	return SandboxProductionPoint:superClass().getOutputDistributionMode(self, outputFillTypeId)
end

function SandboxProductionPoint:getFillLevelPercentage(fillTypeId)
	local fillLevel = self:getFillLevel(fillTypeId)
	local capacity = self:getCapacity(fillTypeId)

	return capacity > 0 and fillLevel / capacity or 0
end

function SandboxProductionPoint:loadExhaustEffects(xmlFile, key, components, i3dMappings)
	self.exhaustEffects = {}
	self.sharedLoadRequestIds = {}

	xmlFile:iterate(key .. ".exhaustEffects.exhaustEffect", function (index, keyI)
		local linkNode = xmlFile:getValue(keyI .. "#node", nil, components, i3dMappings)
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

			table.insert(self.sharedLoadRequestIds, sharedLoadRequestId)
		end
	end)
end

function SandboxProductionPoint:onExhaustEffectI3DLoaded(i3dNode, failedReason, args)
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

			table.insert(self.exhaustEffects, effect)
		end
	end
end
