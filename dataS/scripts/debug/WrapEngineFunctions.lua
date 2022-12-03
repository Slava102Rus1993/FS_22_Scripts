WrapEngineFunctions = {
	SCRIPT_BINDING_PATH = "../tools/debugger/Farming_Simulator_22_Dev.xml",
	ACTIVE = false,
	funcCallsThisFrame = {},
	funcTimeThisFrame = {},
	maxTotalCallsInOneFrame = 0,
	maxTotalTimeInOneFrame = 0,
	maxFuncCalls = {},
	maxFuncTime = {},
	ignore = {}
}

function WrapEngineFunctions.init()
	print("Warning: Engine function profiling / wrapping active")
	addConsoleCommand("gsFunctionStatsReset", "Reset maximum function call counts and execution times", "resetFunctionStats", WrapEngineFunctions)
	addConsoleCommand("gsFunctionStatsExport", "Export currently tracked function stats", "exportFunctionStats", WrapEngineFunctions)

	WrapEngineFunctions.openIntervalTimer = openIntervalTimer
	WrapEngineFunctions.readIntervalTimerMs = readIntervalTimerMs
	WrapEngineFunctions.closeIntervalTimer = closeIntervalTimer
	WrapEngineFunctions.setTextColor = setTextColor
	WrapEngineFunctions.setTextAlignment = setTextAlignment
	WrapEngineFunctions.renderText = renderText

	WrapEngineFunctions.wrapEngineFunctions()

	WrapEngineFunctions.ACTIVE = true
end

