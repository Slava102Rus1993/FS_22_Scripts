CropSensorLinkageData = {
	MOD_NAME = g_currentModName,
	BASE_DIRECTORY = g_currentModDirectory,
	xmlSchema = nil
}
local CropSensorLinkageData_mt = Class(CropSensorLinkageData)

function CropSensorLinkageData.new(precisionFarming, customMt)
	local self = setmetatable({}, customMt or CropSensorLinkageData_mt)
	self.precisionFarming = precisionFarming
	self.configurationPrice = 0
	self.sensorData = {}
	self.linkageData = {}
	self.dataLoaded = false
	CropSensorLinkageData.xmlSchema = XMLSchema.new("cropSensorLinkageData")

	self:registerXMLPaths(CropSensorLinkageData.xmlSchema)

	return self
end

function CropSensorLinkageData:delete()
	for i = 1, #self.sensorData do
		delete(self.sensorData[i].node)
	end

	self.sensorData = {}
	self.linkageData = {}
end

function CropSensorLinkageData:loadFromXML(_, _, baseDirectory, configFileName, mapFilename)
	if not self.dataLoaded then
		self:loadLinkageData()
	end
end

function CropSensorLinkageData:loadLinkageData(loadVehicleData, loadSensorData)
	local filename = Utils.getFilename("CropSensorLinkageData.xml", CropSensorLinkageData.BASE_DIRECTORY)
	local xmlFile = XMLFile.load("CropSensorLinkageData", filename, CropSensorLinkageData.xmlSchema)

	if xmlFile ~= nil then
		self.configurationPrice = xmlFile:getValue("cropSensorLinkageData.configuration#price", 0)

		if loadVehicleData ~= false then
			self.linkageData = {}

			xmlFile:iterate("cropSensorLinkageData.vehicles.vehicle", function (index, key)
				local vehicleData = {
					filename = xmlFile:getValue(key .. "#filename")
				}

				if vehicleData.filename ~= nil then
					vehicleData.linkNodes = {}

					xmlFile:iterate(key .. ".linkNode", function (_, linkNodeKey)
						local linkNode = {
							nodeName = xmlFile:getValue(linkNodeKey .. "#node"),
							typeName = xmlFile:getValue(linkNodeKey .. "#type", "SENSOR_LEFT"):upper(),
							translation = xmlFile:getValue(linkNodeKey .. "#translation", "0 0 0", true),
							rotation = xmlFile:getValue(linkNodeKey .. "#rotation", "0 0 0", true),
							rotationNodes = {}
						}

						xmlFile:iterate(linkNodeKey .. ".rotationNode", function (_, rotationNodeKey)
							local rotatioNode = {
								autoRotate = xmlFile:getValue(rotationNodeKey .. "#autoRotate"),
								rotation = xmlFile:getValue(rotationNodeKey .. "#rotation", nil, true)
							}

							table.insert(linkNode.rotationNodes, rotatioNode)
						end)
						table.insert(vehicleData.linkNodes, linkNode)
					end)
				end

				table.insert(self.linkageData, vehicleData)
			end)
		end

		if loadSensorData ~= false then
			local sensorsFilename = xmlFile:getValue("cropSensorLinkageData.sensors#filename")

			if sensorsFilename ~= nil then
				sensorsFilename = Utils.getFilename(sensorsFilename, CropSensorLinkageData.BASE_DIRECTORY)

				g_i3DManager:loadI3DFileAsync(sensorsFilename, true, true, CropSensorLinkageData.onSensorDataLoaded, self, {
					xmlFile
				})
			else
				xmlFile:delete()
			end
		else
			xmlFile:delete()
		end
	end

	self.dataLoaded = true

	return true
end

function CropSensorLinkageData:onSensorDataLoaded(i3dNode, failedReason, args)
	local xmlFile = unpack(args)

	if i3dNode ~= 0 then
		xmlFile:iterate("cropSensorLinkageData.sensors.sensor", function (index, key)
			local sensorData = {
				node = xmlFile:getValue(key .. "#node", nil, i3dNode)
			}

			if sensorData.node ~= nil then
				sensorData.type = xmlFile:getValue(key .. "#type", "SENSOR_LEFT")
				sensorData.measurementNodePath = xmlFile:getValue(key .. "#measurementNode")
				sensorData.requiresDaylight = xmlFile:getValue(key .. "#requiresDaylight", true)
				sensorData.rotationNodes = {}

				xmlFile:iterate(key .. ".rotationNode", function (_, rotationNodeKey)
					local rotationNode = {
						nodePath = xmlFile:getValue(rotationNodeKey .. "#node"),
						autoRotate = xmlFile:getValue(rotationNodeKey .. "#autoRotate")
					}

					table.insert(sensorData.rotationNodes, rotationNode)
				end)
				table.insert(self.sensorData, sensorData)
			end
		end)

		for i = 1, #self.sensorData do
			unlink(self.sensorData[i].node)
		end

		delete(i3dNode)
	end

	xmlFile:delete()
end

