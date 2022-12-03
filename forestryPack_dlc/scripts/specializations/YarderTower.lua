local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

YarderTower = {
	MOD_NAME = g_currentModName,
	MOD_DIRECTORY = g_currentModDirectory,
	SPEC_NAME = g_currentModName .. ".yarderTower",
	TREE_RAYCAST_DISTANCE = 40,
	TERRAIN_RAYCAST_DISTANCE = 20,
	MAX_CONTROL_DISTANCE = 15,
	DAMAGED_SPEED_REDUCTION = 0.3,
	FOLLOW_MODE_NONE = 0,
	FOLLOW_MODE_ME = 1,
	FOLLOW_MODE_HOME = 2,
	FOLLOW_MODE_PICKUP = 3,
	FAILED_REASON_NONE = 0,
	FAILED_REASON_TOO_LONG = 1,
	FAILED_REASON_WRONG_ANGLE = 2,
	FAILED_REASON_TREE_TOO_SMALL = 3,
	FAILED_REASON_WAY_BLOCKED = 4,
	FAILED_REASON_ONLY_UPHILL_YARDING = 5
}

source(g_currentModDirectory .. "scripts/specializations/activatables/YarderTowerSetupActivatable.lua")
source(g_currentModDirectory .. "scripts/specializations/activatables/YarderTowerControlActivatable.lua")
source(g_currentModDirectory .. "scripts/specializations/events/YarderTowerFollowModeEvent.lua")
source(g_currentModDirectory .. "scripts/specializations/events/YarderTowerSetTargetEvent.lua")
source(g_currentModDirectory .. "scripts/hud/YarderTowerHUDExtension.lua")
VehicleHUDExtension.registerHUDExtension(YarderTower, YarderTowerHUDExtension)

function YarderTower.prerequisitesPresent(specializations)
	return true
end

function YarderTower.initSpecialization()
	g_storeManager:addSpecType("yarderMaxLength", "shopListAttributeIconWinchMaxLength", YarderTower.loadSpecValueMaxLength, YarderTower.getSpecValueMaxLength, "vehicle")
	g_storeManager:addSpecType("yarderMaxMass", "shopListAttributeIconWinchMaxMass", YarderTower.loadSpecValueMaxMass, YarderTower.getSpecValueMaxMass, "vehicle")

	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("YarderTower")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.yarderTower#controlTrigger", "Trigger for player to control the tower")
	schema:register(XMLValueType.BOOL, "vehicle.yarderTower#requiresAttacherVehicle", "Attacher vehicle is not allowed to be detached", false)
	schema:register(XMLValueType.BOOL, "vehicle.yarderTower#requiresLowering", "Yarder can only be set up while lowered", false)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower#foldMinLimit", "Yarder can only be set up while fold time in between these limits", 0)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower#foldMaxLimit", "Yarder can only be set up while fold time in between these limits", 1)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.placement#height", "Default height used on the trees", 10)
	schema:register(XMLValueType.STRING, "vehicle.yarderTower.placement#minHeightOffset", "Min. height offset from main rope start to position on the tree ('-' for no limit)", "-1")
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.carriage#maxSpeed", "Max. speed of carriage in kph", 20)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.carriage#acceleration", "Acceleration speed", 0.01)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.carriage#deceleration", "Deceleration speed", 0.05)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.carriage#startOffset", "Min. offset from tower to the carriage in meter", 1)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.carriage#endOffset", "Min. offset from tree to the carriage in meter", 1)
	schema:register(XMLValueType.STRING, "vehicle.yarderTower.carriage#filename", "Path to vehicle xml of carriage vehicle")
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.carriage#maxTreeMass", "Max. tree mass that can be attached (used for store spec data)")
	ForestryHook.registerXMLPaths(schema, "vehicle.yarderTower.hooks.tree")
	ForestryHook.registerXMLPaths(schema, "vehicle.yarderTower.hooks.ground")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.yarderTower.ropes.setupRope#node", "Setup rope start node")
	schema:register(XMLValueType.COLOR, "vehicle.yarderTower.ropes.setupRope#colorInvalid", "Emissive color of rope while placement is invalid")
	schema:register(XMLValueType.COLOR, "vehicle.yarderTower.ropes.setupRope#colorValid", "Emissive color of rope while placement is valid")
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.ropes.setupRope#diameterTree", "Rope diameter while on a tree", 0.015)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.ropes.setupRope#diameterPlayer", "Rope diameter while in players hand", 0.015)
	YarderTower.registerRopeXMLPaths(schema, "vehicle.yarderTower.ropes.setupRope")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.yarderTower.ropes.mainRope#node", "Main rope start node")
	schema:register(XMLValueType.ANGLE, "vehicle.yarderTower.ropes.mainRope#maxAngle", "Max angle to the target", 80)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.ropes.mainRope#maxLength", "Max distance to the target", 100)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.ropes.mainRope#clearance", "Min. clearance below the rope", 2)
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.ropes.mainRope#minTreeDiameter", "Min. diameter of target tree", 0.2)
	YarderTower.registerRopeXMLPaths(schema, "vehicle.yarderTower.ropes.mainRope")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.yarderTower.ropes.pullRope#node", "Pull rope start node")
	YarderTower.registerRopeXMLPaths(schema, "vehicle.yarderTower.ropes.pullRope")
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.ropes.pushRope#yOffset", "Y Offset from main anchor point", 1.5)
	YarderTower.registerRopeXMLPaths(schema, "vehicle.yarderTower.ropes.pushRope")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.yarderTower.ropes.supportRopes#centerNode", "Center of search radius")
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.ropes.supportRopes#treeRadius", "Radius to search mounting trees", 25)
	schema:register(XMLValueType.NODE_INDEX, "vehicle.yarderTower.ropes.supportRopes.supportRope(?)#node", "Support node which is automatically connected")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.yarderTower.ropes.supportRopes.supportRope(?)#raycastNode", "Dedicated node only used for ground detection raycast", "#node")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.yarderTower.ropes.supportRopes.supportRope(?)#angleReferenceNode", "Node used for angle calculations to validate the mounting point")
	schema:register(XMLValueType.ANGLE, "vehicle.yarderTower.ropes.supportRopes.supportRope(?)#maxAngle", "Max. angle to tree", 15)
	schema:register(XMLValueType.ANGLE, "vehicle.yarderTower.ropes.supportRopes.supportRope(?)#raycastRotY", "Y rotation of rotNode while searching for ground mounting point via raycast")
	schema:register(XMLValueType.FLOAT, "vehicle.yarderTower.ropes.supportRopes.supportRope(?)#treeYOffset", "Y translation offset from tree root", 1)
	YarderTower.registerRopeXMLPaths(schema, "vehicle.yarderTower.ropes.supportRopes.supportRope(?)")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "setupRopeIncrease")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "setupRopeDecrease")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "setupRopeValidTarget")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "setupStarted")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "setupFinished")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "setupCanceled")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "ropeLinkTree")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "ropeLinkGround")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "removeYarder")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "carriageMovePos")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "carriageMoveNeg")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "carriageMovePosLimit")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "carriageMoveNegLimit")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "carriageDriveMovePos")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "carriageDriveMoveNeg")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "carriageDriveMovePosLimit")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "carriageDriveMoveNegLimit")
	SoundManager.registerSampleXMLPaths(schema, "vehicle.yarderTower.sounds", "motor")
	EffectManager.registerEffectXMLPaths(schema, "vehicle.yarderTower.motorEffects")
	schema:setXMLSpecializationType()

	local schemaSavegame = Vehicle.xmlSchemaSavegame
	local key = "vehicles.vehicle(?)." .. YarderTower.SPEC_NAME

	schemaSavegame:register(XMLValueType.BOOL, key .. "#isActive", "Main rope is active")
	schemaSavegame:register(XMLValueType.FLOAT, key .. "#position", "Current carriage position")
	schemaSavegame:register(XMLValueType.FLOAT, key .. ".target#x", "Target x position")
	schemaSavegame:register(XMLValueType.FLOAT, key .. ".target#y", "Target y position")
	schemaSavegame:register(XMLValueType.FLOAT, key .. ".target#z", "Target z position")
	YarderCarriage.registerSavegameXMLPaths(schemaSavegame, key)
end

function YarderTower.registerRopeXMLPaths(schema, baseKey)
	schema:register(XMLValueType.FLOAT, baseKey .. "#maxOffset", "Max y offset from direct line in the center of the rope", 0.1)
	schema:register(XMLValueType.FLOAT, baseKey .. "#offsetReferenceLength", "Y offset is interpolated up to this distance of rope length", 5)
	schema:register(XMLValueType.STRING, baseKey .. "#filename", "Path to rope i3d file")
	schema:register(XMLValueType.STRING, baseKey .. "#ropeNode", "Index path to rope to load", "0|0")
	schema:register(XMLValueType.FLOAT, baseKey .. "#diameter", "Rope diameter", 0.015)
	schema:register(XMLValueType.NODE_INDEX, baseKey .. "#rotNode", "Rotation node which is aligned in the rope direction")
	schema:register(XMLValueType.BOOL, baseKey .. "#rotNodeAllAxis", "Adjust all axis of the rotation node - otherwise only rotated about the Y axis", false)
	schema:register(XMLValueType.NODE_INDEX, baseKey .. ".ropeLengthNode(?)#node", "Node that is changing depending on the rope length")
	schema:register(XMLValueType.FLOAT, baseKey .. ".ropeLengthNode(?)#minLength", "Min. length for reference", 0)
	schema:register(XMLValueType.FLOAT, baseKey .. ".ropeLengthNode(?)#maxLength", "Max. length for reference", 10)
	schema:register(XMLValueType.VECTOR_ROT, baseKey .. ".ropeLengthNode(?)#minRot", "Rotation to apply at min. length")
	schema:register(XMLValueType.VECTOR_ROT, baseKey .. ".ropeLengthNode(?)#maxRot", "Rotation to apply at max. length")
	schema:register(XMLValueType.VECTOR_TRANS, baseKey .. ".ropeLengthNode(?)#minTrans", "Translation to apply at min. length")
	schema:register(XMLValueType.VECTOR_TRANS, baseKey .. ".ropeLengthNode(?)#maxTrans", "Translation to apply at max. length")
	schema:register(XMLValueType.VECTOR_SCALE, baseKey .. ".ropeLengthNode(?)#minScale", "Scale to apply at min. length")
	schema:register(XMLValueType.VECTOR_SCALE, baseKey .. ".ropeLengthNode(?)#maxScale", "Scale to apply at max. length")
	schema:register(XMLValueType.STRING, baseKey .. ".ropeLengthNode(?)#shaderParameterName", "Shader parameter to adjust")
	schema:register(XMLValueType.VECTOR_4, baseKey .. ".ropeLengthNode(?)#minShaderParameter", "Shader parameter to apply at min. length")
	schema:register(XMLValueType.VECTOR_4, baseKey .. ".ropeLengthNode(?)#maxShaderParameter", "Shader parameter to apply at max. length")
	ObjectChangeUtil.registerObjectChangeXMLPaths(schema, baseKey)
end

function YarderTower.registerEvents(vehicleType)
	SpecializationUtil.registerEvent(vehicleType, "onYarderCarriageTreeAttached")
end