function WrapEngineFunctions.renderStats()
	local totalCallsInFrame = 0
	local callsSorted = {}

	for name, calls in pairs(WrapEngineFunctions.funcCallsThisFrame) do
		if calls > 0 then
			WrapEngineFunctions.maxFuncCalls[name] = WrapEngineFunctions.maxFuncCalls[name] or 0

			if WrapEngineFunctions.maxFuncCalls[name] < calls then
				WrapEngineFunctions.maxFuncCalls[name] = calls
			end

			totalCallsInFrame = totalCallsInFrame + calls

			table.insert(callsSorted, {
				calls,
				name
			})
		end
	end

	table.sort(callsSorted, function (a, b)
		return b[1] < a[1]
	end)

	if WrapEngineFunctions.maxTotalCallsInOneFrame < totalCallsInFrame then
		WrapEngineFunctions.maxTotalCallsInOneFrame = totalCallsInFrame
	end

	local totalTimeInFrame = 0
	local callsSortedTimed = {}

	for name, timeMs in pairs(WrapEngineFunctions.funcTimeThisFrame) do
		if timeMs > 0 then
			WrapEngineFunctions.maxFuncTime[name] = WrapEngineFunctions.maxFuncTime[name] or 0

			if WrapEngineFunctions.maxFuncTime[name] < timeMs then
				WrapEngineFunctions.maxFuncTime[name] = timeMs
			end

			table.insert(callsSortedTimed, {
				timeMs,
				name
			})

			totalTimeInFrame = totalTimeInFrame + timeMs
		end
	end

	table.sort(callsSortedTimed, function (a, b)
		return b[1] < a[1]
	end)

	if WrapEngineFunctions.maxTotalTimeInOneFrame < totalTimeInFrame then
		WrapEngineFunctions.maxTotalTimeInOneFrame = totalTimeInFrame
	end

	local xOffset = 0
	local yOffset = 0
	local xStart = 0.02
	local yStart = 0.535
	local columnWidth = 0.18
	local fontSize = 0.013
	local lineHeight = fontSize * 0.9

	WrapEngineFunctions.setTextColor(1, 1, 1, 1)
	WrapEngineFunctions.setTextAlignment(RenderText.ALIGN_LEFT)
	WrapEngineFunctions.renderText(0.01, yStart + 0.04, 0.016, "function stats - 'gsFunctionStatsReset' to reset total/max values")
	WrapEngineFunctions.renderText(0.01, yStart + 0.028, 0.014, "max calls one frame " .. tostring(WrapEngineFunctions.maxTotalCallsInOneFrame) .. " - total calls this frame " .. tostring(totalCallsInFrame))
	WrapEngineFunctions.renderText(0.01, yStart + 0.016, 0.014, "max us in one frame " .. string.format("%.1fus", WrapEngineFunctions.maxTotalTimeInOneFrame * 1000) .. " - total us in this frame " .. string.format("%.1fus", totalTimeInFrame * 1000))

	for _, callsNamePair in ipairs(callsSorted) do
		local calls = callsNamePair[1]
		local name = callsNamePair[2]

		if calls > 0 then
			WrapEngineFunctions.setTextAlignment(RenderText.ALIGN_RIGHT)
			WrapEngineFunctions.renderText(xStart + columnWidth * xOffset, yStart - lineHeight * yOffset, fontSize, tostring(calls))
			WrapEngineFunctions.renderText(xStart + 0.03 + columnWidth * xOffset, yStart - lineHeight * yOffset, fontSize, tostring(WrapEngineFunctions.maxFuncCalls[name]))
			WrapEngineFunctions.setTextAlignment(RenderText.ALIGN_LEFT)
			WrapEngineFunctions.renderText(xStart + 0.034 + columnWidth * xOffset, yStart - lineHeight * yOffset, fontSize, name)

			yOffset = yOffset + 1

			if yStart - lineHeight * yOffset <= 0 then
				yOffset = 0
				xOffset = xOffset + 1
			end
		end
	end

	xOffset = 0
	yOffset = 0
	yStart = 0.85
	xStart = 0.58
	columnWidth = 0.24

	for _, callsNamePair in ipairs(callsSortedTimed) do
		local timeMs = callsNamePair[1]
		local name = callsNamePair[2]

		if timeMs > 0 then
			WrapEngineFunctions.setTextAlignment(RenderText.ALIGN_RIGHT)
			WrapEngineFunctions.renderText(xStart + columnWidth * xOffset, yStart - lineHeight * yOffset, fontSize, string.format("%.1f us", timeMs * 1000))
			WrapEngineFunctions.renderText(xStart + 0.015 + columnWidth * xOffset, yStart - lineHeight * yOffset, fontSize, tostring(WrapEngineFunctions.funcCallsThisFrame[name]))
			WrapEngineFunctions.renderText(xStart + 0.06 + columnWidth * xOffset, yStart - lineHeight * yOffset, fontSize, string.format("%.1f us", WrapEngineFunctions.maxFuncTime[name] * 1000))
			WrapEngineFunctions.setTextAlignment(RenderText.ALIGN_LEFT)
			WrapEngineFunctions.renderText(xStart + 0.064 + columnWidth * xOffset, yStart - lineHeight * yOffset, fontSize, tostring(name))

			yOffset = yOffset + 1

			if yStart - lineHeight * yOffset <= 0 then
				yOffset = 0
				xOffset = xOffset + 1
			end
		end
	end

	for name in pairs(WrapEngineFunctions.funcCallsThisFrame) do
		WrapEngineFunctions.funcCallsThisFrame[name] = 0
	end

	for name in pairs(WrapEngineFunctions.funcTimeThisFrame) do
		WrapEngineFunctions.funcTimeThisFrame[name] = 0
	end
end

function WrapEngineFunctions.resetFunctionStats()
	WrapEngineFunctions.maxTotalCallsInOneFrame = 0
	WrapEngineFunctions.maxTotalTimeInOneFrame = 0
	WrapEngineFunctions.maxFuncCalls = {}
	WrapEngineFunctions.maxFuncTime = {}

	return "Reset maximum values"
end

