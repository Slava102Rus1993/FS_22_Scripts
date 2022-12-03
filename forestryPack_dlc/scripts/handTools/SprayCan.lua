local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

SprayCan = {
	CUSTOM_ENVIRONMENT = g_currentModName,
	MOD_DIRECTORY = g_currentModDirectory,
	LAST_SELECTED_MARKER_INDEX = nil
}
local SprayCan_mt = Class(SprayCan, HandTool)

InitObjectClass(SprayCan, "SprayCan")
g_xmlManager:addInitSchemaFunction(function ()
	local schema = HandTool.xmlSchema

	schema:setXMLSpecializationType("SprayCan")
	schema:register(XMLValueType.NODE_INDEX, "handTool.sprayCan#colorNode", "Color node")
	schema:register(XMLValueType.VECTOR_4, "handTool.sprayCan#color", "Color of the paint")
	schema:register(XMLValueType.FLOAT, "handTool.sprayCan#distance", "Spray distance")
	schema:register(XMLValueType.FLOAT, "handTool.sprayCan#delay", "Spray delay in seconds")
	SoundManager.registerSampleXMLPaths(schema, "handTool.sprayCan.sounds", "spraying")
	EffectManager.registerEffectXMLPaths(schema, "handTool.sprayCan.effects")
	schema:setXMLSpecializationType()
end)

function SprayCan.new(isServer, isClient, customMt)
	local self = HandTool.new(isServer, isClient, customMt or SprayCan_mt)
	self.sprayDetectionDistance = 1.5
	self.foundTreeShape = nil
	self.foundTreeHitPosition = {
		0,
		0,
		0
	}
	self.sprayColor = {
		1,
		0,
		1,
		1
	}
	self.treeMarkerTypeIndex = SprayCan.LAST_SELECTED_MARKER_INDEX

	if g_iconGenerator == nil then
		self.treeMarkerType = g_currentMission.treeMarkerSystem:getTreeMarkerTypeByIndex(self.treeMarkerTypeIndex)

		if self.treeMarkerType == nil then
			self.treeMarkerTypeIndex = 1
			self.treeMarkerType = g_currentMission.treeMarkerSystem:getTreeMarkerTypeByIndex(self.treeMarkerTypeIndex)
		end
	end

	self.wasActivatePressed = false
	self.isSpraying = false
	self.sprayDelay = 0
	self.sprayDuration = 500
	self.sprayStopTime = 0
	self.numShakes = 3
	self.shakeDuration = 200
	self.shakeEndTime = 0
	self.delayedMarker = nil

	return self
end

function SprayCan:postLoad(xmlFile)
	if not SprayCan:superClass().postLoad(self, xmlFile) then
		return false
	end

	local color = xmlFile:getValue("handTool.sprayCan#color", {
		1,
		1,
		1,
		1
	}, true)
	self.sprayColor = color
	self.sprayDetectionDistance = xmlFile:getValue("handTool.sprayCan#distance", self.sprayDetectionDistance)
	self.sprayDelay = xmlFile:getValue("handTool.sprayCan#delay", 0) * 1000
	local colorNode = xmlFile:getValue("handTool.sprayCan#colorNode", self.rootNode, self.components, self.i3dMappings)

	if colorNode ~= nil then
		setShaderParameter(colorNode, "colorMat0", color[1], color[2], color[3], color[4], false)
	end

	self.canNode = colorNode
	self.originalPos = {
		getTranslation(colorNode)
	}
	self.effects = g_effectManager:loadEffect(xmlFile, "handTool.sprayCan.effects", self.components, self, self.i3dMappings)

	g_effectManager:setFillType(self.effects, FillType.WATER)

	for _, effect in ipairs(self.effects) do
		if effect.setColor ~= nil then
			effect:setColor(color[1], color[2], color[3], color[4])
		end
	end

	self.sprayingSample = g_soundManager:loadSampleFromXML(xmlFile, "handTool.sprayCan.sounds", "spraying", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)

	return true
end

function SprayCan:delete()
	self:processDelayedMarker()
	g_effectManager:deleteEffects(self.effects)
	g_soundManager:deleteSample(self.sprayingSample)
	SprayCan:superClass().delete(self)
end

function SprayCan:treeRaycastCallback(hitObjectId, x, y, z, distance)
	if getHasClassId(hitObjectId, ClassIds.MESH_SPLIT_SHAPE) then
		self.foundTreeShape = hitObjectId
		self.foundTreeHitPosition[1] = x
		self.foundTreeHitPosition[2] = y
		self.foundTreeHitPosition[3] = z
	end
end

