local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

RollercoasterStateBuilding = {}
local RollercoasterStateBuilding_mt = Class(RollercoasterStateBuilding, RollercoasterState)

function RollercoasterStateBuilding.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".toggleMesh(?)#node", "")
	schema:register(XMLValueType.BOOL, basePath .. ".toggleMesh(?)#active", "")
	schema:register(XMLValueType.BOOL, basePath .. ".toggleMesh(?)#updatePhysics", "", false)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".mesh(?)#node", "")
	schema:register(XMLValueType.INT, basePath .. ".mesh(?)#indexMin", "")
	schema:register(XMLValueType.INT, basePath .. ".mesh(?)#indexMax", "")
	schema:register(XMLValueType.INT, basePath .. ".mesh(?)#direction", "")
	schema:register(XMLValueType.STRING, basePath .. ".input(?)#fillType", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".input(?)#amount", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".input(?)#usagePerHour", "")
end

function RollercoasterStateBuilding.registerSavegameXMLPaths(schema, basePath)
	schema:register(XMLValueType.STRING, basePath .. ".state.input(?)#fillType", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".state.input(?)#remainingAmount", "")
end

function RollercoasterStateBuilding.new(rollercoaster, customMt)
	local self = RollercoasterState.new(rollercoaster, customMt or RollercoasterStateBuilding_mt)

	return self
end

function RollercoasterStateBuilding:load(xmlFile, key)
	RollercoasterStateBuilding:superClass().load(self, xmlFile, key)

	self.totalAmount = 0
	self.inputs = {}
	self.hasInputMaterials = true

	xmlFile:iterate(key .. ".input", function (_, inputKey)
		local fillTypeStr = xmlFile:getValue(inputKey .. "#fillType")
		local fillType = g_fillTypeManager:getFillTypeByName(fillTypeStr)

		if fillType == nil then
			Logging.xmlWarning(xmlFile, "Unknown fillType '%s' in '%s'", fillTypeStr, inputKey)

			return
		end

		if not self.rollercoaster[PlaceableRollercoaster.SPEC].storage:getIsFillTypeSupported(fillType.index) then
			Logging.xmlWarning(xmlFile, "Filltype '%s' in '%s' not supported by storage", fillType.name, inputKey)

			return
		end

		local amount = xmlFile:getValue(inputKey .. "#amount")
		local usagePerSecond = xmlFile:getValue(inputKey .. "#usagePerHour") / 60 / 60
		self.totalAmount = self.totalAmount + amount

		table.insert(self.inputs, {
			fillType = fillType,
			amount = amount,
			remainingAmount = amount,
			lastSyncedAmount = amount,
			usagePerSecond = usagePerSecond,
			infoTableEntry = {
				title = fillType.title,
				text = g_i18n:formatVolume(amount)
			}
		})
	end)

	self.meshes = {}
	self.toggleMeshes = {}

	xmlFile:iterate(key .. ".mesh", function (_, nodeKey)
		local node = xmlFile:getValue(nodeKey .. "#node", nil, self.components, self.i3dMappings)

		if not getHasClassId(node, ClassIds.SHAPE) then
			Logging.xmlError(xmlFile, "node '%s' at '%s' is not a shape", getName(node), nodeKey)

			return
		end

		if not getHasShaderParameter(node, "hideByIndex") then
			Logging.xmlError(xmlFile, "mesh '%s' at '%s' does not have required shader parameter 'hideByIndex'", getName(node), nodeKey)

			return
		end

		local indexMin = xmlFile:getValue(nodeKey .. "#indexMin", 0)
		local indexMax = xmlFile:getValue(nodeKey .. "#indexMax")
		local direction = xmlFile:getValue(nodeKey .. "#direction", 1)
		local mesh = {
			lastValue = -1,
			node = node,
			childIndex = getChildIndex(node),
			index = #self.meshes + 1,
			indexMin = indexMin,
			indexMax = indexMax,
			direction = direction,
			dirtyFlag = self.rollercoaster:getNextDirtyFlag(),
			numBits = MathUtil.getNumRequiredBits(indexMax)
		}

		self:setMeshProgress(mesh, 0)
		table.insert(self.meshes, mesh)
	end)
	xmlFile:iterate(key .. ".toggleMesh", function (_, nodeKey)
		local node = xmlFile:getValue(nodeKey .. "#node", nil, self.components, self.i3dMappings)
		local active = xmlFile:getValue(nodeKey .. "#active", true)
		local physics = xmlFile:getValue(nodeKey .. "#updatePhysics", false)
		local collision = {
			node = node,
			active = active,
			physics = physics
		}

		table.insert(self.toggleMeshes, collision)
	end)

	self.infoBoxRequiredGoods = {
		accentuate = true,
		title = g_i18n:getText("infohud_requiredMaterialsNextStep")
	}
end

function RollercoasterStateBuilding:saveToXMLFile(xmlFile, key, usedModNames)
	xmlFile:setSortedTable(key .. ".state.input", self.inputs, function (inputKey, input)
		xmlFile:setValue(inputKey .. "#fillType", input.fillType.name)
		xmlFile:setValue(inputKey .. "#remainingAmount", input.remainingAmount)
	end)
end

function RollercoasterStateBuilding:loadFromXMLFile(xmlFile, key)
	xmlFile:iterate(key .. ".state.input", function (index, inputKey)
		local fillType = g_fillTypeManager:getFillTypeByName(xmlFile:getValue(inputKey .. "#fillType"))
		local remainingAmount = xmlFile:getValue(inputKey .. "#remainingAmount")

		for _, input in ipairs(self.inputs) do
			if input.fillType == fillType then
				self:updateRemainingAmount(input, remainingAmount)
			end
		end
	end)
end

