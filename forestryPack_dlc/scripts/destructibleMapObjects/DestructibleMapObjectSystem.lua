local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

DestructibleMapObjectSystem = {
	GROUP_ID_NUM_BITS = 8
}
DestructibleMapObjectSystem.MAX_GORUP_ID = 2^DestructibleMapObjectSystem.GROUP_ID_NUM_BITS - 1
DestructibleMapObjectSystem.CHILD_INDEX_NUM_BITS = 9
DestructibleMapObjectSystem.MAX_CHILD_INDEX = 2^DestructibleMapObjectSystem.CHILD_INDEX_NUM_BITS - 1
DestructibleMapObjectSystem.ERROR_WRONG_DESTRUCTIBLE_TYPE = 0
local DestructibleMapObjectSystem_mt = Class(DestructibleMapObjectSystem)

g_xmlManager:addCreateSchemaFunction(function ()
	DestructibleMapObjectSystem.xmlSchemaSavegame = XMLSchema.new("destructibleMapObjects_savegame")
end)
g_xmlManager:addInitSchemaFunction(function ()
	local schema = DestructibleMapObjectSystem.xmlSchemaSavegame

	schema:register(XMLValueType.INT, "destructibleMapObjects.group(?)#id", "Group id defined as user attribute in map")
	schema:register(XMLValueType.INT, "destructibleMapObjects.group(?).item(?)#index", "I3d child index of destroyed object in group")
end)

function DestructibleMapObjectSystem.onCreateGroup(node)
	g_currentMission.destructibleMapObjectSystem:addGroup(node)
end

g_onCreateUtil.addOnCreateFunction("onCreateDestructibleObjectsGroup", DestructibleMapObjectSystem.onCreateGroup)

function DestructibleMapObjectSystem.new(mission, isServer, customMt)
	local self = setmetatable({}, customMt or DestructibleMapObjectSystem_mt)
	self.mission = mission
	self.isServer = isServer
	self.groups = {}
	self.groupIdToGroupRoot = {}
	self.destructibleTypes = {}
	self.nodeToDestructible = {}
	self.destructibleToGroup = {}
	self.destructibleDamage = {}
	self.destructibleToRigidBodies = {}
	self.destructibleDestroyedListeners = {}
	self.activeDestructionAnimations = {}
	self.activeDestructionAnimationsToDelete = {}

	addConsoleCommand("gsDestructibleObjectsDebug", "Toggle DestructibleMapObjectSystem debug", "consoleCommandToggleDebug", self)

	if self.isServer then
		addConsoleCommand("gsDestructibleObjectsDamageAdd", "Add damage to destructible object camera is pointed at", "consoleCommandNodeAddDamage", self)
	end

	return self
end

function DestructibleMapObjectSystem:delete()
	g_currentMission:removeUpdateable(self)
	removeConsoleCommand("gsDestructibleObjectsDebug")
	removeConsoleCommand("gsDestructibleObjectsDestroy")
end

function DestructibleMapObjectSystem:onClientJoined(connection)
	for groupRoot, group in pairs(self.groups) do
		local childIndices = {}
		local numChildren = getNumOfChildren(groupRoot)

		for childIndex = 0, numChildren - 1 do
			childIndices[childIndex + 1] = not getVisibility(getChildAt(groupRoot, childIndex))
		end

		connection:sendEvent(DestroyedMapObjectsEvent.new(group.groupId, childIndices))
	end
end

