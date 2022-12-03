local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

BoatyardStateRelease = {}
local BoatyardStateRelease_mt = Class(BoatyardStateRelease, BoatyardState)

function BoatyardStateRelease.new(boatyard, customMt)
	local self = BoatyardState.new(boatyard, customMt or BoatyardStateRelease_mt)

	return self
end

function BoatyardStateRelease:isDone()
	return true
end

function BoatyardStateRelease:activate()
	BoatyardStateRelease:superClass().activate(self)
	self.boatyard:releaseBoat()
	self.boatyard:setSplineTime(0, true)
	BoatyardStateRelease:superClass().activate(self)
end
