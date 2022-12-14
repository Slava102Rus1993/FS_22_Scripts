ConstructionBrushFence = {}
local ConstructionBrushFence_mt = Class(ConstructionBrushFence, ConstructionBrush)
ConstructionBrushFence.ERROR = {
	MINIMUM_ANGLE = 101,
	MININUM_LENGTH = 100,
	NOT_ENOUGH_MONEY = 104,
	CANNOT_BE_PLACED_HERE = 105,
	MAXIMUM_ANGLE = 102,
	COLLISION = 103
}
ConstructionBrushFence.ERROR_MESSAGES = {
	[ConstructionBrushFence.ERROR.MININUM_LENGTH] = "ui_construction_distanceTooShort",
	[ConstructionBrushFence.ERROR.MINIMUM_ANGLE] = "ui_construction_cornerAngleTooLarge",
	[ConstructionBrushFence.ERROR.MAXIMUM_ANGLE] = "ui_construction_terrainTooSteep",
	[ConstructionBrushFence.ERROR.COLLISION] = "ui_construction_collidesWithItem",
	[ConstructionBrushFence.ERROR.NOT_ENOUGH_MONEY] = "ui_construction_notEnoughMoney",
	[ConstructionBrushFence.ERROR.CANNOT_BE_PLACED_HERE] = "ui_construction_cannotBePlacedHere"
}
ConstructionBrushFence.MINIMUM_LENGTH = 0.5
ConstructionBrushFence.MINIMUM_ANGLE = math.rad(30)
ConstructionBrushFence.SNAP_DISTANCE = 0.4
ConstructionBrushFence.LAST_SNAPPING_STATE = false