function DestructibleMapObjectSystem:addGroup(groupRootNode)
	local function printUserAttributeInterface()
		print("Supported userAttributes next to DestructibleMapObjectSystem.onCreate")
		printf("    'destructibleType'           (string)  (required) - string used to differentiate between different types of objects, e.g. used for which tools can work on them")
		printf("    'groupId'                    (integer) (required if more than one group exists) default: 0; allowed values: 0 - %d)", DestructibleMapObjectSystem.MAX_GORUP_ID)
		printf("    'dropFillTypeName'           (string)  (optional) default: nil - fillTypeName of tipAny dropped upon destruction")
		printf("    'dropAmount'                 (float)   (optional) default: 500 - amount of tipAny dropped upon destruction")
		printf("    'destructionVolume'          (float)   (optional) default: 50 - destruction amount trequired to destroy the object")
		printf("    'animDurationScrollPosition' (float)   (optional) default: 2 - duration for destruction animation shader parameter scrollPosition in seconds")
		printf("    'animDurationHideByIndex'    (float)   (optional) default: 1 - duration for destruction animation shader parameter hideByIndex in seconds")
		printf("    'animDelayHideByIndex'       (float)   (optional) default: 0.75 * animDurationScrollPosition - delay for start of hideByIndex animation in seconds")
	end

	local destructibleType = getUserAttribute(groupRootNode, "destructibleType")

	if destructibleType == nil then
		Logging.error("Missing userAttribute 'destructibleType' for '%s'", I3DUtil.getNodePath(groupRootNode))
		printUserAttributeInterface()

		return false
	end

	local groupId = math.floor(tonumber(getUserAttribute(groupRootNode, "groupId")) or 0)

	if groupId < 0 or DestructibleMapObjectSystem.MAX_GORUP_ID < groupId then
		Logging.error("GroupId '%d' for %s out of allowed rage [0 %d]", groupId, I3DUtil.getNodePath(groupRootNode), DestructibleMapObjectSystem.MAX_GORUP_ID)

		return false
	end

	if self.groupIdToGroupRoot[groupId] ~= nil then
		Logging.error("GroupId '%d' of '%s' already in use in '%s'. Please use a different groupId", groupId, I3DUtil.getNodePath(groupRootNode), I3DUtil.getNodePath(self.groupIdToGroupRoot[groupId]))
		printUserAttributeInterface()

		return false
	end

	local dropFillTypeName = getUserAttribute(groupRootNode, "dropFillTypeName") or destructibleType
	local dropFillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(dropFillTypeName)
	local dropAmount = getUserAttribute(groupRootNode, "dropAmount") or 500
	local destructionVolume = getUserAttribute(groupRootNode, "destructionVolume") or 50
	local animDurationScrollPositionSec = getUserAttribute(groupRootNode, "animDurationScrollPosition") or 2
	local animDurationHideByIndexSec = getUserAttribute(groupRootNode, "animDurationHideByIndex") or 2
	local animDelayHideByIndexSec = getUserAttribute(groupRootNode, "animDelayHideByIndex") or 0.75 * animDurationScrollPositionSec
	local group = {
		destructibleType = string.upper(destructibleType),
		groupId = groupId,
		dropFillTypeIndex = dropFillTypeIndex,
		dropAmount = dropAmount,
		destructionVolume = destructionVolume,
		animDurationScrollPosition = animDurationScrollPositionSec * 1000,
		animDurationHideByIndex = animDurationHideByIndexSec * 1000,
		animDelayHideByIndex = animDelayHideByIndexSec * 1000
	}
	self.groupIdToGroupRoot[groupId] = groupRootNode
	self.groups[groupRootNode] = group

	if self.destructibleTypes[destructibleType] == nil then
		self.destructibleTypes[destructibleType] = {}
	end

	self.destructibleTypes[destructibleType][group] = true
	local numChildren = getNumOfChildren(groupRootNode)

	if DestructibleMapObjectSystem.MAX_CHILD_INDEX < numChildren then
		Logging.warning("Only %d child nodes supported per group, group has %d. Ignoring additional children for '%s'", DestructibleMapObjectSystem.MAX_CHILD_INDEX + 1, numChildren, I3DUtil.getNodePath(groupRootNode))

		numChildren = DestructibleMapObjectSystem.MAX_CHILD_INDEX
	end

	local function addRigidBodyToMapping(childNode, node)
		self.nodeToDestructible[node] = childNode
		self.destructibleToGroup[childNode] = group
		self.destructibleToRigidBodies[childNode] = self.destructibleToRigidBodies[childNode] or {}

		table.insert(self.destructibleToRigidBodies[childNode], node)
	end

	for childIndex = 0, numChildren - 1 do
		local childNode = getChildAt(groupRootNode, childIndex)
		local hasCol = false

		local function checkRigidBody(node)
			if getRigidBodyType(node) ~= RigidBodyType.NONE then
				addRigidBodyToMapping(childNode, node)

				hasCol = true
			end
		end

		checkRigidBody(childNode)
		I3DUtil.interateRecursively(childNode, checkRigidBody)

		if not hasCol then
			Logging.warning("Child %d (%s) of group '%s' has no collision mesh in any of its children and will not be destroyable ingame", childIndex, getName(childNode), I3DUtil.getNodePath(groupRootNode))
		end
	end

	return true
