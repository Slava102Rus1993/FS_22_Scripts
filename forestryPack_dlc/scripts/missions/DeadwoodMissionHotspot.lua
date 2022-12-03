local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

DeadwoodMissionHotspot = {
	MOD_DIRECTORY = g_currentModDirectory
}
local DeadwoodMissionHotspot_mt = Class(DeadwoodMissionHotspot, MapHotspot)

function DeadwoodMissionHotspot.new(customMt)
	local self = MapHotspot.new(customMt or DeadwoodMissionHotspot_mt)
	self.width, self.height = getNormalizedScreenValues(50, 50)
	local filename = Utils.getFilename("menu/hud/deadwoodHotspot.png", DeadwoodMissionHotspot.MOD_DIRECTORY)
	local uvs = GuiUtils.getUVs({
		13,
		13,
		103,
		103
	}, {
		128,
		128
	})
	self.icon = Overlay.new(filename, 0, 0, self.width, self.height)

	self.icon:setUVs(uvs)

	local circleFilename = Utils.getFilename("$dataS/menu/hud/hud_elements.png", DeadwoodMissionHotspot.MOD_DIRECTORY)
	local circleUVs = GuiUtils.getUVs({
		48,
		291,
		256,
		256
	}, {
		1024,
		1024
	})
	self.circle = Overlay.new(circleFilename, 0, 0, self.width, self.height)

	self.circle:setUVs(circleUVs)
	self.circle:setColor(0.5089, 0.016, 0.016, 1)

	self.worldRadius = 50
	self.forceNoRotation = true

	return self
end

function DeadwoodMissionHotspot:delete()
	DeadwoodMissionHotspot:superClass().delete(self)

	if self.icon ~= nil then
		self.icon:delete()

		self.icon = nil
	end

	if self.circle ~= nil then
		self.circle:delete()

		self.circle = nil
	end
end

function DeadwoodMissionHotspot:setWorldRadius(worldRadius)
	self.worldRadius = worldRadius
end

function DeadwoodMissionHotspot:updateCircleSize()
	local ingameMap = g_currentMission.hud:getIngameMap()
	local layout = ingameMap.layout
	local mapWidth, mapHeight = layout:getMapSize()
	local width = self.worldRadius / ingameMap.worldSizeX * mapWidth
	local height = self.worldRadius / ingameMap.worldSizeZ * mapHeight

	self.circle:setDimension(width, height)
end

function DeadwoodMissionHotspot:getWidth()
	if self.circle ~= nil then
		self:updateCircleSize()

		return self.circle.width
	end

	if self.icon ~= nil then
		return self.icon.width
	end

	return 0
end

function DeadwoodMissionHotspot:getHeight()
	if self.circle ~= nil then
		self:updateCircleSize()

		return self.circle.height
	end

	if self.icon ~= nil then
		return self.icon.height
	end

	return 0
end

function DeadwoodMissionHotspot:setScale(scale)
	if self.circle ~= nil then
		self.circle:setScale(scale, scale)
	end

	if self.icon ~= nil then
		self.icon:setScale(scale, scale)
	end
end

function DeadwoodMissionHotspot:getCategory()
	return MapHotspot.CATEGORY_MISSION
end

function DeadwoodMissionHotspot:getIsPersistent()
	return false
end

function DeadwoodMissionHotspot:getRenderLast()
	return false
end

function DeadwoodMissionHotspot:render(x, y, rotation, small)
	local circle = self.circle

	if circle ~= nil then
		circle:setPosition(x, y)
		circle:setColor(nil, , , self.isBlinking and self:getCanBlink() and IngameMap.alpha or 1)
		circle:render()

		x = x + circle.width * 0.5
		y = y + circle.height * 0.5

		if self.icon ~= nil then
			x = x - self.icon.width * 0.5
			y = y - self.icon.height * 0.5
		end
	end

	local icon = self.icon

	if icon ~= nil then
		icon:setPosition(x, y)
		icon:setColor(nil, , , self.isBlinking and self:getCanBlink() and IngameMap.alpha or 1)
		icon:render()
	end
end