function WrapEngineFunctions.exportFunctionStats()
	setFileLogPrefixTimestamp(false)

	local countsSorted = {}

	for name, count in pairs(WrapEngineFunctions.maxFuncCalls) do
		table.insert(countsSorted, {
			name,
			count
		})
	end

	table.sort(countsSorted, function (a, b)
		return b[2] < a[2]
	end)
	log("max calls in one frame")

	for _, nameCountPair in ipairs(countsSorted) do
		log(nameCountPair[2], nameCountPair[1])
	end

	local timeSorted = {}

	for name, timeMs in pairs(WrapEngineFunctions.maxFuncTime) do
		table.insert(timeSorted, {
			name,
			timeMs
		})
	end

	table.sort(timeSorted, function (a, b)
		return b[2] < a[2]
	end)
	log("max time of a single call in one frame")

	for _, nameTimePair in ipairs(timeSorted) do
		print(string.format("%.1f us %s", nameTimePair[2] * 1000, nameTimePair[1]))
	end

	setFileLogPrefixTimestamp(g_logFilePrefixTimestamp)
end

function WrapEngineFunctions.engineFunctionCalled(name, timeMs)
	WrapEngineFunctions.funcCallsThisFrame[name] = (WrapEngineFunctions.funcCallsThisFrame[name] or 0) + 1
	WrapEngineFunctions.funcTimeThisFrame[name] = (WrapEngineFunctions.funcTimeThisFrame[name] or 0) + timeMs
end

function WrapEngineFunctions.wrap(name, func)
	local oldFunc = func

	_G[name] = function (...)
		local timer = WrapEngineFunctions.openIntervalTimer()
		local ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10, ret11, ret12, ret13, ret14, ret15, ret16 = oldFunc(...)

		WrapEngineFunctions.engineFunctionCalled(name, WrapEngineFunctions.readIntervalTimerMs(timer))
		WrapEngineFunctions.closeIntervalTimer(timer)

		if ret16 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10, ret11, ret12, ret13, ret14, ret15, ret16
		elseif ret15 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10, ret11, ret12, ret13, ret14, ret15
		elseif ret14 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10, ret11, ret12, ret13, ret14
		elseif ret13 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10, ret11, ret12, ret13
		elseif ret12 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10, ret11, ret12
		elseif ret11 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10, ret11
		elseif ret10 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10
		elseif ret9 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9
		elseif ret8 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8
		elseif ret7 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6, ret7
		elseif ret6 ~= nil then
			return ret1, ret2, ret3, ret4, ret5, ret6
		elseif ret5 ~= nil then
			return ret1, ret2, ret3, ret4, ret5
		elseif ret4 ~= nil then
			return ret1, ret2, ret3, ret4
		elseif ret3 ~= nil then
			return ret1, ret2, ret3
		elseif ret2 ~= nil then
			return ret1, ret2
		elseif ret1 ~= nil then
			return ret1
		end

		return nil
	end
end

function WrapEngineFunctions.wrapEngineFunctions()
	local xml = loadXMLFile("scriptBinding", WrapEngineFunctions.SCRIPT_BINDING_PATH)

	if xml ~= 0 then
		log("WrapEngineFunctions.wrapEngineFunctions(): loading script biding from", WrapEngineFunctions.SCRIPT_BINDING_PATH)

		local i = 0

		while true do
			local key = "scriptBinding.function(" .. i .. ")"

			if not hasXMLProperty(xml, key .. "#name") then
				break
			end

			local functionName = getXMLString(xml, key .. "#name")
			local global = string.split(functionName, ".")[1]

			if WrapEngineFunctions.ignore[functionName] == nil and not string.contains(functionName, ":") then
				local codeStr = string.format("if %s ~= nil then\n", global)
				codeStr = codeStr .. string.format("WrapEngineFunctions.wrap(\"%s\", %s)\n", functionName, functionName)
				codeStr = codeStr .. "else\n"
				codeStr = codeStr .. string.format("print(\"Error: %s from script binding does not exist\")\n", global)
				codeStr = codeStr .. "end"
				local code, err = loadstring(codeStr)

				if code then
					code()
				else
					print(string.format("Error parsing '%s'\n%s", codeStr, err))
				end
			end

			i = i + 1
		end
	end
end