end

function DestructibleMapObjectSystem:registerDestructibleDestroyedListener(target, func)
	self.destructibleDestroyedListeners[target] = func
end

function DestructibleMapObjectSystem:unregisterDestructibleDestroyedListener(target)
	self.destructibleDestroyedListeners[target] = nil
end

function DestructibleMapObjectSystem:getDestructibleFromNode(nodeId, destructibleTypes)
	local destructible = self.nodeToDestructible[nodeId]

	if destructible and destructibleTypes ~= nil then
		local group = self.destructibleToGroup[destructible]

		if group ~= nil and destructibleTypes[group.destructibleType] then
			return destructible
		else
			return nil, DestructibleMapObjectSystem.ERROR_WRONG_DESTRUCTIBLE_TYPE
		end
	end

	return destructible
end

function DestructibleMapObjectSystem:getGroupAndIndexForDestructible(destructible)
	return self.destructibleToGroup[destructible], getChildIndex(destructible)
end

function DestructibleMapObjectSystem:getGroupRootById(groupId)
	return self.groupIdToGroupRoot[groupId]
end

function DestructibleMapObjectSystem:getDestructibleRigidBodies(destructible)
	return self.destructibleToRigidBodies[destructible]
end

function DestructibleMapObjectSystem:addDestructibleDamage(destructible, damage)
	local group = self.destructibleToGroup[destructible]

	if group ~= nil then
		local totalDamage = math.max(0, (self.destructibleDamage[destructible] or 0) + damage)
		local relativeProgress = totalDamage / group.destructionVolume

		if group.destructionVolume <= totalDamage then
			if self.isServer then
				self:destroyDestructible(destructible, true)

				return 1, group.destructionVolume
			end
		else
			self.destructibleDamage[destructible] = totalDamage
		end

		return relativeProgress, totalDamage
	end

	return nil
end

function DestructibleMapObjectSystem:disableDestructiblePhysics(destructible)
	local lx, ly, lz, bvRadius, wx, wz, minX, maxX, minZ, maxZ = nil
	local rigidBodies = self.destructibleToRigidBodies[destructible]

	if rigidBodies ~= nil then
		for _, rigidBody in ipairs(rigidBodies) do
			setRigidBodyType(rigidBody, RigidBodyType.NONE)

			lx, ly, lz, bvRadius = getShapeBoundingSphere(rigidBody)
			wx, _, wz = localToWorld(rigidBody, lx, ly, lz)
			minX = wx - bvRadius
			maxX = wx + bvRadius
			minZ = wz - bvRadius
			maxZ = wz + bvRadius

			g_densityMapHeightManager:setCollisionMapAreaDirty(minX, minZ, maxX, maxZ, true)
			self.mission.aiSystem:setAreaDirty(minX, maxX, minZ, maxZ)
		end
	end

	return bvRadius
end

function DestructibleMapObjectSystem:destroyDestructible(destructible, dropTipAny)
	local bvRadius = self:disableDestructiblePhysics(destructible)

	if dropTipAny then
		local group = self.destructibleToGroup[destructible]

		if group.dropFillTypeIndex ~= nil and group.dropAmount > 0 then
			wx, wy, wz = getWorldTranslation(destructible)
			local halfWidth = bvRadius / 2
			local startX = wx - halfWidth
			local startY = wy
			local startZ = wz - halfWidth
			local endX = wx - halfWidth
			local endY = wy
			local endZ = wz + halfWidth
			local heightX = wx + halfWidth
			local heightY = wy
			local heightZ = wz - halfWidth
			local lsx, lsy, lsz, lex, ley, lez, radius = DensityMapHeightUtil.getLineByAreaDimensions(startX, startY, startZ, endX, endY, endZ, heightX, heightY, heightZ, false)

			DensityMapHeightUtil.tipToGroundAroundLine(nil, group.dropAmount, group.dropFillTypeIndex, lsx, lsy, lsz, lex, ley, lez, radius, nil, , , )
		end
	end

	if g_server ~= nil then
		local group = self.destructibleToGroup[destructible]

		if group ~= nil then
			local childIndex = getChildIndex(destructible)

			g_server:broadcastEvent(MapObjectDestroyedEvent.new(group.groupId, childIndex))
		end
	end

	for target, func in pairs(self.destructibleDestroyedListeners) do
		func(target, destructible)
	end

	if I3DUtil.getHasShaderParameterRec(destructible, "hideByIndex") or I3DUtil.getHasShaderParameterRec(destructible, "scrollPosition") then
		if self.activeDestructionAnimations[destructible] == nil then
			self.activeDestructionAnimations[destructible] = 0

			g_currentMission:addUpdateable(self)
		end
	else
		self:setDestructibleDestroyed(destructible, false)
	end
