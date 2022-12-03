local isEditor = g_isEditor or false
local isIsIconGenerator = g_iconGenerator ~= nil or false
local isRunByTool = isEditor or isIsIconGenerator
local modDirectory = g_currentModDirectory or ""
local modName = g_currentModName or "unknown"
local modEnvironment = nil
local sourceFiles = {
	"src/shared/globals.lua",
	"src/shared/class.lua",
	"src/shared/table.lua",
	"src/gui/InGameMenuProductionFrameExtension.lua",
	"src/gui/PlaceableInfoDialogExtension.lua",
	"src/hud/UmbilicalPumpHUD.lua",
	"src/math/math.lua",
	"src/math/Vector3.lua",
	"src/math/Curve.lua",
	"src/misc/I3DCacheEntry.lua",
	"src/misc/I3DShapeContainer.lua",
	"src/collection/Stack.lua",
	"src/umbilical/UmbilicalReelDrum.lua",
	"src/umbilical/UmbilicalReelHose.lua",
	"src/umbilical/hoses/HoseBase.lua",
	"src/umbilical/UmbilicalHose.lua",
	"src/umbilical/UmbilicalHosePoint.lua",
	"src/umbilical/UmbilicalHoseOrchestrator.lua",
	"src/objects/SandboxProductionPoint.lua",
	"src/objects/ManureSeparator.lua",
	"src/objects/LinearAnimation.lua",
	"src/placeables/placeableSystemSandboxExtension.lua",
	"src/handTools/UmbilicalHoseWrench.lua",
	"src/Manure.lua",
	"src/overwrites.lua"
}

if not isRunByTool then
	table.insert(sourceFiles, "src/network/NetworkHelper.lua")
	table.insert(sourceFiles, "src/network/events/ToolCarrierStateEvent.lua")
	table.insert(sourceFiles, "src/network/events/UmbilicalReelLengthEvent.lua")
	table.insert(sourceFiles, "src/network/events/UmbilicalReelOverloadEvent.lua")
	table.insert(sourceFiles, "src/network/events/UmbilicalReelDirectionEvent.lua")
	table.insert(sourceFiles, "src/network/events/UmbilicalReelActiveEvent.lua")
	table.insert(sourceFiles, "src/network/events/UmbilicalHoseConnectorAttachEvent.lua")
	table.insert(sourceFiles, "src/network/events/UmbilicalHoseConnectorDetachEvent.lua")
	table.insert(sourceFiles, "src/network/events/umbilical/UmbilicalHoseCreateEvent.lua")
	table.insert(sourceFiles, "src/network/events/umbilical/UmbilicalHoseSpawnEvent.lua")
	table.insert(sourceFiles, "src/network/events/umbilical/UmbilicalHoseRemoveEvent.lua")
	table.insert(sourceFiles, "src/network/events/overload/UmbilicalReelUnloadEvent.lua")
	table.insert(sourceFiles, "src/network/events/overload/UmbilicalReelInstantOverloadEvent.lua")
	table.insert(sourceFiles, "src/vehicles/specializations/events/UmbilicalPumpActiveEvent.lua")
	table.insert(sourceFiles, "src/vehicles/specializations/events/UmbilicalPumpCirculatingEvent.lua")
	table.insert(sourceFiles, "src/vehicles/specializations/events/UmbilicalCleanerEvent.lua")
	table.insert(sourceFiles, "src/objects/events/ManureSeparatorProcessingEvent.lua")
	table.insert(sourceFiles, "src/handTools/events/UmbilicalHoseWrenchAttachEvent.lua")
	table.insert(sourceFiles, "src/handTools/events/UmbilicalHoseWrenchDetachEvent.lua")
	table.insert(sourceFiles, "src/placeables/specializations/events/SandboxPlaceableRootNameEvent.lua")
	table.insert(sourceFiles, "src/placeables/specializations/events/SandboxPlaceableRootStateEvent.lua")
	table.insert(sourceFiles, "src/placeables/specializations/events/SandboxPlaceableActiveAnimationsEvent.lua")
end

for _, file in ipairs(sourceFiles) do
	source(modDirectory .. file)
end

local function isLoaded()
	return modEnvironment ~= nil and g_modIsLoaded[modName]
end

local function registerSeparatedManure()
	local fillToGroundScale = 1
	local allowsSmoothing = false
	local collisionScale = 1
	local collisionBaseOffset = 0.08
	local minCollisionOffset = 0
	local maxCollisionOffset = collisionBaseOffset

	g_densityMapHeightManager:addDensityMapHeightType("SEPARATED_MANURE", math.rad(30), collisionScale, collisionBaseOffset, minCollisionOffset, maxCollisionOffset, fillToGroundScale, allowsSmoothing, false)

	local sprayGroundType = g_currentMission.fieldGroundSystem:getFieldSprayValueByName("MANURE")

	g_sprayTypeManager:addSprayType("SEPARATED_MANURE", 0.4, "FERTILIZER", sprayGroundType, false)
end

local function load(mission)
	assert(modEnvironment == nil)

	modEnvironment = Manure(modName, modDirectory, mission, g_i3DManager, g_i18n)
	mission.manure = modEnvironment

	addModEventListener(modEnvironment)
	registerHandTool("umbilicalHoseWrench", UmbilicalHoseWrench)
	registerSeparatedManure()
	pnh_overwrite.load()
	g_animationManager:registerAnimationClass("LinearAnimation", LinearAnimation)
end

local function unload()
	if not isLoaded() then
		return
	end

	if GS_IS_CONSOLE_VERSION then
		pnh_overwrite.resetOriginalFunctions()
	end

	if modEnvironment ~= nil then
		modEnvironment:delete()

		modEnvironment = nil

		if g_currentMission ~= nil then
			g_currentMission.manure = nil
		end
	end
end

local function validateTypes(typeManager)
	if g_modIsLoaded[modName] then
		typeManager.isForPlaceables = typeManager.typeName == "placeable"
		typeManager.isForVehicles = typeManager.typeName == "vehicle"

		if typeManager.isForPlaceables then
			Manure.installPlaceableSpecializations(typeManager, typeManager.specializationManager, modDirectory, modName)
		end

		if typeManager.isForVehicles then
			Manure.installVehicleSpecializations(typeManager, typeManager.specializationManager, modDirectory, modName)
		end

		pnh_overwrite.validateTypes(typeManager, typeManager.specializationManager, modDirectory, modName)
	end
end

local function init()
	FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
	Mission00.load = Utils.prependedFunction(Mission00.load, load)
	TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, validateTypes)

	pnh_overwrite.init()
end

if not isRunByTool then
	init()

	g_manureModName = modName

	function Vehicle:manure_getModName()
		return modName
	end

	local isBeforePatch1_7 = g_gameVersion < 10

	if isBeforePatch1_7 and g_addCheatCommands and g_showDevelopmentWarnings then
		local function getClassName(classObject, superFunc)
			local className = superFunc(classObject)

			if className == nil or className == "" then
				className = classObject.className
			end

			return className
		end

		local modEnvMeta = getmetatable(_G)
		local env = modEnvMeta.__index
		env.ClassUtil.getClassName = Utils.overwrittenFunction(env.ClassUtil.getClassName, getClassName)
	end

	FillUnit.UNIT.KILOMETER = {
		l10n = "unit_kmShort",
		conversionFunc = function (value)
			return MathUtil.round(value, 1)
		end
	}
end
