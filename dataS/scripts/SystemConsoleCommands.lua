SystemConsoleCommands = {
	init = function ()
		addConsoleCommand("gsGuiDrawHelper", "", "drawGuiHelper", SystemConsoleCommands)
		addConsoleCommand("gsI3DCacheClean", "Removes all cached i3d files to ensure the latest versions are loaded from disk", "cleanI3DCache", SystemConsoleCommands)
		addConsoleCommand("gsSetHighQuality", "Incease draw and LOD distances of foliage, terrain and objects", "setHighQuality", SystemConsoleCommands)
		addConsoleCommand("gsGuiSafeFrameShow", "", "showSafeFrame", SystemConsoleCommands)
		addConsoleCommand("gsGuiDebug", "", "toggleUiDebug", SystemConsoleCommands)
		addConsoleCommand("gsGuiFocusDebug", "", "toggleUiFocusDebug", SystemConsoleCommands)
		addConsoleCommand("gsRenderColorAndDepthScreenShot", "", "renderColorAndDepthScreenShot", SystemConsoleCommands)

		if g_addCheatCommands then
			addConsoleCommand("gsRenderingDebugMode", "", "setDebugRenderingMode", SystemConsoleCommands)
			addConsoleCommand("gsInputDrawRaw", "", "drawRawInput", SystemConsoleCommands)
			addConsoleCommand("gsTestForceFeedback", "", "testForceFeedback", SystemConsoleCommands)
			addConsoleCommand("gsTextureStreamingSetBudget", "", "setTextureStreamingBudget", SystemConsoleCommands)
		end

		if g_addTestCommands then
			addConsoleCommand("gsLanguageSet", "Set active language", "changeLanguage", SystemConsoleCommands)
			addConsoleCommand("gsGuiReloadCurrent", "", "reloadCurrentGui", SystemConsoleCommands)

			if not GS_IS_CONSOLE_VERSION and not GS_IS_MOBILE_VERSION then
				addConsoleCommand("gsSuspendApp", "", "suspendApp", SystemConsoleCommands)
			end

			addConsoleCommand("gsInputFuzz", "", "fuzzInput", SystemConsoleCommands)
			addConsoleCommand("gsUpdateDownloadFinished", "", "updateDownloadFinished", SystemConsoleCommands)
			addConsoleCommand("gsRenderingFidelityFxSRSet", "", "setFidelityFxSR", SystemConsoleCommands)
			addConsoleCommand("gsSoftRestart", "", "softRestart", SystemConsoleCommands)
		end
	end,
	delete = function ()
		removeConsoleCommand("gsGuiDrawHelper")
		removeConsoleCommand("gsI3DCacheClean")
		removeConsoleCommand("gsSetHighQuality")
		removeConsoleCommand("gsGuiSafeFrameShow")
		removeConsoleCommand("gsGuiDebug")
		removeConsoleCommand("gsGuiFocusDebug")
		removeConsoleCommand("gsRenderColorAndDepthScreenShot")
		removeConsoleCommand("gsRenderingDebugMode")
		removeConsoleCommand("gsInputDrawRaw")
		removeConsoleCommand("gsTestForceFeedback")
		removeConsoleCommand("gsTextureStreamingSetBudget")
		removeConsoleCommand("gsLanguageSet")
		removeConsoleCommand("gsGuiReloadCurrent")
		removeConsoleCommand("gsSuspendApp")
		removeConsoleCommand("gsInputFuzz")
		removeConsoleCommand("gsUpdateDownloadFinished")
		removeConsoleCommand("gsRenderingFidelityFxSRSet")
		removeConsoleCommand("gsSoftRestart")
	end,
	drawGuiHelper = function (self, steps)
		steps = tonumber(steps)

		if steps ~= nil then
			g_guiHelperSteps = math.max(steps, 0.001)
			g_drawGuiHelper = true
		else
			g_guiHelperSteps = 0.1
			g_drawGuiHelper = false
		end

		if g_drawGuiHelper then
			return "DrawGuiHelper = true (step = " .. g_guiHelperSteps .. ")"
		else
			return "DrawGuiHelper = false"
		end
	end,
	showSafeFrame = function (self)
		g_showSafeFrame = not g_showSafeFrame

		return string.format("showSafeFrame = %s", g_showSafeFrame)
	end,
	drawRawInput = function (self)
		g_showRawInput = not g_showRawInput

		return string.format("showRawInput = %s", g_showRawInput)
	end,
	testForceFeedback = function (self)
		if getHasGamepadAxisForceFeedback(0, 0) then
			co = coroutine.create(function ()
				for i = 1, 0, -0.2 do
					setGamepadAxisForceFeedback(0, 0, 0.8, i)
					print(string.format("TestForceFeedback %1.2f", i))
					usleep(500000)
					setGamepadAxisForceFeedback(0, 0, 0.8, -i)
					usleep(500000)
				end

				setGamepadAxisForceFeedback(0, 0, 0, 0)
			end)

			coroutine.resume(co)
		else
			print("Force feedback not available")
		end
	end,
	setTextureStreamingBudget = function (self, sizeInMB)
		sizeInMB = tonumber(sizeInMB)

		if sizeInMB == nil then
			setTextureStreamingMemoryBudget(0)

			return "Reset Texture Streaming Memory Budget to default"
		else
			setTextureStreamingMemoryBudget(sizeInMB)

			return "Set Texture Streaming Memory Budget to " .. sizeInMB .. " MB"
		end
	end,
	cleanI3DCache = function (self, verbose)
		verbose = Utils.stringToBoolean(verbose)

		g_i3DManager:clearEntireSharedI3DFileCache(verbose)

		local ret = "I3D cache cleaned."

		if not verbose then
			ret = ret .. " Use 'true' parameter for verbose output"
		end

		return ret
	end,
	setHighQuality = function (self, coeffOverride)
		local minValue = 1e-06
		local maxValue = 10
		local default = 5
		local usage = string.format("Usage 'gsSetHighQuality <factor (default=%d)>'", default)
		local coeff = MathUtil.clamp(tonumber(coeffOverride) or default, minValue, maxValue)

		setViewDistanceCoeff(coeff)
		setLODDistanceCoeff(coeff)
		setTerrainLODDistanceCoeff(coeff)
		setFoliageViewDistanceCoeff(math.max(1, coeff * 0.5))

		return string.format("High quality activated, used factor=%s.%s", MathUtil.round(coeff, 8), coeffOverride == nil and " " .. usage or "")
	end,
	renderColorAndDepthScreenShot = function (self, inWidth, inHeight)
		local width, height = nil

		if inWidth == nil or inHeight == nil then
			local curScrMode = getScreenMode()
			width, height = getScreenModeInfo(curScrMode)
		else
			width = tonumber(inWidth)
			height = tonumber(inHeight)
		end

		setDebugRenderingMode(DebugRendering.NONE)

		local strDate = getDate("%Y_%m_%d_%H_%M_%S") .. ".hdr"
		local colorScreenShot = g_screenshotsDirectory .. "fsScreen_color_" .. strDate

		print("Saving color screenshot: " .. colorScreenShot)
		renderScreenshot(colorScreenShot, width, height, width / height, "raw_hdr", 1, 0, 0, 0, 0, 0, 15, false, 4)
		setDebugRenderingMode(DebugRendering.DEPTH)

		local depthScreenShot = g_screenshotsDirectory .. "fsScreen_depth_" .. strDate

		print("Saving depth screenshot: " .. depthScreenShot)
		renderScreenshot(depthScreenShot, width, height, width / height, "raw_hdr", 1, 0, 0, 0, 0, 0, 15, false, 0)
		setDebugRenderingMode(DebugRendering.NONE)
	end,
	setDebugRenderingMode = function (self, newMode)
		if newMode == nil or newMode == "" then
			setDebugRenderingMode(DebugRendering.NONE)

			return "Possible modes: alpha, parallax, albedo, normals, smoothness, metalness, ambientOcclusion (ao), bakedAmbientOcclusion (bakedAO), screenSpaceAmbientOcclusion(ssao), specularOcclusion, diffuseLighting, specularLighting, indirectLighting, lightGrid, shadowSplits, depth, mipLevels, triangleDensity, terrainSlopes, motionVectors, vrs"
		end

		newMode = newMode:lower()
		local modeDescs = {
			alpha = {
				DebugRendering.ALPHA,
				"alpha"
			},
			parallax = {
				DebugRendering.PARALLAX,
				"parallax"
			},
			albedo = {
				DebugRendering.ALBEDO,
				"albedo"
			},
			normals = {
				DebugRendering.NORMALS,
				"normals"
			},
			tangent_space_normals = {
				DebugRendering.TANGENT_SPACE_NORMALS,
				"tangentSpaceNormals"
			},
			smoothness = {
				DebugRendering.SMOOTHNESS,
				"smoothness"
			},
			metalness = {
				DebugRendering.METALNESS,
				"metalness"
			},
			ambient_occlusion = {
				DebugRendering.AMBIENT_OCCLUSION,
				"ambientOcclusion"
			},
			ambientocclusion = {
				DebugRendering.AMBIENT_OCCLUSION,
				"ambientOcclusion"
			},
			ao = {
				DebugRendering.AMBIENT_OCCLUSION,
				"ambientOcclusion"
			},
			baked_ambient_occlusion = {
				DebugRendering.BAKED_AMBIENT_OCCLUSION,
				"bakedAmbientOcclusion"
			},
			bakedambientocclusion = {
				DebugRendering.BAKED_AMBIENT_OCCLUSION,
				"bakedAmbientOcclusion"
			},
			bakedao = {
				DebugRendering.BAKED_AMBIENT_OCCLUSION,
				"bakedAmbientOcclusion"
			},
			screenspaceambientocclusion = {
				DebugRendering.SCREEN_SPACE_AMBIENT_OCCLUSION,
				"screenSpaceAmbientOcclusion"
			},
			screen_space_ambient_occlusion = {
				DebugRendering.SCREEN_SPACE_AMBIENT_OCCLUSION,
				"screenSpaceAmbientOcclusion"
			},
			ssao = {
				DebugRendering.SCREEN_SPACE_AMBIENT_OCCLUSION,
				"screenSpaceAmbientOcclusion"
			},
			specular_occlusion = {
				DebugRendering.SPECULAR_OCCLUSION,
				"specularOcclusion"
			},
			specularocclusion = {
				DebugRendering.SPECULAR_OCCLUSION,
				"specularOcclusion"
			},
			diffuse_lighting = {
				DebugRendering.DIFFUSE_LIGHTING,
				"diffuseLighting"
			},
			diffuselighting = {
				DebugRendering.DIFFUSE_LIGHTING,
				"diffuseLighting"
			},
			diffuse = {
				DebugRendering.DIFFUSE_LIGHTING,
				"diffuseLighting"
			},
			specular_lighting = {
				DebugRendering.SPECULAR_LIGHTING,
				"specularLighting"
			},
			specularlighting = {
				DebugRendering.SPECULAR_LIGHTING,
				"specularLighting"
			},
			specular = {
				DebugRendering.SPECULAR_LIGHTING,
				"specularLighting"
			},
			indirect_lighting = {
				DebugRendering.INDIRECT_LIGHTING,
				"indirectLighting"
			},
			indirectlighting = {
				DebugRendering.INDIRECT_LIGHTING,
				"indirectLighting"
			},
			indirect = {
				DebugRendering.INDIRECT_LIGHTING,
				"indirectLighting"
			},
			light_grid = {
				DebugRendering.LIGHT_GRID,
				"lightGrid"
			},
			lightgrid = {
				DebugRendering.LIGHT_GRID,
				"lightGrid"
			},
			shadow_splits = {
				DebugRendering.SHADOW_SPLITS,
				"shadowSplits"
			},
			shadowsplits = {
				DebugRendering.SHADOW_SPLITS,
				"shadowSplits"
			},
			depth = {
				DebugRendering.DEPTH_SCALED,
				"depth"
			},
			miplevels = {
				DebugRendering.MIP_LEVELS,
				"mipLevels"
			},
			mips = {
				DebugRendering.MIP_LEVELS,
				"mipLevels"
			},
			triangledensity = {
				DebugRendering.TRIANGLE_DENSITY,
				"triangleDensity"
			},
			terrainslopes = {
				DebugRendering.TERRAIN_SLOPES,
				"terrainSlopes"
			},
			motionvectors = {
				DebugRendering.MOTION_VECTORS,
				"motionVectors"
			},
			vrs = {
				DebugRendering.SHADING_RATE,
				"vrs"
			},
			custom1 = {
				DebugRendering.CUSTOM1,
				"custom1"
			},
			custom2 = {
				DebugRendering.CUSTOM2,
				"custom2"
			}
		}
		local modeDesc = modeDescs[newMode]
		local modeName = "none"
		local mode = DebugRendering.NONE

		if modeDesc ~= nil then
			mode = modeDesc[1]
			modeName = modeDesc[2]
		end

		setDebugRenderingMode(mode)

		return "Changed debug rendering to " .. modeName
	end,
	changeLanguage = function (self, newCode)
		local numLanguages = getNumOfLanguages()
		local newLang = -1

		if newCode == nil then
			local newIndex = g_settingsLanguageGUI + 1

			if table.getn(g_availableLanguagesTable) <= newIndex then
				newIndex = 0
			end

			newLang = g_availableLanguagesTable[newIndex + 1]
		else
			for i = 0, numLanguages - 1 do
				if getLanguageCode(i) == newCode then
					newLang = i

					break
				end
			end

			if newLang < 0 then
				return "Invalid language parameter " .. tostring(newCode)
			end
		end

		if setLanguage(newLang) then
			local xmlFile = XMLFile.load("SettingsFile", "dataS/settings.xml")

			loadLanguageSettings(xmlFile)
			xmlFile:delete()
			g_i18n:load()

			return string.format("Changed language to '%s'. Note that many texts are loaded on game start and need a reboot to be updated.", getLanguageCode(newLang))
		end

		return "Invalid language parameter " .. tostring(newCode)
	end,
	reloadCurrentGui = function (self)
		if g_gui.currentGuiName ~= nil and g_gui.currentGuiName ~= "" then
			local guiName = g_gui.currentGuiName
			local guiController = g_gui.currentGui.target

			g_gui:showGui("")
			g_i18n:load()

			g_gui.profiles = {}
			g_gui.traits = {}
			local success = g_gui:loadProfiles("dataS/guiProfiles.xml")

			if not success then
				return "Failed to reload profiles"
			end

			local class = ClassUtil.getClassObject(guiName)
			g_dummyGui = nil

			if class.createFromExistingGui ~= nil then
				g_dummyGui = class.createFromExistingGui(guiController, guiName)
			else
				g_dummyGui = class.new()

				g_gui.guis[guiName]:delete()
				g_gui.guis[guiName].target:delete()
				g_gui:loadGui(guiController.xmlFilename, guiName, g_dummyGui)
			end

			g_gui:showGui(guiName)

			return "Reloaded gui " .. tostring(guiName)
		end

		return "No GUI active!"
	end,
	toggleUiDebug = function (self)
		if g_uiDebugEnabled then
			g_uiDebugEnabled = false

			return "UI Debug disabled"
		else
			g_uiDebugEnabled = true

			return "UI Debug enabled"
		end
	end,
	toggleUiFocusDebug = function (self)
		if g_uiFocusDebugEnabled then
			g_uiFocusDebugEnabled = false

			return "UI Focus Debug disabled"
		else
			g_uiFocusDebugEnabled = true

			return "UI Focus Debug enabled"
		end
	end,
	suspendApp = function (self)
		if g_appIsSuspended then
			notifyAppResumed()
		else
			notifyAppSuspended()
		end

		return "App Suspended: " .. tostring(g_appIsSuspended)
	end,
	fuzzInput = function (self)
		beginInputFuzzing()
	end,
	softRestart = function (self)
		if g_currentMission ~= nil then
			OnInGameMenuMenu()

			return
		end

		RestartManager:setStartScreen(RestartManager.START_SCREEN_MAIN)
		doRestart(false, "")
	end,
	updateDownloadFinished = function (self)
		g_updateDownloadFinished = true

		log("g_updateDownloadFinished = true")
	end,
	setFidelityFxSR = function (self, newQuality)
		local usage = "Usage: gsRenderingFidelityFxSRSet <qualityNumber>"
		newQuality = tonumber(newQuality)
		local currentQuality = getFidelityFxSRQuality()

		print(string.format("current setting: %s (%d)", getFidelityFxSRQualityName(currentQuality), currentQuality))
		print("Available settings:")

		for i = 0, FidelityFxSRQuality.NUM - 1 do
			local name = getFidelityFxSRQualityName(i)

			print(string.format("    %d | %s | supported=%s", i, name, getSupportsFidelityFxSRQuality(i)))
		end

		if newQuality ~= nil then
			if newQuality >= 0 and newQuality < FidelityFxSRQuality.NUM and getSupportsFidelityFxSRQuality(newQuality) then
				setFidelityFxSRQuality(newQuality)
			else
				return string.format("Error: Given quality '%d' not supported\n%s", newQuality, usage)
			end

			local effectiveQuality = getFidelityFxSRQuality()

			return string.format("new setting: %s (%d)", getFidelityFxSRQualityName(effectiveQuality), effectiveQuality)
		else
			return usage
		end
	end
}