function ConstructionBrushFence.new(subclass_mt, cursor)
	local self = ConstructionBrushFence:superClass().new(subclass_mt or ConstructionBrushFence_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsSecondaryButton = true
	self.supportsTertiaryButton = true
	self.needsOverlayReset = {}
	self.requiredPermission = Farm.PERMISSION.BUY_PLACEABLE
	self.parallelSnappingEnabled = false
	self.doFindPlaceable = false
	self.supportsSnapping = true
	self.snappingActive = ConstructionBrushFence.LAST_SNAPPING_STATE
	self.snappingAngleDeg = 7.5
	self.snappingSize = 0.25

	return self
end

function ConstructionBrushFence:delete()
	ConstructionBrushFence:superClass().delete(self)

	self.doFindPlaceable = false
end

function ConstructionBrushFence:activate()
	ConstructionBrushFence:superClass().activate(self)
	self.cursor:setRotationEnabled(false)
	self.cursor:setShape(GuiTopDownCursor.SHAPES.NONE)
	g_messageCenter:subscribe(PlaceableFenceAddSegmentEvent, self.onFenceSegmentCreated, self)
	self:acquirePlaceable()
end

function ConstructionBrushFence:deactivate()
	self:releasePlaceable()

	self.fence = nil
	self.doFindPlaceable = false

	self.cursor:setColorMode(GuiTopDownCursor.SHAPES_COLORS.SELECT, nil)
	self:resetErrorOverlays()
	g_messageCenter:unsubscribeAll(self)
	ConstructionBrushFence:superClass().deactivate(self)
end

function ConstructionBrushFence:setFilename(xmlFilename)
	if not self.isActive then
		self.xmlFilename = xmlFilename
	end
end

function ConstructionBrushFence:setIsGate(isGate, gateIndex)
	if isGate then
		self.gateIndex = gateIndex
	else
		self.gateIndex = nil
	end
end

function ConstructionBrushFence:setParameters(filename, isGate, gateIndex)
	if isGate == "true" then
		gateIndex = tonumber(gateIndex)

		self:setIsGate(true, gateIndex)
	else
		self:setIsGate(false)
	end

	self:setFilename(filename)
end

function ConstructionBrush:setStoreItem(storeItem)
	if not self.isActive then
		self.storeItem = storeItem
	end
end

function ConstructionBrushFence:canCancel()
	return self.fence ~= nil and self.fence:getPreviewSegment() ~= nil
end

function ConstructionBrushFence:acquirePlaceable()
	if self.xmlFilename == nil then
		Logging.warning("Fence brush has no placeable set")

		return
	end

	self.fence = self:findPlaceable()

	self:setInputTextDirty()

	if self.fence == nil then
		g_messageCenter:subscribe(BuyPlaceableEvent, self.onPlaceableCreated, self)
		g_client:getServerConnection():sendEvent(BuyPlaceableEvent.new(self.xmlFilename, 100, PlacementUtil.NETHER_HEIGHT - 1, 0, 0, 0, 0, 0, g_currentMission:getFarmId(), false, 0, true))
	elseif self.fence:getHasParallelSnapping() then
		self.parallelSnappingEnabled = true
	end
end

function ConstructionBrushFence:findPlaceable()
	local farmId = g_currentMission:getFarmId()

	for _, placeable in pairs(g_currentMission.placeableSystem.placeables) do
		if placeable.configFileName == self.xmlFilename and placeable.ownerFarmId == farmId and not placeable.markedForDeletion then
			return placeable
		end
	end

	return nil
end

function ConstructionBrushFence:onPlaceableCreated()
	g_messageCenter:unsubscribe(BuyPlaceableEvent, self)

	self.doFindPlaceable = true
end

function ConstructionBrushFence:releasePlaceable()
	if self.fence ~= nil then
		if self.fence:getNumSequments() == 0 then
			g_currentMission.shopController.ignoreSoldPlaceableEvent = true

			g_messageCenter:subscribe(SellPlaceableEvent, self.onPlaceableDestroyed, self)
			g_client:getServerConnection():sendEvent(SellPlaceableEvent.new(self.fence, true))
		elseif self.fence:getPreviewSegment() ~= nil then
			self.fence:setPreviewSegment(nil)
		end

		if self.previewPole ~= nil then
			delete(self.previewPole)

			self.previewPole = nil
		end

		self.fence = nil

		self:setInputTextDirty()
	end
end

function ConstructionBrushFence:onPlaceableDestroyed()
	g_messageCenter:unsubscribe(SellPlaceableEvent, self)

	g_currentMission.shopController.ignoreSoldPlaceableEvent = false
end

function ConstructionBrushFence:getSnappedCursorPosition()
	local x, y, z = self.cursor:getHitTerrainPosition()

	local function isNodeSegmentEndpoint(node)
		local pole = getParent(node)
		local group = getParent(pole)

		return pole == getChildAt(group, 0) or pole == getChildAt(group, getNumOfChildren(group) - 1)
	end

	if x == nil then
		local node = self.cursor:getHitNode()

		if node == nil then
			return nil
		end

		local px, py, pz, segment = self.fence:getPolePosition(node)

		if px == nil then
			return nil
		end

		if self.fence:getAllowExtendingOnly() then
			if isNodeSegmentEndpoint(node) then
				return px, py, pz, true, segment
			else
				return x, y, z, false
			end
		end

		return px, py, pz, true, segment
	end

	if self.parallelSnappingEnabled then
		local snapCheckDistance = self.fence:getSnapCheckDistance()
		local px, py, pz, _, segment = self.fence:getPoleNear(x, y, z, snapCheckDistance)
		local previewSegment = self.fence:getPreviewSegment()

		self.cursor:setColorMode(GuiTopDownCursor.SHAPES_COLORS.SELECT, nil)

		if px ~= nil and previewSegment == nil then
			if self.previewPoleCursor then
				self.cursor:setColorMode(GuiTopDownCursor.SHAPES_COLORS.SUCCESS, nil)
			end

			local dx, dz = MathUtil.vector2Normalize(segment.x2 - segment.x1, segment.z2 - segment.z1)
			local dist = self.fence:getSnapDistance()
			local x1 = -dz * dist + px
			local z1 = dx * dist + pz
			local x2 = dz * dist + px
			local z2 = -dx * dist + pz
			local distance1 = MathUtil.vector2Length(x1 - x, z1 - z)
			local distance2 = MathUtil.vector2Length(x2 - x, z2 - z)
			local distancePole = MathUtil.vector2Length(px - x, pz - z)
			local snapX, snapZ = nil

			if distance1 < distance2 then
				snapZ = z1
				snapX = x1
			else
				snapZ = z2
				snapX = x2
			end

			self.parallelSnappingSegment = segment
			local snapY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, snapX, 0, snapZ)

			if self.fence:getMaxCornerAngle() == 0 and distancePole < dist * 0.4 then
				return px, py, pz, true, segment
			end

			return snapX, snapY, snapZ, true
		elseif self.parallelSnappingSegment ~= nil and previewSegment ~= nil then
			local alignSegment = self.parallelSnappingSegment
			local dx, dz = MathUtil.vector2Normalize(alignSegment.x2 - alignSegment.x1, alignSegment.z2 - alignSegment.z1)
			local targetX, targetZ = MathUtil.projectOnLine(x, z, previewSegment.x1, previewSegment.z1, dx, dz)
			local targetY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, targetX, 0, targetZ)

			return targetX, targetY, targetZ, true
		end

		self.parallelSnappingSegment = nil
	end

	local snapDistance = math.max(self.fence:getPanelLength() * ConstructionBrushFence.SNAP_DISTANCE, self.fence:getSnapCheckDistance())
	local px, py, pz, node, segment = self.fence:getPoleNear(x, y, z, snapDistance)

	if px ~= nil and self.fence:getMaxCornerAngle() > 0 then
		if self.fence:getAllowExtendingOnly() then
			if isNodeSegmentEndpoint(node) then
				return px, py, pz, true, segment
			else
				return x, y, z, false
			end
		end

		return px, py, pz, true, segment
	end

	if self.snappingActive then
		local snapSize = 1 / self.snappingSize
		x = math.floor(x * snapSize) / snapSize
		z = math.floor(z * snapSize) / snapSize
	end

	return x, y, z, false
