LinearAnimation = {
	STATE_OFF = 0,
	STATE_TURNING_OFF = 2,
	STATE_ON = 1
}
local LinearAnimation_mt = Class(LinearAnimation, Animation)

function LinearAnimation.new(customMt)
	local self = Animation.new(customMt or LinearAnimation_mt)
	self.state = LinearAnimation.STATE_OFF
	self.node = nil
	self.turnOnOffVariance = nil
	self.turnOnFadeTime = 0
	self.turnOffFadeTime = 0
	self.initialTurnOnFadeTime = 1000
	self.currentAlpha = 0
	self.owner = nil
	self.transSpeed = 1
	self.transAxis = 1
	self.startPos = 0
	self.endPos = 1
	self.currentPos = 0

	function self.speedFunc()
		return 1
	end

	self.speedFuncTarget = self

	return self
end

function LinearAnimation:load(xmlFile, key, rootNodes, owner, i3dMapping)
	if not xmlFile:hasProperty(key) then
		return nil
	end

	self.owner = owner
	self.node = xmlFile:getValue(key .. "#node", nil, rootNodes, i3dMapping)

	if self.node == nil then
		Logging.xmlWarning(xmlFile, "Missing node for linear animation '%s'!", key)

		return nil
	end

	self.turnOnFadeTime = math.max(xmlFile:getValue(key .. "#turnOnFadeTime", 2) * 1000, 1)
	self.turnOffFadeTime = math.max(xmlFile:getValue(key .. "#turnOffFadeTime", 2) * 1000, 1)
	self.turnOnOffVariance = xmlFile:getValue(key .. "#turnOnOffVariance")

	if self.turnOnOffVariance ~= nil then
		self.initialTurnOnFadeTime = self.turnOnFadeTime
		self.initialTurnOffFadeTime = self.turnOffFadeTime
		self.turnOnOffVariance = self.turnOnOffVariance * 1000
	end

	self.transSpeed = xmlFile:getValue(key .. "#transSpeed", 1) * 0.001
	self.transAxis = xmlFile:getValue(key .. "#transAxis", 1)
	self.startPos = xmlFile:getValue(key .. "#startPos", 0)
	self.endPos = xmlFile:getValue(key .. "#endPos", 0)
	local translation = {
		getTranslation(self.node)
	}
	self.currentPos = translation[self.transAxis]
	local speedFuncStr = xmlFile:getValue(key .. "#speedFunc")

	if speedFuncStr ~= nil then
		if owner[speedFuncStr] ~= nil then
			self.speedFunc = owner[speedFuncStr]
			self.speedFuncTarget = self.owner
		else
			Logging.xmlWarning(xmlFile, "Could not find speed function '%s' for linear animation '%s'!", speedFuncStr, key)
		end
	end

	return self
end

function LinearAnimation:update(dt)
	LinearAnimation:superClass().update(self, dt)

	if self.state == LinearAnimation.STATE_ON then
		self.currentAlpha = math.min(1, self.currentAlpha + dt / self.turnOnFadeTime)
	elseif self.state == LinearAnimation.STATE_TURNING_OFF then
		self.currentAlpha = math.max(0, self.currentAlpha - dt / self.turnOffFadeTime)
	end

	if self.currentAlpha > 0 then
		local speedFactor = self.speedFunc(self.speedFuncTarget)
		local trans = self.currentAlpha * dt * self.transSpeed * speedFactor
		self.currentPos = math.max(math.min(self.currentPos + trans, self.endPos), self.startPos)

		if self.currentPos == self.startPos and self.transSpeed < 0 or self.currentPos == self.endPos and self.transSpeed > 0 then
			self.transSpeed = -self.transSpeed
		end

		local translation = {
			[self.transAxis] = self.currentPos,
			getTranslation(self.node)
		}

		setTranslation(self.node, unpack(translation))

		if self.owner ~= nil and self.owner.setMovingToolDirty ~= nil then
			self.owner:setMovingToolDirty(self.node)
		end
	else
		self.state = LinearAnimation.STATE_OFF
	end

	self:updateDuplicates()
end

function LinearAnimation:isRunning()
	return self.state ~= LinearAnimation.STATE_OFF
end

function LinearAnimation:start()
	if self.state ~= LinearAnimation.STATE_ON then
		if self.state == LinearAnimation.STATE_OFF and self.turnOnOffVariance ~= nil and self.currentAlpha == 0 then
			self.turnOnFadeTime = self.initialTurnOnFadeTime + math.random(-self.turnOnOffVariance, self.turnOnOffVariance)
			self.turnOffFadeTime = self.initialTurnOffFadeTime + math.random(-self.turnOnOffVariance, self.turnOnOffVariance)
		end

		self.state = LinearAnimation.STATE_ON

		self:updateDuplicates()

		return true
	end

	return false
end

function LinearAnimation:stop()
	if self.state ~= LinearAnimation.STATE_OFF then
		self.state = LinearAnimation.STATE_TURNING_OFF

		self:updateDuplicates()

		return true
	end

	return false
end

function LinearAnimation:reset()
	self.currentAlpha = 0
	self.state = LinearAnimation.STATE_OFF

	self:updateDuplicates()
end

function LinearAnimation:isDuplicate(otherAnimation)
	return otherAnimation:isa(LinearAnimation) and self.parent == otherAnimation.parent and self.node == otherAnimation.node
end

function LinearAnimation:updateDuplicate(otherAnimation)
	otherAnimation.currentAlpha = self.currentAlpha
	otherAnimation.state = self.state
end

function LinearAnimation.registerAnimationClassXMLPaths(schema, basePath)
	schema:register(XMLValueType.NODE_INDEX, basePath .. "#node", "Node")
	schema:register(XMLValueType.FLOAT, basePath .. "#transSpeed", "Translation speed", 1)
	schema:register(XMLValueType.FLOAT, basePath .. "#transAxis", "Translation axis", 1)
	schema:register(XMLValueType.FLOAT, basePath .. "#startPos", "Start position of animation", 0)
	schema:register(XMLValueType.FLOAT, basePath .. "#endPos", "End position of animation", 1)
	schema:register(XMLValueType.FLOAT, basePath .. "#turnOnFadeTime", "Turn on fade time", 2)
	schema:register(XMLValueType.FLOAT, basePath .. "#turnOffFadeTime", "Turn off fade time", 2)
	schema:register(XMLValueType.FLOAT, basePath .. "#turnOnOffVariance", "Turn off time variance")
	schema:register(XMLValueType.STRING, basePath .. "#speedFunc", "Lua speed function")
end