function YarderTower.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "onHookI3DLoaded", YarderTower.onHookI3DLoaded)
	SpecializationUtil.registerFunction(vehicleType, "onRopeI3DLoaded", YarderTower.onRopeI3DLoaded)
	SpecializationUtil.registerFunction(vehicleType, "getIsSetupModeChangeAllowed", YarderTower.getIsSetupModeChangeAllowed)
	SpecializationUtil.registerFunction(vehicleType, "setYarderSetupModeState", YarderTower.setYarderSetupModeState)
	SpecializationUtil.registerFunction(vehicleType, "setYarderTargetActive", YarderTower.setYarderTargetActive)
	SpecializationUtil.registerFunction(vehicleType, "setYarderCarriageFollowMode", YarderTower.setYarderCarriageFollowMode)
	SpecializationUtil.registerFunction(vehicleType, "setYarderCarriageMoveInput", YarderTower.setYarderCarriageMoveInput)
	SpecializationUtil.registerFunction(vehicleType, "setYarderCarriageLiftInput", YarderTower.setYarderCarriageLiftInput)
	SpecializationUtil.registerFunction(vehicleType, "onYarderCarriageAttach", YarderTower.onYarderCarriageAttach)
	SpecializationUtil.registerFunction(vehicleType, "onYarderCarriageDetach", YarderTower.onYarderCarriageDetach)
	SpecializationUtil.registerFunction(vehicleType, "setupSupportRopes", YarderTower.setupSupportRopes)
	SpecializationUtil.registerFunction(vehicleType, "onCreateCarriageFinished", YarderTower.onCreateCarriageFinished)
	SpecializationUtil.registerFunction(vehicleType, "onCarriageVehicleDeleted", YarderTower.onCarriageVehicleDeleted)
	SpecializationUtil.registerFunction(vehicleType, "setYarderRopeState", YarderTower.setYarderRopeState)
	SpecializationUtil.registerFunction(vehicleType, "updateYarderRope", YarderTower.updateYarderRope)
	SpecializationUtil.registerFunction(vehicleType, "updateYarderRopeLengthNodes", YarderTower.updateYarderRopeLengthNodes)
	SpecializationUtil.registerFunction(vehicleType, "getTreeAtPosition", YarderTower.getTreeAtPosition)
	SpecializationUtil.registerFunction(vehicleType, "getIsPlayerInYarderRange", YarderTower.getIsPlayerInYarderRange)
	SpecializationUtil.registerFunction(vehicleType, "getIsPlayerInYarderControlRange", YarderTower.getIsPlayerInYarderControlRange)
	SpecializationUtil.registerFunction(vehicleType, "getYarderIsSetUp", YarderTower.getYarderIsSetUp)
	SpecializationUtil.registerFunction(vehicleType, "getYarderStatusInfo", YarderTower.getYarderStatusInfo)
	SpecializationUtil.registerFunction(vehicleType, "getYarderMainRopeLength", YarderTower.getYarderMainRopeLength)
	SpecializationUtil.registerFunction(vehicleType, "getYarderCarriageLastSpeed", YarderTower.getYarderCarriageLastSpeed)
	SpecializationUtil.registerFunction(vehicleType, "onYarderControlTriggerCallback", YarderTower.onYarderControlTriggerCallback)
	SpecializationUtil.registerFunction(vehicleType, "onYarderTreeRaycastCallback", YarderTower.onYarderTreeRaycastCallback)
	SpecializationUtil.registerFunction(vehicleType, "doRopePlacementValidation", YarderTower.doRopePlacementValidation)
	SpecializationUtil.registerFunction(vehicleType, "onMainRopePlacementValidated", YarderTower.onMainRopePlacementValidated)
	SpecializationUtil.registerFunction(vehicleType, "onYarderSupportTerrainRaycastCallback", YarderTower.onYarderSupportTerrainRaycastCallback)
	SpecializationUtil.registerFunction(vehicleType, "onSupportRopeTreeOverlapCallback", YarderTower.onSupportRopeTreeOverlapCallback)
	SpecializationUtil.registerFunction(vehicleType, "onYarderTowerPlayerDeleted", YarderTower.onYarderTowerPlayerDeleted)
end

function YarderTower.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "isDetachAllowed", YarderTower.isDetachAllowed)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsFoldAllowed", YarderTower.getIsFoldAllowed)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAllowsLowering", YarderTower.getAllowsLowering)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDoConsumePtoPower", YarderTower.getDoConsumePtoPower)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getConsumingLoad", YarderTower.getConsumingLoad)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsPowerTakeOffActive", YarderTower.getIsPowerTakeOffActive)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDirtMultiplier", YarderTower.getDirtMultiplier)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getWearMultiplier", YarderTower.getWearMultiplier)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getUsageCausesDamage", YarderTower.getUsageCausesDamage)
end

function YarderTower.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", YarderTower)
	SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", YarderTower)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", YarderTower)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", YarderTower)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", YarderTower)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", YarderTower)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", YarderTower)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", YarderTower)
	SpecializationUtil.registerEventListener(vehicleType, "onYarderCarriageTreeAttached", YarderTower)
end

function YarderTower:onLoad(savegame)
	self.spec_yarderTower = self["spec_" .. YarderTower.SPEC_NAME]
	local spec = self.spec_yarderTower
	spec.sharedLoadRequestIds = {}
	spec.controlTriggerNode = self.xmlFile:getValue("vehicle.yarderTower#controlTrigger", nil, self.components, self.i3dMappings)

	if spec.controlTriggerNode ~= nil then
		addTrigger(spec.controlTriggerNode, "onYarderControlTriggerCallback", self)
	end

	spec.requiresAttacherVehicle = self.xmlFile:getValue("vehicle.yarderTower#requiresAttacherVehicle", false)
	spec.requiresLowering = self.xmlFile:getValue("vehicle.yarderTower#requiresLowering", false)
	spec.foldMinLimit = self.xmlFile:getValue("vehicle.yarderTower#foldMinLimit", 0)
	spec.foldMaxLimit = self.xmlFile:getValue("vehicle.yarderTower#foldMaxLimit", 1)
	spec.requiresPowerTimeOffset = 0
	spec.placementHeight = self.xmlFile:getValue("vehicle.yarderTower.placement#height", 10)
	local placementMinHeightOffset = self.xmlFile:getValue("vehicle.yarderTower.placement#minHeightOffset", "-1")

	if placementMinHeightOffset == "-" then
		spec.placementMinHeightOffset = math.huge
	else
		spec.placementMinHeightOffset = tonumber(placementMinHeightOffset)
	end

	spec.carriage = {
		lastMoveInput = 0,
		lastMoveInputTime = 0,
		lastLiftInput = 0,
		lastLiftInputTime = 0,
		speed = 0,
		targetSpeed = 0,
		position = 0,
		lastPosition = 0,
		lastPositionTimeOffset = 0,
		lastSpeed = 0,
		followModeState = YarderTower.FOLLOW_MODE_NONE,
		followModePlayer = nil,
		followModeLocalPlayer = false,
		followModePickupPosition = 0,
		lastPlayerInRange = false,
		maxSpeed = self.xmlFile:getValue("vehicle.yarderTower.carriage#maxSpeed", 20) / 3600,
		acceleration = self.xmlFile:getValue("vehicle.yarderTower.carriage#acceleration", 0.01),
		deceleration = self.xmlFile:getValue("vehicle.yarderTower.carriage#deceleration", 0.05),
		startOffset = self.xmlFile:getValue("vehicle.yarderTower.carriage#startOffset", 1),
		endOffset = self.xmlFile:getValue("vehicle.yarderTower.carriage#endOffset", 1),
		filename = self.xmlFile:getValue("vehicle.yarderTower.carriage#filename")
	}

	if spec.carriage.filename ~= nil then
		spec.carriage.filename = Utils.getFilename(spec.carriage.filename, YarderTower.MOD_DIRECTORY)
	end

	spec.hooks = {
		treeData = ForestryHook.new(self, self.rootNode)
	}

	spec.hooks.treeData:loadFromXML(self.xmlFile, "vehicle.yarderTower.hooks.tree")
	spec.hooks.treeData:setVisibility(false)

	spec.hooks.groundData = ForestryHook.new(self, self.rootNode)

	spec.hooks.groundData:loadFromXML(self.xmlFile, "vehicle.yarderTower.hooks.ground")
	spec.hooks.groundData:setVisibility(false)

	local function loadSharedRopeAttributes(ropeData, key)
		ropeData.isActive = false
		ropeData.maxOffset = self.xmlFile:getValue(key .. "#maxOffset", 0.4)
		ropeData.offsetReferenceLength = self.xmlFile:getValue(key .. "#offsetReferenceLength", 5)
		ropeData.diameter = self.xmlFile:getValue(key .. "#diameter", 0.015)
		ropeData.filename = self.xmlFile:getValue(key .. "#filename")
		ropeData.ropeNodePath = self.xmlFile:getValue(key .. "#ropeNode", "0|0")

		if ropeData.filename ~= nil then
			ropeData.filename = Utils.getFilename(ropeData.filename, YarderTower.MOD_DIRECTORY)
			local sharedLoadRequestId = self:loadSubSharedI3DFile(ropeData.filename, false, false, self.onRopeI3DLoaded, self, ropeData)

			table.insert(spec.sharedLoadRequestIds, sharedLoadRequestId)
		end

		ropeData.rotNode = self.xmlFile:getValue(key .. "#rotNode", nil, self.components, self.i3dMappings)
		ropeData.rotNodeAllAxis = self.xmlFile:getValue(key .. "#rotNodeAllAxis", false)

		if ropeData.rotNode ~= nil then
			ropeData.rotNodeInitRot = {
				getRotation(ropeData.rotNode)
			}
		end

		ropeData.ropeLengthNodes = {}

		self.xmlFile:iterate(key .. ".ropeLengthNode", function (index, nodeKey)
			local entry = {
				node = self.xmlFile:getValue(nodeKey .. "#node", nil, self.components, self.i3dMappings)
			}

			if entry.node ~= nil then
				entry.minLength = self.xmlFile:getValue(nodeKey .. "#minLength", 0)
				entry.maxLength = self.xmlFile:getValue(nodeKey .. "#maxLength", 10)
				entry.minRot = self.xmlFile:getValue(nodeKey .. "#minRot", nil, true)
				entry.maxRot = self.xmlFile:getValue(nodeKey .. "#maxRot", nil, true)
				entry.minTrans = self.xmlFile:getValue(nodeKey .. "#minTrans", nil, true)
				entry.maxTrans = self.xmlFile:getValue(nodeKey .. "#maxTrans", nil, true)
				entry.minScale = self.xmlFile:getValue(nodeKey .. "#minScale", nil, true)
				entry.maxScale = self.xmlFile:getValue(nodeKey .. "#maxScale", nil, true)
				entry.shaderParameterName = self.xmlFile:getValue(nodeKey .. "#shaderParameterName")
				entry.minShaderParameter = self.xmlFile:getValue(nodeKey .. "#minShaderParameter", nil, true)
				entry.maxShaderParameter = self.xmlFile:getValue(nodeKey .. "#maxShaderParameter", nil, true)

				if entry.shaderParameterName ~= nil and not getHasShaderParameter(entry.node, entry.shaderParameterName) then
					Logging.xmlWarning(nodeKey, "Node does not have the provided shader parameter '%s'", entry.shaderParameterName)
				end

				table.insert(ropeData.ropeLengthNodes, entry)
			end
		end)

		ropeData.changeObjects = {}

		ObjectChangeUtil.loadObjectChangeFromXML(self.xmlFile, key, ropeData.changeObjects, self.components, self)
		ObjectChangeUtil.setObjectChanges(ropeData.changeObjects, false, self, self.setMovingToolDirty)
	end

	spec.setupRope = {
		node = self.xmlFile:getValue("vehicle.yarderTower.ropes.setupRope#node", nil, self.components, self.i3dMappings),
		colorInvalid = self.xmlFile:getValue("vehicle.yarderTower.ropes.setupRope#colorInvalid", nil, true),
		colorValid = self.xmlFile:getValue("vehicle.yarderTower.ropes.setupRope#colorValid", nil, true),
		diameterTree = self.xmlFile:getValue("vehicle.yarderTower.ropes.setupRope#diameterTree", 0.015),
		diameterPlayer = self.xmlFile:getValue("vehicle.yarderTower.ropes.setupRope#diameterPlayer", 0.015)
	}

	loadSharedRopeAttributes(spec.setupRope, "vehicle.yarderTower.ropes.setupRope")

	spec.mainRope = {
		node = self.xmlFile:getValue("vehicle.yarderTower.ropes.mainRope#node", nil, self.components, self.i3dMappings),
		maxAngle = self.xmlFile:getValue("vehicle.yarderTower.ropes.mainRope#maxAngle", 80),
		maxLength = self.xmlFile:getValue("vehicle.yarderTower.ropes.mainRope#maxLength", 100),
		clearance = self.xmlFile:getValue("vehicle.yarderTower.ropes.mainRope#clearance", 2),
		minTreeDiameter = self.xmlFile:getValue("vehicle.yarderTower.ropes.mainRope#minTreeDiameter", 0.2)
	}

	loadSharedRopeAttributes(spec.mainRope, "vehicle.yarderTower.ropes.mainRope")

	spec.mainRope.isActive = false
	spec.mainRope.isValid = false
	spec.mainRope.lastIsValid = false
	spec.mainRope.lastLength = 0
	spec.mainRope.lastLengthOffsetTime = 0
	spec.mainRope.failedWarning = nil
	spec.mainRope.target = {
		0,
		0,
		0
	}
	spec.pullRope = {
		node = self.xmlFile:getValue("vehicle.yarderTower.ropes.pullRope#node", nil, self.components, self.i3dMappings)
	}

	loadSharedRopeAttributes(spec.pullRope, "vehicle.yarderTower.ropes.pullRope")

	spec.pushRope = {
		yOffset = self.xmlFile:getValue("vehicle.yarderTower.ropes.pushRope#yOffset", 1.5)
	}

	loadSharedRopeAttributes(spec.pushRope, "vehicle.yarderTower.ropes.pushRope")

	spec.supportRopes = {
		centerNode = self.xmlFile:getValue("vehicle.yarderTower.ropes.supportRopes#centerNode", nil, self.components, self.i3dMappings),
		treeRadius = self.xmlFile:getValue("vehicle.yarderTower.ropes.supportRopes#treeRadius", 25),
		foundTrees = {},
		ropes = {}
	}

	self.xmlFile:iterate("vehicle.yarderTower.ropes.supportRopes.supportRope", function (index, key)
		local supportRope = {
			node = self.xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings)
		}

		if supportRope.node ~= nil then
			supportRope.angleReferenceNode = self.xmlFile:getValue(key .. "#angleReferenceNode", supportRope.node, self.components, self.i3dMappings)
			supportRope.maxAngle = self.xmlFile:getValue(key .. "#maxAngle", 22.5)
			supportRope.raycastRotY = self.xmlFile:getValue(key .. "#raycastRotY")
			supportRope.treeYOffset = self.xmlFile:getValue(key .. "#treeYOffset", 1)
			supportRope.raycastNode = self.xmlFile:getValue(key .. "#raycastNode", supportRope.node, self.components, self.i3dMappings)
			supportRope.target = {
				0,
				0,
				0
			}
			supportRope.vehicle = self
			supportRope.onYarderSupportTerrainRaycastCallback = self.onYarderSupportTerrainRaycastCallback

			loadSharedRopeAttributes(supportRope, key)
			table.insert(spec.supportRopes.ropes, supportRope)
		end
	end)

	spec.isPlayerInRange = false
	spec.setupModeState = false
	spec.updateRopesDirtyTime = 0
	spec.treeRaycast = {
		hasStarted = false,
		lastValidTree = nil,
		lastValidTreeHeight = 0,
		foundTree = nil,
		data = {
			hasStarted = false,
			z = 0,
			y = 0,
			x = 0,
			vehicle = self,
			callback = self.onMainRopePlacementValidated
		}
	}
	spec.lastMotorRpm = 0
	spec.lastMotorPowerTimeOffset = 0
	spec.samples = {}

	if self.isClient then
		spec.samples.setupRopeIncrease = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "setupRopeIncrease", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.setupRopeDecrease = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "setupRopeDecrease", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.setupRopeValidTarget = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "setupRopeValidTarget", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.setupStarted = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "setupStarted", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.setupFinished = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "setupFinished", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.setupCanceled = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "setupCanceled", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.ropeLinkTree = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "ropeLinkTree", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.ropeLinkGround = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "ropeLinkGround", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.removeYarder = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "removeYarder", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.carriageMovePos = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "carriageMovePos", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.carriageMoveNeg = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "carriageMoveNeg", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.carriageMovePosLimit = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "carriageMovePosLimit", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.carriageMoveNegLimit = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "carriageMoveNegLimit", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.carriageDriveMovePos = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "carriageDriveMovePos", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.carriageDriveMoveNeg = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "carriageDriveMoveNeg", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.carriageDriveMovePosLimit = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "carriageDriveMovePosLimit", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.carriageDriveMoveNegLimit = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "carriageDriveMoveNegLimit", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.samples.motor = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.yarderTower.sounds", "motor", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)

		for i = 1, #spec.supportRopes.ropes do
			local supportRope = spec.supportRopes.ropes[i]

			if spec.samples.ropeLinkTree ~= nil then
				supportRope.sampleRopeLinkTree = g_soundManager:cloneSample(spec.samples.ropeLinkTree, self.rootNode, self)
			end

			if spec.samples.ropeLinkGround ~= nil then
				supportRope.sampleRopeLinkGround = g_soundManager:cloneSample(spec.samples.ropeLinkGround, self.rootNode, self)
			end
		end

		if spec.samples.ropeLinkTree ~= nil then
			spec.mainRope.sampleRopeLinkTree = g_soundManager:cloneSample(spec.samples.ropeLinkTree, self.rootNode, self)
		end

		spec.motorEffects = g_effectManager:loadEffect(self.xmlFile, "vehicle.yarderTower.motorEffects", self.components, self, self.i3dMappings)
	end

	spec.texts = {
		warningWrongAngle = g_i18n:getText("yarder_wrongAngle"),
		warningRopeTooLong = g_i18n:getText("yarder_ropeTooLong"),
		warningTreeTooSmall = g_i18n:getText("yarder_treeTooSmall"),
		warningWayIsBlocked = g_i18n:getText("yarder_wayIsBlocked"),
		actionStartSetup = g_i18n:getText("yarder_setup"),
		actionCancelSetup = g_i18n:getText("yarder_cancelSetup"),
		actionRemoveYarder = g_i18n:getText("yarder_remove"),
		actionSetTargetTree = g_i18n:getText("yarder_setTargetTree"),
		actionCarriageFollowModeEnable = g_i18n:getText("yarder_carriageFollowModeEnable"),
		actionCarriageFollowModeDisable = g_i18n:getText("yarder_carriageFollowModeDisable"),
		actionCarriageManualControl = g_i18n:getText("yarder_carriageMove"),
		actionCarriageLiftLower = g_i18n:getText("yarder_carriageLiftLower"),
		actionCarriageAttachTree = g_i18n:getText("yarder_carriageAttachTree"),
		actionCarriageDetachTree = g_i18n:getText("yarder_carriageDetachTree"),
		warningDetachNotAllowed = g_i18n:getText("yarder_detachNotAllowed"),
		warningDoNotMoveVehicle = g_i18n:getText("yarder_doNotMoveVehicle"),
		warningLowerFirst = g_i18n:getText("warning_lowerImplementFirst"),
		warningUnfoldFirst = g_i18n:getText("warning_firstUnfoldTheTool"),
		warningOnlyForUphillYarding = g_i18n:getText("yarder_onlyForUphillYarding")
	}
	spec.setupActivatable = YarderTowerSetupActivatable.new(self)
	spec.controlActivatable = YarderTowerControlActivatable.new(self)
	spec.dirtyFlag = self:getNextDirtyFlag()