end

function ConstructionBrushFence:getLimitedSnappedCursorPosition()
	local x, y, z, snapped, segment = self:getSnappedCursorPosition()
	local pSegment = self.fence:getPreviewSegment()

	if x ~= nil and pSegment ~= nil then
		local dx = x - pSegment.x1
		local dz = z - pSegment.z1
		local panelLength = MathUtil.vector2Length(dx, dz)
		local recalculateY = false

		if panelLength == 0 then
			dz = 0
			dx = 1
		else
			dx, dz = MathUtil.vector2Normalize(dx, dz)
		end

		if self.gateIndex ~= nil then
			panelLength = self.fence:getGate(self.gateIndex).length
			recalculateY = true
		elseif self.fence:getIsPanelLengthFixed() then
			local length = self.fence:getPanelLength()
			panelLength = math.floor(panelLength / length) * length
			recalculateY = true
		end

		local prevSeqment = self.attachmentPointSegment
		local snapAngleDeg = self.fence:getSnapAngle()

		if prevSeqment ~= nil and snapAngleDeg ~= nil then
			local prevdx = prevSeqment.x2 - prevSeqment.x1
			local prevdz = prevSeqment.z2 - prevSeqment.z1
			prevdx, prevdz = MathUtil.vector2Normalize(prevdx, prevdz)
			local prevRotY = MathUtil.getYRotationFromDirection(prevdx, prevdz)
			local rotY = MathUtil.getYRotationFromDirection(dx, dz)
			local diff = prevRotY - rotY
			local snappedAngle = math.rad(MathUtil.snapValue(math.deg(diff), snapAngleDeg))
			dx, dz = MathUtil.vector2Rotate(prevdx, prevdz, snappedAngle)
			recalculateY = true
		end

		x = pSegment.x1 + dx * panelLength
		z = pSegment.z1 + dz * panelLength

		if recalculateY then
			y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
		end
	end

	return x, y, z, snapped, segment
end

function ConstructionBrushFence:getPreviewAngle()
	if self.fence:getPreviewSegment() == nil then
		return nil
	end

	local segment = self.fence:getPreviewSegment()
	local prevSegment = self.attachmentPointSegment

	if prevSegment == nil then
		return nil
	end

	local alpha = nil

	if self.attachmentPointSegmentReversed then
		local dx = prevSegment.x2 - prevSegment.x1
		local dz = prevSegment.z2 - prevSegment.z1
		alpha = MathUtil.getYRotationFromDirection(dx, dz)
	else
		local dx = prevSegment.x1 - prevSegment.x2
		local dz = prevSegment.z1 - prevSegment.z2
		alpha = MathUtil.getYRotationFromDirection(dx, dz)
	end

	local dx = segment.x1 - segment.x2
	local dz = segment.z1 - segment.z2
	local beta = MathUtil.getYRotationFromDirection(dx, dz)
	local angle = MathUtil.getAngleDifference(alpha, beta) - math.pi
	angle = math.abs(angle)

	if math.pi < angle then
		angle = math.pi - (angle - math.pi)
	end

	return math.pi - angle
