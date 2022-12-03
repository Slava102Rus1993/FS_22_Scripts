local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

RollercoasterStateFinalize = {}
local RollercoasterStateFinalize_mt = Class(RollercoasterStateFinalize, RollercoasterState)

function RollercoasterStateFinalize.registerXMLPaths(schema, basePath)
end

function RollercoasterStateFinalize.new(rollercoaster, customMt)
	local self = RollercoasterState.new(rollercoaster, customMt or RollercoasterStateFinalize_mt)

	return self
end

function RollercoasterStateFinalize:isDone()
	return true
end

function RollercoasterStateFinalize:raiseActive()
	return true
end

function RollercoasterStateFinalize:deactivate()
	RollercoasterStateFinalize:superClass().activate(self)
	self.rollercoaster:finalizeBuild()
end