end

function DestructibleMapObjectSystem:setDestructibleDestroyed(destructible, updatePhysics)
	if updatePhysics then
		self:disableDestructiblePhysics(destructible)
	end

	setVisibility(destructible, false)

	self.destructibleDamage[destructible] = nil
end

function DestructibleMapObjectSystem:setGroupChildIndexDestroyed(groupId, childIndex, dropTipAny, playAnimation)
	local groupRoot = self.groupIdToGroupRoot[groupId]

	if groupRoot == nil then
		Logging.error("DestructibleMapObjectSystem: Unable to get groupRoot for group id '%s'", groupId)
	end

	self:setChildIndexDestroyed(groupRoot, childIndex, dropTipAny, playAnimation)
end

function DestructibleMapObjectSystem:setChildIndexDestroyed(groupRoot, childIndex, dropTipAny, playAnimation)
	if getNumOfChildren(groupRoot) < childIndex then
		local group = self.groups[groupRoot]

		Logging.warning("DestructibleMapObjectSystem: Unable to set state on child index %d, group %d at '%s' only has %d children", childIndex, group.groupId, I3DUtil.getNodePath(groupRoot), getNumOfChildren(groupRoot))

		return
	end

	local destructible = getChildAt(groupRoot, childIndex)

	if playAnimation then
		self:destroyDestructible(destructible, dropTipAny)
	else
		self:setDestructibleDestroyed(destructible, true)
	end
end

function DestructibleMapObjectSystem:getDestructedChildIndices(groupRoot)
	local destructedChildIndices = {}
	local numChildren = getNumOfChildren(groupRoot)

	for childIndex = 0, numChildren - 1 do
		if not getVisibility(getChildAt(groupRoot, childIndex)) then
			table.insert(destructedChildIndices, childIndex)
		end
	end

	return destructedChildIndices
end

function DestructibleMapObjectSystem:saveToXMLFile(xmlPath, usedModNames)
	if xmlPath ~= nil and next(self.groups) ~= nil then
		local xmlFile = XMLFile.create("DestructibleMapObjectSystemXML", xmlPath, "destructibleMapObjects", DestructibleMapObjectSystem.xmlSchemaSavegame)
		local numItems = 0

		xmlFile:setTable("destructibleMapObjects.group", self.groups, function (groupKey, group, groupRoot)
			local destructedChildIndices = self:getDestructedChildIndices(groupRoot)

			if #destructedChildIndices == 0 then
				return 0
			end

			numItems = numItems + #destructedChildIndices

			xmlFile:setValue(groupKey .. "#id", group.groupId)
			xmlFile:setTable(groupKey .. ".item", destructedChildIndices, function (path, childIndex, key)
				xmlFile:setValue(path .. "#index", childIndex)
			end)
		end)
		xmlFile:save()
		xmlFile:delete()
	end
end

