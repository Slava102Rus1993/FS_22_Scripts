local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

ExhaustEffect = {}
local ExhaustEffect_mt = Class(ExhaustEffect, Effect)

function ExhaustEffect.new(customMt)
	local self = Effect.new(customMt or ExhaustEffect_mt)

	return self
end

function ExhaustEffect:load(xmlFile, baseName, rootNodes, parent, i3dMapping)
	if ExhaustEffect:superClass().load(self, xmlFile, baseName, rootNodes, parent, i3dMapping) == nil then
		return nil
	end

	self.minRpmColor = XMLValueType.getXMLVector4(xmlFile.handle, baseName .. "#minRpmColor", "0 0 0 1", true)
	self.maxRpmColor = XMLValueType.getXMLVector4(xmlFile.handle, baseName .. "#maxRpmColor", "0.0384 0.0359 0.0627 2.0", true)
	self.minRpmScale = xmlFile:getFloat(baseName .. "#minRpmScale", 0.25)
	self.maxRpmScale = xmlFile:getFloat(baseName .. "#maxRpmScale", 0.95)
	self.upFactor = xmlFile:getFloat(baseName .. "#upFactor", 0.75)
	self.lastPosition = nil
	self.xRot = 0
	self.zRot = 0
	self.isActive = false
	self.lastRpmScale = 0

	return self
end

function ExhaustEffect:loadEffectAttributes(xmlFile, key, node, i3dNode, i3dMapping)
	if xmlFile == nil or not entityExists(xmlFile.handle) then
		return true
	end

	return ExhaustEffect:superClass().loadEffectAttributes(self, xmlFile, key, node, i3dNode, i3dMapping)
end

function ExhaustEffect:transformEffectNode(xmlFile, key, node)
	if xmlFile == nil or not entityExists(xmlFile.handle) then
		return true
	end

	return ExhaustEffect:superClass().transformEffectNode(self, xmlFile, key, node)
end

function ExhaustEffect:update(dt)
	ExhaustEffect:superClass().update(self, dt)

	if self.isActive then
		local posX, posY, posZ = localToWorld(self.node, 0, 0.5, 0)

		if self.lastPosition == nil then
			self.lastPosition = {
				posX,
				posY,
				posZ
			}
		end

		local vx = (posX - self.lastPosition[1]) * 10
		local vy = (posY - self.lastPosition[2]) * 10
		local vz = (posZ - self.lastPosition[3]) * 10
		local ex, ey, ez = localToWorld(self.node, 0, 1, 0)
		vz = ez - vz
		vy = ey - vy + self.upFactor
		vx = ex - vx
		local lx, ly, lz = worldToLocal(self.node, vx, vy, vz)
		local distance = MathUtil.vector2Length(lx, lz)
		lx, lz = MathUtil.vector2Normalize(lx, lz)
		ly = math.abs(math.max(ly, 0.01))
		local xFactor = math.atan(distance / ly) * (1.2 + 2 * ly)
		local yFactor = math.atan(distance / ly) * (1.2 + 2 * ly)
		local xRot = math.atan(lz / ly) * xFactor
		local zRot = -math.atan(lx / ly) * yFactor
		self.xRot = self.xRot * 0.95 + xRot * 0.05
		self.zRot = self.zRot * 0.95 + zRot * 0.05
		local scale = MathUtil.lerp(self.minRpmScale, self.maxRpmScale, self.lastRpmScale)

		setShaderParameter(self.node, "param", self.xRot, self.zRot, 0, scale, false)

		local r = MathUtil.lerp(self.minRpmColor[1], self.maxRpmColor[1], self.lastRpmScale)
		local g = MathUtil.lerp(self.minRpmColor[2], self.maxRpmColor[2], self.lastRpmScale)
		local b = MathUtil.lerp(self.minRpmColor[3], self.maxRpmColor[3], self.lastRpmScale)
		local a = MathUtil.lerp(self.minRpmColor[4], self.maxRpmColor[4], self.lastRpmScale)

		setShaderParameter(self.node, "exhaustColor", r, g, b, a, false)

		self.lastPosition[1] = posX
		self.lastPosition[2] = posY
		self.lastPosition[3] = posZ
	end
end

function ExhaustEffect:isRunning()
	return self.isActive
end

function ExhaustEffect:start()
	self.isActive = true

	setVisibility(self.node, self.isActive)
	setShaderParameter(self.node, "param", self.xRot, self.zRot, 0, 0, false)

	local color = self.minRpmColor

	setShaderParameter(self.node, "exhaustColor", color[1], color[2], color[3], color[4], false)

	return true
end

function ExhaustEffect:stop()
	self.isActive = false

	setVisibility(self.node, self.isActive)

	return true
end

function ExhaustEffect:reset()
end

function ExhaustEffect:setFillType(fillType, force)
	return true
end

function ExhaustEffect:getIsVisible()
	return self.isActive
end

function ExhaustEffect:getIsFullyVisible()
	return self.isActive
end

function ExhaustEffect:setDensity(density)
	self.lastRpmScale = density
end

function ExhaustEffect.registerEffectXMLPaths(schema, basePath)
	schema:register(XMLValueType.VECTOR_4, basePath .. "#minRpmColor", "Min. rpm color", "0 0 0 1")
	schema:register(XMLValueType.VECTOR_4, basePath .. "#maxRpmColor", "Max. rpm color", "0.0384 0.0359 0.0627 2.0")
	schema:register(XMLValueType.FLOAT, basePath .. "#minRpmScale", "Min. rpm scale", 0.25)
	schema:register(XMLValueType.FLOAT, basePath .. "#maxRpmScale", "Max. rpm scale", 0.95)
	schema:register(XMLValueType.FLOAT, basePath .. "#upFactor", "Defines how far the effect goes up in the air in meter", 0.75)
end

g_effectManager:registerEffectClass("ExhaustEffect", ExhaustEffect)
