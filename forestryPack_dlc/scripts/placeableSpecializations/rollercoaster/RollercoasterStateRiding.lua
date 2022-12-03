local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

RollercoasterStateRiding = {}
local RollercoasterStateRiding_mt = Class(RollercoasterStateRiding, RollercoasterState)

function RollercoasterStateRiding.registerXMLPaths(schema, basePath)
end

function RollercoasterStateRiding.new(rollercoaster, customMt)
	local self = RollercoasterState.new(rollercoaster, customMt or RollercoasterStateRiding_mt)
	self.animation = self.rollercoaster:getAnimation()
	self.animationTimeNetworkPrecision = 0.05
	self.animationTimeNetworkPrecisionFactor = 1000 * self.animationTimeNetworkPrecision
	local maxValue = self.animation.clipDuration / self.animationTimeNetworkPrecisionFactor
	self.animationTimeNetworkNumBits = MathUtil.getNumRequiredBits(maxValue)
	self.animationInterpolator = rollercoaster[PlaceableRollercoaster.SPEC].animationInterpolator
	self.animationTimeInterpolator = rollercoaster[PlaceableRollercoaster.SPEC].animationTimeInterpolator
	self.lastSentTime = -1
	self.infoBoxRideUnderway = {
		accentuate = true,
		title = g_i18n:getText("infohud_rideUnderway")
	}

	return self
end

function RollercoasterStateRiding:isDone()
	return self.animation.clipCharacterSet ~= nil and self.animation.clipDuration <= getAnimTrackTime(self.animation.clipCharacterSet, self.animation.clipIndex)
end

function RollercoasterStateRiding:raiseActive()
	return true
end

function RollercoasterStateRiding:activate()
	RollercoasterStateRiding:superClass().activate(self)

	if self.isClient and not self.isServer then
		g_currentMission:addUpdateable(self)
	end

	self.rollercoaster:startRide()
end

function RollercoasterStateRiding:deactivate()
	RollercoasterStateRiding:superClass().activate(self)

	if self.isClient and not self.isServer then
		g_currentMission:removeUpdateable(self)
	end

	self.rollercoaster:endRide()
end

function RollercoasterStateRiding:update(dt)
	if self.isClient then
		self.rollercoaster:updateFxModifierValues(dt)
	end

	if self.isServer then
		if self.lastSentTime ~= MathUtil.round(getAnimTrackTime(self.animation.clipCharacterSet, self.animation.clipIndex) / self.animationTimeNetworkPrecisionFactor) then
			self.rollercoaster:raiseDirtyFlags(self.dirtyFlag)
		end
	else
		self.animationTimeInterpolator:update(dt)

		local interpolationAlpha = self.animationTimeInterpolator:getAlpha()
		local animationTime = self.animationInterpolator:getInterpolatedValue(interpolationAlpha)

		self.rollercoaster:setAnimationTime(animationTime)
	end
end

function RollercoasterStateRiding:onReadStream(streamId, connection)
	local animationTime = streamReadUInt16(streamId)

	self.animationInterpolator:setValue(animationTime)
	self.animationTimeInterpolator:reset()
end

function RollercoasterStateRiding:onWriteStream(streamId, connection)
	streamWriteUInt16(streamId, getAnimTrackTime(self.animation.clipCharacterSet, self.animation.clipIndex))
end

function RollercoasterStateRiding:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		local animationTime = streamReadUIntN(streamId, self.animationTimeNetworkNumBits) * self.animationTimeNetworkPrecisionFactor

		self.animationTimeInterpolator:startNewPhaseNetwork()
		self.animationInterpolator:setTargetValue(animationTime)
	end
end

function RollercoasterStateRiding:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local animationTimeCompacted = MathUtil.round(getAnimTrackTime(self.animation.clipCharacterSet, self.animation.clipIndex) / self.animationTimeNetworkPrecisionFactor)
		self.lastSentTime = animationTimeCompacted

		streamWriteUIntN(streamId, animationTimeCompacted, self.animationTimeNetworkNumBits)
	end
end

function RollercoasterStateRiding:updateInfo(infoTable)
	table.insert(infoTable, self.infoBoxRideUnderway)
end