end

function YarderTower:onLoadFinished(savegame)
	local spec = self.spec_yarderTower

	if savegame ~= nil and not savegame.resetVehicles then
		local key = savegame.key .. "." .. YarderTower.SPEC_NAME
		spec.mainRope.isActive = savegame.xmlFile:getValue(key .. "#isActive", false)
		spec.carriage.position = savegame.xmlFile:getValue(key .. "#position", 0)

		if spec.mainRope.isActive then
			spec.mainRope.isValid = true
			spec.mainRope.target[1] = savegame.xmlFile:getValue(key .. ".target#x", spec.mainRope.target[1])
			spec.mainRope.target[2] = savegame.xmlFile:getValue(key .. ".target#y", spec.mainRope.target[2])
			spec.mainRope.target[3] = savegame.xmlFile:getValue(key .. ".target#z", spec.mainRope.target[3])

			self:setYarderTargetActive(true, true)

			spec.loadedAttachedTreesData = YarderCarriage.loadAttachedTreesFromXML(savegame.xmlFile, key)
		end
	end
end

function YarderTower:onDelete()
	local spec = self.spec_yarderTower

	if spec.mainRope ~= nil and spec.mainRope.isActive then
		self:setYarderTargetActive(false, true)
	end

	if spec.controlTriggerNode ~= nil then
		removeTrigger(spec.controlTriggerNode)
	end

	if spec.sharedLoadRequestIds ~= nil then
		for _, sharedLoadRequestId in ipairs(spec.sharedLoadRequestIds) do
			g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)
		end
	end

	if spec.hooks.treeData ~= nil then
		spec.hooks.treeData:delete()
	end

	if spec.hooks.groundData ~= nil then
		spec.hooks.groundData:delete()
	end

	if self.isClient then
		g_soundManager:deleteSamples(spec.samples)

		if spec.supportRopes ~= nil then
			for i = 1, #spec.supportRopes.ropes do
				local supportRope = spec.supportRopes.ropes[i]

				g_soundManager:deleteSample(supportRope.sampleRopeLinkTree)
				g_soundManager:deleteSample(supportRope.sampleRopeLinkGround)
			end
		end

		if spec.mainRope ~= nil then
			g_soundManager:deleteSample(spec.mainRope.sampleRopeLinkTree)
		end

		g_effectManager:deleteEffects(spec.motorEffects)
	end

	g_currentMission.activatableObjectsSystem:removeActivatable(spec.setupActivatable)
	g_currentMission.activatableObjectsSystem:removeActivatable(spec.controlActivatable)
end

function YarderTower:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_yarderTower

	xmlFile:setValue(key .. "#isActive", spec.mainRope.isActive)
	xmlFile:setValue(key .. "#position", spec.carriage.position)

	if spec.mainRope.isActive then
		xmlFile:setValue(key .. ".target#x", spec.mainRope.target[1])
		xmlFile:setValue(key .. ".target#y", spec.mainRope.target[2])
		xmlFile:setValue(key .. ".target#z", spec.mainRope.target[3])
	end

	if spec.carriage.vehicle ~= nil then
		spec.carriage.vehicle:saveAttachedTreesToXML(xmlFile, key, usedModNames)
	end
end

function YarderTower:onReadStream(streamId, connection)
	local spec = self.spec_yarderTower
	spec.carriage.followModeState = streamReadUIntN(streamId, 2)

	if streamReadBool(streamId) then
		local x = streamReadFloat32(streamId)
		local y = streamReadFloat32(streamId)
		local z = streamReadFloat32(streamId)
		spec.mainRope.isValid = true
		spec.mainRope.target[3] = z
		spec.mainRope.target[2] = y
		spec.mainRope.target[1] = x

		self:setYarderTargetActive(true, true)
	end
end

function YarderTower:onWriteStream(streamId, connection)
	local spec = self.spec_yarderTower

	streamWriteUIntN(streamId, spec.carriage.followModeState, 2)

	if streamWriteBool(streamId, spec.mainRope.isActive) then
		streamWriteFloat32(streamId, spec.mainRope.target[1])
		streamWriteFloat32(streamId, spec.mainRope.target[2])
		streamWriteFloat32(streamId, spec.mainRope.target[3])
	end
end

function YarderTower:onReadUpdateStream(streamId, timestamp, connection)
	if not connection:getIsServer() and streamReadBool(streamId) then
		self:setYarderCarriageMoveInput(streamReadUIntN(streamId, 2) - 1)
		self:setYarderCarriageLiftInput(streamReadUIntN(streamId, 2) - 1)
	end
end

