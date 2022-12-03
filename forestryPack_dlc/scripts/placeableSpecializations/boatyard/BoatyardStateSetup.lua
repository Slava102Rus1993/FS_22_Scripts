local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

BoatyardStateSetup = {}
local BoatyardStateSetup_mt = Class(BoatyardStateSetup, BoatyardState)

function BoatyardStateSetup.new(boatyard, customMt)
	local self = BoatyardState.new(boatyard, customMt or BoatyardStateSetup_mt)

	return self
end

function BoatyardStateSetup:activate()
	self.boatyard:setSplineTime(0, true)
	self.boatyard:createBoat()
	BoatyardStateSetup:superClass().activate(self)
end
