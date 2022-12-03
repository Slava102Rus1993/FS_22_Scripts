HoseBase = class("HoseBase")
HoseBase.Y_OFFSET = 0.0508
HoseBase.COLOR_DEFAULT_RED = 0.05
HoseBase.COLOR_DEFAULT_GREEN = 0.05
HoseBase.COLOR_DEFAULT_BLUE = 0.05
HoseBase.DEFAULT_MATERIAL = 0

function HoseBase:construct(startNode, endNode, mesh, length, bends, adaptToGround, parametricConstant)
	self.startNode = startNode
	self.endNode = endNode
	self.length = length or 10

	if g_isEditor ~= nil then
		adaptToGround = false
	end

	self.adaptToGround = adaptToGround or false
	self.bends = bends or false
	self.scrollPosition = 0
	self.isActive = true
	self.canCompute = true
	self.computed = false
	self.isInverted = false
	self.alpha = parametricConstant or 0.5
	self.mul = self.length * self.alpha
	self.curve = Curve(Curve.BEZIER_CUBIC)
	self.color = {
		HoseBase.COLOR_DEFAULT_RED,
		HoseBase.COLOR_DEFAULT_GREEN,
		HoseBase.COLOR_DEFAULT_BLUE,
		HoseBase.DEFAULT_MATERIAL
	}

	self:addMesh(mesh)
end

function HoseBase:delete()
	self.canCompute = false

	if self.mesh ~= nil then
		delete(self.mesh)

		self.mesh = nil
	end
end

function HoseBase:setParametricConstant(constant)
	assert(constant >= 0 and constant <= 1)

	self.alpha = constant
	self.mul = self.length * self.alpha
end

function HoseBase:addMesh(mesh)
	if mesh ~= nil then
		self.mesh = mesh

		self:linkMeshToNode(mesh, self.startNode)

		self.canCompute = getHasShaderParameter(mesh, "lengthAndDiameter")

		if self.canCompute then
			setShaderParameter(mesh, "lengthAndDiameter", self.length, 1, 0, 0, false)
		end

		self:applyColor()
	end
end

function HoseBase:linkMeshToNode(mesh, node)
	unlink(mesh)
	link(node, mesh)
	setTranslation(mesh, 0, 0, 0)
	setRotation(mesh, 0, math.rad(180), 0)
	setVisibility(mesh, true)
end

function HoseBase:setDirection(isInverted)
	if isInverted ~= self.isInverted then
		self.isInverted = isInverted

		if self.mesh ~= nil then
			setRotation(self.mesh, 0, isInverted and math.rad(180) or 0, 0)
		end
	end
end

function HoseBase:invertMesh(isInverted)
	self.isInverted = isInverted
	local startNode = self.startNode
	local endNode = self.endNode

	self:setStartNode(endNode)
	self:setEndNode(startNode)
end

function HoseBase:setStartNode(node)
	self.startNode = node

	self:linkMeshToNode(self.mesh, node)
end

function HoseBase:setEndNode(node)
	self.endNode = node
end

function HoseBase:setColor(color)
	self.color = color

	self:applyColor()
end

function HoseBase:applyColor()
	if self.mesh ~= nil then
		local r, g, b, m = unpack(self.color)
		r = r or HoseBase.COLOR_DEFAULT_RED
		g = g or HoseBase.COLOR_DEFAULT_GREEN
		b = b or HoseBase.COLOR_DEFAULT_BLUE
		m = m or HoseBase.DEFAULT_MATERIAL

		if getHasShaderParameter(self.mesh, "colorMat0") then
			setShaderParameter(self.mesh, "colorMat0", r, g, b, m, false)
		end
	end
end

function HoseBase:setLength(length, lengthConstraint)
	lengthConstraint = lengthConstraint or length
	self.length = math.max(length, lengthConstraint)
	self.mul = self.length * self.alpha
end

function HoseBase:setActiveState(isActive)
	if self.isActive ~= isActive then
		self.isActive = isActive

		if self.mesh ~= nil then
			setVisibility(self.mesh, isActive)
		end
	end
end

function HoseBase:scroll(length)
	if self.mesh ~= nil then
		self.scrollPosition = (self.scrollPosition + length) % self.length
		local _, y, z, w = getShaderParameter(self.mesh, "offsetUV")

		setShaderParameter(self.mesh, "offsetUV", self.scrollPosition, y, z, w, false)
	end
end

function HoseBase:getTerrainLimitedYPosition(x, y, z)
	local terrainY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
	self.correctedY = -1

	raycastClosest(x, y + HoseBase.Y_OFFSET, z, 0, -1, 0, "groundRaycastCallback", 5, self, CollisionFlag.TERRAIN + CollisionFlag.STATIC_OBJECT)

	return math.max(terrainY, self.correctedY) + HoseBase.Y_OFFSET
end

