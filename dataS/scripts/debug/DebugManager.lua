DebugManager = {}
local DebugManager_mt = Class(DebugManager, AbstractManager)

function DebugManager.new(customMt)
	local self = AbstractManager.new(customMt or DebugManager_mt)

	return self
end

function DebugManager:initDataStructures()
	self.permanentElements = {}
	self.permanentFunctions = {}
	self.frameElements = {}
	self.debugMaterial = nil

	if self.debugMaterialNode ~= nil then
		delete(self.debugMaterialNode)

		self.debugMaterialNode = nil
	end

	self.splineDebugEnabled = false
	self.splineDebugElements = {}
	self.occluderDebugEnabled = false

	if not self.initialized then
		addConsoleCommand("gsDebugManagerClearElements", "Removes all permanent elements and functions from DebugManager", "consoleCommandRemovePermanentElements", self)
		addConsoleCommand("gsSplineDebug", "Toggles debug visualization for all splines currently in the scene", "consoleCommandSplineToggleDebug", self)
		addConsoleCommand("gsOccluderDebug", "Toggles debug visualization for all occluders currently in the scene", "consoleCommandOccluderToggleDebug", self)

		self.initialized = true
	end
end

function DebugManager:getDebugMat()
	if self.debugMaterial == nil then
		local debugMatI3d = loadI3DFile("data/shared/materialHolders/debugMaterialHolder.i3d", false, false, false)
		self.debugMaterialNode = getChildAt(debugMatI3d, 0)

		unlink(self.debugMaterialNode)

		self.debugMaterial = getMaterial(self.debugMaterialNode, 0)

		delete(debugMatI3d)
	end

	return self.debugMaterial
end

function DebugManager:unloadMapData()
	self.loadedMapData = false

	self:initDataStructures()
end

function DebugManager:update(dt)
	for _, element in ipairs(self.permanentElements) do
		element:update(dt)
	end
end

function DebugManager:draw()
	for _, element in ipairs(self.permanentElements) do
		element:draw()
	end

	for _, element in ipairs(self.permanentFunctions) do
		element[1](unpack(element[2]))
	end

	for i = #self.frameElements, 1, -1 do
		self.frameElements[i]:draw()
		table.remove(self.frameElements, i)
	end
end

function DebugManager:addPermanentElement(element)
	table.addElement(self.permanentElements, element)
end

function DebugManager:removePermanentElement(element)
	table.removeElement(self.permanentElements, element)
end

function DebugManager:addFrameElement(element)
	table.addElement(self.frameElements, element)
end

function DebugManager:addPermanentFunction(funcAndParams)
	table.addElement(self.permanentFunctions, funcAndParams)
end

function DebugManager:removePermanentFunction(funcAndParams)
	table.removeElement(self.permanentFunctions, funcAndParams)
end

function DebugManager:consoleCommandRemovePermanentElements()
	self.permanentElements = {}
	self.permanentFunctions = {}

	return "Cleared all permanent debug elements"
end

function DebugManager:consoleCommandSplineToggleDebug()
	self.splineDebugEnabled = not self.splineDebugEnabled

	if self.splineDebugEnabled then
		self.splineDebugElements = {}
		local debugMat = self:getDebugMat()
		local numAffectedNodes = 0

		local function checkNode(node)
			if I3DUtil.getIsSpline(node) then
				self.splineDebugElements[node] = self.splineDebugElements[node] or {}

				DebugUtil.setNodeEffectivelyVisible(node)

				local r, g, b = unpack(DebugUtil.getDebugColor(node))

				setMaterial(node, debugMat, 0)
				setShaderParameter(node, "color", r, g, b, 0, false)
				setShaderParameter(node, "alpha", 1, 0, 0, 0, false)

				local debugElements = DebugUtil.getSplineDebugElements(node)
				self.splineDebugElements[node] = debugElements

				for elemName, debugElement in pairs(debugElements) do
					if elemName == "splineAttributes" then
						debugElement:setColor(r, g, b)
					end

					g_debugManager:addPermanentElement(debugElement)
				end

				numAffectedNodes = numAffectedNodes + 1
			end
		end

		I3DUtil.interateRecursively(getRootNode(), checkNode)

		return string.format("Added debug visualization to %d splines", numAffectedNodes)
	elseif self.splineDebugElements then
		for node, debugElements in pairs(self.splineDebugElements) do
			if entityExists(node) then
				setVisibility(node, false)
			end

			for _, debugElement in pairs(debugElements) do
				g_debugManager:removePermanentElement(debugElement)
			end
		end

		self.splineDebugElements = nil

		return string.format("Removed spline debug elements")
	end
end

function DebugManager:consoleCommandOccluderToggleDebug()
	self.occluderDebugEnabled = not self.occluderDebugEnabled

	if self.occluderDebugEnabled then
		self.occluderDebugElements = {}
		local debugMat = self:getDebugMat()
		local count = 0

		local function checkNode(node)
			if getHasClassId(node, ClassIds.SHAPE) and getIsOccluderMesh(node) then
				setIsNonRenderable(node, false)
				setMaterial(node, debugMat, 0)

				local color = DebugUtil.getDebugColor(node)

				setShaderParameter(node, "color", color[1], color[2], color[3], 0, false)
				setShaderParameter(node, "alpha", 0.3, 0, 0, 0, false)

				local _, effectiveCd = getEffectiveClipDistancesWithLOD(node)
				local cd = getClipDistance(node)
				local text = string.format("OccluderMesh: %s (CD=%d)", getName(node), math.min(effectiveCd, cd))
				local debugElement = DebugText.new():createWithNodeToCamera(node, 0.3 + math.random(), text, 0.13):setColor(color[1], color[2], color[3])
				self.occluderDebugElements[node] = debugElement

				g_debugManager:addPermanentElement(debugElement)

				count = count + 1
			end
		end

		I3DUtil.interateRecursively(getRootNode(), checkNode)

		return string.format("Added debug material to %d occluders", count)
	else
		for node, debugElement in pairs(self.occluderDebugElements) do
			if entityExists(node) then
				setIsNonRenderable(node, true)
			end

			g_debugManager:removePermanentElement(debugElement)
		end

		return "Reset occluders to be non-renderable"
	end
end

g_debugManager = DebugManager.new()
