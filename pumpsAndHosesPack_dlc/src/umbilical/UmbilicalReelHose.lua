UmbilicalReelHose = {}
local UmbilicalReelHose_mt = Class(UmbilicalReelHose)
UmbilicalReelHose.SHADER_PARAM = "hosePosition"
UmbilicalReelHose.SHADER_PARAM_COILS = "coilOffsets"
UmbilicalReelHose.DEFAULT_INNER_DIAMETER = 0.5
UmbilicalReelHose.DEFAULT_SHIFT = 0.22
UmbilicalReelHose.DEFAULT_COILS = 10
UmbilicalReelHose.DEFAULT_CAPACITY = 1000
UmbilicalReelHose.DEFAULT_LAYER_THICKNESS = 0.025

function UmbilicalReelHose.new(hoseCache, linkNode)
	local self = setmetatable({}, UmbilicalReelHose_mt)
	self.hoseCache = hoseCache
	self.linkNode = linkNode
	self.rotation = {
		0,
		0,
		0
	}
	self.translation = {
		0,
		0,
		0
	}
	self.color = {
		0.05,
		0.05,
		0.05,
		0
	}
	self.layers = {}
	self.amountOfLayers = 0
	self.innerDiameter = UmbilicalReelHose.DEFAULT_INNER_DIAMETER
	self.diameter = UmbilicalReelHose.innerDiameter
	self.capacity = UmbilicalReelHose.DEFAULT_CAPACITY
	self.layerThickness = UmbilicalReelHose.DEFAULT_LAYER_THICKNESS
	self.coilsAmount = UmbilicalReelHose.DEFAULT_COILS
	self.shift = UmbilicalReelHose.DEFAULT_SHIFT
	self.length = 0
	self.lengthSent = 0
	self.damage = 0

	return self
end

function UmbilicalReelHose:delete()
	for _, layer in ipairs(self.layers) do
		delete(layer.node)
	end
end

function UmbilicalReelHose:setCapacity(capacity)
	self.capacity = capacity or UmbilicalReelHose.DEFAULT_CAPACITY
end

function UmbilicalReelHose:setCoilsAmount(amount)
	self.coilsAmount = amount or UmbilicalReelHose.DEFAULT_COILS
end

function UmbilicalReelHose:setLayerThickness(layerThickness)
	self.layerThickness = layerThickness or UmbilicalReelHose.DEFAULT_LAYER_THICKNESS
end

function UmbilicalReelHose:setShift(shift)
	self.shift = shift or UmbilicalReelHose.DEFAULT_SHIFT
end

function UmbilicalReelHose:setInnerDiameter(diameter)
	self.innerDiameter = diameter or UmbilicalReelHose.DEFAULT_INNER_DIAMETER
	self.diameter = self.innerDiameter
end

function UmbilicalReelHose:setColor(color)
	self.color = color

	self:applyColor()
end

function UmbilicalReelHose:getColor()
	return self.color
end

function UmbilicalReelHose:applyColor()
	local r, g, b, m = unpack(self.color)
	r = r or 0.05
	g = g or 0.05
	b = b or 0.05
	m = m or 0

	for _, layer in ipairs(self.layers) do
		if getHasShaderParameter(layer.node, "colorMat") then
			setShaderParameter(layer.node, "colorMat", r, g, b, m, false)
		end
	end
end

function UmbilicalReelHose:loadLayers(length, invert)
	invert = invert or false

	self:getAmountOfLayersForLength(self.capacity, function (layers, currentLength)
		table.insert(self.layers, self:create(layers, 0, currentLength, invert))
	end)
	self:applyLayersForLength(length, 1)
	self:applyColor()
end

function UmbilicalReelHose:applyLayersForLength(length, direction)
	for i = #self.layers, 0, -1 do
		self:updateLayers(i, -1)
	end

	self:getAmountOfLayersForLength(length, function (layers)
		self:updateLayers(layers, direction)
	end)
end

function UmbilicalReelHose:create(layers, state, currentLength, isInverted)
	isInverted = isInverted or false
	local entry = {
		index = layers + 1,
		length = currentLength,
		linkNode = self.linkNode,
		isVisible = state > 0,
		isInverted = isInverted
	}
	local cacheEntry = self.hoseCache:clone()
	entry.node = cacheEntry.node
	local initialState = 0

	if entry.node ~= nil then
		local shaderState, _, _, _ = getShaderParameter(entry.node, UmbilicalReelHose.SHADER_PARAM)
		initialState = shaderState
	end

	state = state or initialState
	local tx, ty, tz = unpack(self.translation)
	local rx, ry, rz = unpack(self.rotation)
	local offset = self.shift
	local isEven = layers % 2 ~= 0

	if not isInverted and not isEven or isInverted and isEven then
		offset = -offset
		tx = tx + self.coilsAmount * math.abs(offset)
	end

	entry.params = {
		state = initialState,
		offset = offset,
		thickness = self.layerThickness,
		layer = layers
	}

	if entry.node ~= nil then
		local _, coilsDirection, _, w = getShaderParameter(entry.node, UmbilicalReelHose.SHADER_PARAM_COILS)

		setShaderParameter(entry.node, UmbilicalReelHose.SHADER_PARAM_COILS, self.coilsAmount, coilsDirection, self.innerDiameter, w, false)
		setShaderParameter(entry.node, UmbilicalReelHose.SHADER_PARAM, state, offset, self.layerThickness, layers, false)
		link(entry.linkNode, entry.node)
		setRotation(entry.node, rx, ry, rz)
		setTranslation(entry.node, tx, ty, tz)
		setVisibility(entry.node, entry.isVisible)
	end

	return entry
