source("manure/src/editor/editor.lua")

local reelCache = Cache(I3DManager(), g_baseDirectory)
local cache = Cache(I3DManager(), g_baseDirectory, "data/shared/hose/hoseFlat.i3d")
local rootNode = getChildAt(getRootNode(), 0)
local guideNode = createTransformGroup("GuidNode")
local linkNode = createTransformGroup("linkNode")
local reelHose = UmbilicalReelHose(reelCache, linkNode)
local f = getSelection(0) or rootNode
local node = getSelection(1) or rootNode

link(node, linkNode)
link(rootNode, guideNode)
setTranslation(linkNode, -1.1, 0, 0)

local followNode = getSelection(2) or createTransformGroup("followNode")

link(f, followNode)
setTranslation(followNode, 0, 0, 3)

local dummyHose = Hose(followNode, guideNode, cache:getByKeyOrDefault(), 5, 0.5)
local dir = 1
local length = 0
local capacity = 1300

reelHose:setCapacity(capacity)
reelHose:setCoilsAmount(10)
reelHose:setShift(0.22)
reelHose:setInnerDiameter(0.5)
reelHose:setLayerThickness(0.025)
reelHose:loadLayers(length)

function onUpdate(dt)
	if getIsEditorPlaying() then
		local delta = dt * 0.001
		length = length + delta * dir

		if capacity < length or length < 0 then
			return
		end

		local a = reelHose:getActiveLayer(length)
		local state = reelHose:getState(a)
		local targetRot = reelHose:getRotationByState(state)

		setRotation(node, -targetRot, 0, 0)

		local layer = reelHose:getCurrentLayer()
		local layers = reelHose:getAmountOfLayers()

		reelHose:updateLayers(a, dir)

		local offset = -1.1
		local _, y, z = getTranslation(guideNode)
		local x = reelHose:getPlacementOffset(layers - 1, offset)
		local tx = reelHose:getPlacementOffset(layers, offset)
		local t = x + (tx - x) * state

		setTranslation(guideNode, t, y, z)

		local x, y, z = getWorldTranslation(guideNode)

		Utils.renderTextAtWorldPosition(x, y, z, "GUIDE", 0.012)

		x, y, z = getWorldTranslation(followNode)

		Utils.renderTextAtWorldPosition(x, y, z, "FOLLOW", 0.012)
		dummyHose:compute()
		dummyHose:scroll(length)
		dummyHose:draw()
	end
end

if g_updateListener ~= nil then
	removeUpdateListener(g_updateListener)

	g_updateListener = nil
end

g_updateListener = addUpdateListener("onUpdate")
