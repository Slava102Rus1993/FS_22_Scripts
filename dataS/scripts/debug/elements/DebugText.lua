DebugText = {}
local DebugText_mt = Class(DebugText)

function DebugText.new(customMt)
	local self = setmetatable({}, customMt or DebugText_mt)
	self.z = 0
	self.y = 0
	self.x = 0
	self.rotZ = 0
	self.rotY = 0
	self.rotX = 0
	self.alignment = RenderText.ALIGN_CENTER
	self.verticalAlignment = RenderText.VERTICAL_ALIGN_MIDDLE
	self.a = 1
	self.b = 1
	self.g = 1
	self.r = 1
	self.size = 0.1
	self.text = nil
	self.alignToGround = false
	self.alignToCamera = false
	self.clipDistance = nil

	return self
end

function DebugText:delete()
end

function DebugText:update(dt)
	if self.alignToCamera then
		self.rotY = self:getRotationToCamera(self.x, self.y, self.z)
	end
end

function DebugText:draw()
	if self.clipDistance ~= nil then
		local x, y, z = getWorldTranslation(getCamera())

		if self.clipDistance < MathUtil.vector3Length(x - self.x, y - self.y, z - self.z) then
			return
		end
	end

	setTextDepthTestEnabled(false)
	setTextAlignment(self.alignment)
	setTextVerticalAlignment(self.verticalAlignment)
	setTextColor(self.r, self.g, self.b, self.a)
	renderText3D(self.x, self.y, self.z, self.rotX, self.rotY, self.rotZ, self.size, self.text)
	setTextAlignment(RenderText.ALIGN_LEFT)
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
	setTextDepthTestEnabled(true)
end

function DebugText:createWithNode(node, text, size)
	local x, y, z = getWorldTranslation(node)
	local rotX, rotY, rotZ = getWorldRotation(node)

	return self:createWithWorldPosAndRot(x, y, z, rotX, rotY, rotZ, text, size)
end

function DebugText:createWithNodeToCamera(node, yOffset, text, size)
	self.alignToCamera = true
	local x, y, z = localToWorld(node, 0, yOffset, 0)

	return self:createWithWorldPosAndRot(x, y, z, 0, self:getRotationToCamera(x, y, z), 0, text, size)
end

function DebugText:createWithWorldPosAndRot(x, y, z, rotX, rotY, rotZ, text, size)
	self.z = z
	self.y = y
	self.x = x
	self.rotZ = rotZ
	self.rotY = rotY
	self.rotX = rotX
	self.text = text
	self.size = size

	return self
end

function DebugText:getRotationToCamera(x, y, z)
	local cx, cy, cz = getWorldTranslation(getCamera())
	local dirX, _, dirZ = MathUtil.vector3Normalize(cx - x, cy - y, cz - z)

	return MathUtil.getYRotationFromDirection(dirX, dirZ)
end

function DebugText:setColor(r, g, b, a)
	self.r = r or self.r
	self.g = g or self.g
	self.b = b or self.b
	self.a = a or self.a

	return self
end

function DebugText:setClipDistance(clipDistance)
	self.clipDistance = clipDistance

	return self
end