function RollercoasterStateBuilding:isDone()
	for _, input in ipairs(self.inputs) do
		if input.remainingAmount > 0 then
			return false
		end
	end

	return true
end

function RollercoasterStateBuilding:onReadStream(streamId, connection)
	for i, input in ipairs(self.inputs) do
		self:updateRemainingAmount(input, streamReadFloat32(streamId))
	end

	for meshIndex, mesh in ipairs(self.meshes) do
		local hideByIndexValue = streamReadUIntN(streamId, mesh.numBits)
		local progress = MathUtil.inverseLerp(mesh.indexMax, mesh.indexMin, hideByIndexValue)

		if mesh.direction == -1 then
			progress = 1 - progress
		end

		self:setMeshProgress(mesh, progress)
	end
end

function RollercoasterStateBuilding:onWriteStream(streamId, connection)
	for i, input in ipairs(self.inputs) do
		streamWriteFloat32(streamId, input.remainingAmount)
	end

	for meshIndex, mesh in ipairs(self.meshes) do
		streamWriteUIntN(streamId, mesh.lastValue, mesh.numBits)
	end
end

function RollercoasterStateBuilding:onReadUpdateStream(streamId, timestamp, connection)
	for i, input in ipairs(self.inputs) do
		self:updateRemainingAmount(input, streamReadFloat32(streamId))
	end

	for meshIndex, mesh in ipairs(self.meshes) do
		if streamReadBool(streamId) then
			local hideByIndexValue = streamReadUIntN(streamId, mesh.numBits)
			local progress = MathUtil.inverseLerp(mesh.indexMax, mesh.indexMin, hideByIndexValue)

			if mesh.direction == -1 then
				progress = 1 - progress
			end

			self:setMeshProgress(mesh, progress)
		end
	end
end

function RollercoasterStateBuilding:onWriteUpdateStream(streamId, connection, dirtyMask)
	for i, input in ipairs(self.inputs) do
		streamWriteFloat32(streamId, input.remainingAmount)
	end

	for _, mesh in ipairs(self.meshes) do
		if streamWriteBool(streamId, bitAND(dirtyMask, mesh.dirtyFlag) ~= 0) then
			streamWriteUIntN(streamId, mesh.lastValue, mesh.numBits)
		end
	end
end

function RollercoasterStateBuilding:raiseActive()
	return self.hasInputMaterials
end

function RollercoasterStateBuilding:getPlaySound()
	return self.hasInputMaterials
end

function RollercoasterStateBuilding:update(dt)
	local usedAmount = 0
	self.hasInputMaterials = false

	for i, input in ipairs(self.inputs) do
		usedAmount = usedAmount + input.amount - input.remainingAmount

		if input.remainingAmount > 0 then
			local amount = input.usagePerSecond / 1000 * dt * g_currentMission.missionInfo.timeScale
			local delta = self.rollercoaster:removeFillLevel(input.fillType.index, amount)

			if delta > 0 then
				self.hasInputMaterials = true

				self:updateRemainingAmount(input, input.remainingAmount - delta)

				if math.abs(input.remainingAmount - input.lastSyncedAmount) > input.amount / 100 or input.remainingAmount <= 0.01 or input.remainingAmount == input.amount then
					self.rollercoaster:raiseDirtyFlags(self.dirtyFlag)

					input.lastSyncedAmount = input.remainingAmount
				end
			end
		end
	end

	for _, mesh in ipairs(self.meshes) do
		self:setMeshProgress(mesh, usedAmount / self.totalAmount)
	end

	RollercoasterStateBuilding:superClass().update(self, dt)
end

function RollercoasterStateBuilding:activate()
	RollercoasterStateBuilding:superClass().activate(self)

	for _, toggleMesh in ipairs(self.toggleMeshes) do
		if toggleMesh.active then
			if toggleMesh.physics then
				addToPhysics(toggleMesh.node)
			end

			setVisibility(toggleMesh.node, true)
		else
			if toggleMesh.physics then
				removeFromPhysics(toggleMesh.node)
			end

			setVisibility(toggleMesh.node, false)
		end
	end
end

function RollercoasterStateBuilding:deactivate()
	for i, input in ipairs(self.inputs) do
		self:updateRemainingAmount(input, input.amount)
	end

	for _, mesh in ipairs(self.meshes) do
		self:setMeshProgress(mesh, 1)
	end

	RollercoasterStateBuilding:superClass().deactivate(self)
end

function RollercoasterStateBuilding:updateInfo(infoTable)
	table.insert(infoTable, self.infoBoxRequiredGoods)

	for i, input in ipairs(self.inputs) do
		if input.remainingAmount > 0 then
			table.insert(infoTable, input.infoTableEntry)
		end
	end
end

function RollercoasterStateBuilding:updateRemainingAmount(input, amount)
	input.remainingAmount = math.max(0, amount)
	input.infoTableEntry.text = g_i18n:formatVolume(input.remainingAmount)
end

function RollercoasterStateBuilding:setMeshProgress(mesh, percentage)
	if mesh ~= nil then
		if mesh.direction == -1 then
			percentage = 1 - percentage
		end

		local hideByIndexValue = MathUtil.round(MathUtil.lerp(mesh.indexMax, mesh.indexMin, percentage))

		if hideByIndexValue ~= mesh.lastValue then
			local node = mesh.node

			setVisibility(node, percentage ~= 0)

			mesh.lastValue = hideByIndexValue

			setShaderParameter(node, "hideByIndex", hideByIndexValue, 0, 0, 0, false)

			if self.isServer then
				self.rollercoaster:raiseDirtyFlags(mesh.dirtyFlag)
				self.rollercoaster:raiseDirtyFlags(self.dirtyFlag)
			end
		end
	end
end
