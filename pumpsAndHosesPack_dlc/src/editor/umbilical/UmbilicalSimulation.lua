source("manure/src/editor/editor.lua")

g_physicsDt = 16.666666666666668
local simulateReel = false
local atTail = true
local createAtTail = true

local function clear(node)
	local numChildren = getNumOfChildren(node)

	for i = numChildren, 1, -1 do
		local childId = getChildAt(node, i - 1)

		log("DELETE: " .. getName(childId))
		delete(childId)
	end
end

local rootNode = getChildAt(getChildAt(getRootNode(), 0), 0)
local transNode = getChildAt(rootNode, 0)
local hoseSegmentNodes = getChildAt(rootNode, 1)
g_hoseLinkNode = hoseSegmentNodes
local numChildren = getNumOfChildren(hoseSegmentNodes)
local container = I3DShapeContainer(I3DManager(), g_baseDirectory)

container:load("hoseUmbilical", "umbilicalHoses.i3d", 0)
container:load("connector", "umbilicalHoses.i3d", 1)

local umbilicalHose = UmbilicalHose.new(g_currentMission, container, true, true)
local r, g, b, m = nil
r = r or 0.05
g = g or 0.05
b = b or 0.05
m = m or 0

umbilicalHose:setColor({
	r,
	g,
	b,
	m
})

if not simulateReel then
	for i = 0, numChildren - 1 do
		local childId = getChildAt(hoseSegmentNodes, i)

		log(getName(childId))
		clear(childId)

		local x, y, z = getWorldTranslation(childId)

		umbilicalHose:addPointByPosition(x, y, z, createAtTail)
	end

	umbilicalHose:finalize()
else
	clear(hoseSegmentNodes)
end

local distance = 0
local lastSegment = nil
local runningSimulation = simulateReel
local lx, ly, lz = nil

function updateCallback(dt)
	if getIsEditorPlaying() then
		local x, y, z = getWorldTranslation(transNode)

		if lastSegment ~= nil then
			local diff = 0

			if lx ~= nil and ly ~= nil and lz ~= nil then
				diff = Vector3(lx, ly, lz) - Vector3(x, y, z)
			else
				diff = lastSegment.lastPosition - Vector3(x, y, z)
			end

			distance = diff:magnitude()
		end

		local point = umbilicalHose:getNumberOfControlPoints()
		local hasPoints = point > 0

		umbilicalHose:move(x, y, z, atTail, hasPoints and not runningSimulation)

		runningSimulation = simulateReel and point < 20

		if runningSimulation and (umbilicalHose.controlPointDistance < distance or not hasPoints) then
			local lastAdded = umbilicalHose:addPointByPosition(x, y, z, createAtTail)

			if lastAdded ~= nil then
				lastSegment = lastAdded

				if lastSegment.hose ~= nil then
					lastSegment.hose:setLength(distance)
				end

				lz = z
				ly = y
				lx = x
			end
		end
	end
end

function drawCallback()
	if getIsEditorPlaying() then
		umbilicalHose:draw()
	end
end

if g_hoseDrawListener ~= nil then
	removeDrawListener(g_hoseDrawListener)

	g_hoseDrawListener = nil
end

g_vehicleDrawListener = addDrawListener("drawCallback")

if g_updateListener ~= nil then
	removeUpdateListener(g_updateListener)

	g_updateListener = nil
end

g_vehicleUpdateListener = addUpdateListener("updateCallback")