function YarderTower:onWriteUpdateStream(streamId, connection, dirtyMask)
	local spec = self.spec_yarderTower

	if connection:getIsServer() and streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
		streamWriteUIntN(streamId, MathUtil.sign(spec.carriage.lastMoveInput) + 1, 2)
		streamWriteUIntN(streamId, MathUtil.sign(spec.carriage.lastLiftInput) + 1, 2)
	end
end

function YarderTower:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_yarderTower

	if spec.setupModeState then
		if spec.mainRope.node ~= nil and g_currentMission.player ~= nil and g_currentMission.player.isEntered then
			local player = g_currentMission.player
			local x1, y1, z1 = getWorldTranslation(spec.mainRope.node)
			local kinematicHelperNode, _ = player.model:getKinematicHelpers()
			local x2, y2, z2 = getWorldTranslation(kinematicHelperNode)
			local length = MathUtil.vector3Length(x2 - x1, y2 - y1, z2 - z1)

			if not spec.treeRaycast.hasStarted then
				spec.treeRaycast.hasStarted = true
				spec.treeRaycast.foundTree = nil
				local x, y, z = localToWorld(player.cameraNode, 0, 0, 1)
				local dx, dy, dz = localDirectionToWorld(player.cameraNode, 0, 0, -1)

				raycastClosest(x, y, z, dx, dy, dz, "onYarderTreeRaycastCallback", YarderTower.TREE_RAYCAST_DISTANCE, self, CollisionFlag.TREE, false, true)
			end

			if spec.treeRaycast.lastValidTree ~= nil then
				local shapeId = spec.treeRaycast.lastValidTree
				local x3, y3, z3 = getWorldTranslation(shapeId)
				y3 = math.max(y3 + spec.placementHeight, spec.treeRaycast.lastValidTreeHeight)
				y3 = math.min(y3, y1 + spec.placementMinHeightOffset)
				local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x3, 0, z3)
				y3 = math.max(y3, terrainHeight + 0.2)

				self:doRopePlacementValidation(spec.mainRope.node, shapeId, x3, y3, z3, spec.mainRope.maxAngle, spec.mainRope.maxLength, spec.mainRope.clearance, spec.mainRope.minTreeDiameter, spec.treeRaycast.data)

				z2 = spec.mainRope.target[3]
				y2 = spec.mainRope.target[2]
				x2 = spec.mainRope.target[1]
				length = MathUtil.vector3Length(x2 - x1, y2 - y1, z2 - z1)
			else
				spec.mainRope.isValid = false
				spec.mainRope.target[3] = z2
				spec.mainRope.target[2] = y2
				spec.mainRope.target[1] = x2
				spec.setupRope.diameter = spec.setupRope.diameterPlayer
			end

			if spec.mainRope.isValid ~= spec.mainRope.lastIsValid then
				spec.mainRope.lastIsValid = spec.mainRope.isValid

				if spec.mainRope.isValid then
					g_soundManager:playSample(spec.samples.setupRopeValidTarget)
				end
			end

			if length ~= spec.mainRope.lastLength then
				if spec.mainRope.lastLength < length then
					if not g_soundManager:getIsSamplePlaying(spec.samples.setupRopeIncrease) then
						g_soundManager:playSample(spec.samples.setupRopeIncrease)
						g_soundManager:stopSample(spec.samples.setupRopeDecrease)
					end
				elseif not g_soundManager:getIsSamplePlaying(spec.samples.setupRopeDecrease) then
					g_soundManager:playSample(spec.samples.setupRopeDecrease)
					g_soundManager:stopSample(spec.samples.setupRopeIncrease)
				end

				spec.mainRope.lastLength = length
				spec.mainRope.lastLengthOffsetTime = 250
			end

			if spec.mainRope.lastLengthOffsetTime > 0 then
				spec.mainRope.lastLengthOffsetTime = spec.mainRope.lastLengthOffsetTime - dt

				if spec.mainRope.lastLengthOffsetTime <= 0 then
					g_soundManager:stopSample(spec.samples.setupRopeIncrease)
					g_soundManager:stopSample(spec.samples.setupRopeDecrease)
				end
			end

			local emissiveColor = spec.mainRope.isValid and spec.setupRope.colorValid or spec.setupRope.colorInvalid

			setShaderParameter(spec.setupRope.ropeNode, "ropeEmissiveColor", emissiveColor[1], emissiveColor[2], emissiveColor[3], 1, false)
			self:updateYarderRope(spec.setupRope, x2, y2, z2, dt)
		else
			self:setYarderSetupModeState(false, true)

			spec.mainRope.isValid = false
			spec.mainRope.lastIsValid = false
		end

		spec.setupActivatable:updateActionEventTexts()
		self:raiseActive()
	end

	if spec.mainRope.isActive then
		if spec.loadedAttachedTreesData ~= nil and spec.carriage.vehicle ~= nil and spec.carriage.vehicle.isAddedToPhysics and spec.carriage.vehicle:resolveLoadedAttachedTrees(spec.loadedAttachedTreesData) then
			spec.loadedAttachedTreesData = nil
		end

		local x1, y1, z1 = getWorldTranslation(spec.mainRope.node)
		local x2 = spec.mainRope.target[1]
		local y2 = spec.mainRope.target[2]
		local z2 = spec.mainRope.target[3]

		if self.isServer and spec.carriage.vehicle ~= nil and spec.carriage.vehicle.getCarriageDimensions ~= nil then
			local length, rollSpacing = spec.carriage.vehicle:getCarriageDimensions()
			local totalRopeLength = MathUtil.vector3Length(x2 - x1, y2 - y1, z2 - z1)
			local maxSpeed = spec.carriage.maxSpeed
			local damage = self:getVehicleDamage()

			if damage > 0 then
				maxSpeed = maxSpeed * (1 - damage * YarderTower.DAMAGED_SPEED_REDUCTION)
			end

			if spec.carriage.followModeState ~= YarderTower.FOLLOW_MODE_NONE then
				local targetPosition = 0

				if spec.carriage.followModeState == YarderTower.FOLLOW_MODE_ME then
					local player = spec.carriage.followModePlayer

					if player ~= nil then
						local x, y, z = getWorldTranslation(player.rootNode)
						local _ = nil
						_, _, _, targetPosition = MathUtil.getClosestPointOnLineSegment(x1, 0, z1, x2, 0, z2, x, y, z)
					end
				end

				if spec.carriage.followModeState == YarderTower.FOLLOW_MODE_PICKUP then
					targetPosition = spec.carriage.followModePickupPosition
				end

				local direction = MathUtil.sign(targetPosition - spec.carriage.position)
				local speed = maxSpeed / totalRopeLength * dt * math.min(math.abs(targetPosition - spec.carriage.position) * totalRopeLength / 2, 1)
				spec.carriage.targetSpeed = direction * speed

				if spec.carriage.followModeState ~= YarderTower.FOLLOW_MODE_ME and math.abs(targetPosition - spec.carriage.position) * totalRopeLength < 0.1 then
					self:setYarderCarriageFollowMode(YarderTower.FOLLOW_MODE_NONE)
				end
			elseif spec.carriage.lastMoveInput ~= 0 then
				spec.carriage.targetSpeed = maxSpeed / totalRopeLength * dt * spec.carriage.lastMoveInput

				if g_time - spec.carriage.lastMoveInputTime > 250 then
					spec.carriage.lastMoveInput = 0
				end
			else
				spec.carriage.targetSpeed = 0
			end

			if spec.carriage.lastLiftInput ~= 0 then
				if g_time - spec.carriage.lastLiftInputTime > 250 then
					spec.carriage.lastLiftInput = 0
				end

				spec.carriage.vehicle:setCarriageLiftInput(spec.carriage.lastLiftInput)
			end

			if spec.requiresAttacherVehicle then
				if spec.carriage.followModeState ~= YarderTower.FOLLOW_MODE_NONE or spec.carriage.lastLiftInput ~= 0 or spec.carriage.lastMoveInput ~= 0 then
					spec.requiresPowerTimeOffset = 10000
				end

				local attacherVehicle = self:getAttacherVehicle()

				if attacherVehicle ~= nil and attacherVehicle.startMotor ~= nil then
					if spec.requiresPowerTimeOffset > 0 then
						spec.requiresPowerTimeOffset = spec.requiresPowerTimeOffset - dt

						if not attacherVehicle:getIsMotorStarted() then
							if attacherVehicle:getCanMotorRun() then
								attacherVehicle:startMotor()
							end
						else
							local motor = attacherVehicle:getMotor()
							local maxMotorRotAcceleration = motor:getMotorRotationAccelerationLimit()
							local minMotorRpm, maxMotorRpm = motor:getRequiredMotorRpmRange()
							local neededPtoTorque, _ = PowerConsumer.getTotalConsumedPtoTorque(attacherVehicle)
							neededPtoTorque = neededPtoTorque / motor:getPtoMotorRpmRatio()

							attacherVehicle:controlVehicle(0, 0, 0, minMotorRpm * math.pi / 30, maxMotorRpm * math.pi / 30, maxMotorRotAcceleration, 0, 0, motor:getMaxClutchTorque(), neededPtoTorque)
							attacherVehicle:raiseActive()
						end
					elseif (attacherVehicle.getIsControlled == nil or not attacherVehicle:getIsControlled()) and attacherVehicle:getIsMotorStarted() then
						attacherVehicle:stopMotor()
					end
				end
			end

			spec.carriage.position = MathUtil.clamp(spec.carriage.position + spec.carriage.speed, 0, 1)
			local direction = MathUtil.sign(spec.carriage.targetSpeed - spec.carriage.speed)
			local acceleration = direction * MathUtil.sign(spec.carriage.speed)
			local func = direction == 1 and math.min or math.max
			spec.carriage.speed = func(spec.carriage.speed + spec.carriage.maxSpeed / totalRopeLength * dt * (acceleration == 1 and spec.carriage.acceleration or spec.carriage.deceleration) * direction, spec.carriage.targetSpeed)
			local alphaOffset = length / totalRopeLength
			local startAlphaOffset = spec.carriage.startOffset / totalRopeLength + alphaOffset * 0.5
			local endAlphaOffset = spec.carriage.endOffset / totalRopeLength + alphaOffset * 0.5
			local alpha = startAlphaOffset + spec.carriage.position * (1 - (startAlphaOffset + endAlphaOffset))
			local cx, cy, cz = MathUtil.lerp3(x1, y1, z1, x2, y2, z2, alpha)
			local yOffset = math.sin(alpha * math.pi) * spec.mainRope.maxOffset
			local rollSpacingAlpha = rollSpacing / totalRopeLength * 0.5
			local rsx1, rsy1, rsz1 = MathUtil.lerp3(x1, y1, z1, x2, y2, z2, alpha - rollSpacingAlpha)
			rsy1 = rsy1 - math.sin((alpha - rollSpacingAlpha) * math.pi) * spec.mainRope.maxOffset
			local rsx2, rsy2, rsz2 = MathUtil.lerp3(x1, y1, z1, x2, y2, z2, alpha + rollSpacingAlpha)
			rsy2 = rsy2 - math.sin((alpha + rollSpacingAlpha) * math.pi) * spec.mainRope.maxOffset
			local cDirX, cDirY, cDirZ = MathUtil.vector3Normalize(rsx2 - rsx1, rsy2 - rsy1, rsz2 - rsz1)

			setDirection(spec.carriage.vehicle.rootNode, cDirX, cDirY, cDirZ, 0, 1, 0)

			local rx, ry, rz = getWorldRotation(spec.carriage.vehicle.rootNode)

			if not spec.carriage.vehicle.isAddedToPhysics then
				spec.carriage.vehicle:setAbsolutePosition(cx, cy - yOffset, cz, rx, ry, rz)
				spec.carriage.vehicle:addToPhysics()
				spec.carriage.vehicle:addWearAmount(self:getWearTotalAmount(), true)
				spec.carriage.vehicle:setDamageAmount(self:getDamageAmount(), true)
				spec.carriage.vehicle:addDirtAmount(self:getDirtAmount(), true)
			else
				spec.carriage.vehicle:setWorldPosition(cx, cy - yOffset, cz, rx, ry, rz, 1, false)
			end

			spec.carriage.vehicle:raiseActive()
		end

		if spec.carriage.vehicle ~= nil and spec.carriage.vehicle.getCarriagePullRopeTargetNode ~= nil then
			local pullRopeTargetNode = spec.carriage.vehicle:getCarriagePullRopeTargetNode()

			if pullRopeTargetNode ~= nil then
				local px, py, pz = getWorldTranslation(pullRopeTargetNode)
				local maxOffset = self:updateYarderRope(spec.pullRope, px, py, pz, dt)

				spec.carriage.vehicle:updateRopeAlignmentNodes(spec.pullRope.ropeNode, px, py, pz, maxOffset)

				local length, _ = spec.carriage.vehicle:getCarriageDimensions()
				local totalRopeLength = MathUtil.vector3Length(x2 - x1, y2 - y1, z2 - z1)
				local alphaOffset = (length + 0.025) / totalRopeLength * 0.5
				local startAlphaOffset = spec.carriage.startOffset / totalRopeLength + alphaOffset
				local endAlphaOffset = spec.carriage.endOffset / totalRopeLength + alphaOffset
				local cx, cy, cz = getWorldTranslation(spec.carriage.vehicle.rootNode)
				local _, _, z = worldToLocal(spec.mainRope.ropeNode, cx, cy, cz)
				local position = MathUtil.clamp((z / totalRopeLength - startAlphaOffset) / (1 - (startAlphaOffset + endAlphaOffset)), 0, 1)
				spec.carriage.lastSpeed = math.abs((spec.carriage.lastPosition - position) / dt * totalRopeLength) / spec.carriage.maxSpeed

				if math.abs(position - spec.carriage.lastPosition) * totalRopeLength > 0.005 then
					if spec.carriage.lastPosition < position then
						if not g_soundManager:getIsSamplePlaying(spec.samples.carriageMovePos) then
							g_soundManager:playSample(spec.samples.carriageMovePos)
							g_soundManager:playSample(spec.samples.carriageDriveMovePos)
							g_soundManager:stopSample(spec.samples.carriageMoveNeg)
							g_soundManager:stopSample(spec.samples.carriageDriveMoveNeg)
						end
					elseif not g_soundManager:getIsSamplePlaying(spec.samples.carriageMoveNeg) then
						g_soundManager:playSample(spec.samples.carriageMoveNeg)
						g_soundManager:playSample(spec.samples.carriageDriveMoveNeg)
						g_soundManager:stopSample(spec.samples.carriageMovePos)
						g_soundManager:stopSample(spec.samples.carriageDriveMovePos)
					end

					if position == 1 then
						g_soundManager:playSample(spec.samples.carriageMovePosLimit)
						g_soundManager:playSample(spec.samples.carriageDriveMovePosLimit)
					elseif position == 0 then
						g_soundManager:playSample(spec.samples.carriageMoveNegLimit)
						g_soundManager:playSample(spec.samples.carriageDriveMoveNegLimit)
					end

					spec.carriage.lastPosition = position
					spec.carriage.lastPositionTimeOffset = 250

					if spec.samples.carriageMovePos ~= nil then
						setWorldTranslation(spec.samples.carriageMovePos.soundNode, cx, cy, cz)
					end

					if spec.samples.carriageMoveNeg ~= nil then
						setWorldTranslation(spec.samples.carriageMoveNeg.soundNode, cx, cy, cz)
					end

					if spec.samples.carriageMovePosLimit ~= nil then
						setWorldTranslation(spec.samples.carriageMovePosLimit.soundNode, cx, cy, cz)
					end

					if spec.samples.carriageMoveNegLimit ~= nil then
						setWorldTranslation(spec.samples.carriageMoveNegLimit.soundNode, cx, cy, cz)
					end

					spec.controlActivatable:updateActionEventTexts()
				elseif spec.carriage.lastPositionTimeOffset > 0 then
					spec.carriage.lastPositionTimeOffset = spec.carriage.lastPositionTimeOffset - dt

					if spec.carriage.lastPositionTimeOffset <= 0 then
						g_soundManager:stopSample(spec.samples.carriageMovePos)
						g_soundManager:stopSample(spec.samples.carriageDriveMovePos)
						g_soundManager:stopSample(spec.samples.carriageMoveNeg)
						g_soundManager:stopSample(spec.samples.carriageDriveMoveNeg)
					end
				end
			end

			if spec.pushRope.isActive ~= nil then
				local pushRopeTargetNode = spec.carriage.vehicle:getCarriagePushRopeTargetNode()

				if pushRopeTargetNode ~= nil then
					spec.pushRope.hookData:setTargetNode(pushRopeTargetNode, false)
					setWorldTranslation(spec.pushRope.ropeNode, spec.pushRope.hookData:getRopeTargetPosition())

					local px, py, pz = getWorldTranslation(pushRopeTargetNode)

					self:updateYarderRope(spec.pushRope, px, py, pz, dt)
				end
			end

			local isInRange, _ = self:getIsPlayerInYarderControlRange()

			if isInRange then
				spec.carriage.vehicle:updateCarriageInRange(dt)

				if not spec.carriage.lastPlayerInRange then
					g_currentMission.hud.inputHelp:addExtraExtensionVehicleNodeId(self.rootNode)
				end
			elseif spec.carriage.lastPlayerInRange then
				spec.carriage.vehicle:onYarderCarriageUpdateEnd()
				g_currentMission.hud.inputHelp:removeExtraExtensionVehicleNodeId(self.rootNode)
			end

			spec.carriage.lastPlayerInRange = isInRange
		end

		if spec.updateRopesDirtyTime <= 0 then
			-- Nothing
		end

		spec.updateRopesDirtyTime = spec.updateRopesDirtyTime - dt

		self:updateYarderRope(spec.mainRope, x2, y2, z2, dt)

		for i = 1, #spec.supportRopes.ropes do
			local supportRope = spec.supportRopes.ropes[i]

			if supportRope.isActive then
				self:updateYarderRope(supportRope, supportRope.target[1], supportRope.target[2], supportRope.target[3], dt)
			end
		end

		if spec.carriage.vehicle ~= nil then
			if not g_soundManager:getIsSamplePlaying(spec.samples.motor) then
				g_soundManager:playSample(spec.samples.motor)

				spec.lastMotorRpm = 0

				g_effectManager:startEffects(spec.motorEffects)
			end

			if spec.carriage.lastPositionTimeOffset > 0 then
				spec.lastMotorPowerTimeOffset = 10000
			else
				spec.lastMotorPowerTimeOffset = math.max(spec.lastMotorPowerTimeOffset - dt, 0)
			end

			local targetRpm = 0
			local minLoad = 0.33 * spec.carriage.lastSpeed

			if spec.lastMotorPowerTimeOffset > 0 then
				targetRpm = 0.5 + spec.carriage.lastSpeed * 0.5
			end

			spec.lastMotorRpm = spec.lastMotorRpm * 0.975 + targetRpm * 0.025
			local loadFactor = spec.carriage.vehicle:getNumAttachedTrees() / spec.carriage.vehicle:getMaxNumAttachedTrees()
			loadFactor = minLoad + loadFactor * spec.carriage.lastSpeed * (1 - minLoad)

			g_soundManager:setSampleLoopSynthesisParameters(spec.samples.motor, spec.lastMotorRpm, loadFactor)
			g_effectManager:setDensity(spec.motorEffects, spec.lastMotorRpm)
		end

		self:raiseActive()
	end