function SprayCan:update(dt, allowInput)
	SprayCan:superClass().update(self, dt, allowInput)

	if allowInput then
		local x, y, z = getWorldTranslation(self.player.cameraNode)
		local dx, dy, dz = localDirectionToWorld(self.player.cameraNode, 0, 0, -1)
		self.foundTreeShape = nil

		raycastClosest(x, y, z, dx, dy, dz, "treeRaycastCallback", self.sprayDetectionDistance, self, CollisionFlag.TREE)

		if self.activatePressed and not self.wasActivatePressed and not self.isSpraying then
			local treeMarkerTypeIndex = self.treeMarkerTypeIndex
			local shape = self.foundTreeShape
			local hitX = self.foundTreeHitPosition[1]
			local hitY = self.foundTreeHitPosition[2]
			local hitZ = self.foundTreeHitPosition[3]

			if self:getIsSprayingAllowed(shape) then
				g_client:getServerConnection():sendEvent(SprayCanEvent.new(self.player, treeMarkerTypeIndex, shape, x, y, z, hitX, hitY, hitZ))
			else
				g_currentMission:showBlinkingWarning(g_i18n:getText("warning_youAreNotAllowedToMarkThisTree", SprayCan.CUSTOM_ENVIRONMENT), 2000)
			end

			self.wasActivatePressed = true
		end
	end

	if self.delayedMarker ~= nil and self.delayedMarker.time <= g_time then
		self:processDelayedMarker()
	end

	if self.isSpraying then
		if allowInput then
			local x = self.originalPos[1]
			local y = self.originalPos[2]
			local z = self.originalPos[3]
			local timeLeft = math.max(0, self.shakeEndTime - g_time)
			local factor = 1 - timeLeft / self.shakeDuration
			local animValue = MathUtil.lerp(0, self.numShakes, factor)
			x = x + math.sin(animValue * math.pi) * 0.01
			y = y + math.sin(animValue * math.pi) * 0.05
			z = z + math.sin(animValue * math.pi) * 0.01

			setTranslation(self.canNode, x, y, z)
		end

		if self.sprayStopTime < g_time then
			self:setIsSpraying(false, false)
		end
	end

	if not self.activatePressed then
		self.wasActivatePressed = false
	end

	self.activatePressed = false
end

function SprayCan:draw()
	SprayCan:superClass().draw(self)

	if self.treeMarkerType ~= nil then
		local overlay = self.treeMarkerType.iconOverlay

		if overlay ~= nil then
			overlay:render()
		end

		if self.foundTreeShape ~= nil then
			local treeOverlay = g_currentMission.treeMarkerSystem.treeOverlay

			if treeOverlay ~= nil then
				treeOverlay:render()
			end
		end
	end
end

function SprayCan:spray(treeMarkerTypeIndex, splitShapeId, x, y, z, hitX, hitY, hitZ)
	self:setIsSpraying(true, false)

	self.sprayStopTime = g_time + self.sprayDuration

	if splitShapeId ~= nil and self:getIsSprayingAllowed(splitShapeId) then
		self.delayedMarker = {
			time = g_time + self.sprayDelay,
			splitShapeId = splitShapeId,
			treeMarkerTypeIndex = treeMarkerTypeIndex,
			hitX = hitX,
			hitY = hitY,
			hitZ = hitZ,
			x = x,
			y = y,
			z = z
		}
	end
end

function SprayCan:processDelayedMarker()
	if self.delayedMarker ~= nil then
		local splitShapeId = self.delayedMarker.splitShapeId
		local treeMarkerTypeIndex = self.delayedMarker.treeMarkerTypeIndex
		local x = self.delayedMarker.x
		local y = self.delayedMarker.y
		local z = self.delayedMarker.z
		local hitX = self.delayedMarker.hitX
		local hitY = self.delayedMarker.hitY
		local hitZ = self.delayedMarker.hitZ
		local r = self.sprayColor[1]
		local g = self.sprayColor[2]
		local b = self.sprayColor[3]
		local a = self.sprayColor[4]

		g_currentMission.treeMarkerSystem:addTreeMarkerCameraBased(splitShapeId, treeMarkerTypeIndex, r, g, b, a, x, y, z, hitX, hitY, hitZ, true)

		self.delayedMarker = nil
	end
end

function SprayCan:setIsSpraying(isSpraying, force)
	if self.isSpraying ~= isSpraying then
		if isSpraying then
			g_effectManager:startEffects(self.effects)
			g_soundManager:playSample(self.sprayingSample)

			self.shakeEndTime = g_time + self.shakeDuration
		else
			if force then
				g_effectManager:resetEffects(self.effects)
			else
				g_effectManager:stopEffects(self.effects)
			end

			g_soundManager:stopSample(self.sprayingSample)

			self.sprayStopTime = 0
		end

		self.isSpraying = isSpraying
	end
end

function SprayCan:onDeactivate(allowInput)
	SprayCan:superClass().onDeactivate(self)
	self:setIsSpraying(false, true)

	self.wasActivatePressed = false
end

function SprayCan:registerActionEvents()
	SprayCan:superClass().registerActionEvents(self)
	g_inputBinding:beginActionEventsModification(Player.INPUT_CONTEXT_NAME)
	g_inputBinding:registerActionEvent(InputAction.SPRAYCAN_CHANGE_MARKER, self, self.onChangeMarker, false, true, false, true)
	g_inputBinding:endActionEventsModification()
end

function SprayCan:onChangeMarker(_, inputValue)
	local treeMarkerSystem = g_currentMission.treeMarkerSystem
	self.treeMarkerTypeIndex = self.treeMarkerTypeIndex + 1

	if treeMarkerSystem:getNumOfTreeMarkerTypes() < self.treeMarkerTypeIndex then
		self.treeMarkerTypeIndex = 1
	end

	SprayCan.LAST_SELECTED_MARKER_INDEX = self.treeMarkerTypeIndex
	self.treeMarkerType = treeMarkerSystem:getTreeMarkerTypeByIndex(self.treeMarkerTypeIndex)
end

function SprayCan:getIsSprayingAllowed(shape)
	if shape == nil or shape == 0 then
		return true
	end

	local x, _, z = getWorldTranslation(shape)

	if g_currentMission.accessHandler:canFarmAccessLand(self.player.farmId, x, z) then
		return true
	end

	return false
end

registerHandTool(SprayCan.CUSTOM_ENVIRONMENT .. ".sprayCan", SprayCan)
