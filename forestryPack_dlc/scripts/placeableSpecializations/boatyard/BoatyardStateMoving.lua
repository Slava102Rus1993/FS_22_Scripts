local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

BoatyardStateMoving = {}
local BoatyardStateMoving_mt = Class(BoatyardStateMoving, BoatyardState)

function BoatyardStateMoving.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.FLOAT, basePath .. ".spline#startTime", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".spline#endTime", "")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".spline#endPosNode", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".spline#maxSpeed", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".spline#acceleration", "")
end

function BoatyardStateMoving.new(boatyard, customMt)
	local self = BoatyardState.new(boatyard, customMt or BoatyardStateMoving_mt)

	return self
end

function BoatyardStateMoving:load(xmlFile, key)
	BoatyardStateMoving:superClass().load(self, xmlFile, key)

	self.splineStartTime = xmlFile:getValue(key .. ".spline#startTime")
	self.splineEndTime = xmlFile:getValue(key .. ".spline#endTime")
	local splineEndPosNode = xmlFile:getValue(key .. ".spline#endPosNode", nil, self.boatyard.components, self.boatyard.i3dMappings)

	if splineEndPosNode ~= nil then
		local x, y, z = getWorldTranslation(splineEndPosNode)
		local _, _, _, splineTime = getClosestSplinePosition(self.spline, x, y, z, 0.3)
		self.splineEndTime = splineTime
	end

	self.speed = 0
	self.maxSpeed = xmlFile:getValue(key .. ".spline#maxSpeed", 2)
	self.acc = xmlFile:getValue(key .. ".spline#acceleration", 1)
end

function BoatyardStateMoving:isDone()
	return self.splineEndTime <= self.boatyard:getSplineTime()
end

function BoatyardStateMoving:update(dt)
	if self.boatyard.isServer then
		local splineTime = self.boatyard:addSplineDistanceDelta(self.speed / 1000 * dt)
		local remainingDistance = self.splineLength * (self.splineEndTime - splineTime)

		if remainingDistance < 3 then
			self.deaccSpeed = self.deaccSpeed or self.speed
			self.speed = MathUtil.lerp(self.deaccSpeed, 0.1, 1 - remainingDistance / 3)
		else
			self.speed = MathUtil.clamp(self.speed + self.acc * dt / 1000, 0.01, self.maxSpeed)
		end
	end

	BoatyardStateMoving:superClass().update(self, dt)
end

function BoatyardStateMoving:activate()
	self.speed = 0

	if self.splineStartTime ~= nil then
		self.boatyard:setSplineTime(self.splineStartTime)
	end

	BoatyardStateMoving:superClass().activate(self)
end

function BoatyardStateMoving:getMovingSpeedSoundModifier()
	return self.speed / self.maxSpeed
end

g_soundManager:registerModifierType("BOATYARD_MOVING_SPEED", BoatyardStateMoving.getMovingSpeedSoundModifier)
