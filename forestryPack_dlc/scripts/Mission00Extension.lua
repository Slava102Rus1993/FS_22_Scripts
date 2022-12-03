local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

local function postLoadAdditionalFilesFinished(self)
	if self:getIsServer() and self.missionInfo.savegameDirectory ~= nil then
		self:startLoadingTask()
		g_asyncTaskManager:addTask(function ()
			self.destructibleMapObjectSystem:loadFromXMLFile(self.missionInfo.savegameDirectory .. "/destructibleMapObjectSystem.xml")
		end)
		g_asyncTaskManager:addTask(function ()
			self.treeMarkerSystem:loadFromXMLFile(self.missionInfo.savegameDirectory .. "/treeMarkerSystem.xml")
		end)
		g_asyncTaskManager:addTask(function ()
			self:finishLoadingTask()
		end)
	end
end

Mission00.loadAdditionalFilesFinished = Utils.appendedFunction(Mission00.loadAdditionalFilesFinished, postLoadAdditionalFilesFinished)
local modDirectory = g_currentModDirectory

local function postLoadMission00Finished(self, node, arguments)
	if self.cancelLoading then
		return
	end

	g_particleSystemManager:addParticleType("HYDRAULIC_HAMMER")
	g_particleSystemManager:addParticleType("HYDRAULIC_HAMMER_DEBRIS")
	g_particleSystemManager:addParticleType("SPRAYCAN_PAINT")
	g_materialManager:addMaterialType("SPRAYCAN_PAINT")
	g_particleSystemManager:addParticleType("MINING_SHAFT")
	g_particleSystemManager:addParticleType("OLDSAWMILL1")
	g_particleSystemManager:addParticleType("OLDSAWMILL2")

	local i3dsPending = 0

	local function callbackFunc()
		i3dsPending = i3dsPending - 1

		if i3dsPending == 0 then
			self:finishLoadingTask()
		end
	end

	local extraFiles = {
		"effects/hydraulicHammer/particle/debris.i3d",
		"effects/hydraulicHammer/particle/smoke.i3d",
		"effects/sprayCan/particle/sprayCan.i3d",
		"effects/sprayCan/sprayCan_materialHolder.i3d"
	}

	self:startLoadingTask()

	for _, file in ipairs(extraFiles) do
		g_asyncTaskManager:addTask(function ()
			local filename = Utils.getFilename(file, modDirectory)
			i3dsPending = i3dsPending + 1

			g_i3DManager:loadI3DFileAsync(filename, true, true, self.onLoadedMapI3DFiles, self, {
				callbackFunc,
				self
			})
		end)
	end
end

Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, postLoadMission00Finished)

local function postSetMissionInfo(self, missionInfo, missionDynamicInfo)
	g_asyncTaskManager:addTask(function ()
		self.treeMarkerSystem:loadMapData(self.xmlFile, missionInfo, modDirectory)
	end)
end

Mission00.setMissionInfo = Utils.appendedFunction(Mission00.setMissionInfo, postSetMissionInfo)
