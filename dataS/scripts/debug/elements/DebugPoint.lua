DebugPoint = {}
local DebugPoint_mt = Class(DebugPoint)

function DebugPoint.new(customMt)
	local self = setmetatable({}, customMt or DebugPoint_mt)
	self.z = 0
	self.y = 0
	self.x = 0
	self.color = {
		g = 1,
		a = 1,
		b = 1,
		r = 1
	}
	self.solid = false
	self.alignToGround = false
	self.hideWhenGuiIsOpen = false
	self.clipDistance = 2000

	return self
end

function DebugPoint:delete()
end

function DebugPoint:update(dt)
end

function DebugPoint:draw()
	if self.hideWhenGuiIsOpen and g_gui:getIsGuiVisible() then
		return
	end

	if not DebugUtil.isPositionInCameraRange(self.x, self.y, self.z, self.clipDistance) then
		return
	end

	drawDebugPoint(self.x, self.y, self.z, self.color.r, self.color.g, self.color.b, self.color.a, self.solid)
end

function DebugPoint:createWithNode(node, alignToGround, solid, hideWhenGUIOpen, clipDistance)
	local x, y, z = getWorldTranslation(node)

	return self:createWithWorldPosAndDir(x, y, z, alignToGround, solid, hideWhenGUIOpen, clipDistance)
end

function DebugPoint:createWithWorldPos(x, y, z, alignToGround, solid, hideWhenGUIOpen, clipDistance)
	if alignToGround and g_currentMission.terrainRootNode ~= nil then
		y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 0.1
	end

	self.z = z
	self.y = y
	self.x = x
	self.solid = Utils.getNoNil(solid, self.solid)
	self.hideWhenGuiIsOpen = Utils.getNoNil(hideWhenGUIOpen, self.hideWhenGuiIsOpen)
	self.clipDistance = Utils.getNoNil(clipDistance, self.clipDistance)

	return self
end

function DebugPoint:setColor(r, g, b, a)
	self.color.r = r or self.color.r
	self.color.g = g or self.color.g
	self.color.b = b or self.color.b
	self.color.a = a or self.color.a

	return self
end

function DebugPoint:setClipDistance(clipDistance)
	self.clipDistance = clipDistance

	return self
end
