Vector3 = class("Vector3")

function Vector3.translationFromWorldNode(node)
	local x, y, z = getWorldTranslation(node)

	return Vector3(x, y, z)
end

function Vector3.translationFromTwoNodes(node1, node2)
	local x1, y1, z1 = getTranslation(node1)
	local x2, y2, z2 = getTranslation(node2)

	return Vector3(x1 - x2, y1 - y2, z1 - z2)
end

function Vector3.translationFromTwoWorldNodes(node1, node2)
	local x1, y1, z1 = getWorldTranslation(node1)
	local x2, y2, z2 = getWorldTranslation(node2)

	return Vector3(x1 - x2, y1 - y2, z1 - z2)
end

function Vector3:construct(x, y, z)
	if type(x) == "table" then
		x, y, z = unpack(x)
	end

	self.x = x
	self.y = y
	self.z = z
end

function Vector3:copy()
	return Vector3(self.x, self.y, self.z)
end

function Vector3:getPosition()
	return self.x, self.y, self.z
end

function Vector3:getPositionTable()
	return {
		self.x,
		self.y,
		self.z
	}
end

function Vector3:applyTranslationToNode(node)
	return setTranslation(node, self.x, self.y, self.z)
end

function Vector3:applyRotationToNode(node)
	return setRotation(node, self.x, self.y, self.z)
end

function Vector3:normalized(m)
	m = m or self:magnitude()

	if m ~= 0 then
		return self / m
	end

	return self
end

function Vector3:magnitude()
	return math.sqrt(self.x^2 + self.y^2 + self.z^2)
end

function Vector3:magnitudeSquared()
	return self.x^2 + self.y^2 + self.z^2
end

function Vector3:angleY()
	return math.atan2(self.x, self.z)
end

function Vector3:angleX()
	return math.atan2(self.y, self.z)
end

function Vector3:lerp(b, t)
	return self + (b - self) * t
end

function Vector3.__mul(v1, v2)
	if type(v1) == "number" then
		return Vector3(v1 * v2.x, v1 * v2.y, v1 * v2.z)
	elseif type(v2) == "number" then
		return Vector3(v1.x * v2, v1.y * v2, v1.z * v2)
	else
		assert(v1:isa(Vector3) and v2:isa(Vector3), "mul: wrong argument types: (expected <Vector3> or <number>)")

		return Vector3(v1.x * v2.x, v1.y * v2.y, v1.z * v2.z)
	end
end

function Vector3.__div(v1, v2)
	if type(v2) == "number" then
		return Vector3(v1.x / v2, v1.y / v2, v1.z / v2)
	end

	return Vector3(v1.x / v2.x, v1.y / v2.y, v1.z / v2.z)
end

function Vector3.__add(v1, v2)
	if type(v2) == "number" then
		return Vector3(v1.x + v2, v1.y + v2, v1.z + v2)
	end

	return Vector3(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
end

function Vector3.__sub(v1, v2)
	if type(v2) == "number" then
		return Vector3(v1.x - v2, v1.y - v2, v1.z - v2)
	end

	return Vector3(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
end

function Vector3:__tostring()
	return string.format("(%.2f, %.2f, %.2f)", self.x, self.y, self.z)
end

Vector3.zero = Vector3(0, 0, 0)
Vector3.forward = Vector3(0, 0, 1)
Vector3.back = Vector3(0, 0, -1)
Vector3.down = Vector3(0, -1, 0)
Vector3.up = Vector3(0, 1, 0)