function DestructibleMapObjectSystem:loadFromXMLFile(xmlPath)
	if xmlPath ~= nil and next(self.groups) ~= nil then
		local xmlFile = XMLFile.loadIfExists("DestructibleMapObjectSystemXML", xmlPath, DestructibleMapObjectSystem.xmlSchemaSavegame)

		if xmlFile ~= nil then
			local loadedGroups = 0
			local loadedChildren = 0

			xmlFile:iterate("destructibleMapObjects.group", function (groupIndex, groupKey)
				local groupId = xmlFile:getValue(groupKey .. "#id")

				if groupId == nil then
					Logging.xmlWarning(xmlFile, "Group %s is missing an 'id' attribute", groupKey)

					return true
				end

				local groupRoot = self.groupIdToGroupRoot[groupId]

				if groupRoot == nil then
					Logging.xmlWarning(xmlFile, "Group with id '%s' (%s) does not exist in map", groupId, groupKey)

					return true
				end

				loadedGroups = loadedGroups + 1

				xmlFile:iterate(groupKey .. ".item", function (itemIndex, itemKey)
					local childIndex = xmlFile:getValue(itemKey .. "#index")
					loadedChildren = loadedChildren + 1

					self:setChildIndexDestroyed(groupRoot, childIndex, false)
				end)

				return true
			end)
			xmlFile:delete()
		else
			Logging.devInfo("DestructibleMapObjectSystem: no xml to load from savegame")
		end
	end
end

function DestructibleMapObjectSystem:update(dt)
	for destructible, animationTime in pairs(self.activeDestructionAnimations) do
		animationTime = animationTime + dt
		self.activeDestructionAnimations[destructible] = animationTime
		local group = self.destructibleToGroup[destructible]

		if animationTime < group.animDurationScrollPosition then
			local shaderValue = animationTime / group.animDurationScrollPosition

			I3DUtil.setShaderParameterRec(destructible, "scrollPosition", shaderValue, nil, , )

			shaderValue = (animationTime - dt) / group.animDurationScrollPosition

			I3DUtil.setShaderParameterRec(destructible, "prevScrollPosition", shaderValue, nil, , )
		end

		if group.animDelayHideByIndex < animationTime and animationTime < group.animDelayHideByIndex + group.animDurationHideByIndex then
			local shaderValue = (animationTime - group.animDelayHideByIndex) / group.animDurationHideByIndex

			I3DUtil.setShaderParameterRec(destructible, "hideByIndex", shaderValue, nil, , )
		end

		if animationTime > group.animDelayHideByIndex + group.animDurationHideByIndex then
			self:setDestructibleDestroyed(destructible, false)
			table.insert(self.activeDestructionAnimationsToDelete, destructible)
		end
	end

	for i = #self.activeDestructionAnimationsToDelete, 1, -1 do
		local destructible = self.activeDestructionAnimationsToDelete[i]
		self.activeDestructionAnimations[destructible] = nil

		table.remove(self.activeDestructionAnimationsToDelete, i)
	end

	if next(self.activeDestructionAnimations) == nil then
		g_currentMission:removeUpdateable(self)
	end
end

function DestructibleMapObjectSystem:consoleCommandNodeAddDamage(damageAmount, destructibleType)
	damageAmount = tonumber(damageAmount) or 5
	destructibleType = destructibleType and string.upper(destructibleType)
	local cam = getCamera(0)
	local wx, wy, wz = getWorldTranslation(cam)
	local dx, dy, dz = localDirectionToWorld(cam, 0, 0, -1)
	wz = wz + dz
	wy = wy + dy
	wx = wx + dx
	local distance = 30

	raycastClosest(wx, wy, wz, dx, dy, dz, "consoleCommandNodeAddDamageRaycastCallback", distance, self, CollisionMask.ALL - CollisionFlag.PLAYER)

	local callbackNode = self.callbackNode
	self.callbackNode = nil
	local destructible = self.nodeToDestructible[callbackNode]

	if destructible then
		if destructibleType ~= nil then
			local destructibleTypeGroups = self.destructibleTypes[destructibleType]

			if not destructibleTypeGroups or not destructibleTypeGroups[self.destructibleToGroup[destructible]] then
				return string.format("No destructible found for given destructible type '%s'", destructibleType)
			end
		end

		local destuctionPercentage, totalDamange = self:addDestructibleDamage(destructible, damageAmount, true)
		local group = self.destructibleToGroup[destructible]

		if destuctionPercentage >= 1 then
			return string.format("Destroyed destructible %d (Type:%s) of group %d", getChildIndex(destructible), group.destructibleType, group.groupId)
		else
			return string.format("Added %d damage (%d%%, %d total) to destructible %d (Type:%s) of group %d", damageAmount, destuctionPercentage * 100, totalDamange, getChildIndex(destructible), group.destructibleType, group.groupId)
		end
	else
		return "No destructible found"
	end