end

function UmbilicalReelHose:getLayerByIndex(index)
	return self.layers[index]
end

function UmbilicalReelHose:getCurrentLayer()
	return self:getLayerByIndex(self.amountOfLayers)
end

function UmbilicalReelHose:getAmountOfLayers()
	return self.amountOfLayers
end

function UmbilicalReelHose:getAmountOfLayersForLength(length, updateFunc)
	local layers = 0
	local currentLength = 0

	while length > currentLength do
		if updateFunc ~= nil then
			updateFunc(layers, currentLength)
		end

		local diameter = self:getDiameterByLayers(layers)
		currentLength = self:getRealLength(diameter)
		layers = layers + 1
	end

	return layers
end

function UmbilicalReelHose:getActiveLayer(length)
	local layers = math.max(1, (self.diameter - self.innerDiameter) / self.layerThickness)
	local l = math.max(1, self:getRealLength(self.diameter))

	return length / l * layers
end

function UmbilicalReelHose:getState(layers)
	return math.max(1 - (self.amountOfLayers - layers), 0)
end

function UmbilicalReelHose:getDiameterByState(state)
	local diameter = self.innerDiameter + self.amountOfLayers * self.layerThickness

	return diameter + self.layerThickness * state
end

function UmbilicalReelHose:getDiameterByLayers(layers)
	local diameter = self.innerDiameter + layers * self.layerThickness

	return diameter + self.layerThickness
end

function UmbilicalReelHose:getDiameter()
	return self.diameter
end

function UmbilicalReelHose:getRadius()
	return self.diameter * 0.5
end

function UmbilicalReelHose:getRealLength(diameter)
	local innerDiameter = self.innerDiameter
	local thickness = self.layerThickness * 0.5
	local lengthPerCoil = math.pi * (diameter^2 / 4 - innerDiameter^2 / 4) / thickness

	return lengthPerCoil * self.coilsAmount
end

function UmbilicalReelHose:getRotationByState(state)
	return math.pi * 2 * self.coilsAmount * state
end

function UmbilicalReelHose:getPlacementOffset(layerNumber, startPlacementX)
	local layer = self:getCurrentLayer()

	if layer == nil then
		layer = table.first(self.layers)
	end

	local x = startPlacementX
	local isEven = layerNumber % 2 ~= 0

	if not layer.isInverted and not isEven or layer.isInverted and isEven then
		x = x + self.coilsAmount * math.abs(layer.params.offset)
	end

	return x
end

function UmbilicalReelHose:setLayerVisibility(layer, isVisible)
	if isVisible == nil then
		isVisible = true
	end

	if layer.isVisible ~= isVisible then
		if layer.node ~= nil then
			setVisibility(layer.node, isVisible)
		end

		layer.isVisible = isVisible
	end
end

function UmbilicalReelHose:setLayerActiveState(layer, state, isVisible)
	self:setLayerVisibility(layer, isVisible)

	if layer.node ~= nil then
		setShaderParameter(layer.node, UmbilicalReelHose.SHADER_PARAM, state, layer.params.offset, layer.params.thickness, layer.params.layer, false)
	end
end

function UmbilicalReelHose:updateLayers(activeLayer, direction)
	local currentLayer = self.amountOfLayers
	local targetLayer = math.floor(activeLayer) + 1
	local state = self:getState(activeLayer)
	self.diameter = self:getDiameterByState(state)
	local layer = self:getLayerByIndex(currentLayer)

	if layer ~= nil then
		self:setLayerActiveState(layer, state)
	end

	local isUnwinding = direction < 0
	local isWinding = direction > 0

	if isUnwinding and targetLayer < currentLayer or isWinding and currentLayer < targetLayer then
		if layer ~= nil then
			local isRemoving = currentLayer - targetLayer > 0
			local finalState = math.booltointeger(not isRemoving)

			self:setLayerActiveState(layer, finalState, not isRemoving)
		end

		if targetLayer <= #self.layers then
			self.amountOfLayers = targetLayer
		end
	end
end

function UmbilicalReelHose:setLength(length, reelDirection)
	self.length = math.clamp(length, 0, self.capacity)

	self:applyLayersForLength(self.length, reelDirection)
end

function UmbilicalReelHose:addLength(length, reelDirection)
	self.length = math.clamp(self.length + length, 0, self.capacity)
end

function UmbilicalReelHose:getCapacity()
	return self.capacity
end

function UmbilicalReelHose:getLength()
	return self.length
end

function UmbilicalReelHose:isEmpty()
	return self.length <= 0
end

function UmbilicalReelHose:isFull()
	return self.capacity <= self.length
end

function UmbilicalReelHose:setDamageAmount(damage)
	self.damage = damage
end

function UmbilicalReelHose:getDamageAmount()
	return self.damage
end