end

function YarderTower:onYarderCarriageTreeAttached(treeId)
	local spec = self.spec_yarderTower
	spec.carriage.followModePickupPosition = spec.carriage.lastPosition

	spec.controlActivatable:updateActionEventTexts()
end

function YarderTower:onHookI3DLoaded(i3dNode, failedReason, hookData)
	if i3dNode ~= 0 then
		local hookNode = getChildAt(i3dNode, 0)

		link(getRootNode(), hookNode)
		setVisibility(hookNode, false)

		hookData.hookNode = hookNode

		delete(i3dNode)
	end
end

function YarderTower:onRopeI3DLoaded(i3dNode, failedReason, ropeData)
	if i3dNode ~= 0 then
		local ropeNode = I3DUtil.indexToObject(i3dNode, ropeData.ropeNodePath)

		if ropeNode ~= nil then
			link(ropeData.node or self.rootNode, ropeNode)
			setVisibility(ropeNode, false)

			ropeData.ropeNode = ropeNode
		end

		delete(i3dNode)
	end
end

function YarderTower:getIsSetupModeChangeAllowed()
	local spec = self.spec_yarderTower

	if spec.setupModeState then
		return true
	else
		if spec.requiresLowering and not self:getIsLowered() then
			return false, string.format(spec.texts.warningLowerFirst, self:getName())
		end

		if self.getFoldAnimTime ~= nil then
			local time = self:getFoldAnimTime()

			if time < spec.foldMinLimit or spec.foldMaxLimit < time then
				return false, string.format(spec.texts.warningUnfoldFirst, self:getName())
			end
		end
	end

	return true
end

function YarderTower:setYarderSetupModeState(state, canceled)
	local spec = self.spec_yarderTower

	if state == nil then
		state = not spec.setupModeState
	end

	spec.setupModeState = state

	if state then
		g_soundManager:playSample(spec.samples.setupStarted)
		self:setYarderTargetActive(false)
		self:setYarderRopeState(spec.setupRope, true)
		self:raiseActive()
	else
		self:setYarderRopeState(spec.setupRope, false)

		if not self.spec_yarderTower.isPlayerInRange then
			g_currentMission.activatableObjectsSystem:removeActivatable(spec.setupActivatable)
		end

		if canceled then
			g_soundManager:playSample(spec.samples.setupCanceled)
		end
	end
end