end

function ConstructionBrushFence:getPrice(length)
	local price = nil

	if self.gateIndex ~= nil then
		price = self.storeItem.price
	else
		if length == nil then
			length = self.fence:getSegmentLength(self.fence:getPreviewSegment())
		end

		price = length * self.storeItem.price
	end

	return price
end

function ConstructionBrushFence:verifyPreview()
	local pSegment = self.fence:getPreviewSegment()
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pSegment.x2, 0, pSegment.z2)
	local err = self:verifyAccess(pSegment.x2, y, pSegment.z2)

	if err ~= nil then
		return err
	end

	local canBePlaced, placingFailedMessage = self.fence:getCanBePlacedAt(pSegment.x2, 0, pSegment.z2, g_currentMission:getFarmId())

	if not canBePlaced then
		return ConstructionBrushFence.ERROR.CANNOT_BE_PLACED_HERE, placingFailedMessage
	end

	local length = self.fence:getSegmentLength(pSegment)

	if length < self.fence:getPanelLength() * ConstructionBrushFence.MINIMUM_LENGTH then
		return ConstructionBrushFence.ERROR.MININUM_LENGTH
	end

	local verticalAngle, minY, maxY = self.fence:getMaxVerticalAngleAndYForPreview()

	if self.fence:getMaxVerticalAngle() < verticalAngle or pSegment.gateIndex ~= nil and self.fence:getMaxVerticalGateAngle() < verticalAngle then
		return ConstructionBrushFence.ERROR.MAXIMUM_ANGLE
	end

	local price = self:getPrice(length)

	if g_currentMission:getMoney(self.fence:getOwnerFarmId()) < price then
		return ConstructionBrushFence.ERROR.NOT_ENOUGH_MONEY
	end

	local angle = self:getPreviewAngle()

	if self.parallelSnappingSegment == nil and angle ~= nil and self.fence:getMaxCornerAngle() < angle then
		return ConstructionBrushFence.ERROR.MINIMUM_ANGLE
	end

	local bx = pSegment.x1 / 2 + pSegment.x2 / 2
	local bz = pSegment.z1 / 2 + pSegment.z2 / 2
	local by = minY / 2 + maxY / 2
	local rx = 0
	local ry = math.atan2(pSegment.x2 - pSegment.x1, pSegment.z2 - pSegment.z1) + 0.5 * math.pi
	local rz = 0
	local ex = length * 0.5 + self.fence:getBoundingCheckWidth() * 0.5
	local ey = math.abs(minY - maxY) * 0.5 + 2
	local ez = self.fence:getBoundingCheckWidth() * 0.5
	local collisionMask = bitAND(CollisionMask.ALL, bitNOT(bitOR(bitOR(CollisionFlag.TERRAIN, CollisionMask.TRIGGERS), CollisionFlag.GROUND_TIP_BLOCKING)))
	local dynamics = true
	local statics = true
	local exact = true
	self.hitAnyObjects = false

	overlapBox(bx, by, bz, rx, ry, rz, ex, ey, ez, "boxOverlapCallback", self, collisionMask, dynamics, statics, exact)

	if self.hitAnyObjects then
		return ConstructionBrushFence.ERROR.COLLISION
	end

	return nil
end

