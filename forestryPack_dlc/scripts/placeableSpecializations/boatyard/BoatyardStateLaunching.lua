local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

BoatyardStateLaunching = {}
local BoatyardStateLaunching_mt = Class(BoatyardStateLaunching, BoatyardState)

function BoatyardStateLaunching.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.FLOAT, basePath .. "#friction", "")
	schema:register(XMLValueType.FLOAT, basePath .. "#maxSpeed", "")
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "splash")
end

function BoatyardStateLaunching.new(boatyard, customMt)
	local self = BoatyardState.new(boatyard, customMt or BoatyardStateLaunching_mt)
	self.speed = 0
	self.maxSpeed = 8
	self.waterY = -2000
	self.friction = 0.0017
	self.launchHour = 14
	self.launchDayTimeMs = self.launchHour * 60 * 60 * 1000

	return self
end

function BoatyardStateLaunching:load(xmlFile, key)
	BoatyardStateLaunching:superClass().load(self, xmlFile, key)

	self.friction = xmlFile:getValue(key .. "#friction", self.friction)
	self.maxSpeed = xmlFile:getValue(key .. "#maxSpeed", self.maxSpeed)
	local baseDirecory = self.boatyard.baseDirectory
	local components = self.boatyard.components
	local i3dMappings = self.boatyard.i3dMappings
	self.samples.splash = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "splash", baseDirecory, components, 0, AudioGroup.ENVIRONMENT, i3dMappings, self)
end

function BoatyardStateLaunching:isDone()
	return self.done
end

function BoatyardStateLaunching:activate()
	self.done = false
	self.speed = 0
	self.startTime = 0
	self.launching = false
	self.playedSplash = false

	if self.boatyard.isServer then
		g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.hourChanged, self)
	end

	self.infoBoxText = g_i18n:getText("infohub_launchingIn")
	self.infoBoxElement = {
		accentuate = true,
		title = ""
	}

	BoatyardStateLaunching:superClass().activate(self)
end

function BoatyardStateLaunching:deactivate()
	if self.boatyard.isServer then
		g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED, self)
	end

	BoatyardStateLaunching:superClass().deactivate(self)
end

function BoatyardStateLaunching:hourChanged(hour)
	if hour == self.launchHour then
		self.boatyard:raiseActive()

		self.launching = true
		self.startTimeCooldown = g_time + 5000

		g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED, self)
	end
end

function BoatyardStateLaunching:raiseActive()
	return self.launching
end

function BoatyardStateLaunching:getPlaySound()
	return self.launching and not self.playedSplash
end

function BoatyardStateLaunching:update(dt)
	if self.launching then
		local splineTime = self.boatyard:getSplineTime()

		if splineTime >= 1 or self.speed < 0.001 and self.startTimeCooldown < g_time then
			self.done = true
		end

		local x, y, z = getSplinePosition(self.spline, splineTime)

		g_currentMission.environmentAreaSystem:getWaterYAtWorldPositionAsync(x, y, z, function (_, waterY)
			self.waterY = waterY or -2000
		end, nil, )

		local waterDepth = self.waterY - y
		local acc = 0
		local friction = 0

		if waterDepth < 0.1 then
			local angle = SplineUtil.getSlopeAngle(self.spline, splineTime)
			acc = 9.81 * 0.6 * math.sin(angle) * dt / 1000
			friction = self.friction
		else
			if not self.playedSplash and self.samples.splash ~= nil then
				g_soundManager:playSample(self.samples.splash)

				self.playedSplash = true
			end

			friction = friction + waterDepth / 250
		end

		self.speed = self.speed + acc - MathUtil.sign(self.speed) * friction
		self.speed = MathUtil.clamp(self.speed, 0, self.maxSpeed * (1 - splineTime^4))

		self.boatyard:addSplineDistanceDelta(self.speed / 1000 * dt)
	end

	BoatyardStateLaunching:superClass().update(self, dt)
end

function BoatyardStateLaunching:updateInfo(infoTable)
	if not self.launching then
		local timeUntilLaunch = nil

		if self.launchDayTimeMs < g_currentMission.environment.dayTime then
			timeUntilLaunch = self.launchDayTimeMs + 86400000 - g_currentMission.environment.dayTime
		else
			timeUntilLaunch = self.launchDayTimeMs - g_currentMission.environment.dayTime
		end

		self.infoBoxElement.title = string.format(self.infoBoxText, g_i18n:formatMinutes(timeUntilLaunch / 60 / 1000))

		table.insert(infoTable, self.infoBoxElement)
	end
end

function BoatyardStateLaunching:getLaunchingSpeedSoundModifier()
	return self.speed / self.maxSpeed
end

g_soundManager:registerModifierType("BOATYARD_LAUNCHING_SPEED", BoatyardStateLaunching.getLaunchingSpeedSoundModifier)