function YarderTower:setYarderTargetActive(state, noEventSend)
	local spec = self.spec_yarderTower

	if state then
		if spec.mainRope.isValid then
			local x = spec.mainRope.target[1]
			local y = spec.mainRope.target[2]
			local z = spec.mainRope.target[3]
			local shapeId = self:getTreeAtPosition(x, y, z, 3)

			if shapeId ~= nil and shapeId ~= 0 then
				local sx, sy, sz = getWorldTranslation(spec.mainRope.node)
				spec.mainRope.hookData = spec.hooks.treeData:clone()
				local centerX, centerY, centerZ = spec.mainRope.hookData:mountToTree(shapeId, x, y, z, 4, sx, sy, sz)

				if centerX == nil then
					return
				end

				spec.mainRope.hookData:setTargetNode(spec.mainRope.node, false)

				spec.mainRope.target[1], spec.mainRope.target[2], spec.mainRope.target[3] = spec.mainRope.hookData:getRopeTargetPosition()

				if spec.mainRope.sampleRopeLinkTree ~= nil then
					setWorldTranslation(spec.mainRope.sampleRopeLinkTree.soundNode, centerX, centerY, centerZ)
					g_soundManager:playSample(spec.mainRope.sampleRopeLinkTree)
				end

				spec.mainRope.isActive = true
				spec.mainRope.treeId = shapeId

				if spec.pushRope.ropeNode ~= nil then
					spec.pushRope.hookData = spec.hooks.treeData:clone()

					spec.pushRope.hookData:mountToTree(shapeId, x, y - spec.pushRope.yOffset, z, 4, sx, sy - spec.pushRope.yOffset, sz)
					self:setYarderRopeState(spec.pushRope, true)
				end

				g_soundManager:playSample(spec.samples.setupFinished)
				self:raiseActive()
				self:setYarderSetupModeState(false, false)
				self:setupSupportRopes()

				if self.isServer then
					if spec.carriage.filename ~= nil then
						local yRot = MathUtil.getYRotationFromDirection(MathUtil.vector2Normalize(x - sx, z - sz))
						local location = {
							x = spec.mainRope.target[1],
							z = spec.mainRope.target[3],
							yRot = yRot
						}

						VehicleLoadingUtil.loadVehicle(spec.carriage.filename, location, true, 0, Vehicle.PROPERTY_STATE_OWNED, self:getOwnerFarmId(), nil, , self.onCreateCarriageFinished, self)
					else
						Logging.error("Carriage vehicle could not be loaded")
					end

					for i = 1, #self.components do
						local component = self.components[i]

						setRigidBodyType(component.node, RigidBodyType.KINEMATIC)

						component.isDynamic = false
						component.isKinematic = true
					end
				end

				spec.updateRopesDirtyTime = 500

				g_currentMission.activatableObjectsSystem:addActivatable(spec.controlActivatable)
				YarderTowerSetTargetEvent.sendEvent(self, true, centerX, centerY, centerZ, noEventSend)
			end
		end

		spec.treeRaycast.hasStarted = false
		spec.treeRaycast.lastValidTree = nil
	else
		if self.isClient and spec.mainRope.isActive then
			g_soundManager:playSample(spec.samples.removeYarder)

			if g_soundManager:getIsSamplePlaying(spec.samples.motor) then
				g_soundManager:stopSample(spec.samples.motor)
				g_effectManager:stopEffects(spec.motorEffects)
			end
		end

		spec.mainRope.isValid = false
		spec.mainRope.isActive = false
		spec.mainRope.treeId = nil

		for i = 1, #spec.supportRopes.ropes do
			local supportRope = spec.supportRopes.ropes[i]

			self:setYarderRopeState(supportRope, false)

			supportRope.treeId = nil
		end

		self:setYarderRopeState(spec.pushRope, false)

		if spec.carriage.vehicle ~= nil then
			if self.isServer then
				g_currentMission:removeVehicle(spec.carriage.vehicle)
			end

			spec.carriage.vehicle = nil
			spec.carriage.lastPlayerInRange = false

			g_currentMission.hud.inputHelp:removeExtraExtensionVehicleNodeId(self.rootNode)
		end

		spec.carriage.position = 0

		g_currentMission.activatableObjectsSystem:removeActivatable(spec.controlActivatable)

		if self.isServer then
			for i = 1, #self.components do
				local component = self.components[i]

				setRigidBodyType(component.node, RigidBodyType.DYNAMIC)

				component.isDynamic = true
				component.isKinematic = false
			end
		end

		YarderTowerSetTargetEvent.sendEvent(self, false, 0, 0, 0, noEventSend)
	end

	self:setYarderRopeState(spec.mainRope, spec.mainRope.isActive)
	self:setYarderRopeState(spec.pullRope, spec.mainRope.isActive)
end

function YarderTower:setYarderCarriageFollowMode(state, connection, noEventSend)
	local spec = self.spec_yarderTower

	if state == nil then
		state = YarderTower.FOLLOW_MODE_NONE
	end

	spec.carriage.followModeState = state

	if state == YarderTower.FOLLOW_MODE_ME then
		if self.isServer then
			if connection ~= nil then
				for _, player in pairs(g_currentMission.players) do
					if player.networkInformation.creatorConnection == connection then
						spec.carriage.followModePlayer = player

						spec.carriage.followModePlayer:addDeleteListener(self, "onYarderTowerPlayerDeleted")
					end
				end
			else
				spec.carriage.followModePlayer = g_currentMission.player

				spec.carriage.followModePlayer:addDeleteListener(self, "onYarderTowerPlayerDeleted")
			end
		end

		if connection == nil then
			spec.carriage.followModeLocalPlayer = true
		end
	else
		if spec.carriage.followModePlayer ~= nil then
			spec.carriage.followModePlayer:removeDeleteListener(self, "onYarderTowerPlayerDeleted")
		end

		spec.carriage.followModePlayer = nil
		spec.carriage.followModeLocalPlayer = false
	end

	YarderTowerFollowModeEvent.sendEvent(self, state, noEventSend)
	spec.controlActivatable:updateActionEventTexts()
end

function YarderTower:setYarderCarriageMoveInput(direction)
	local spec = self.spec_yarderTower

	if direction ~= 0 and spec.carriage.followModeState ~= YarderTower.FOLLOW_MODE_NONE then
		self:setYarderCarriageFollowMode(YarderTower.FOLLOW_MODE_NONE)
	end

	spec.carriage.lastMoveInput = direction or 0
	spec.carriage.lastMoveInputTime = g_time

	if spec.carriage.lastMoveInput ~= 0 then
		self:raiseDirtyFlags(spec.dirtyFlag)
	end
end

function YarderTower:setYarderCarriageLiftInput(direction)
	local spec = self.spec_yarderTower
	spec.carriage.lastLiftInput = direction or 0
	spec.carriage.lastLiftInputTime = g_time

	if spec.carriage.lastLiftInput ~= 0 then
		self:raiseDirtyFlags(spec.dirtyFlag)
	end
end

function YarderTower:onYarderCarriageAttach()
	self.spec_yarderTower.carriage.vehicle:onAttachTreeAction()
end

function YarderTower:onYarderCarriageDetach()
	self.spec_yarderTower.carriage.vehicle:onDetachTreeAction()
end

function YarderTower:setupSupportRopes()
	local spec = self.spec_yarderTower
	local x, y, z = getWorldTranslation(spec.supportRopes.centerNode)

	for j = 1, #spec.supportRopes.ropes do
		self:setYarderRopeState(spec.supportRopes.ropes[j], false)
	end

	for i = #spec.supportRopes.foundTrees, 1, -1 do
		spec.supportRopes.foundTrees[i] = nil
	end

	overlapSphere(x, y, z, spec.supportRopes.treeRadius, "onSupportRopeTreeOverlapCallback", self, CollisionFlag.TREE, false, true, false, false, false)

	local function getBestTreeIndex(node, maxAngle)
		local minAngle = math.huge
		local minAngleTree = nil

		for j = 1, #spec.supportRopes.foundTrees do
			local treeId = spec.supportRopes.foundTrees[j]
			local tx, ty, tz = getWorldTranslation(treeId)
			local dx, _, dz = MathUtil.vector3Normalize(worldToLocal(node, tx, ty, tz))
			dx, dz = MathUtil.vector2Normalize(dx, dz)
			local angle = math.abs(MathUtil.getYRotationFromDirection(dx, dz))

			if angle < maxAngle and angle < minAngle then
				minAngle = angle
				minAngleTree = treeId
			end
		end

		return minAngleTree, minAngle
	end

	local function mountToTree(supportRope, targetTreeId)
		for j = 1, #spec.supportRopes.foundTrees do
			local treeId = spec.supportRopes.foundTrees[j]

			if treeId == targetTreeId then
				local tx, ty, tz = getWorldTranslation(treeId)
				ty = math.max(ty, getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tx, 0, tz))
				local centerX, centerY, centerZ, _, _, _, radius = SplitShapeUtil.getTreeOffsetPosition(treeId, tx, ty + supportRope.treeYOffset, tz, 3)

				if centerX ~= nil then
					self:setYarderRopeState(supportRope, true)

					local sx, sy, sz = getWorldTranslation(supportRope.node)
					supportRope.hookData = spec.hooks.treeData:clone()

					supportRope.hookData:mountToTree(treeId, centerX, centerY, centerZ, 4, sx, sy, sz)
					supportRope.hookData:setTargetNode(spec.mainRope.node, false)

					supportRope.treeId = treeId
					supportRope.target[1], supportRope.target[2], supportRope.target[3] = supportRope.hookData:getRopeTargetPosition()

					if supportRope.sampleRopeLinkTree ~= nil then
						setWorldTranslation(supportRope.sampleRopeLinkTree.soundNode, centerX, centerY, centerZ)
						g_soundManager:playSample(supportRope.sampleRopeLinkTree)
					end

					table.remove(spec.supportRopes.foundTrees, j)

					return true
				end
			end
		end

		return false
	end

	local treesToAttach = {}

	for i = 1, #spec.supportRopes.ropes do
		local supportRope = spec.supportRopes.ropes[i]
		local treeId, angle = getBestTreeIndex(supportRope.angleReferenceNode, supportRope.maxAngle)

		if treeId ~= nil then
			table.insert(treesToAttach, {
				supportRope = supportRope,
				treeId = treeId,
				angle = angle
			})
		end
	end

	table.sort(treesToAttach, function (a, b)
		return b.angle < a.angle
	end)

	local usedTrees = {}

	for i = #treesToAttach, 1, -1 do
		local treeData = treesToAttach[i]

		if usedTrees[treeData.treeId] == nil and mountToTree(treeData.supportRope, treeData.treeId) then
			usedTrees[treeData.treeId] = true

			table.remove(treesToAttach, i)
		end
	end

	for i = 1, #treesToAttach do
		local treeData = treesToAttach[i]
		local treeId, _ = getBestTreeIndex(treeData.supportRope.angleReferenceNode, treeData.supportRope.maxAngle)

		if treeId ~= nil then
			mountToTree(treeData.supportRope, treeId)
		end
	end

	for i = 1, #spec.supportRopes.ropes do
		local supportRope = spec.supportRopes.ropes[i]

		if not supportRope.isActive then
			if supportRope.rotNode ~= nil and supportRope.raycastRotY ~= nil then
				local rx, _, rz = getRotation(supportRope.rotNode)

				setRotation(supportRope.rotNode, rx, supportRope.raycastRotY, rz)

				if self.setMovingToolDirty ~= nil then
					self:setMovingToolDirty(supportRope.rotNode)
				end
			end

			local sx, sy, sz = getWorldTranslation(supportRope.raycastNode)
			local ex, ey, ez = localToWorld(supportRope.raycastNode, 0, 0, YarderTower.TERRAIN_RAYCAST_DISTANCE)
			ey = math.min(ey, getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, ex, 0, ez) - 0.25)
			local dx = ex - sx
			local dy = ey - sy
			local dz = ez - sz
			local distance = MathUtil.vector3Length(dx, dy, dz)
			dx, dy, dz = MathUtil.vector3Normalize(dx, dy, dz)

			raycastClosest(sx, sy, sz, dx, dy, dz, "onYarderSupportTerrainRaycastCallback", distance, supportRope, CollisionFlag.TERRAIN + CollisionFlag.STATIC_WORLD, false, true)
		end
	end
end

function YarderTower:onCreateCarriageFinished(vehicle, vehicleLoadState, arguments)
	if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_OK then
		local spec = self.spec_yarderTower
		spec.carriage.vehicle = vehicle

		vehicle:addDeleteListener(self, "onCarriageVehicleDeleted")
		vehicle:setYarderTowerVehicle(self)
		vehicle:removeFromPhysics()
	end
end

function YarderTower:onCarriageVehicleDeleted(rope, state)
	local spec = self.spec_yarderTower
	spec.carriage.vehicle = nil
	spec.carriage.lastPlayerInRange = nil

	g_currentMission.hud.inputHelp:removeExtraExtensionVehicleNodeId(self.rootNode)
end

function YarderTower:setYarderRopeState(rope, state)
	rope.isActive = state

	if rope.ropeNode ~= nil then
		setVisibility(rope.ropeNode, state)
	end

	if rope.rotNode ~= nil and not state then
		setRotation(rope.rotNode, unpack(rope.rotNodeInitRot))

		if self.setMovingToolDirty ~= nil then
			self:setMovingToolDirty(rope.rotNode)
		end
	end

	if not state then
		if rope.hookData ~= nil then
			rope.hookData:delete()

			rope.hookData = nil
		end

		self:updateYarderRopeLengthNodes(rope, 0)
	end

	ObjectChangeUtil.setObjectChanges(rope.changeObjects, state, self, self.setMovingToolDirty)
end

