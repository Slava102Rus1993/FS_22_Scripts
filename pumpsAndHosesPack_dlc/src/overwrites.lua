local modDirectory = g_currentModDirectory or ""

source(modDirectory .. "src/overwrites/overwrites_sandbox.lua")
source(modDirectory .. "src/overwrites/overwrites_pf.lua")

pnh_overwrite = {}
local originalFunctions = {}

local function inject_helpline_loadMapData(manager, superFunc, xmlFile, missionInfo)
	if not superFunc(manager, xmlFile, missionInfo) then
		return false
	end

	local filename = Utils.getFilename("data/gui/helpLine.xml", modDirectory)

	if filename ~= nil and filename ~= "" then
		manager:loadFromXML(filename)
	end

	return true
end

local function inj_sellingStation_load(object, superFunc, ...)
	if not superFunc(object, ...) then
		return false
	end

	local acceptsStraw = object.acceptedFillTypes[FillType.STRAW]
	local acceptsHay = object.acceptedFillTypes[FillType.DRYGRASS_WINDROW]
	local acceptsGrass = object.acceptedFillTypes[FillType.GRASS_WINDROW]
	local acceptsSilage = object.acceptedFillTypes[FillType.SILAGE]
	local acceptsSugarBeet = object.acceptedFillTypes[FillType.SUGARBEET_CUT]

	if acceptsStraw and acceptsHay and acceptsGrass and acceptsSilage and acceptsSugarBeet then
		for _, trigger in ipairs(object.unloadTriggers) do
			trigger.fillTypes[FillType.SEPARATED_MANURE] = true
		end

		local fillType = g_fillTypeManager:getFillTypeByIndex(FillType.SEPARATED_MANURE)

		object:addAcceptedFillType(FillType.SEPARATED_MANURE, fillType.pricePerLiter, true, false)
		object:initPricingDynamics()
	end

	return true
end

function pnh_overwrite.init()
	pnh_overwrite_sandbox_init()
	pnh_overwrite.overwrittenFunction(SellingStation, "load", inj_sellingStation_load)
	pnh_overwrite.overwrittenFunction(HelpLineManager, "loadMapData", inject_helpline_loadMapData)
end

function pnh_overwrite.load()
	pnh_overwrite_sandbox()
	pnh_overwrite_pf()
end

function pnh_overwrite.validateTypes(typeManager, specializationManager, modDirectory, modName)
	pnh_overwrite_pf_typeManager(typeManager, specializationManager, modDirectory, modName)
end

local function storeOriginalFunction(target, name)
	if not GS_IS_CONSOLE_VERSION then
		return
	end

	if originalFunctions[target] == nil then
		originalFunctions[target] = {}
	end

	if originalFunctions[target][name] == nil then
		originalFunctions[target][name] = target[name]
	end
end

function pnh_overwrite.overwrittenFunction(target, name, newFunc)
	storeOriginalFunction(target, name)

	target[name] = Utils.overwrittenFunction(target[name], newFunc)
end

function pnh_overwrite.appendedFunction(target, name, newFunc)
	storeOriginalFunction(target, name)

	target[name] = Utils.appendedFunction(target[name], newFunc)
end

function pnh_overwrite.prependedFunction(target, name, newFunc)
	storeOriginalFunction(target, name)

	target[name] = Utils.prependedFunction(target[name], newFunc)
end

function pnh_overwrite.resetOriginalFunctions()
	for target, functions in pairs(originalFunctions) do
		for name, func in pairs(functions) do
			target[name] = func
		end
	end
end