function WrapEngineFunctions.customWrappers()
	local function debugSplitFindTest(x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ, r, g, b, a)
		local zx, zy, zz = MathUtil.crossProduct(nx, ny, nz, yx, yy, yz)
		local x2 = x + yx * cutSizeY
		local y2 = y + yy * cutSizeY
		local z2 = z + yz * cutSizeY
		local x3 = x + zx * cutSizeZ
		local y3 = y + zy * cutSizeZ
		local z3 = z + zz * cutSizeZ
		local x4 = x + zx * cutSizeZ + yx * cutSizeY
		local y4 = y + zy * cutSizeZ + yy * cutSizeY
		local z4 = z + zz * cutSizeZ + yz * cutSizeY

		drawDebugTriangle(x3, y3, z3, x, y, z, x2, y2, z2, r, g, b, a, true)
		drawDebugTriangle(x4, y4, z4, x3, y3, z3, x2, y2, z2, r, g, b, a, true)
		drawDebugTriangle(x4, y4, z4, x, y, z, x3, y3, z3, r, g, b, a, true)
		drawDebugTriangle(x4, y4, z4, x2, y2, z2, x, y, z, r, g, b, a, true)
	end

	local engineFindSplitShape = findSplitShape

	function findSplitShape(x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ)
		debugSplitFindTest(x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ, 1, 0, 0, 0.5)

		local shape, minY, maxY, minZ, maxZ = engineFindSplitShape(x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ)

		if shape ~= nil and shape ~= 0 then
			Utils.renderTextAtWorldPosition(x, y, z, string.format("findSplitShape shape:%s minY:%.3f maxY:%.3f minZ:%.3f maxZ:%.3f", shape, minY, maxY, minZ, maxZ), 0.02)
		else
			Utils.renderTextAtWorldPosition(x, y, z, "findSplitShape nil", 0.02)
		end

		return shape, minY, maxY, minZ, maxZ
	end

	local engineTestSplitShape = testSplitShape

	function testSplitShape(splitShape, x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ)
		debugSplitFindTest(x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ, 0, 1, 0, 0.5)

		local minY, maxY, minZ, maxZ = engineTestSplitShape(splitShape, x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ)

		if minY then
			Utils.renderTextAtWorldPosition(x, y, z, string.format("testSplitShape shape:%s minY:%.3f maxY:%.3f minZ:%.3f maxZ:%.3f", splitShape, minY, maxY, minZ, maxZ), 0.02)
		else
			Utils.renderTextAtWorldPosition(x, y, z, "testSplitShape nil", 0.02)
		end

		return minY, maxY, minZ, maxZ
	end

	local engineRaycastClosest = raycastClosest

	function raycastClosest(x, y, z, nx, ny, nz, raycastFunctionCallback, maxDistance, targetObject, collisionMask, generateNormal, async)
		if not DebugUtil.isPositionInCameraRange(x, y, z, 3) then
			drawDebugArrow(x, y, z, nx * maxDistance, ny * maxDistance, nz * maxDistance, 0.3, 0.3, 0.3, 0.8, 0, 0, true)
		end

		return engineRaycastClosest(x, y, z, nx, ny, nz, raycastFunctionCallback, maxDistance, targetObject, collisionMask, generateNormal, async)
	end

	local engineRaycastAll = raycastAll

	function raycastAll(x, y, z, nx, ny, nz, raycastFunctionCallback, maxDistance, targetObject, collisionMask, generateNormal, async)
		if not DebugUtil.isPositionInCameraRange(x, y, z, 3) then
			drawDebugArrow(x, y, z, nx * maxDistance, ny * maxDistance, nz * maxDistance, 0.3, 0.3, 0.3, 0, 0.8, 0, true)
		end

		return engineRaycastAll(x, y, z, nx, ny, nz, raycastFunctionCallback, maxDistance, targetObject, collisionMask, generateNormal, async)
	end

	local engineOverlapBox = overlapBox

	function overlapBox(x, y, z, rx, ry, rz, ex, ey, ez, overlapFunctionCallback, targetObject, collisionMask, includeDynamics, includeStatics, exactTest, async)
		DebugUtil.drawOverlapBox(x, y, z, rx, ry, rz, ex, ey, ez)

		return engineOverlapBox(x, y, z, rx, ry, rz, ex, ey, ez, overlapFunctionCallback, targetObject, collisionMask, includeDynamics, includeStatics, exactTest, async)
	end
end