function YarderTower:updateYarderRope(rope, tx, ty, tz, dt, isSupportRope, emissiveColor)
	local x1, y1, z1 = getWorldTranslation(rope.node or rope.ropeNode)
	local totalRopeLength = MathUtil.vector3Length(tx - x1, ty - y1, tz - z1)
	local maxOffset = (rope.maxOffset or 0) * math.min(totalRopeLength / (rope.offsetReferenceLength or 0), 1)

	if totalRopeLength ~= rope.lastTotalRopeLength then
		local dirX, dirY, dirZ = MathUtil.vector3Normalize(tx - x1, ty - y1, tz - z1)

		if rope.rotNode ~= nil then
			local lDirX, lDirY, lDirZ = worldDirectionToLocal(getParent(rope.rotNode), dirX, dirY, dirZ)

			if rope.rotNodeAllAxis then
				lDirX, lDirY, lDirZ = MathUtil.vector3Normalize(lDirX, lDirY, lDirZ)

				setDirection(rope.rotNode, lDirX, lDirY, lDirZ, 0, 1, 0)
			else
				lDirX, lDirZ = MathUtil.vector2Normalize(lDirX, lDirZ)

				setDirection(rope.rotNode, lDirX, 0, lDirZ, 0, 1, 0)
			end

			if self.setMovingToolDirty ~= nil then
				self:setMovingToolDirty(rope.rotNode)
			end
		end

		if rope.ropeNode ~= nil then
			local lDirX, lDirY, lDirZ = worldDirectionToLocal(getParent(rope.ropeNode), dirX, dirY, dirZ)

			setDirection(rope.ropeNode, lDirX, lDirY, lDirZ, 0, 1, 0)
			g_animationManager:setPrevShaderParameter(rope.ropeNode, "ropeLengthBendSizeUv", totalRopeLength, -maxOffset, rope.diameter, 4, false, "prevRopeLengthBendSizeUv")

			local boundingRadius = math.max(math.ceil(totalRopeLength), 1) * 0.5

			if math.ceil(boundingRadius) ~= rope.boundingRadius then
				setShapeBoundingSphere(rope.ropeNode, 0, 0, boundingRadius, boundingRadius)

				rope.boundingRadius = boundingRadius
			end
		end

		self:updateYarderRopeLengthNodes(rope, totalRopeLength)

		rope.lastTotalRopeLength = totalRopeLength
	end

	return maxOffset
end

function YarderTower:updateYarderRopeLengthNodes(rope, length)
	if rope.ropeLengthNodes ~= nil then
		for i = 1, #rope.ropeLengthNodes do
			local ropeLengthNode = rope.ropeLengthNodes[i]
			local alpha = MathUtil.inverseLerp(ropeLengthNode.minLength, ropeLengthNode.maxLength, length)

			if ropeLengthNode.minRot ~= nil and ropeLengthNode.maxRot ~= nil then
				local x, y, z = MathUtil.vector3ArrayLerp(ropeLengthNode.minRot, ropeLengthNode.maxRot, alpha)

				setRotation(ropeLengthNode.node, x, y, z)
			end

			if ropeLengthNode.minTrans ~= nil and ropeLengthNode.maxTrans ~= nil then
				local x, y, z = MathUtil.vector3ArrayLerp(ropeLengthNode.minTrans, ropeLengthNode.maxTrans, alpha)

				setTranslation(ropeLengthNode.node, x, y, z)
			end

			if ropeLengthNode.minScale ~= nil and ropeLengthNode.maxScale ~= nil then
				local x, y, z = MathUtil.vector3ArrayLerp(ropeLengthNode.minScale, ropeLengthNode.maxScale, alpha)

				setScale(ropeLengthNode.node, x, y, z)
			end

			if ropeLengthNode.shaderParameterName ~= nil and ropeLengthNode.minShaderParameter ~= nil and ropeLengthNode.maxShaderParameter ~= nil then
				setShaderParameter(ropeLengthNode.node, ropeLengthNode.shaderParameterName, MathUtil.lerp(ropeLengthNode.minShaderParameter[1], ropeLengthNode.maxShaderParameter[1], alpha), MathUtil.lerp(ropeLengthNode.minShaderParameter[2], ropeLengthNode.maxShaderParameter[2], alpha), MathUtil.lerp(ropeLengthNode.minShaderParameter[3], ropeLengthNode.maxShaderParameter[3], alpha), MathUtil.lerp(ropeLengthNode.minShaderParameter[4], ropeLengthNode.maxShaderParameter[4], alpha), false)
			end
		end
	end
end

function YarderTower:getTreeAtPosition(x, y, z, maxRadius)
	local cx = x - maxRadius * 0.5
	local cy = y
	local cz = z - maxRadius * 0.5
	local nx = 0
	local ny = 1
	local nz = 0
	local yx = 0
	local yy = 0
	local yz = 1
	local shapeId, _, _, _, _ = findSplitShape(cx, cy, cz, nx, ny, nz, yx, yy, yz, maxRadius, maxRadius)

	return shapeId
end

function YarderTower:getIsPlayerInYarderRange()
	local spec = self.spec_yarderTower

	if self:getOwnerFarmId() ~= g_currentMission:getFarmId() then
		return false
	end

	return spec.isPlayerInRange or spec.setupModeState
end

function YarderTower:getIsPlayerInYarderControlRange(x, y, z)
	local spec = self.spec_yarderTower

	if spec.isPlayerInRange then
		return false, math.huge
	end

	if x == nil then
		if g_currentMission.player ~= nil then
			x, y, z = getWorldTranslation(g_currentMission.player.rootNode)
		else
			return false
		end
	end

	if self:getOwnerFarmId() ~= g_currentMission:getFarmId() then
		return false
	end

	local x1, _, z1 = getWorldTranslation(spec.mainRope.node)
	local x2 = spec.mainRope.target[1]
	local z2 = spec.mainRope.target[3]
	local tx, _, tz = MathUtil.getClosestPointOnLineSegment(x1, 0, z1, x2, 0, z2, x, y, z)
	local distance = MathUtil.vector2Length(x - tx, z - tz)

	return distance < YarderTower.MAX_CONTROL_DISTANCE, distance
end

function YarderTower:getYarderIsSetUp()
	return self.spec_yarderTower.carriage.vehicle ~= nil
end

function YarderTower:getYarderStatusInfo()
	local spec = self.spec_yarderTower
	local isLoaded = spec.carriage.vehicle ~= nil and #spec.carriage.vehicle.spec_yarderCarriage.attachedTrees > 0
	local targetPosition = nil

	if spec.carriage.followModeState == YarderTower.FOLLOW_MODE_HOME then
		targetPosition = 0
	elseif spec.carriage.followModeState == YarderTower.FOLLOW_MODE_PICKUP then
		targetPosition = spec.carriage.followModePickupPosition
	end

	local x, y, z = nil

	if g_currentMission.player ~= nil and g_currentMission.player.isEntered then
		x, y, z = getWorldTranslation(g_currentMission.player.rootNode)
	else
		return false, isLoaded, 0, spec.carriage.lastPosition, spec.carriage.followModeState, spec.carriage.followModeLocalPlayer, targetPosition
	end

	local x1, _, z1 = getWorldTranslation(spec.mainRope.node)
	local x2 = spec.mainRope.target[1]
	local z2 = spec.mainRope.target[3]
	local _, _, _, playerPosition = MathUtil.getClosestPointOnLineSegment(x1, 0, z1, x2, 0, z2, x, y, z)

	return true, isLoaded, playerPosition, spec.carriage.lastPosition, spec.carriage.followModeState, spec.carriage.followModeLocalPlayer, targetPosition
end

function YarderTower:getYarderMainRopeLength()
	local spec = self.spec_yarderTower

	if not spec.mainRope.isValid then
		return 0
	end

	local x1, y1, z1 = getWorldTranslation(spec.mainRope.node)
	local x2 = spec.mainRope.target[1]
	local y2 = spec.mainRope.target[2]
	local z2 = spec.mainRope.target[3]

	return MathUtil.vector3Length(x2 - x1, y2 - y1, z2 - z1)
end

function YarderTower:getYarderCarriageLastSpeed()
	return self.spec_yarderTower.carriage.lastSpeed
end

g_soundManager:registerModifierType("CARRIAGE_SPEED", YarderTower.getYarderCarriageLastSpeed)

function YarderTower:onYarderControlTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if (onEnter or onLeave) and g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
		local spec = self.spec_yarderTower

		if onEnter then
			self.spec_yarderTower.isPlayerInRange = true

			g_currentMission.activatableObjectsSystem:addActivatable(spec.setupActivatable)
		else
			self.spec_yarderTower.isPlayerInRange = false

			if not spec.setupModeState then
				g_currentMission.activatableObjectsSystem:removeActivatable(spec.setupActivatable)
			end
		end
	end
end

function YarderTower:onYarderTreeRaycastCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex, shapeId, isLast)
	local spec = self.spec_yarderTower

	if hitObjectId ~= 0 and getHasClassId(hitObjectId, ClassIds.SHAPE) and getSplitType(hitObjectId) ~= 0 and not getIsSplitShapeSplit(hitObjectId) then
		if isLast then
			spec.treeRaycast.hasStarted = false
			spec.treeRaycast.lastValidTree = hitObjectId
			spec.treeRaycast.lastValidTreeHeight = y
		end

		return false
	end

	if isLast then
		spec.treeRaycast.hasStarted = false
		spec.treeRaycast.lastValidTree = nil
	end
end

function YarderTower:doRopePlacementValidation(ropeNode, treeId, ex, ey, ez, maxAngle, maxLength, clearance, minTreeDiameter, callbackData)
	if not callbackData.hasStarted then
		local sx, sy, sz = getWorldTranslation(ropeNode)

		if ey > sy + self.spec_yarderTower.placementMinHeightOffset then
			return callbackData.callback(callbackData.vehicle, false, ex, ey, ez, YarderTower.FAILED_REASON_ONLY_UPHILL_YARDING)
		end

		local dx, dz = MathUtil.vector2Normalize(sx - ex, sz - ez)
		local ldx, _, ldz = worldDirectionToLocal(ropeNode, dx, 0, dz)
		local angle = math.pi - math.abs(MathUtil.getYRotationFromDirection(ldx, ldz))
		local centerX, centerY, centerZ, _, _, _, radius = SplitShapeUtil.getTreeOffsetPosition(treeId, ex, ey, ez, 3)

		if centerX ~= nil and minTreeDiameter <= radius * 2 then
			dx, dz = MathUtil.vector2Normalize(sx - centerX, sz - centerZ)
			ez = centerZ + dz * radius
			ey = centerY
			ex = centerX + dx * radius

			if angle < maxAngle then
				local length = MathUtil.vector3Length(ex - sx, ey - sy, ez - sz)

				if length < maxLength then
					local wdx, wdy, wdz = MathUtil.vector3Normalize(ex - sx, ey - sy, ez - sz)
					callbackData.z = ez
					callbackData.y = ey
					callbackData.x = ex
					callbackData.hasStarted = true
					callbackData.onYarderMainTreeRaycastCallback = YarderTower.onYarderMainTreeRaycastCallback

					raycastClosest(sx, sy - 2, sz, wdx, wdy, wdz, "onYarderMainTreeRaycastCallback", length - 0.5, callbackData, CollisionFlag.STATIC_WORLD + CollisionFlag.DYNAMIC_OBJECT, false, true)
				else
					callbackData.callback(callbackData.vehicle, false, ex, ey, ez, YarderTower.FAILED_REASON_TOO_LONG)
				end
			else
				callbackData.callback(callbackData.vehicle, false, ex, ey, ez, YarderTower.FAILED_REASON_WRONG_ANGLE)
			end
		else
			callbackData.callback(callbackData.vehicle, false, ex, ey, ez, YarderTower.FAILED_REASON_TREE_TOO_SMALL)
		end
	end
end

function YarderTower.onYarderMainTreeRaycastCallback(callbackData, hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex, shapeId, isLast)
	callbackData.hasStarted = false

	if hitObjectId ~= 0 then
		return callbackData.callback(callbackData.vehicle, false, callbackData.x, callbackData.y, callbackData.z, YarderTower.FAILED_REASON_WAY_BLOCKED)
	end

	if hitObjectId == 0 and isLast then
		return callbackData.callback(callbackData.vehicle, true, callbackData.x, callbackData.y, callbackData.z, YarderTower.FAILED_REASON_NONE)
	end
end