function ConstructionBrushFence:boxOverlapCallback(hitObjectId, x, y, z, distance)
	if hitObjectId ~= 0 and hitObjectId ~= g_currentMission.terrainRootNode then
		local object = g_currentMission:getNodeObject(hitObjectId)

		if object ~= nil and object.setOverlayColor ~= nil then
			if object.findRaycastInfo ~= nil then
				local _, panelVisuals, segment, pole, poleIndex = object:findRaycastInfo(hitObjectId)

				if pole ~= nil then
					local pSegment = self.fence:getPreviewSegment()

					if object == self.fence and (MathUtil.equalEpsilon(segment.poles[poleIndex], pSegment.x1, 0.01) and MathUtil.equalEpsilon(segment.poles[poleIndex + 1], pSegment.z1, 0.01) or MathUtil.equalEpsilon(segment.poles[poleIndex], pSegment.x2, 0.01) and MathUtil.equalEpsilon(segment.poles[poleIndex + 1], pSegment.z2, 0.01) or MathUtil.equalEpsilon(segment.poles[poleIndex + 2], pSegment.x1, 0.01) and MathUtil.equalEpsilon(segment.poles[poleIndex + 3], pSegment.z1, 0.01) or MathUtil.equalEpsilon(segment.poles[poleIndex + 2], pSegment.x2, 0.01) and MathUtil.equalEpsilon(segment.poles[poleIndex + 3], pSegment.z2, 0.01)) then
						return
					end

					local function setColoredNodes(node)
						if getHasClassId(node, ClassIds.SHAPE) then
							setShaderParameter(node, "placeableColorScale", 1, 0, 0, 1, false)
							table.insert(self.needsOverlayReset, node)
						end

						for i = 0, getNumOfChildren(node) - 1 do
							setColoredNodes(getChildAt(node, i))
						end
					end

					if getNumOfChildren(pole) > 1 then
						local poleVisuals = getChildAt(pole, 1)

						setColoredNodes(poleVisuals)
					end

					if panelVisuals ~= nil then
						setColoredNodes(panelVisuals)
					end
				end
			else
				object:setOverlayColor(1, 0, 0, 1)
				table.insert(self.needsOverlayReset, object)
			end
		end

		self.hitAnyObjects = true
	end
end

function ConstructionBrushFence:update(dt)
	ConstructionBrushFence:superClass().update(self, dt)

	if self.doFindPlaceable then
		self.fence = self:findPlaceable()

		self:setInputTextDirty()

		if self.fence ~= nil then
			if self.fence:getHasParallelSnapping() then
				self.parallelSnappingEnabled = true
			end

			self.doFindPlaceable = false
		end
	end

	if self.fence == nil then
		if not self:hasPlayerPermission() then
			self.cursor:setErrorMessage(g_i18n:getText(ConstructionBrush.ERROR_MESSAGES[ConstructionBrush.ERROR.NO_PERMISSION]))
		end

		return
	end

	local x, y, z, _, _ = self:getLimitedSnappedCursorPosition()
	local err, msg = nil
	local segment = self.fence:getPreviewSegment()

	if x ~= nil and segment ~= nil then
		if segment.x2 ~= x or segment.z2 ~= z then
			segment.x2 = x
			segment.z2 = z

			self.fence:setPreviewSegment(segment)
		end

		if self.previewPole ~= nil then
			setVisibility(self.previewPole, false)
		end

		if self.previewPoleCursor then
			self.cursor:setShape(GuiTopDownCursor.SHAPES.NONE)
		end

		self:resetErrorOverlays()

		err, msg = self:verifyPreview()
	else
		if self.previewPole == nil then
			self.previewPole = self.fence:getPoleShapeForPreview()

			if self.previewPole == nil then
				self.previewPole = createTransformGroup("PreviewPole")
				self.previewPoleCursor = true
			else
				self.previewPoleCursor = false
			end

			link(getRootNode(), self.previewPole)
		end

		if self.previewPoleCursor then
			self.cursor:setShape(GuiTopDownCursor.SHAPES.CIRCLE)
			self.cursor:setShapeSize(1)
		end

		if x ~= nil then
			setWorldTranslation(self.previewPole, x, y, z)

			err = self:verifyAccess(x, y, z)
		end

		setVisibility(self.previewPole, self.cursor.isVisible)
	end

	if err ~= nil then
		self.cursor:setErrorMessage(msg or g_i18n:getText(ConstructionBrushFence.ERROR_MESSAGES[err] or ConstructionBrush.ERROR_MESSAGES[err]))
	elseif self.fence:getPreviewSegment() ~= nil then
		self.cursor:setMessage(g_i18n:formatMoney(self:getPrice(), 0, true, true))
	end
end

