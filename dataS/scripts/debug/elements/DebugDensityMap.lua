DebugDensityMap = {}
local DebugDensityMap_mt = Class(DebugDensityMap)

function DebugDensityMap.new(densityMap, firstChannel, numChannels, radius, yOffset, colors, customMt)
	local self = setmetatable({}, customMt or DebugDensityMap_mt)
	local size = getDensityMapSize(densityMap)
	self.resolution = g_currentMission.terrainSize / size
	self.firsChannel = firstChannel
	self.numChannels = numChannels
	self.colors = colors
	self.radius = radius
	self.yOffset = yOffset or 0.1
	self.modifier = DensityMapModifier.new(densityMap, firstChannel, numChannels, g_currentMission.terrainNode)
	self.filter = DensityMapFilter.new(self.modifier)

	return self
end

function DebugDensityMap:delete()
end

function DebugDensityMap:update(dt)
end

function DebugDensityMap:draw()
	local resolution = self.resolution
	local colors = self.colors
	local radius = self.radius
	local steps = math.ceil(radius / resolution - resolution * 0.5)
	local visualOffsetX = resolution * 0.5
	local visualOffsetZ = resolution * 0.5
	local x = self.centerX
	local z = self.centerZ

	if x == nil then
		local _ = nil
		x, _, z = getWorldTranslation(getCamera())
	end

	x = math.floor(x / self.resolution) * self.resolution
	z = math.floor(z / self.resolution) * self.resolution
	local densityOffsetX = resolution * 0.1
	local densityOffsetZ = resolution * 0.1

	for xStep = 1, steps do
		for zStep = 1, steps do
			local startWorldX = x + (xStep - steps * 0.5) * resolution
			local startWorldZ = z + (zStep - steps * 0.5) * resolution
			local widthWorldX = x + (xStep + 1 - steps * 0.5) * resolution
			local widthWorldZ = z + (zStep - steps * 0.5) * resolution
			local heightWorldX = x + (xStep - steps * 0.5) * resolution
			local heightWorldZ = z + (zStep + 1 - steps * 0.5) * resolution
			local dStartWorldX = startWorldX + densityOffsetX
			local dStartWorldZ = startWorldZ + densityOffsetZ
			local dWidthWorldX = widthWorldX - densityOffsetX
			local dWidthWorldZ = widthWorldZ + densityOffsetZ
			local dHeightWorldX = heightWorldX + densityOffsetX
			local dHeightWorldZ = heightWorldZ - densityOffsetZ

			self.modifier:setParallelogramWorldCoords(dStartWorldX, dStartWorldZ, dWidthWorldX, dWidthWorldZ, dHeightWorldX, dHeightWorldZ, DensityCoordType.POINT_POINT_POINT)

			for i = 0, 2^self.numChannels - 1 do
				self.filter:setValueCompareParams(DensityValueCompareType.EQUAL, i)

				local _, numPixels, _ = self.modifier:executeGet(self.filter)

				if numPixels > 0 then
					local vStartWorldX = startWorldX + resolution * 0.1 - visualOffsetX
					local vStartWorldZ = startWorldZ + resolution * 0.1 - visualOffsetZ
					local vWidthWorldX = widthWorldX - resolution * 0.1 - visualOffsetX
					local vWidthWorldZ = widthWorldZ + resolution * 0.1 - visualOffsetZ
					local vHeightWorldX = heightWorldX + resolution * 0.1 - visualOffsetX
					local vHeightWorldZ = heightWorldZ - resolution * 0.1 - visualOffsetZ
					local color = colors[i]

					if color ~= nil then
						self:drawDebugAreaRectangleFilled(vStartWorldX, vStartWorldZ, vWidthWorldX, vWidthWorldZ, vHeightWorldX, vHeightWorldZ, color[1], color[2], color[3], color[4])
					end

					local centerX = (vStartWorldX + vWidthWorldX) * 0.5
					local centerZ = (vStartWorldZ + vHeightWorldZ) * 0.5
					local centerY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, centerX, 0, centerZ) + self.yOffset

					Utils.renderTextAtWorldPosition(centerX, centerY, centerZ, tostring(i), 0.012, 0, {
						1,
						1,
						1,
						1
					})

					break
				end
			end
		end
	end
end

function DebugDensityMap:setCenter(x, z)
	self.centerX = x
	self.centerZ = z
end

function DebugDensityMap:drawDebugAreaRectangleFilled(x, z, x1, z1, x2, z2, r, g, b, a)
	local x3 = x1
	local z3 = z2
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + self.yOffset
	local y1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x1, 0, z1) + self.yOffset
	local y2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x2, 0, z2) + self.yOffset
	local y3 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x3, 0, z3) + self.yOffset

	drawDebugTriangle(x, y, z, x2, y2, z2, x1, y1, z1, r, g, b, a, false)
	drawDebugTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, a, false)
end