function CropSensorLinkageData:getCropSensorLinkageData(configFileName)
	for i = 1, #self.linkageData do
		local vehicleData = self.linkageData[i]

		if configFileName:endsWith(vehicleData.filename) then
			return vehicleData
		end
	end
end

function CropSensorLinkageData:getClonedCropSensorNode(typeName)
	for i = 1, #self.sensorData do
		local sensorData = self.sensorData[i]

		if sensorData.type:upper() == typeName:upper() then
			local clonedData = table.copy(sensorData, 10)
			clonedData.node = clone(sensorData.node, false, false, false)

			for j = 1, #clonedData.rotationNodes do
				local rotationNode = clonedData.rotationNodes[j]
				rotationNode.node = I3DUtil.indexToObject(clonedData.node, rotationNode.nodePath)
			end

			if clonedData.measurementNodePath ~= nil then
				clonedData.measurementNode = I3DUtil.indexToObject(clonedData.node, clonedData.measurementNodePath)
			end

			return clonedData
		end
	end
end

function CropSensorLinkageData:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(FSBaseMission, "consoleCommandReloadVehicle", function (superFunc, mission, resetVehicle, radius)
		self:loadLinkageData(true, false)

		return superFunc(mission, resetVehicle, radius)
	end)
	pfModule:overwriteGameFunction(StoreItemUtil, "getConfigurationsFromXML", function (superFunc, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)
		local configurations, defaultConfigurationIds = superFunc(xmlFile, key, baseDir, customEnvironment, isMod, storeItem)

		if not self.dataLoaded then
			self:loadLinkageData(true)
		end

		local vehicleData = self:getCropSensorLinkageData(xmlFile.filename)

		if vehicleData ~= nil then
			if configurations == nil then
				configurations = {}
			end

			if defaultConfigurationIds == nil then
				defaultConfigurationIds = {}
			end

			configurations.cropSensor = {
				{
					isDefault = true,
					saveId = "1",
					isSelectable = true,
					index = 1,
					dailyUpkeep = 0,
					price = 0,
					name = g_i18n:getText("configuration_valueNo"),
					nameCompareParams = {}
				},
				{
					isDefault = false,
					saveId = "2",
					isSelectable = true,
					index = 2,
					dailyUpkeep = 0,
					name = g_i18n:getText("configuration_valueYes"),
					price = self.configurationPrice,
					nameCompareParams = {}
				}
			}
		end

		return configurations, defaultConfigurationIds
	end)
end

function CropSensorLinkageData:registerXMLPaths(schema)
	schema:register(XMLValueType.STRING, "cropSensorLinkageData.sensors#filename", "Link to i3d filename containing the sensors")
	schema:register(XMLValueType.STRING, "cropSensorLinkageData.sensors.sensor(?)#type", "Type of sensor (SENSOR_LEFT | SENSOR_RIGHT | SENSOR_TOP)")
	schema:register(XMLValueType.NODE_INDEX, "cropSensorLinkageData.sensors.sensor(?)#node", "Path to sensor node")
	schema:register(XMLValueType.STRING, "cropSensorLinkageData.sensors.sensor(?)#measurementNode", "Reference node for measuring")
	schema:register(XMLValueType.BOOL, "cropSensorLinkageData.sensors.sensor(?)#requiresDaylight", "Sensor requires daylight", true)
	schema:register(XMLValueType.STRING, "cropSensorLinkageData.sensors.sensor(?).rotationNode(?)#node", "Path to rotation node")
	schema:register(XMLValueType.BOOL, "cropSensorLinkageData.sensors.sensor(?).rotationNode(?)#autoRotate", "Rotation will be automatically adjusted to the vehicle orientation", false)
	schema:register(XMLValueType.STRING, "cropSensorLinkageData.vehicles.vehicle(?)#filename", "Last part of vehicle filename")
	schema:register(XMLValueType.STRING, "cropSensorLinkageData.vehicles.vehicle(?).linkNode(?)#node", "Name of node in i3d mapping")
	schema:register(XMLValueType.STRING, "cropSensorLinkageData.vehicles.vehicle(?).linkNode(?)#type", "Type of node to link (SENSOR_LEFT | SENSOR_RIGHT | SENSOR_TOP)")
	schema:register(XMLValueType.VECTOR_TRANS, "cropSensorLinkageData.vehicles.vehicle(?).linkNode(?)#translation", "Translation offset from node", "0 0 0")
	schema:register(XMLValueType.VECTOR_ROT, "cropSensorLinkageData.vehicles.vehicle(?).linkNode(?)#rotation", "Rotation offset from node", "0 0 0")
	schema:register(XMLValueType.BOOL, "cropSensorLinkageData.vehicles.vehicle(?).linkNode(?).rotationNode(?)#autoRotate", "Rotation will be automatically adjusted to the vehicle orientation")
	schema:register(XMLValueType.VECTOR_ROT, "cropSensorLinkageData.vehicles.vehicle(?).linkNode(?).rotationNode(?)#rotation", "Rotation of rotation node", "0 0 0")
	schema:register(XMLValueType.FLOAT, "cropSensorLinkageData.configuration#price", "Price of crop sensor config", 0)
end