function ConstructionBrushFence:resetErrorOverlays()
	for i = #self.needsOverlayReset, 1, -1 do
		local item = self.needsOverlayReset[i]

		if type(item) == "number" then
			setShaderParameter(item, "placeableColorScale", 0, 0, 0, 0, false)
		else
			item:setOverlayColor(0, 0, 0, 0)
		end

		self.needsOverlayReset[i] = nil
	end
end

function ConstructionBrushFence:onButtonPrimary()
	if self.fence == nil then
		return
	end

	local x, y, z, snapped, segment = self:getLimitedSnappedCursorPosition()

	if x == nil then
		return
	end

	if self.fence:getPreviewSegment() == nil then
		local err = self:verifyAccess(x, y, z)

		if err == nil then
			local previewSegment = self.fence:createSegment(x, z, x, z, not snapped or segment == nil, self.gateIndex)

			if snapped and segment ~= nil then
				self.attachmentPointSegment = segment

				if segment ~= nil then
					self.attachmentPointSegmentReversed = MathUtil.equalEpsilon(segment.x1, x, 0.01) and MathUtil.equalEpsilon(segment.z1, z, 0.01)
				end
			end

			self.fence:setPreviewSegment(previewSegment)
		end
	else
		local err = self:verifyPreview()

		if err == nil then
			local pSegment = self.fence:getPreviewSegment()
			local price = self:getPrice()
			local event = PlaceableFenceAddSegmentEvent.new(self.fence, pSegment.x1, pSegment.z1, x, z, pSegment.renderFirst, not snapped or segment == nil, pSegment.gateIndex, price)

			g_client:getServerConnection():sendEvent(event)

			if self.fence.playPlaceSound ~= nil then
				self.fence:playPlaceSound()
			end

			if self.parallelSnappingEnabled then
				self.fence:setPreviewSegment(nil)

				self.attachmentPointSegment = nil
				self.attachmentPointSegmentReversed = nil

				self:resetErrorOverlays()
			else
				pSegment.x1 = x
				pSegment.z1 = z
				pSegment.renderFirst = false
				pSegment.renderLast = true

				self.fence:setPreviewSegment(pSegment)

				self.parallelSnappingSegment = nil
			end
		end
	end
end

function ConstructionBrushFence:onFenceSegmentCreated(fence, segment)
	if self.fence == fence then
		self.attachmentPointSegment = segment
		self.attachmentPointSegmentReversed = false
	end
end

function ConstructionBrushFence:onButtonSecondary()
	if self.fence == nil then
		return
	end

	if self.fence:getPreviewSegment() ~= nil then
		self.fence:setPreviewSegment(nil)

		self.attachmentPointSegment = nil
		self.attachmentPointSegmentReversed = nil

		self:resetErrorOverlays()
	end
end

function ConstructionBrushFence:onButtonTertiary()
	if self.fence:getSupportsParallelSnapping() and self.fence:getMaxCornerAngle() > 0 then
		self.parallelSnappingEnabled = not self.parallelSnappingEnabled

		self:setInputTextDirty()
	end
end

function ConstructionBrushFence:onButtonSnapping()
	self.snappingActive = not self.snappingActive
	ConstructionBrushFence.LAST_SNAPPING_STATE = self.snappingActive

	self:setInputTextDirty()
end

function ConstructionBrushFence:cancel()
	self:onButtonSecondary()
end

function ConstructionBrushFence:getButtonPrimaryText()
	return "$l10n_input_CONSTRUCTION_PLACE_POLE"
end

function ConstructionBrushFence:getButtonSecondaryText()
	return "$l10n_input_CONSTRUCTION_FINISH"
end

function ConstructionBrushFence:getButtonTertiaryText()
	if self.fence ~= nil and self.fence:getSupportsParallelSnapping() and self.fence:getMaxCornerAngle() > 0 then
		return string.format(g_i18n:getText("input_CONSTRUCTION_SNAP"), g_i18n:getText(self.parallelSnappingEnabled and "ui_on" or "ui_off"))
	else
		return nil
	end
end

function ConstructionBrushFence:getButtonSnappingText()
	return string.format("%s (%s)", g_i18n:getText("input_CONSTRUCTION_ACTION_SNAPPING"), g_i18n:getText(self.snappingActive and "ui_on" or "ui_off"))
end