function YarderTower:onMainRopePlacementValidated(isValid, x, y, z, reason)
	local spec = self.spec_yarderTower

	if spec.setupModeState then
		spec.mainRope.isValid = isValid
		spec.mainRope.target[1] = x
		spec.mainRope.target[2] = y
		spec.mainRope.target[3] = z
	end

	if not isValid then
		if reason == YarderTower.FAILED_REASON_TOO_LONG then
			g_currentMission:showBlinkingWarning(spec.texts.warningRopeTooLong, 1000)
		elseif reason == YarderTower.FAILED_REASON_WRONG_ANGLE then
			g_currentMission:showBlinkingWarning(spec.texts.warningWrongAngle, 1000)
		elseif reason == YarderTower.FAILED_REASON_TREE_TOO_SMALL then
			g_currentMission:showBlinkingWarning(spec.texts.warningTreeTooSmall, 1000)
		elseif reason == YarderTower.FAILED_REASON_WAY_BLOCKED then
			g_currentMission:showBlinkingWarning(spec.texts.warningWayIsBlocked, 1000)
		elseif reason == YarderTower.FAILED_REASON_ONLY_UPHILL_YARDING then
			g_currentMission:showBlinkingWarning(spec.texts.warningOnlyForUphillYarding, 1000)
		end
	end

	spec.setupRope.diameter = spec.setupRope.diameterTree
end

function YarderTower.onYarderSupportTerrainRaycastCallback(supportRope, hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex, shapeId, isLast)
	if hitObjectId ~= 0 and getHasClassId(hitObjectId, ClassIds.TERRAIN_TRANSFORM_GROUP) then
		supportRope.vehicle:setYarderRopeState(supportRope, true)

		local sx, _, sz = getWorldTranslation(supportRope.node)
		local spec = supportRope.vehicle.spec_yarderTower
		supportRope.hookData = spec.hooks.groundData:clone()

		supportRope.hookData:setPositionAndDirection(x, y, z, MathUtil.vector2Normalize(sx - x, sz - z))
		supportRope.hookData:setTargetNode(supportRope.node, false)

		supportRope.target[1], supportRope.target[2], supportRope.target[3] = supportRope.hookData:getRopeTargetPosition()

		if supportRope.sampleRopeLinkGround ~= nil then
			setWorldTranslation(supportRope.sampleRopeLinkGround.soundNode, x, y, z)
			g_soundManager:playSample(supportRope.sampleRopeLinkGround)
		end

		return false
	end

	if isLast and not supportRope.isActive then
		supportRope.vehicle:setYarderRopeState(supportRope, false)
	end
end

function YarderTower:onSupportRopeTreeOverlapCallback(objectId, ...)
	local spec = self.spec_yarderTower

	if objectId ~= spec.mainRope.treeId then
		table.insert(spec.supportRopes.foundTrees, objectId)
	end
end

function YarderTower:onYarderTowerPlayerDeleted()
	self:setYarderCarriageFollowMode(YarderTower.FOLLOW_MODE_NONE)
end

function YarderTower:isDetachAllowed(superFunc)
	local detachAllowed, warning, showWarning = superFunc(self)

	if not detachAllowed then
		return detachAllowed, warning, showWarning
	end

	local spec = self.spec_yarderTower

	if spec.requiresAttacherVehicle and spec.mainRope.isActive then
		return false, spec.texts.warningDetachNotAllowed
	end

	return true
end

function YarderTower:getIsFoldAllowed(superFunc, direction, onAiTurnOn)
	local spec = self.spec_yarderTower

	if spec.mainRope.isActive then
		return false
	end

	return superFunc(self, direction, onAiTurnOn)
end

function YarderTower:getAllowsLowering(superFunc)
	local spec = self.spec_yarderTower

	if spec.mainRope.isActive then
		return false
	end

	return superFunc(self)
end

function YarderTower:getDoConsumePtoPower(superFunc)
	local spec = self.spec_yarderTower

	if spec.mainRope.isActive then
		return true
	end

	return superFunc(self)
end

function YarderTower:getConsumingLoad(superFunc)
	local value, count = superFunc(self)
	local spec = self.spec_yarderTower
	local loadPercentage = 0

	if spec.mainRope.isActive then
		loadPercentage = 0.05 + spec.carriage.lastSpeed * 0.95
	end

	return value + loadPercentage, count + 1
end

function YarderTower:getIsPowerTakeOffActive(superFunc)
	local spec = self.spec_yarderTower

	if spec.mainRope.isActive then
		local attacherVehicle = self:getAttacherVehicle()

		if attacherVehicle ~= nil and attacherVehicle.getIsMotorStarted ~= nil and attacherVehicle:getIsMotorStarted() then
			return true
		end
	end

	return superFunc(self)
end

function YarderTower:getDirtMultiplier(superFunc)
	local multiplier = superFunc(self)
	local spec = self.spec_yarderTower

	if spec.mainRope.isActive then
		multiplier = multiplier + spec.carriage.lastSpeed * self:getWorkDirtMultiplier()
	end

	return multiplier
end

function YarderTower:getWearMultiplier(superFunc)
	local multiplier = superFunc(self)
	local spec = self.spec_yarderTower

	if spec.mainRope.isActive then
		multiplier = multiplier + spec.carriage.lastSpeed * self:getWorkWearMultiplier()
	end

	return multiplier
end

function YarderTower:getUsageCausesDamage(superFunc)
	local spec = self.spec_yarderTower

	if spec.mainRope.isActive then
		return spec.carriage.lastPositionTimeOffset > 0 and self.propertyState ~= Vehicle.PROPERTY_STATE_MISSION
	end

	return superFunc(self)
end

function YarderTower.loadSpecValueMaxLength(xmlFile, customEnvironment, baseDir)
	return xmlFile:getValue("vehicle.yarderTower.ropes.mainRope#maxLength")
end

function YarderTower.getSpecValueMaxLength(storeItem, realItem, configurations, saleItem, returnValues, returnRange)
	if storeItem.specs.yarderMaxLength ~= nil then
		local maxLength = storeItem.specs.yarderMaxLength
		local str = string.format("%d%s", maxLength, g_i18n:getText("unit_mShort"))

		if returnValues and returnRange then
			return maxLength, maxLength, str
		elseif returnValues then
			return maxLength, str
		elseif maxLength ~= 0 then
			return str
		end
	end
end

function YarderTower.loadSpecValueMaxMass(xmlFile, customEnvironment, baseDir)
	return xmlFile:getValue("vehicle.yarderTower.carriage#maxTreeMass")
end

function YarderTower.getSpecValueMaxMass(storeItem, realItem, configurations, saleItem, returnValues, returnRange)
	if storeItem.specs.yarderMaxMass ~= nil then
		local maxTreeMass = storeItem.specs.yarderMaxMass
		local str = string.format("%.1f%s", maxTreeMass, g_i18n:getText("unit_tonsShort"))

		if returnValues and returnRange then
			return maxTreeMass, maxTreeMass, str
		elseif returnValues then
			return maxTreeMass, str
		elseif maxTreeMass ~= 0 then
			return str
		end
	end
end

ShopConfigScreen.registerCustomSpecValues = Utils.overwrittenFunction(ShopConfigScreen.registerCustomSpecValues, function (self, superFunc, values, storeItems, vehicle, saleItem)
	superFunc(self, values, storeItems, vehicle, saleItem)

	local maxYarderLength = 0
	local maxTreeMass = 0

	for itemIndex, storeItem in ipairs(storeItems) do
		local realItem = self.previewVehicles[itemIndex] or vehicle

		if storeItem.specs ~= nil then
			if storeItem.specs.yarderMaxLength ~= nil then
				maxYarderLength = math.max(YarderTower.getSpecValueMaxLength(storeItem, realItem, self.configurations, saleItem, true, false) or 0, maxYarderLength)
			end

			if storeItem.specs.yarderMaxMass ~= nil then
				maxTreeMass = math.max(YarderTower.getSpecValueMaxMass(storeItem, realItem, self.configurations, saleItem, true, false) or 0, maxTreeMass)
			end
		end
	end

	if maxYarderLength ~= 0 then
		table.insert(values, {
			profile = "shopConfigAttributeIconMaxMaxLength",
			value = string.format("%d%s", maxYarderLength, g_i18n:getText("unit_mShort"))
		})
	end

	if maxTreeMass ~= 0 then
		table.insert(values, {
			profile = "shopConfigAttributeIconMaxMaxMass",
			value = string.format("%.1f%s", maxTreeMass, g_i18n:getText("unit_tonsShort"))
		})
	end
end)
Chainsaw.isCuttingAllowed = Utils.overwrittenFunction(Chainsaw.isCuttingAllowed, function (self, superFunc, x, y, z, shape)
	if not superFunc(self, x, y, z, shape) then
		return false
	end

	for i = 1, #g_currentMission.vehicles do
		local vehicle = g_currentMission.vehicles[i]

		if vehicle.spec_yarderTower ~= nil then
			local spec = vehicle.spec_yarderTower

			if shape == spec.mainRope.treeId then
				return false
			end

			for j = 1, #spec.supportRopes.ropes do
				local supportRope = spec.supportRopes.ropes[j]

				if supportRope.treeId == shape then
					return false
				end
			end
		end
	end

	return true
end)
WoodHarvester.getCanSplitShapeBeAccessed = Utils.overwrittenFunction(WoodHarvester.getCanSplitShapeBeAccessed, function (self, superFunc, x, z, shape)
	if not superFunc(self, x, z, shape) then
		return false
	end

	for i = 1, #g_currentMission.vehicles do
		local vehicle = g_currentMission.vehicles[i]

		if vehicle.spec_yarderTower ~= nil then
			local spec = vehicle.spec_yarderTower

			if shape == spec.mainRope.treeId then
				return false
			end

			for j = 1, #spec.supportRopes.ropes do
				local supportRope = spec.supportRopes.ropes[j]

				if supportRope.treeId == shape then
					return false
				end
			end
		end
	end

	return true
end)

local function getIsActiveYarderAttached(self)
	for i = 1, #self.childVehicles do
		local vehicle = self.childVehicles[i]

		if vehicle.spec_yarderTower ~= nil and vehicle.spec_yarderTower.mainRope.isActive then
			return true, vehicle.spec_yarderTower.texts.warningDoNotMoveVehicle
		end
	end

	return false, nil
end

Drivable.setAccelerationPedalInput = Utils.overwrittenFunction(Drivable.setAccelerationPedalInput, function (self, superFunc, inputValue)
	local activeYarderIsAttached, warning = getIsActiveYarderAttached(self)

	if inputValue ~= 0 and activeYarderIsAttached then
		g_currentMission:showBlinkingWarning(warning, 2000)

		return
	end

	superFunc(self, inputValue)
end)
Drivable.setBrakePedalInput = Utils.overwrittenFunction(Drivable.setBrakePedalInput, function (self, superFunc, inputValue)
	local activeYarderIsAttached, warning = getIsActiveYarderAttached(self)

	if inputValue ~= 0 and activeYarderIsAttached then
		g_currentMission:showBlinkingWarning(warning, 2000)

		return
	end

	superFunc(self, inputValue)
end)
Drivable.setSteeringInput = Utils.overwrittenFunction(Drivable.setSteeringInput, function (self, superFunc, inputValue, isAnalog, deviceCategory)
	local activeYarderIsAttached, warning = getIsActiveYarderAttached(self)

	if inputValue ~= 0 and activeYarderIsAttached then
		g_currentMission:showBlinkingWarning(warning, 2000)

		return
	end

	superFunc(self, inputValue, isAnalog, deviceCategory)
end)
Drivable.actionEventCruiseControlState = Utils.overwrittenFunction(Drivable.actionEventCruiseControlState, function (self, superFunc, actionName, inputValue, callbackState, isAnalog)
	local activeYarderIsAttached, warning = getIsActiveYarderAttached(self)

	if inputValue ~= 0 and activeYarderIsAttached then
		g_currentMission:showBlinkingWarning(warning, 2000)

		return
	end

	superFunc(self, actionName, inputValue, callbackState, isAnalog)
end)