function HoseBase:groundRaycastCallback(hitObjectId, x, y, z, distance)
	if getHasTrigger(hitObjectId) then
		return true
	end

	self.correctedY = y

	return true
end

function HoseBase:update()
	if not self:canPerformCompute() then
		return
	end

	self.p0, self.p1, self.p2, self.p3 = self:getControlPoints()

	if self.canCompute and self.isActive then
		local p0, p1, p2, p3 = self.curve:controlsFromCubicBezierToCatmull(self.p0, self.p1, self.p2, self.p3)

		self:updateMesh(p0, p1, p2, p3)
	end

	self.computed = true

	if g_currentMission.manure.isDebug then
		self:draw()
	end
end

function HoseBase:canPerformCompute()
	if self.length <= 0 then
		return false
	end

	if not entityExists(self.startNode) or not entityExists(self.endNode) then
		return false
	end

	return true
end

function HoseBase:curveToByVectors(p0, p1, p2, p3)
	if self.canCompute and self.isActive and self.length > 0 then
		self:updateMesh(p0:getPositionTable(), p1:getPositionTable(), p2:getPositionTable(), p3:getPositionTable())
	end
end

function HoseBase:curveTo(p0, p1, p2, p3)
	if self.canCompute and self.isActive and self.length > 0 then
		self:updateMesh(p0, p1, p2, p3)
	end
end

function HoseBase:updateMesh(p0, p1, p2, p3)
	if self.mesh ~= nil then
		local p0x, p0y, p0z = worldToLocal(self.mesh, p0[1], p0[2], p0[3])
		local p1x, p1y, p1z = worldToLocal(self.mesh, p1[1], p1[2], p1[3])
		local p2x, p2y, p2z = worldToLocal(self.mesh, p2[1], p2[2], p2[3])
		local p3x, p3y, p3z = worldToLocal(self.mesh, p3[1], p3[2], p3[3])
		local intersectionOffset = 0.001

		setShaderParameter(self.mesh, "cv0", p0x + intersectionOffset, p0y, p0z, 0, false)
		setShaderParameter(self.mesh, "cv2", p1x, p1y, p1z, 0, false)
		setShaderParameter(self.mesh, "cv2", p1x, p1y, p1z, 0, false)
		setShaderParameter(self.mesh, "cv3", p2x, p2y, p2z, 0, false)
		setShaderParameter(self.mesh, "cv4", p3x, p3y, p3z, 0, false)
	end
end

function HoseBase:draw()
	if not self.computed then
		return
	end

	local p0, p1, p2, p3 = self.curve:controlsFromCubicBezierToCatmull(self.p0, self.p1, self.p2, self.p3)

	self.curve:draw(Curve.CATMULL, p0, p1, p2, p3)
end

function HoseBase:isComputed()
	return self.computed
end

function HoseBase:getControlPoints(offset)
	offset = offset or self.mul
	local mul = offset * math.booltodirection(not self.isInverted)
	local p0 = self:getDirectionPoint(self.startNode, 0)
	local p3 = self:getDirectionPoint(self.endNode, 0)
	local p1 = self:getDirectionPoint(self.startNode, -mul)
	local p2 = self:getDirectionPoint(self.endNode, mul)

	if self.bends then
		local distanceVector = Vector3(p3[1] - p0[1], p3[2] - p0[2], p3[3] - p0[3])
		local distance = distanceVector:magnitude()
		local lengthDifference = math.max(self.length - distance, 0)
		local beta = math.max(lengthDifference, 0.04 * distance) * 0.5
		p1[2] = p1[2] - beta
	end

	if self.adaptToGround then
		p2[2] = self:getTerrainLimitedYPosition(p2[1], p2[2], p2[3])
		p1[2] = self:getTerrainLimitedYPosition(p1[1], p1[2], p1[3])
	end

	return p0, p1, p2, p3
end

function HoseBase:getDirectionPoint(node, mul)
	local x, y, z = localToWorld(node, 0, 0, mul or 1)

	return {
		x,
		y,
		z
	}
end

function HoseBase:getComputedTargetAsVector()
	return Vector3((self.p0[1] + self.p3[1]) * 0.5, (self.p0[2] + self.p3[2]) * 0.5, (self.p0[3] + self.p3[3]) * 0.5)
end

function HoseBase:getComputedTarget()
	return self.p2[1], self.p2[2], self.p2[3]
end

function HoseBase:getApproximateArcLength()
	local x1 = self.p0[1] - self.center[1]
	local y1 = self.p0[2] - self.center[2]
	local z1 = self.p0[3] - self.center[3]
	local x2 = self.center[1] - self.p3[1]
	local y2 = self.center[2] - self.p3[2]
	local z2 = self.center[3] - self.p3[3]

	return math.sqrt(x1^2 + y1^2 + z1^2) + math.sqrt(x2^2 + y2^2 + z2^2)
end
