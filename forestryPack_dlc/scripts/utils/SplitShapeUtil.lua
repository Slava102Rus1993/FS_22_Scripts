local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

SplitShapeUtil = {
	getTreeOffsetPosition = function (shapeId, x, y, z, maxRadius, minLength)
		local localX, localY, localZ = worldToLocal(shapeId, x, y, z)
		local cx, cy, cz = localToWorld(shapeId, localX - maxRadius * 0.5, localY, localZ - maxRadius * 0.5)
		local nx, ny, nz = localDirectionToWorld(shapeId, 0, 1, 0)
		local yx, yy, yz = localDirectionToWorld(shapeId, 0, 0, 1)
		local minY, maxY, minZ, maxZ = testSplitShape(shapeId, cx, cy, cz, nx, ny, nz, yx, yy, yz, maxRadius, maxRadius)

		if minY ~= nil then
			if minLength ~= nil then
				local lengthBelow, lengthAbove = getSplitShapePlaneExtents(shapeId, cx, cy, cz, nx, ny, nz)

				if lengthBelow ~= nil and lengthBelow < minLength then
					return nil
				elseif lengthAbove ~= nil and lengthAbove < minLength then
					return nil
				end
			end

			local minMaxY = (minY + maxY) * 0.5
			local minMaxZ = (minZ + maxZ) * 0.5
			local centerX, centerY, centerZ = localToWorld(shapeId, localX - maxRadius * 0.5 + minMaxZ, localY, localZ - maxRadius * 0.5 + minMaxY)
			local radius = math.max(maxY - minY, maxZ - minZ) * 0.5

			return centerX, centerY, centerZ, nx, ny, nz, radius
		end

		return nil
	end,
	createTreeBelt = function (beltData, shapeId, tx, ty, tz, sx, sy, sz, upX, upY, upZ, hookOffset, ignoreYDirection, spacing)
		local dir2X, dir2Y, dir2Z = MathUtil.vector3Normalize(sx - tx, sy - ty, sz - tz)

		if ignoreYDirection then
			dir2Y = 0
		end

		spacing = spacing or 0.0025
		local rootNode = createTransformGroup("rootNode")

		link(getRootNode(), rootNode)
		setTranslation(rootNode, tx, ty, tz)
		setDirection(rootNode, dir2X, dir2Y, dir2Z, upX, upY, upZ)

		local startNode = createTransformGroup("startNode")

		link(rootNode, startNode)
		setTranslation(startNode, -spacing * 0.5, 0, hookOffset)
		setRotation(startNode, -math.pi * 0.5, 0, -math.pi * 0.5)

		local endNode = createTransformGroup("endNode")

		link(startNode, endNode)
		setTranslation(endNode, 0, 0, spacing)
		setRotation(endNode, 0, 0, 0)

		local linkNode = createTransformGroup("linkNode")

		link(startNode, linkNode)
		setTranslation(linkNode, 0, 0, spacing * 0.5)
		setRotation(linkNode, 0, 0, 0)

		local tensionBelt = TensionBeltGeometryConstructor.new()

		tensionBelt:setWidth(beltData.width)
		tensionBelt:setMaterial(beltData.material.materialId)
		tensionBelt:setUVscale(beltData.material.uvScale)
		tensionBelt:setMaxEdgeLength(0.1)
		tensionBelt:setFixedPoints(startNode, endNode)
		tensionBelt:setGeometryBias(0.005)
		tensionBelt:setLinkNode(linkNode)
		tensionBelt:addShape(shapeId, -100, 100, -100, 100)

		local beltShapeId, _, _ = tensionBelt:finalize()
		local wx, wy, wz = getWorldTranslation(beltShapeId)
		local rx, ry, rz = getWorldRotation(beltShapeId)

		link(getRootNode(), beltShapeId)
		setWorldTranslation(beltShapeId, wx, wy, wz)
		setWorldRotation(beltShapeId, rx, ry, rz)
		delete(rootNode)

		return beltShapeId
	end
}

function SplitShapeUtil.getSplitShapeId(node)
	if getHasClassId(node, ClassIds.MESH_SPLIT_SHAPE) then
		return node
	else
		for i = 0, getNumOfChildren(node) - 1 do
			local ret = SplitShapeUtil.getSplitShapeId(getChildAt(node, i))

			if ret ~= nil then
				return ret
			end
		end

		return nil
	end
end