end

function DestructibleMapObjectSystem:consoleCommandNodeAddDamageRaycastCallback(transformId, x, y, z, distance, nx, ny, nz)
	if getName(transformId) == "playerCCT" then
		return true
	end

	self.callbackNode = transformId

	return false
end

function DestructibleMapObjectSystem:consoleCommandToggleDebug()
	if not self.mission:getHasDrawable(self) then
		self.mission:addDrawable(self)

		for groupRootNode, group in pairs(self.groups) do
			local color = DebugUtil.tableToColor(group)
			local numChildren = getNumOfChildren(groupRootNode)

			for childIndex = 0, numChildren - 1 do
				local destructibleNode = getChildAt(groupRootNode, childIndex)

				if getVisibility(destructibleNode) then
					local text = string.format("%s #%d\ndestuction volume %d\ndrop amount %d", getName(groupRootNode), childIndex, group.destructionVolume, group.dropAmount)
					local note = createNoteNode(destructibleNode, text, color[1], color[2], color[3])

					setName(note, "destructibleDebugNote")
					setTranslation(note, 0, 2.5, 0)
				end
			end
		end

		if g_isDevelopmentVersion then
			executeConsoleCommand("enableNoteRendering true")
		end

		return "DestructibleMapObjectSystem: Enabled debug"
	else
		self.mission:removeDrawable(self)

		for groupRootNode, group in pairs(self.groups) do
			local numChildren = getNumOfChildren(groupRootNode)

			for childIndex = 0, numChildren - 1 do
				local destructibleNode = getChildAt(groupRootNode, childIndex)
				local note = getChild(destructibleNode, "destructibleDebugNote")

				if note ~= 0 then
					delete(note)
				end
			end
		end

		return "DestructibleMapObjectSystem: Disabled debug"
	end
end

function DestructibleMapObjectSystem:draw()
	setTextBold(false)

	local textSize = 0.015
	local startY = 0.97
	local i = 1

	if next(self.groups) then
		renderText(0.28, startY, textSize, string.format("%d Groups - Total num destructibles: %s", table.size(self.groups), table.size(self.nodeToDestructible)))

		for groupRootNode, group in pairs(self.groups) do
			local destructedChildIndices = self:getDestructedChildIndices(groupRootNode)

			renderText(0.3, startY - i * textSize, textSize, string.format("%s (%s) (%s) - %d destructibles - %d destroyed", getName(groupRootNode), groupRootNode, group.destructibleType, getNumOfChildren(groupRootNode), #destructedChildIndices))

			for childNumber, childIndex in ipairs(destructedChildIndices) do
				i = i + 1

				renderText(0.32, startY - i * textSize, textSize, string.format("#%d - node child index: %d", childNumber, childIndex))
			end

			i = i + 1
		end
	else
		renderText(0.32, startY - i * textSize, textSize, string.format("no destructibles defined in map"))

		return
	end

	i = i + 1

	if next(self.destructibleTypes) then
		renderText(0.28, startY - i * textSize, textSize, "Destructible Types")

		i = i + 1

		for typeName, groups in pairs(self.destructibleTypes) do
			renderText(0.3, startY - i * textSize, textSize, string.format("%s - num groups: %d", typeName, table.size(groups)))

			i = i + 1
		end
	end

	i = i + 1

	if next(self.destructibleDamage) then
		renderText(0.28, startY - i * textSize, textSize, "Destructible Damage")

		i = i + 1

		for destructible, damage in pairs(self.destructibleDamage) do
			renderText(0.3, startY - i * textSize, textSize, string.format("%s: %d", getName(destructible), damage))

			i = i + 1
		end
	end

	if g_currentMission:getHasUpdateable(self) then
		setTextColor(1, 0, 0, 1)
		renderText(0.5, 0.2, 0.02, "update/animation active")
		setTextColor(1, 1, 1, 1)
	end
end
