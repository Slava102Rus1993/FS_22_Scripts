source("dataS/scripts/std.lua")
source("dataS/scripts/StartParams.lua")
source("dataS/scripts/shared/string.lua")
source("dataS/scripts/testing.lua")
source("dataS/scripts/events.lua")
source("dataS/scripts/menu.lua")

local debugTool = debug
debug = nil
GS_PROFILE_LOW = 1
GS_PROFILE_MEDIUM = 2
GS_PROFILE_HIGH = 3
GS_PROFILE_VERY_HIGH = 4
g_gameVersion = 14
g_gameVersionNotification = "1.8.2.0"
g_gameVersionDisplay = "1.8.2.0"
g_gameVersionDisplayExtra = ""
g_isDevelopmentConsoleScriptModTesting = false
g_minModDescVersion = 60
g_maxModDescVersion = 72
g_language = 0
g_languageShort = "en"
g_languageSuffix = "_en"
g_showSafeFrame = false
g_flightModeEnabled = false
g_noHudModeEnabled = false
g_woodCuttingMarkerEnabled = true
g_isDevelopmentVersion = false
g_isServerStreamingVersion = false
g_addTestCommands = false
g_addCheatCommands = false
g_showDevelopmentWarnings = false
g_appIsSuspended = false
g_defaultFrameLimit = 60
g_networkDebug = false
g_networkDebugPrints = false
g_gameRevision = "000"
g_buildName = ""
g_buildTypeParam = ""
g_showDeeplinkingFailedMessage = false
g_isSignedIn = false
g_settingsLanguageGUI = 0
g_availableLanguageNamesTable = {}
g_availableLanguagesTable = {}
g_fovYDefault = math.rad(60)
g_fovYMin = math.rad(45)
g_fovYMax = math.rad(90)
g_uiDebugEnabled = false
g_uiFocusDebugEnabled = false
g_logFilePrefixTimestamp = true
g_vehicleColors = {
	{
		brandColor = "SHARED_WHITE2",
		name = "$l10n_ui_colorWhite"
	},
	{
		brandColor = "SHARED_BEIGE",
		name = "$l10n_ui_colorBeige"
	},
	{
		brandColor = "SHARED_SILVER",
		name = "$l10n_ui_colorSilver"
	},
	{
		brandColor = "SHARED_GREYLIGHT",
		name = "$l10n_ui_colorGreyLight"
	},
	{
		brandColor = "SHARED_GREY",
		name = "$l10n_ui_colorGrey"
	},
	{
		brandColor = "SHARED_GREYDARK",
		name = "$l10n_ui_colorGreyDark"
	},
	{
		brandColor = "SHARED_BLACKONYX",
		name = "$l10n_ui_colorBlackOnyx"
	},
	{
		brandColor = "SHARED_BLACKJET",
		name = "$l10n_ui_colorBlackJet"
	},
	{
		brandColor = "JOHNDEERE_YELLOW1",
		name = "John Deere"
	},
	{
		brandColor = "JCB_YELLOW1",
		name = "JCB"
	},
	{
		brandColor = "CHALLENGER_YELLOW1",
		name = "Challenger"
	},
	{
		brandColor = "SCHOUTEN_ORANGE1",
		name = "Schouten"
	},
	{
		brandColor = "FENDT_RED1",
		name = "Fendt"
	},
	{
		brandColor = "CASEIH_RED1",
		name = "Case IH"
	},
	{
		brandColor = "MASSEYFERGUSON_RED",
		name = "Massey Ferguson"
	},
	{
		brandColor = "HARDI_RED",
		name = "Hardi"
	},
	{
		brandColor = "NEWHOLLAND_BLUE2",
		name = "$l10n_ui_colorAzul"
	},
	{
		brandColor = "RABE_BLUE1",
		name = "Rabe"
	},
	{
		brandColor = "LEMKEN_BLUE1",
		name = "Lemken"
	},
	{
		brandColor = "NEWHOLLAND_BLUE1",
		name = "New Holland"
	},
	{
		brandColor = "BOECKMANN_BLUE1",
		name = "Boeckmann"
	},
	{
		brandColor = "GOLDHOFER_BLUE",
		name = "Goldhofer"
	},
	{
		brandColor = "SHARED_BLUENAVY",
		name = "$l10n_ui_colorBlueNavy"
	},
	{
		brandColor = "LIZARD_PURPLE1",
		name = "$l10n_ui_colorPurple"
	},
	{
		brandColor = "VALTRA_GREEN2",
		name = "Valtra"
	},
	{
		brandColor = "DEUTZ_GREEN4",
		name = "Deutz Fahr"
	},
	{
		brandColor = "JOHNDEERE_GREEN1",
		name = "John Deere"
	},
	{
		brandColor = "FENDT_NEWGREEN1",
		name = "Fendt Nature Green"
	},
	{
		brandColor = "FENDT_OLDGREEN1",
		name = "Fendt Classic"
	},
	{
		brandColor = "KOTTE_GREEN2",
		name = "Kotte"
	},
	{
		brandColor = "CLAAS_GREEN1",
		name = "Claas"
	},
	{
		brandColor = "LIZARD_OLIVE1",
		name = "$l10n_ui_colorGreenOlive"
	},
	{
		brandColor = "LIZARD_ECRU1",
		name = "$l10n_ui_colorBeige"
	},
	{
		brandColor = "SHARED_BROWN",
		name = "$l10n_ui_colorBrown"
	},
	{
		brandColor = "SHARED_REDCRIMSON",
		name = "$l10n_ui_colorRedCrimson"
	},
	{
		brandColor = "LIZARD_PINK1",
		name = "$l10n_ui_colorPink"
	}
}
g_densityMapRevision = 3
g_terrainTextureRevision = 1
g_terrainLodTextureRevision = 2
g_splitShapesRevision = 2
g_tipCollisionRevision = 2
g_placementCollisionRevision = 2
g_navigationCollisionRevision = 2
g_menuMusic = nil
g_menuMusicIsPlayingStarted = false
g_clientInterpDelay = 100
g_clientInterpDelayMin = 60
g_clientInterpDelayMax = 150
g_clientInterpDelayBufferOffset = 30
g_clientInterpDelayBufferScale = 0.5
g_clientInterpDelayBufferMin = 45
g_clientInterpDelayBufferMax = 60
g_clientInterpDelayAdjustDown = 0.002
g_clientInterpDelayAdjustUp = 0.08
g_time = 0
g_currentDt = 16.666666666666668
g_updateLoopIndex = 0
g_physicsTimeLooped = 0
g_physicsDt = 16.666666666666668
g_physicsDtUnclamped = 16.666666666666668
g_physicsDtNonInterpolated = 16.666666666666668
g_physicsDtLastValidNonInterpolated = 16.666666666666668
g_packetPhysicsNetworkTime = 0
g_networkTime = netGetTime()
g_physicsNetworkTime = g_networkTime
g_analogStickHTolerance = 0.45
g_analogStickVTolerance = 0.45
g_referenceScreenWidth = 1920
g_referenceScreenHeight = 1080
g_maxUploadRate = 30.72
g_maxUploadRatePerClient = 393.216
g_drawGuiHelper = false
g_guiHelperSteps = 0.1
g_lastMousePosX = 0
g_lastMousePosY = 0
g_screenWidth = 800
g_screenHeight = 600
g_screenAspectRatio = g_screenWidth / g_screenHeight
g_presentedScreenAspectRatio = g_screenAspectRatio
g_darkControllerOverlay = nil
g_aspectScaleX = 1
g_aspectScaleX = 1
g_dedicatedServer = nil
g_joinServerMaxCapacity = 16
g_serverMaxClientCapacity = 16
g_serverMinCapacity = 2
g_nextModRecommendationTime = 0
g_maxNumLoadingBarSteps = 35
g_curNumLoadingBarStep = 0
g_updateDownloadFinished = false
g_updateDownloadFinishedDialogShown = false
g_skipStartupScreen = false

function initPlatform()
	local debugPlatformId = nil

	if StartParams.getIsSet("platform") then
		local debugPlatform = string.trim(StartParams.getValue("platform") or "")

		if PlatformId[debugPlatform] ~= nil then
			debugPlatformId = PlatformId[debugPlatform]
		end
	end

	if debugPlatformId ~= nil then
		function getPlatformId()
			return debugPlatformId
		end
	end

	local platformId = getPlatformId()
	GS_PLATFORM_ID = platformId
	GS_PLATFORM_PC = platformId == PlatformId.WIN or platformId == PlatformId.MAC
	GS_PLATFORM_XBOX = platformId == PlatformId.XBOX_ONE or platformId == PlatformId.XBOX_SERIES
	GS_PLATFORM_PLAYSTATION = platformId == PlatformId.PS4 or platformId == PlatformId.PS5
	GS_PLATFORM_GGP = platformId == PlatformId.GGP
	GS_PLATFORM_SWITCH = platformId == PlatformId.SWITCH
	GS_PLATFORM_PHONE = platformId == PlatformId.ANDROID or platformId == PlatformId.IOS
	GS_IS_CONSOLE_VERSION = GS_PLATFORM_XBOX or GS_PLATFORM_PLAYSTATION
	GS_IS_MOBILE_VERSION = GS_PLATFORM_PHONE or GS_PLATFORM_SWITCH
end

function init(args)
	StartParams.init(args)

	if initTesting() then
		return
	end

	initPlatform()
	source("dataS/scripts/game.lua")
	Platform.init()

	local settingsXML = XMLFile.load("SettingsFile", "dataS/settings.xml")
	local developmentLevel = settingsXML:getString("settings#developmentLevel", "release"):lower()
	g_buildName = settingsXML:getString("settings#buildName", g_buildName)
	g_buildTypeParam = settingsXML:getString("settings#buildTypeParam", g_buildTypeParam)
	g_gameRevision = settingsXML:getString("settings#revision", g_gameRevision)
	g_gameRevision = g_gameRevision .. getGameRevisionExtraText()
	g_isDevelopmentVersion = false

	if developmentLevel == "internal" then
		print("INTERNAL VERSION")

		g_addTestCommands = true
	elseif developmentLevel == "development" then
		print("DEVELOPMENT VERSION")

		g_isDevelopmentVersion = true
		g_addTestCommands = true

		enableDevelopmentControls()
	end

	if g_isDevelopmentVersion then
		g_networkDebug = true
	end

	if g_addTestCommands or StartParams.getIsSet("cheats") then
		g_addCheatCommands = true
	end

	if g_addTestCommands or StartParams.getIsSet("devWarnings") then
		g_showDevelopmentWarnings = true
	end

	if g_isDevelopmentVersion then
		if StartParams.getIsSet("consoleSimulator") then
			ConsoleSimulator.init()
			ImeSimulator.init()
		end

		if StartParams.getIsSet("stadiaSimulator") then
			StadiaSimulator.init()
			ImeSimulator.init()
		end

		if StartParams.getIsSet("imeSimulator") then
			ImeSimulator.init()
		end

		if StartParams.getIsSet("iapSimulator") then
			IAPSimulator.init()
		end
	end

	g_serverMaxCapacity = GS_IS_CONSOLE_VERSION and 6 or 16

	AudioGroup.loadGroups()
	g_i3DManager:init()
	updateLoadingBarProgress()

	g_messageCenter = MessageCenter.new()

	updateLoadingBarProgress()

	g_soundMixer = SoundMixer.new()

	updateLoadingBarProgress()

	g_autoSaveManager = AutoSaveManager.new()

	updateLoadingBarProgress()

	local kioskMode = KioskMode.new()

	if kioskMode:load() then
		g_kioskMode = kioskMode
	end

	g_lifetimeStats = LifetimeStats.new()

	g_lifetimeStats:load()

	local isServerStart = StartParams.getIsSet("server")
	local autoStartSavegameId = StartParams.getValue("autoStartSavegameId")
	local devStartServer = StartParams.getValue("devStartServer")
	local devStartClient = StartParams.getValue("devStartClient")
	local devUniqueUserId = g_isDevelopmentVersion and StartParams.getValue("uniqueUserId") or nil

	if Platform.isPlaystation then
		g_screenWidth = 1920
		g_screenHeight = 1080
	else
		g_screenWidth, g_screenHeight = getScreenModeInfo(getScreenMode())
	end

	g_baseUIPostfix = ""
	g_baseUIFilename = "dataS/menu/hud/ui_elements.png"
	g_iconsUIFilename = "dataS/menu/hud/ui_icons.png"
	g_baseHUDFilename = "dataS/menu/hud/hud_elements.png"

	if g_isDevelopmentVersion then
		print(string.format(" Loading UI-textures: '%s' '%s' '%s'", g_baseUIFilename, g_baseHUDFilename, g_iconsUIFilename))
	end

	g_screenAspectRatio = g_screenWidth / g_screenHeight
	g_presentedScreenAspectRatio = getScreenAspectRatio()

	updateAspectRatio(g_presentedScreenAspectRatio)

	g_colorBgUVs = GuiUtils.getUVs({
		10,
		1010,
		4,
		4
	})
	local safeFrameOffsetX = Platform.safeFrameOffsetX
	local safeFrameOffsetY = Platform.safeFrameOffsetY
	g_safeFrameOffsetX, g_safeFrameOffsetY = getNormalizedScreenValues(safeFrameOffsetX, safeFrameOffsetY)
	local safeFrameMajorOffsetX = Platform.safeFrameMajorOffsetX
	local safeFrameMajorOffsetY = Platform.safeFrameMajorOffsetY
	g_safeFrameMajorOffsetX, g_safeFrameMajorOffsetY = getNormalizedScreenValues(safeFrameMajorOffsetX, safeFrameMajorOffsetY)

	registerProfileFile("gameSettings.xml")
	registerProfileFile("extraContent.xml")

	g_gameSettings = GameSettings.new(nil, g_messageCenter)

	loadUserSettings(g_gameSettings)
	updateLoadingBarProgress()
	loadLanguageSettings(settingsXML)

	local availableLanguagesString = "Available Languages:"

	for _, lang in ipairs(g_availableLanguagesTable) do
		availableLanguagesString = availableLanguagesString .. " " .. getLanguageCode(lang)
	end

	settingsXML:delete()

	local caption = "Farming Simulator 22"

	if Platform.isPlaystation then
		caption = caption .. " (PlayStation 4)"
	elseif Platform.isXbox then
		caption = caption .. " (XboxOne)"
	elseif Platform.isSwitch then
		caption = caption .. " (Switch)"
	elseif Platform.isAndroid then
		caption = caption .. " (Android)"
	elseif Platform.isIOS then
		caption = caption .. " (iOS)"
	end

	if g_isDevelopmentVersion then
		local gameVersionText = g_gameVersionDisplay .. g_gameVersionDisplayExtra .. " (" .. getEngineRevision() .. "/" .. g_gameRevision .. ")"
		caption = caption .. " - DevelopmentVersion - " .. gameVersionText
	elseif g_addTestCommands then
		caption = caption .. " - InternalVersion"
	end

	if I3DManager.loadingDelay ~= nil then
		caption = caption .. " - I3D Delay " .. I3DManager.loadingDelay .. "ms"
	end

	setCaption(caption)
	addNotificationFilter(GS_PRODUCT_ID, g_gameVersionNotification)
	updateLoadingBarProgress()

	local nameExtra = ""

	if g_buildTypeParam ~= "" then
		nameExtra = nameExtra .. " " .. g_buildTypeParam
	end

	if GS_IS_STEAM_VERSION then
		nameExtra = nameExtra .. " (Steam)"
	end

	if GS_IS_EPIC_VERSION then
		nameExtra = nameExtra .. " (Epic)"
	end

	if isServerStart then
		nameExtra = nameExtra .. " (Server)"
	end

	print("Farming Simulator 22" .. nameExtra)
	print("  Version: " .. g_gameVersionDisplay .. g_gameVersionDisplayExtra .. " " .. g_buildName)
	print("  " .. availableLanguagesString)
	print("  Language: " .. g_languageShort)
	print("  Time: " .. getDate("%Y-%m-%d %H:%M:%S"))
	print("  ModDesc Version: " .. g_maxModDescVersion)

	if Platform.isPC then
		local screenshotsDir = getUserProfileAppPath() .. "screenshots/"
		g_screenshotsDirectory = screenshotsDir

		createFolder(screenshotsDir)

		local modSettingsDir = getUserProfileAppPath() .. "modSettings/"
		g_modSettingsDirectory = modSettingsDir

		createFolder(modSettingsDir)
	end

	g_adsSystem = AdsSystem.new()
	local modsDir = getModInstallPath()
	local modDownloadDir = getModDownloadPath()

	updateLoadingBarProgress()

	if Platform.allowsModDirectoryOverride then
		local modsDir2 = nil

		if Utils.getNoNil(getXMLBool(g_savegameXML, "gameSettings.modsDirectoryOverride#active"), false) then
			modsDir2 = getXMLString(g_savegameXML, "gameSettings.modsDirectoryOverride#directory")

			if modsDir2 ~= nil and modsDir2 ~= "" then
				modsDir = modsDir2
				modsDir = modsDir:gsub("\\", "/")

				if modsDir:sub(1, 2) == "//" then
					modsDir = "\\\\" .. modsDir:sub(3)
				end

				if modsDir:sub(modsDir:len(), modsDir:len()) ~= "/" then
					modsDir = modsDir .. "/"
				end
			end
		end
	end

	updateLoadingBarProgress()

	if modsDir then
		print("  Mod Directory: " .. modsDir)
		createFolder(modsDir)
	end

	if modDownloadDir then
		createFolder(modDownloadDir)
	end

	g_modsDirectory = modsDir

	if g_addTestCommands then
		print("  Testing Commands: Enabled")
	elseif g_addCheatCommands then
		print("  Cheats: Enabled")
	end

	updateLoadingBarProgress()

	g_i18n = I18N.new()

	g_i18n:load()

	if Platform.hasExtraContent then
		g_extraContentSystem = ExtraContentSystem.new()

		g_extraContentSystem:loadFromXML("dataS/extraContent.xml")
		g_extraContentSystem:loadFromProfile()
	end

	updateLoadingBarProgress()
	setMaxNumOfReflectionPlanes(math.max(g_gameSettings:getValue("maxNumMirrors") + 1, 3))
	math.randomseed(getTime())
	math.random()
	math.random()
	math.random()
	updateLoadingBarProgress()
	g_splitTypeManager:load()
	addSplitShapesShaderParameterOverwrite("windSnowLeafScale", 0, 0, 0, 80)

	local mapsXML = XMLFile.load("MapsXML", "dataS/maps.xml")

	mapsXML:iterate("maps.map", function (_, key)
		g_mapManager:loadMapFromXML(mapsXML, key, "", nil, true, true, false)
	end)
	mapsXML:delete()
	updateLoadingBarProgress()
	g_characterModelManager:load("dataS/character/humans/player/playerModels.xml")
	updateLoadingBarProgress()
	registerHandTool("chainsaw", Chainsaw)
	registerHandTool("highPressureWasherLance", HighPressureWasherLance)

	g_animCache = AnimationCache.new()

	g_animCache:load(AnimationCache.CHARACTER, "dataS/character/humans/player/animations.i3d")
	updateLoadingBarProgress()
	g_animCache:load(AnimationCache.VEHICLE_CHARACTER, "dataS/character/humans/player/vehicleCharacterAnimations.i3d")

	if Platform.supportsPedestrians then
		g_animCache:load(AnimationCache.PEDESTRIAN, "dataS/character/humans/npc/animations.i3d")
	end

	g_achievementManager = AchievementManager.new(nil, g_messageCenter)

	g_achievementManager:load()
	updateLoadingBarProgress()

	if g_modsDirectory then
		initModDownloadManager(g_modsDirectory, modDownloadDir, g_minModDescVersion, g_maxModDescVersion, g_isDevelopmentVersion)
	end

	startUpdatePendingMods()
	updateLoadingBarProgress()
	loadDlcs()
	updateLoadingBarProgress()

	local startedRepeat = startFrameRepeatMode()

	while isModUpdateRunning() do
		usleep(16000)
	end

	if startedRepeat then
		endFrameRepeatMode()
	end

	if Platform.supportsMods then
		loadInternalMods()
		loadMods()
	end

	if not Platform.isConsole then
		copyFile(getAppBasePath() .. "VERSION", getUserProfileAppPath() .. "VERSION", true)
	end

	updateLoadingBarProgress()

	g_inputBinding = InputBinding.new(g_modManager, g_messageCenter, GS_IS_CONSOLE_VERSION)

	g_inputBinding:load()

	if g_kioskMode ~= nil then
		g_kioskMode:loadInputBindings()
	end

	g_inputDisplayManager = InputDisplayManager.new(g_messageCenter, g_inputBinding, g_modManager, GS_IS_CONSOLE_VERSION)

	g_inputDisplayManager:load()

	if Platform.isMobile then
		g_touchHandler = TouchHandler.new()
	end

	updateLoadingBarProgress()
	simulatePhysics(false)

	if isServerStart then
		g_dedicatedServer = DedicatedServer.new()

		g_dedicatedServer:load(getUserProfileAppPath() .. "dedicated_server/dedicatedServerConfig.xml")
		g_dedicatedServer:setGameStatsPath(getUserProfileAppPath() .. "dedicated_server/gameStats.xml")
	end

	updateLoadingBarProgress()

	g_connectionManager = ConnectionManager.new()
	g_masterServerConnection = MasterServerConnection.new()
	local guiSoundPlayer = GuiSoundPlayer.new(g_soundManager)
	g_gui = Gui.new(g_messageCenter, g_languageSuffix, g_inputBinding, guiSoundPlayer)

	g_gui:loadProfiles("dataS/guiProfiles.xml")

	local startMissionInfo = StartMissionInfo.new()
	g_mainScreen = MainScreen.new(nil, , startMissionInfo)
	g_creditsScreen = CreditsScreen.new(nil, , startMissionInfo)

	updateLoadingBarProgress()

	local settingsModel = SettingsModel.new(g_gameSettings, g_savegameXML, g_i18n, g_soundMixer, GS_IS_CONSOLE_VERSION)
	g_settingsScreen = SettingsScreen.new(nil, , g_messageCenter, g_i18n, g_inputBinding, settingsModel, GS_IS_CONSOLE_VERSION)
	local savegameController = SavegameController.new()
	g_careerScreen = CareerScreen.new(nil, , savegameController, startMissionInfo)
	g_scenariosScreen = ScenariosScreen.new(nil, , savegameController, startMissionInfo)
	g_difficultyScreen = DifficultyScreen.new(nil, , startMissionInfo)

	updateLoadingBarProgress()

	local inAppPurchaseController = InAppPurchaseController.new(g_messageCenter, g_i18n, g_gameSettings)
	local shopController = ShopController.new(g_messageCenter, g_i18n, g_storeManager, g_brandManager, g_fillTypeManager, inAppPurchaseController)
	local inGameMenuMapFrame = InGameMenuMapFrame.new(nil, g_messageCenter, g_i18n, g_inputBinding, g_inputDisplayManager, g_fruitTypeManager, g_fillTypeManager, g_storeManager, shopController, g_farmlandManager, g_farmManager)
	local inGameMenuAIFrame = InGameMenuAIFrame.new(nil, g_messageCenter, g_i18n, g_inputBinding, g_inputDisplayManager, g_fruitTypeManager, g_fillTypeManager, g_storeManager, shopController, g_farmlandManager, g_farmManager)
	local inGameMenuPricesFrame = InGameMenuPricesFrame.new(nil, g_i18n, g_fillTypeManager)
	local inGameMenuVehiclesFrame = InGameMenuVehiclesFrame.new(nil, g_messageCenter, g_i18n, g_storeManager, g_brandManager, shopController)
	local inGameMenuFinancesFrame = InGameMenuFinancesFrame.new(nil, g_messageCenter, g_i18n, g_inputBinding)
	local animalFrameClass = GS_IS_MOBILE_VERSION and InGameMenuAnimalsFrameMobile or InGameMenuAnimalsFrame
	local inGameMenuAnimalsFrame = animalFrameClass.new(nil, g_messageCenter, g_i18n, g_fillTypeManager)
	local inGameMenuContractsFrame = InGameMenuContractsFrame.new(nil, g_messageCenter, g_i18n, g_missionManager)
	local inGameMenuCalendarFrame = InGameMenuCalendarFrame.new(nil, g_messageCenter, g_i18n)
	local inGameMenuWeatherFrame = InGameMenuWeatherFrame.new(nil, g_messageCenter, g_i18n)
	local inGameMenuProductionFrame = InGameMenuProductionFrame.new(g_messageCenter, g_i18n)
	local inGameMenuStatisticsFrame = InGameMenuStatisticsFrame.new()
	local inGameMenuMultiplayerFarmsFrame = InGameMenuMultiplayerFarmsFrame.new(nil, g_messageCenter, g_i18n, g_farmManager)
	local inGameMenuMultiplayerUsersFrame = InGameMenuMultiplayerUsersFrame.new(nil, g_messageCenter, g_i18n, g_farmManager)
	local inGameMenuHelpFrame = InGameMenuHelpFrame.new(nil, g_i18n, g_helpLineManager)
	local inGameMenuTourFrame = InGameMenuTourFrame.new(nil, g_i18n)
	local inGameMenuGeneralSettingsFrame = InGameMenuGeneralSettingsFrame.new(nil, settingsModel)
	local inGameMenuGameSettingsFrame = InGameMenuGameSettingsFrame.new(nil, g_i18n)
	local inGameMenuMobileSettingsFrame, inGameMenuMainFrame = nil

	if Platform.isMobile then
		inGameMenuMobileSettingsFrame = InGameMenuMobileSettingsFrame.new(nil, settingsModel, g_messageCenter)
		inGameMenuMainFrame = InGameMenuMainFrame.new(nil, g_i18n)
	end

	local shopCategoriesFrame = ShopCategoriesFrame.new(nil, shopController)
	local shopOthersFrame = ShopOthersFrame.new()
	local shopItemsFrame = ShopItemsFrame.new(nil, shopController, g_i18n, g_brandManager, GS_IS_CONSOLE_VERSION)
	g_shopConfigScreen = ShopConfigScreen.new(shopController, g_messageCenter, g_i18n, g_i3DManager, g_brandManager, g_configurationManager, g_vehicleTypeManager, g_inputBinding, g_inputDisplayManager)
	local inGameMenu = InGameMenu.new(nil, , g_messageCenter, g_i18n, g_inputBinding, savegameController, g_fruitTypeManager, g_fillTypeManager, GS_IS_CONSOLE_VERSION)
	local shopMenu = ShopMenu.new(nil, , g_messageCenter, g_i18n, g_inputBinding, g_fruitTypeManager, g_fillTypeManager, g_storeManager, shopController, g_shopConfigScreen, GS_IS_CONSOLE_VERSION, inAppPurchaseController)
	local constructionScreen = ConstructionScreen.new(nil, , g_i18n, g_messageCenter, g_inputBinding)

	updateLoadingBarProgress()

	if Platform.needsSignIn then
		g_gamepadSigninScreen = GamepadSigninScreen.new(inGameMenu, shopMenu, g_achievementManager, settingsModel)
	end

	g_animalScreen = AnimalScreen.new()
	g_workshopScreen = WorkshopScreen.new(nil, , g_shopConfigScreen, g_messageCenter)
	local missionCollaborators = MissionCollaborators.new()
	missionCollaborators.messageCenter = g_messageCenter
	missionCollaborators.savegameController = savegameController
	missionCollaborators.achievementManager = g_achievementManager
	missionCollaborators.inputManager = g_inputBinding
	missionCollaborators.inputDisplayManager = g_inputDisplayManager
	missionCollaborators.modManager = g_modManager
	missionCollaborators.fillTypeManager = g_fillTypeManager
	missionCollaborators.fruitTypeManager = g_fruitTypeManager
	missionCollaborators.inGameMenu = inGameMenu
	missionCollaborators.shopMenu = shopMenu
	missionCollaborators.guiSoundPlayer = guiSoundPlayer
	missionCollaborators.shopController = shopController
	g_mpLoadingScreen = MPLoadingScreen.new(nil, , missionCollaborators, savegameController, OnLoadingScreen)
	g_mapSelectionScreen = MapSelectionScreen.new(nil, , startMissionInfo)
	g_modSelectionScreen = ModSelectionScreen.new(nil, , startMissionInfo, g_i18n, GS_IS_CONSOLE_VERSION)
	g_achievementsScreen = AchievementsScreen.new(nil, , g_achievementManager)

	updateLoadingBarProgress()

	if Platform.showStartupScreen and g_skipStartupScreen == false then
		g_startupScreen = StartupScreen.new()
	end

	g_createGameScreen = CreateGameScreen.new(nil, , startMissionInfo)
	g_multiplayerScreen = MultiplayerScreen.new(nil, , startMissionInfo)
	g_joinGameScreen = JoinGameScreen.new(nil, , startMissionInfo, g_messageCenter, g_inputBinding)
	g_connectToMasterServerScreen = ConnectToMasterServerScreen.new(nil, , startMissionInfo)

	updateLoadingBarProgress()

	g_serverDetailScreen = ServerDetailScreen.new()
	g_messageDialog = MessageDialog.new()
	g_yesNoDialog = YesNoDialog.new()
	local leaseYesNoDialog = LeaseYesNoDialog.new()
	local optionDialog = OptionDialog.new()
	local sleepDialog = SleepDialog.new()
	g_textInputDialog = TextInputDialog.new(nil, , g_inputBinding)
	g_passwordDialog = TextInputDialog.new(nil, , g_inputBinding)
	g_infoDialog = InfoDialog.new()
	local placeableInfoDialog = PlaceableInfoDialog.new()
	g_connectionFailedDialog = ConnectionFailedDialog.new()
	g_colorPickerDialog = ColorPickerDialog.new()
	g_licensePlateDialog = LicensePlateDialog.new()
	g_chatDialog = ChatDialog.new()
	g_denyAcceptDialog = DenyAcceptDialog.new()
	g_siloDialog = SiloDialog.new()
	g_refillDialog = RefillDialog.new()
	g_animalDialog = AnimalDialog.new()
	g_savegameConflictDialog = SavegameConflictDialog.new(nil, , g_i18n, savegameController)
	g_gameRateDialog = GameRateDialog.new()
	local transferMoneyDialog = TransferMoneyDialog.new()
	g_sellItemDialog = SellItemDialog.new()
	local editFarmDialog = EditFarmDialog.new(nil, , g_i18n, g_farmManager)
	local unBanDialog = UnBanDialog.new(nil, , g_i18n)
	local serverSettingsDialog = ServerSettingsDialog.new(nil, , g_i18n, settingsModel)
	local modHubScreenshotDialog = ModHubScreenshotDialog.new()

	updateLoadingBarProgress()

	g_modHubController = ModHubController.new(g_messageCenter, g_i18n, g_gameSettings)

	if g_kioskMode ~= nil then
		g_kioskMode:initializedGUIClasses()
	end

	g_gui:loadGui("dataS/gui/SettingsGeneralFrame.xml", "SettingsGeneralFrame", SettingsGeneralFrame.new(nil, , settingsModel, g_i18n), true)
	g_gui:loadGui("dataS/gui/SettingsAdvancedFrame.xml", "SettingsAdvancedFrame", SettingsAdvancedFrame.new(nil, , settingsModel, g_i18n), true)
	g_gui:loadGui("dataS/gui/SettingsHDRFrame.xml", "SettingsHDRFrame", SettingsHDRFrame.new(nil, , settingsModel, g_i18n), true)
	g_gui:loadGui("dataS/gui/SettingsDisplayFrame.xml", "SettingsDisplayFrame", SettingsDisplayFrame.new(nil, , settingsModel, g_i18n), true)
	g_gui:loadGui("dataS/gui/SettingsControlsFrame.xml", "SettingsControlsFrame", SettingsControlsFrame.new(nil, g_i18n), true)
	g_gui:loadGui("dataS/gui/SettingsConsoleFrame.xml", "SettingsConsoleFrame", SettingsConsoleFrame.new(nil, , settingsModel, g_i18n), true)
	g_gui:loadGui("dataS/gui/SettingsDeviceFrame.xml", "SettingsDeviceFrame", SettingsDeviceFrame.new(nil, , settingsModel, g_i18n), true)
	g_gui:loadGui("dataS/gui/MainScreen.xml", "MainScreen", g_mainScreen)
	g_gui:loadGui("dataS/gui/CreditsScreen.xml", "CreditsScreen", g_creditsScreen)

	if Platform.needsSignIn then
		g_gui:loadGui("dataS/gui/GamepadSigninScreen.xml", "GamepadSigninScreen", g_gamepadSigninScreen)
	end

	g_gui:loadGui("dataS/gui/SettingsScreen.xml", "SettingsScreen", g_settingsScreen)
	g_gui:loadGui("dataS/gui/CareerScreen.xml", "CareerScreen", g_careerScreen)
	g_gui:loadGui("dataS/gui/ScenariosScreen.xml", "ScenariosScreen", g_scenariosScreen)
	updateLoadingBarProgress()
	g_gui:loadGui("dataS/gui/DifficultyScreen.xml", "DifficultyScreen", g_difficultyScreen)
	updateLoadingBarProgress()
	g_gui:loadGui("dataS/gui/ShopConfigScreen.xml", "ShopConfigScreen", g_shopConfigScreen)
	g_gui:loadGui("dataS/gui/ConstructionScreen.xml", "ConstructionScreen", constructionScreen)
	g_gui:loadGui("dataS/gui/MapSelectionScreen.xml", "MapSelectionScreen", g_mapSelectionScreen)
	g_gui:loadGui("dataS/gui/ModSelectionScreen.xml", "ModSelectionScreen", g_modSelectionScreen)
	updateLoadingBarProgress()
	g_gui:loadGui("dataS/gui/AchievementsScreen.xml", "AchievementsScreen", g_achievementsScreen)
	g_gui:loadGui("dataS/gui/AnimalScreen.xml", "AnimalScreen", g_animalScreen)

	if Platform.showStartupScreen and g_skipStartupScreen == false then
		g_gui:loadGui("dataS/gui/StartupScreen.xml", "StartupScreen", g_startupScreen)
	end

	g_gui:loadGui("dataS/gui/MPLoadingScreen.xml", "MPLoadingScreen", g_mpLoadingScreen)
	g_gui:loadGui("dataS/gui/CreateGameScreen.xml", "CreateGameScreen", g_createGameScreen)
	updateLoadingBarProgress()
	g_gui:loadGui("dataS/gui/WorkshopScreen.xml", "WorkshopScreen", g_workshopScreen)
	g_gui:loadGui("dataS/gui/MultiplayerScreen.xml", "MultiplayerScreen", g_multiplayerScreen)
	g_gui:loadGui("dataS/gui/JoinGameScreen.xml", "JoinGameScreen", g_joinGameScreen)
	g_gui:loadGui("dataS/gui/ConnectToMasterServerScreen.xml", "ConnectToMasterServerScreen", g_connectToMasterServerScreen)
	g_gui:loadGui("dataS/gui/ServerDetailScreen.xml", "ServerDetailScreen", g_serverDetailScreen)

	if Platform.supportsMods then
		local modHubLoadingFrame = ModHubLoadingFrame.new(nil)
		local modHubCategoriesFrame = ModHubCategoriesFrame.new(nil, g_modHubController, g_i18n, GS_IS_CONSOLE_VERSION)
		local modHubItemsFrame = ModHubItemsFrame.new(nil, g_modHubController, g_i18n, GS_IS_CONSOLE_VERSION)
		local modHubDetailsFrame = ModHubDetailsFrame.new(nil, g_modHubController, g_i18n, GS_IS_CONSOLE_VERSION, GS_IS_STEAM_VERSION)
		local modHubExtraContentFrame = ModHubExtraContentFrame.new(nil)
		local voteDialog = VoteDialog.new(nil, )
		g_modHubScreen = ModHubScreen.new(nil, , g_messageCenter, g_i18n, g_inputBinding, g_modHubController, GS_IS_CONSOLE_VERSION)

		g_gui:loadGui("dataS/gui/ModHubLoadingFrame.xml", "ModHubLoadingFrame", modHubLoadingFrame, true)
		g_gui:loadGui("dataS/gui/ModHubCategoriesFrame.xml", "ModHubCategoriesFrame", modHubCategoriesFrame, true)
		g_gui:loadGui("dataS/gui/ModHubItemsFrame.xml", "ModHubItemsFrame", modHubItemsFrame, true)
		g_gui:loadGui("dataS/gui/ModHubDetailsFrame.xml", "ModHubDetailsFrame", modHubDetailsFrame, true)
		g_gui:loadGui("dataS/gui/ModHubExtraContentFrame.xml", "ModHubExtraContentFrame", modHubExtraContentFrame, true)
		g_gui:loadGui("dataS/gui/ModHubScreen.xml", "ModHubScreen", g_modHubScreen)
		g_gui:loadGui("dataS/gui/dialogs/VoteDialog.xml", "VoteDialog", voteDialog)
	end

	if Platform.hasWardrobe then
		local wardrobeItemsFrame = WardrobeItemsFrame.new(nil)
		local wardrobeColorsFrame = WardrobeColorsFrame.new(nil)
		local wardrobeOutfitsFrame = WardrobeOutfitsFrame.new(nil)
		local wardrobeCharactersFrame = WardrobeCharactersFrame.new(nil)
		g_wardrobeScreen = WardrobeScreen.new(nil, , g_messageCenter, g_i18n, g_inputBinding)

		g_gui:loadGui("dataS/gui/WardrobeItemsFrame.xml", "WardrobeItemsFrame", wardrobeItemsFrame, true)
		g_gui:loadGui("dataS/gui/WardrobeColorsFrame.xml", "WardrobeColorsFrame", wardrobeColorsFrame, true)
		g_gui:loadGui("dataS/gui/WardrobeOutfitsFrame.xml", "WardrobeOutfitsFrame", wardrobeOutfitsFrame, true)
		g_gui:loadGui("dataS/gui/WardrobeCharactersFrame.xml", "WardrobeCharactersFrame", wardrobeCharactersFrame, true)
		g_gui:loadGui("dataS/gui/WardrobeScreen.xml", "WardrobeScreen", g_wardrobeScreen)
	end

	updateLoadingBarProgress()
	g_gui:loadGui("dataS/gui/InGameMenuMapFrame.xml", "MapFrame", inGameMenuMapFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuAIFrame.xml", "AIFrame", inGameMenuAIFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuPricesFrame.xml", "PricesFrame", inGameMenuPricesFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuVehiclesFrame.xml", "VehiclesFrame", inGameMenuVehiclesFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuFinancesFrame.xml", "FinancesFrame", inGameMenuFinancesFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuStatisticsFrame.xml", "StatisticsFrame", inGameMenuStatisticsFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuAnimalsFrame.xml", "AnimalsFrame", inGameMenuAnimalsFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuContractsFrame.xml", "ContractsFrame", inGameMenuContractsFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuProductionFrame.xml", "ProductionFrame", inGameMenuProductionFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuWeatherFrame.xml", "WeatherFrame", inGameMenuWeatherFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuCalendarFrame.xml", "CalendarFrame", inGameMenuCalendarFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuMultiplayerFarmsFrame.xml", "MultiplayerFarmsFrame", inGameMenuMultiplayerFarmsFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuMultiplayerUsersFrame.xml", "StatisticsFrame", inGameMenuMultiplayerUsersFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuHelpFrame.xml", "HelpFrame", inGameMenuHelpFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuTourFrame.xml", "TourFrame", inGameMenuTourFrame, true)

	if Platform.isMobile then
		g_gui:loadGui("dataS/gui/InGameMenuMainFrame.xml", "MainFrame", inGameMenuMainFrame, true)
		g_gui:loadGui("dataS/gui/InGameMenuMobileSettingsFrame.xml", "InGameMenuMobileSettingsFrame", inGameMenuMobileSettingsFrame, true)
	end

	g_gui:loadGui("dataS/gui/InGameMenuGeneralSettingsFrame.xml", "GeneralSettingsFrame", inGameMenuGeneralSettingsFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenuGameSettingsFrame.xml", "GameSettingsFrame", inGameMenuGameSettingsFrame, true)
	g_gui:loadGui("dataS/gui/InGameMenu.xml", "InGameMenu", inGameMenu)
	g_gui:loadGui("dataS/gui/ShopCategoriesFrame.xml", "ShopCategoriesFrame", shopCategoriesFrame, true)
	g_gui:loadGui("dataS/gui/ShopItemsFrame.xml", "ShopItemsFrame", shopItemsFrame, true)
	g_gui:loadGui("dataS/gui/ShopOthersFrame.xml", "ShopOthersFrame", shopOthersFrame, true)
	g_gui:loadGui("dataS/gui/ShopMenu.xml", "ShopMenu", shopMenu)
	updateLoadingBarProgress()
	g_gui:loadGui("dataS/gui/dialogs/MessageDialog.xml", "MessageDialog", g_messageDialog)
	g_gui:loadGui("dataS/gui/dialogs/YesNoDialog.xml", "YesNoDialog", g_yesNoDialog)
	g_gui:loadGui("dataS/gui/dialogs/LeaseYesNoDialog.xml", "LeaseYesNoDialog", leaseYesNoDialog)
	g_gui:loadGui("dataS/gui/dialogs/OptionDialog.xml", "OptionDialog", optionDialog)
	g_gui:loadGui("dataS/gui/dialogs/InfoDialog.xml", "InfoDialog", g_infoDialog)
	g_gui:loadGui("dataS/gui/dialogs/PlaceableInfoDialog.xml", "PlaceableInfoDialog", placeableInfoDialog)
	updateLoadingBarProgress()
	g_gui:loadGui("dataS/gui/dialogs/InfoDialog.xml", "ConnectionFailedDialog", g_connectionFailedDialog)
	g_gui:loadGui("dataS/gui/dialogs/TextInputDialog.xml", "TextInputDialog", g_textInputDialog)
	g_gui:loadGui("dataS/gui/dialogs/PasswordDialog.xml", "PasswordDialog", g_passwordDialog)
	g_gui:loadGui("dataS/gui/dialogs/ColorPickerDialog.xml", "ColorPickerDialog", g_colorPickerDialog)
	g_gui:loadGui("dataS/gui/dialogs/LicensePlateDialog.xml", "LicensePlateDialog", g_licensePlateDialog)
	g_gui:loadGui("dataS/gui/dialogs/ChatDialog.xml", "ChatDialog", g_chatDialog)
	g_gui:loadGui("dataS/gui/dialogs/DenyAcceptDialog.xml", "DenyAcceptDialog", g_denyAcceptDialog)
	g_gui:loadGui("dataS/gui/dialogs/UnBanDialog.xml", "UnBanDialog", unBanDialog)
	g_gui:loadGui("dataS/gui/dialogs/SleepDialog.xml", "SleepDialog", sleepDialog)
	g_gui:loadGui("dataS/gui/dialogs/ServerSettingsDialog.xml", "ServerSettingsDialog", serverSettingsDialog)
	g_gui:loadGui("dataS/gui/dialogs/ModHubScreenshotDialog.xml", "ModHubScreenshotDialog", modHubScreenshotDialog)
	updateLoadingBarProgress()
	g_gui:loadGui("dataS/gui/dialogs/SiloDialog.xml", "SiloDialog", g_siloDialog)
	g_gui:loadGui("dataS/gui/dialogs/RefillDialog.xml", "RefillDialog", g_refillDialog)
	g_gui:loadGui("dataS/gui/dialogs/AnimalDialog.xml", "AnimalDialog", g_animalDialog)
	g_gui:loadGui("dataS/gui/dialogs/GameRateDialog.xml", "GameRateDialog", g_gameRateDialog)
	g_gui:loadGui("dataS/gui/dialogs/SellItemDialog.xml", "SellItemDialog", g_sellItemDialog)
	g_gui:loadGui("dataS/gui/dialogs/EditFarmDialog.xml", "EditFarmDialog", editFarmDialog)
	g_gui:loadGui("dataS/gui/dialogs/TransferMoneyDialog.xml", "TransferMoneyDialog", transferMoneyDialog)
	g_gui:loadGui("dataS/gui/dialogs/SavegameConflictDialog.xml", "SavegameConflictDialog", g_savegameConflictDialog)

	g_menuMusic = createStreamedSample("menuMusic", true)

	loadStreamedSample(g_menuMusic, "data/music/menu.ogg")
	setStreamedSampleGroup(g_menuMusic, AudioGroup.MENU_MUSIC)
	setStreamedSampleVolume(g_menuMusic, 1)

	local function func(target, audioGroupIndex, volume)
		if g_menuMusicIsPlayingStarted then
			if volume > 0 then
				resumeStreamedSample(g_menuMusic)
			else
				pauseStreamedSample(g_menuMusic)
			end
		end
	end

	g_soundMixer:addVolumeChangedListener(AudioGroup.MENU_MUSIC, func, nil)
	updateLoadingBarProgress(true)

	if g_kioskMode ~= nil then
		g_kioskMode:init()
	end

	if Platform.showStartupScreen and g_skipStartupScreen == false then
		g_gui:showGui("StartupScreen")
	else
		g_gui:showGui("MainScreen")
	end

	g_inputBinding:setShowMouseCursor(true)

	g_defaultCamera = getCamera()

	if g_dedicatedServer == nil then
		local soundPlayerLocal = getAppBasePath() .. "data/music/"
		local soundPlayerTemplate = getAppBasePath() .. "profileTemplate/streamingInternetRadios.xml"
		local soundPlayerReadmeTemplate = getAppBasePath() .. "profileTemplate/ReadmeMusic.txt"
		local soundUserPlayerLocal = soundPlayerLocal
		local soundPlayerTarget = soundPlayerTemplate

		if Platform.supportsCustomInternetRadios then
			soundUserPlayerLocal = getUserProfileAppPath() .. "music/"
			soundPlayerTarget = soundUserPlayerLocal .. "streamingInternetRadios.xml"
			local soundPlayerReadme = soundUserPlayerLocal .. "ReadmeMusic.txt"

			createFolder(soundUserPlayerLocal)
			copyFile(soundPlayerTemplate, soundPlayerTarget, false)
			copyFile(soundPlayerReadmeTemplate, soundPlayerReadme, false)
		end

		g_soundPlayer = SoundPlayer.new(getAppBasePath(), "https://www.farming-simulator.com/feed/fs2022-radio-station-feed.xml", soundPlayerTarget, soundPlayerLocal, soundUserPlayerLocal, g_languageShort, AudioGroup.RADIO)
	end

	RestartManager:init(args)

	if RestartManager.restarting then
		g_gui:showGui("MainScreen")
		RestartManager:handleRestart()
	end

	SystemConsoleCommands.init()

	if g_dedicatedServer ~= nil then
		g_dedicatedServer:start()
	end

	if devStartServer ~= nil then
		startDevServer(devStartServer, devUniqueUserId)
	end

	if devStartClient ~= nil then
		startDevClient(devUniqueUserId)
	end

	if autoStartSavegameId ~= nil then
		autoStartLocalSavegame(autoStartSavegameId)
	end

	if GS_PLATFORM_PC then
		registerGlobalActionEvents(g_inputBinding)
	elseif GS_IS_CONSOLE_VERSION and g_isDevelopmentVersion then
		local eventAdded, eventId = g_inputBinding:registerActionEvent(InputAction.CONSOLE_DEBUG_TOGGLE_FPS, InputBinding.NO_EVENT_TARGET, toggleShowFPS, false, true, false, true)

		if eventAdded then
			g_inputBinding:setActionEventTextVisibility(eventId, false)
		end

		eventAdded, eventId = g_inputBinding:registerActionEvent(InputAction.CONSOLE_DEBUG_TOGGLE_STATS, InputBinding.NO_EVENT_TARGET, toggleStatsOverlay, false, true, false, true)

		if eventAdded then
			g_inputBinding:setActionEventTextVisibility(eventId, false)
		end
	end

	if Platform.supportsMods then
		postInitMods()
	end

	g_logFilePrefixTimestamp = true

	setFileLogPrefixTimestamp(g_logFilePrefixTimestamp)

	if StartParams.getIsSet("invitePlatformServerId") then
		g_invitePlatformServerId = StartParams.getValue("invitePlatformServerId")
		local userName = StartParams.getValue("inviteRequestUserName")
		g_inviteRequestUserName = base64Decode(userName)
		g_handleInviteRequest = true
	end

	if Platform.needsSignIn and StartParams.getIsSet("autoSignIn") and StartParams.getIsSet("restart") and g_gui.currentGuiName ~= "GamepadSigninScreen" then
		g_autoSignIn = true
	end

	if Platform.hasAdjustableFrameLimit then
		setFramerateLimiter(true, g_defaultFrameLimit)
	end

	return true
end

function update(dt)
	if g_autoSignIn then
		g_autoSignIn = nil

		g_gamepadSigninScreen:signIn()
	end

	if g_handleInviteRequest then
		local platformServerId = g_invitePlatformServerId
		local requestUserName = g_inviteRequestUserName
		g_invitePlatformServerId = nil
		g_inviteRequestUserName = nil
		g_handleInviteRequest = nil

		acceptedGameInvite(platformServerId, requestUserName)
	end

	g_time = g_time + dt
	g_currentDt = dt
	g_physicsDt = getPhysicsDt()
	g_physicsDtUnclamped = getPhysicsDtUnclamped()
	g_physicsDtNonInterpolated = getPhysicsDtNonInterpolated()

	if g_physicsDtNonInterpolated > 0 then
		g_physicsDtLastValidNonInterpolated = g_physicsDtNonInterpolated
	end

	g_networkTime = netGetTime()
	g_physicsNetworkTime = g_physicsNetworkTime + g_physicsDtUnclamped
	g_physicsTimeLooped = (g_physicsTimeLooped + g_physicsDt * 10) % 65535
	g_updateLoopIndex = g_updateLoopIndex + 1

	if g_updateLoopIndex > 1073741824 then
		g_updateLoopIndex = 0
	end

	g_physicsDt = math.max(g_physicsDt, 0.001)
	g_physicsDtUnclamped = math.max(g_physicsDtUnclamped, 0.001)

	if g_currentTest ~= nil then
		g_currentTest.update(dt)

		return
	end

	g_debugManager:update(dt)
	g_lifetimeStats:update(dt)
	g_soundMixer:update(dt)
	g_asyncTaskManager:update(dt)
	g_i3DManager:update(dt)
	g_messageCenter:update(dt)

	if g_nextModRecommendationTime < g_time and g_currentMission == nil and g_dedicatedServer == nil and g_modHubController ~= nil then
		g_modHubController:updateRecommendationSystem()

		g_nextModRecommendationTime = g_time + 1800000
	end

	g_inputBinding:update(dt)

	if g_currentMission ~= nil and g_currentMission.isLoaded and g_gui.currentGuiName ~= "GamepadSigninScreen" then
		g_currentMission:preUpdate(dt)
	end

	if Platform.hasFriendInvitation and g_showDeeplinkingFailedMessage == true and g_gui.currentGuiName ~= "GamepadSigninScreen" then
		g_showDeeplinkingFailedMessage = false

		if GS_PLATFORM_XBOX then
			if PlatformPrivilegeUtil.checkMultiplayer(onShowDeepLinkingErrorMsg, nil, , 30000) then
				onShowDeepLinkingErrorMsg()
			end
		else
			onShowDeepLinkingErrorMsg()
		end
	end

	if GS_PLATFORM_GGP then
		if getIsKeyboardAvailable() and g_gameSettings:getValue(GameSettings.SETTING.INPUT_HELP_MODE) ~= GS_INPUT_HELP_MODE_AUTO then
			g_gameSettings:setValue(GameSettings.SETTING.INPUT_HELP_MODE, GS_INPUT_HELP_MODE_AUTO)
		elseif not getIsKeyboardAvailable() and g_gameSettings:getValue(GameSettings.SETTING.INPUT_HELP_MODE) ~= GS_INPUT_HELP_MODE_GAMEPAD then
			g_gameSettings:setValue(GameSettings.SETTING.INPUT_HELP_MODE, GS_INPUT_HELP_MODE_GAMEPAD)
		end
	end

	if g_currentMission == nil or g_currentMission:getAllowsGuiDisplay() then
		g_gui:update(dt)
	end

	if g_currentMission ~= nil and g_currentMission.isLoaded and g_gui.currentGuiName ~= "GamepadSigninScreen" then
		g_currentMission:update(dt)
	end

	if g_soundPlayer ~= nil then
		g_soundPlayer:update(dt)
	end

	if g_gui.currentGuiName == "MainScreen" then
		g_achievementManager:update(dt)
	end

	g_soundManager:update(dt)

	if g_kioskMode ~= nil then
		g_kioskMode:update(dt)
	end

	Input.updateFrameEnd()

	if GS_PLATFORM_PC and g_dedicatedServer == nil then
		if getIsUpdateDownloadFinished() then
			g_updateDownloadFinished = true
		end

		if g_updateDownloadFinished and not g_updateDownloadFinishedDialogShown and (g_gui.currentGuiName == "MainScreen" or g_currentMission ~= nil and g_currentMission.gameStarted) then
			g_updateDownloadFinishedDialogShown = true

			g_gui:showInfoDialog({
				title = g_i18n:getText("ui_updateDownloadFinishedTitle"),
				text = g_i18n:getText("ui_updateDownloadFinishedText")
			})
		end
	end

	if g_pendingRestartData ~= nil then
		performRestart()
	end
end

function draw()
	if g_currentTest ~= nil then
		g_currentTest.draw()

		return
	end

	g_debugManager:draw()

	if g_currentMission == nil or g_currentMission:getAllowsGuiDisplay() then
		g_gui:draw()
	end

	if g_currentMission ~= nil and g_currentMission.isLoaded and g_gui.currentGuiName ~= "GamepadSigninScreen" then
		g_currentMission:draw()
	end

	if g_inputBinding ~= nil then
		g_inputBinding:draw()
	end

	if g_kioskMode ~= nil then
		g_kioskMode:draw()
	end

	if g_isDevelopmentConsoleScriptModTesting then
		renderText(0.2, 0.85, getCorrectTextSize(0.05), "CONSOLE SCRIPTS. DEVELOPMENT USE ONLY")
	end

	if g_showSafeFrame then
		if g_safeFrameOverlay == nil then
			g_safeFrameOverlay = createImageOverlay("dataS/scripts/shared/graph_pixel.png")

			setOverlayColor(g_safeFrameOverlay, 1, 0, 0, 0.4)
		end

		renderOverlay(g_safeFrameOverlay, g_safeFrameOffsetX, 0, 1 - 2 * g_safeFrameOffsetX, g_safeFrameOffsetY)
		renderOverlay(g_safeFrameOverlay, g_safeFrameOffsetX, 1 - g_safeFrameOffsetY, 1 - 2 * g_safeFrameOffsetX, g_safeFrameOffsetY)
		renderOverlay(g_safeFrameOverlay, 0, 0, g_safeFrameOffsetX, 1)
		renderOverlay(g_safeFrameOverlay, 1 - g_safeFrameOffsetX, 0, g_safeFrameOffsetX, 1)

		if g_safeFrameMajorOverlay == nil then
			g_safeFrameMajorOverlay = createImageOverlay("dataS/scripts/shared/graph_pixel.png")

			setOverlayColor(g_safeFrameMajorOverlay, 1, 0, 0, 0.4)
		end

		renderOverlay(g_safeFrameMajorOverlay, g_safeFrameMajorOffsetX, 0, 1 - 2 * g_safeFrameMajorOffsetX, g_safeFrameMajorOffsetY)
		renderOverlay(g_safeFrameMajorOverlay, g_safeFrameMajorOffsetX, 1 - g_safeFrameMajorOffsetY, 1 - 2 * g_safeFrameMajorOffsetX, g_safeFrameMajorOffsetY)
		renderOverlay(g_safeFrameMajorOverlay, 0, 0, g_safeFrameMajorOffsetX, 1)
		renderOverlay(g_safeFrameMajorOverlay, 1 - g_safeFrameMajorOffsetX, 0, g_safeFrameMajorOffsetX, 1)
	end

	if g_drawGuiHelper then
		if g_guiHelperOverlay == nil then
			g_guiHelperOverlay = createImageOverlay("dataS/scripts/shared/graph_pixel.png")
		end

		if g_guiHelperOverlay ~= 0 then
			setTextColor(1, 1, 1, 1)

			local width, height = getScreenModeInfo(getScreenMode())

			for i = g_guiHelperSteps, 1, g_guiHelperSteps do
				renderOverlay(g_guiHelperOverlay, i, 0, 1 / width, 1)
				renderOverlay(g_guiHelperOverlay, 0, i, 1, 1 / height)
			end

			for i = 0.05, 1, 0.05 do
				renderText(i, 0.97, getCorrectTextSize(0.02), tostring(i))
				renderText(0.01, i, getCorrectTextSize(0.02), tostring(i))
			end

			setTextAlignment(RenderText.ALIGN_RIGHT)
			setTextColor(0, 0, 0, 0.9)
			renderText(g_lastMousePosX - 0.015, g_lastMousePosY - 0.0125 - 0.002, getCorrectTextSize(0.025), string.format("%1.4f", g_lastMousePosY))
			setTextColor(1, 1, 1, 1)
			renderText(g_lastMousePosX - 0.015, g_lastMousePosY - 0.0125, getCorrectTextSize(0.025), string.format("%1.4f", g_lastMousePosY))
			setTextAlignment(RenderText.ALIGN_CENTER)
			setTextColor(0, 0, 0, 0.9)
			renderText(g_lastMousePosX, g_lastMousePosY + 0.015 - 0.002, getCorrectTextSize(0.025), string.format("%1.4f", g_lastMousePosX))
			setTextColor(1, 1, 1, 1)
			renderText(g_lastMousePosX, g_lastMousePosY + 0.015, getCorrectTextSize(0.025), string.format("%1.4f", g_lastMousePosX))
			setTextAlignment(RenderText.ALIGN_LEFT)

			local halfCrosshairWidth = 5 / width
			local halfCrosshairHeight = 5 / width

			renderOverlay(g_guiHelperOverlay, g_lastMousePosX - halfCrosshairWidth, g_lastMousePosY, 2 * halfCrosshairWidth, 1 / height)
			renderOverlay(g_guiHelperOverlay, g_lastMousePosX, g_lastMousePosY - halfCrosshairHeight, 1 / width, 2 * halfCrosshairHeight)
		end
	end

	if Platform.requiresConnectedGamepad and getNumOfGamepads() == 0 and g_gui.currentGuiName ~= "StartupScreen" and g_gui.currentGuiName ~= "GamepadSigninScreen" then
		if Platform.isXbox then
			requestGamepadSignin(Input.BUTTON_2, true, false)
		end

		setTextBold(true)
		setTextAlignment(RenderText.ALIGN_CENTER)
		setTextColor(0, 0, 0, 1)

		local xPos = 0.5
		local yPos = 0.6
		local blackOffset = 0.003
		local textSize = getCorrectTextSize(0.05)
		local text = g_i18n:getText("ui_pleaseReconnectController")

		renderText(xPos - blackOffset, yPos + blackOffset * 1.7777777777777777, textSize, text)
		renderText(xPos, yPos + blackOffset * 1.7777777777777777, textSize, text)
		renderText(xPos + blackOffset, yPos + blackOffset * 1.7777777777777777, textSize, text)
		renderText(xPos - blackOffset, yPos, textSize, text)
		renderText(xPos + blackOffset, yPos, textSize, text)
		renderText(xPos - blackOffset, yPos - blackOffset * 1.7777777777777777, textSize, text)
		renderText(xPos, yPos - blackOffset * 1.7777777777777777, textSize, text)
		renderText(xPos + blackOffset, yPos - blackOffset * 1.7777777777777777, textSize, text)
		setTextColor(1, 1, 1, 1)
		renderText(xPos, yPos, textSize, text)
		setTextBold(false)
		setTextColor(1, 1, 1, 1)
		setTextAlignment(RenderText.ALIGN_LEFT)

		if g_darkControllerOverlay == nil then
			g_darkControllerOverlay = createImageOverlay("dataS/menu/blank.png")

			setOverlayColor(g_darkControllerOverlay, 1, 1, 1, 0.3)
		else
			renderOverlay(g_darkControllerOverlay, 0, 0, 1, 1)
		end
	end

	if g_showRawInput then
		setOverlayColor(GuiElement.debugOverlay, 0, 0, 0, 0.9)
		renderOverlay(GuiElement.debugOverlay, 0, 0, 1, 1)
		setTextAlignment(RenderText.ALIGN_LEFT)

		local numGamepads = getNumOfGamepads()
		local yCoord = 0.95

		for i = 0, numGamepads - 1 do
			local numButtons = 0

			for j = 0, Input.MAX_NUM_BUTTONS - 1 do
				if getHasGamepadButton(Input.BUTTON_1 + j, i) then
					numButtons = numButtons + 1
				end
			end

			local numAxes = 0

			for axis = 0, Input.MAX_NUM_AXES - 1 do
				if getHasGamepadAxis(axis, i) then
					numAxes = numAxes + 1
				end
			end

			local versionId = getGamepadVersionId(i)
			local versionText = ""

			if versionId < 65535 then
				versionText = string.format("Version: %04X ", versionId)
			end

			yCoord = yCoord - 0.025

			renderText(0.02, yCoord, 0.025, string.format("Index: %d Name: %s PID: %04X VID: %04X %s#Buttons: %d #Axes: %d", i, getGamepadName(i), getGamepadProductId(i), getGamepadVendorId(i), versionText, numButtons, numAxes))

			for axis = 0, Input.MAX_NUM_AXES - 1 do
				if getHasGamepadAxis(axis, i) then
					local physical = getGamepadAxisPhysicalName(axis, i)
					yCoord = yCoord - 0.016

					renderText(0.025, yCoord, 0.016, string.format("%s->%d: '%s' %1.2f", physical, axis, getGamepadAxisLabel(axis, i), getInputAxis(axis, i)))
				end
			end

			for button = 0, Input.MAX_NUM_BUTTONS - 1 do
				if getInputButton(button, i) > 0 then
					local physical = getGamepadButtonPhysicalName(button, i)
					yCoord = yCoord - 0.025

					renderText(0.025, yCoord, 0.025, string.format("%s->%d: '%s'", physical, button, getGamepadButtonLabel(button, i)))
				end
			end

			yCoord = yCoord - 0.016
		end

		if numGamepads == 0 then
			renderText(0.025, yCoord, 0.025, "No gamepads found")
		end
	end

	g_adsSystem:draw()
end

function postAnimationUpdate(dt)
	for _, callbackData in pairs(g_postAnimationUpdateCallbacks) do
		callbackData.callbackFunc(callbackData.callbackTarget, dt, callbackData.callbackArguments)
	end
end

function cleanUp()
	if g_safeFrameOverlay ~= nil then
		delete(g_safeFrameOverlay)
	end

	if g_safeFrameMajorOverlay ~= nil then
		delete(g_safeFrameMajorOverlay)
	end

	if g_guiHelperOverlay ~= nil then
		delete(g_guiHelperOverlay)
	end

	if GuiElement.debugOverlay ~= nil then
		delete(GuiElement.debugOverlay)
	end

	deleteDrawingOverlays()
	g_masterServerConnection:disconnectFromMasterServer()
	g_connectionManager:shutdownAll()
	g_createGameScreen:removePortMapping()
	g_inputDisplayManager:delete()
	g_gui:delete()
	g_adsSystem:delete()
	delete(g_menuMusic)
	delete(g_savegameXML)
	g_lifetimeStats:save()

	if g_soundPlayer ~= nil then
		g_soundPlayer:delete()

		g_soundPlayer = nil
	end

	g_animCache:delete()
	g_i3DManager:clearEntireSharedI3DFileCache(g_isDevelopmentVersion)
	g_soundManager:delete()

	if g_isDevelopmentVersion then
		setFileLogPrefixTimestamp(false)
		printActiveEntities()
		setFileLogPrefixTimestamp(g_logFilePrefixTimestamp)
	end

	SystemConsoleCommands.delete()
end

function doExit()
	cleanUp()
	print("Application quit")
	requestExit()
end

function doRestart(restartProcess, args)
	if g_invitePlatformServerId ~= nil then
		local userName = base64Encode(g_inviteRequestUserName)
		args = args .. "-invitePlatformServerId " .. g_invitePlatformServerId .. " -inviteRequestUserName " .. userName
	end

	if Platform.needsSignIn and g_isSignedIn then
		local startScreen = getStartMode()

		if startScreen ~= RestartManager.START_SCREEN_GAMEPAD_SIGNIN then
			args = args .. " -autoSignIn"
		end
	end

	g_pendingRestartData = {
		restartProcess = restartProcess,
		args = args
	}
end

function performRestart()
	if g_pendingRestartData == nil then
		return
	end

	local data = g_pendingRestartData

	cleanUp()

	local restartType = ""

	if not data.restartProcess then
		restartType = "(soft restart)"
	end

	print("Application restart " .. restartType)
	restartApplication(data.restartProcess, data.args)
end

function loadLanguageSettings(xmlFile)
	local numLanguages = getNumOfLanguages()
	local languageCodeToLanguage = {}

	for i = 0, numLanguages - 1 do
		languageCodeToLanguage[getLanguageCode(i)] = i
	end

	local language = getLanguage()
	local languageSet = false
	local availableLanguages = {}

	xmlFile:iterate("settings.languages.language", function (_, key)
		local code = xmlFile:getString(key .. "#code")
		local languageShort = xmlFile:getString(key .. "#short")
		local languageSuffix = xmlFile:getString(key .. "#suffix")
		local lang = languageCodeToLanguage[code]

		if lang ~= nil then
			if lang == language or not languageSet then
				languageSet = true
				g_language = lang
				g_languageShort = languageShort
				g_languageSuffix = languageSuffix
			end

			if getIsLanguageEnabled(lang) then
				availableLanguages[lang] = true
			end
		end
	end)

	g_availableLanguagesTable = {}
	g_availableLanguageNamesTable = {}

	for i = 0, numLanguages - 1 do
		if availableLanguages[i] or i == g_language then
			table.insert(g_availableLanguagesTable, i)
			table.insert(g_availableLanguageNamesTable, getLanguageName(i))

			if i == g_language then
				g_settingsLanguageGUI = table.getn(g_availableLanguagesTable) - 1
			end
		end
	end

	if GS_IS_CONSOLE_VERSION then
		g_gameSettings:setValue(GameSettings.SETTING.MP_LANGUAGE, getSystemLanguage())
	end
end

function loadUserSettings(gameSettings, settingsModel)
	local nickname = getUserName():trim()

	if nickname == nil or nickname == "" then
		nickname = "Player"
	end

	gameSettings:setValue(GameSettings.SETTING.ONLINE_PRESENCE_NAME, nickname)
	gameSettings:setValue(GameSettings.SETTING.VOLUME_MASTER, getMasterVolume())
	gameSettings:setValue("joystickVibrationEnabled", getGamepadVibrationEnabled())

	if g_savegameXML ~= nil then
		delete(g_savegameXML)
	end

	local gameSettingsPathTemplate = getAppBasePath() .. "profileTemplate/gameSettingsTemplate.xml"
	g_savegamePath = getUserProfileAppPath() .. "gameSettings.xml"

	copyFile(gameSettingsPathTemplate, g_savegamePath, false)

	g_savegameXML = loadXMLFile("savegameXML", g_savegamePath)

	if settingsModel ~= nil then
		settingsModel:setSettingsFileHandle(g_savegameXML)
	end

	syncProfileFiles()

	local revision = getXMLInt(g_savegameXML, "gameSettings#revision")
	local gameSettingsTemplate = loadXMLFile("GameSettingsTemplate", gameSettingsPathTemplate)
	local revisionTemplate = getXMLInt(gameSettingsTemplate, "gameSettings#revision")

	delete(gameSettingsTemplate)

	if revision == nil or revision ~= revisionTemplate then
		copyFile(gameSettingsPathTemplate, g_savegamePath, true)
		delete(g_savegameXML)

		g_savegameXML = loadXMLFile("savegameXML", g_savegamePath)

		if settingsModel ~= nil then
			settingsModel:setSettingsFileHandle(g_savegameXML)
		end
	end

	if settingsModel ~= nil then
		settingsModel:refresh()
	end

	gameSettings:loadFromXML(g_savegameXML)
	g_soundMixer:setAudioGroupVolumeFactor(AudioGroup.RADIO, g_gameSettings:getValue(GameSettings.SETTING.VOLUME_RADIO))
	g_soundMixer:setAudioGroupVolumeFactor(AudioGroup.VEHICLE, g_gameSettings:getValue(GameSettings.SETTING.VOLUME_VEHICLE))
	g_soundMixer:setAudioGroupVolumeFactor(AudioGroup.MENU_MUSIC, g_gameSettings:getValue(GameSettings.SETTING.VOLUME_MUSIC))
	g_soundMixer:setAudioGroupVolumeFactor(AudioGroup.ENVIRONMENT, g_gameSettings:getValue(GameSettings.SETTING.VOLUME_ENVIRONMENT))

	if GS_IS_MOBILE_VERSION then
		g_soundMixer:setAudioGroupVolumeFactor(AudioGroup.DEFAULT, g_gameSettings:getValue(GameSettings.SETTING.VOLUME_ENVIRONMENT))
	end

	g_soundMixer:setAudioGroupVolumeFactor(AudioGroup.GUI, g_gameSettings:getValue(GameSettings.SETTING.VOLUME_GUI))
	g_soundMixer:setMasterVolume(g_gameSettings:getValue(GameSettings.SETTING.VOLUME_MASTER))
	VoiceChatUtil.setOutputVolume(g_gameSettings:getValue(GameSettings.SETTING.VOLUME_VOICE))
	VoiceChatUtil.setInputVolume(g_gameSettings:getValue(GameSettings.SETTING.VOLUME_VOICE_INPUT))
	VoiceChatUtil.setInputMode(g_gameSettings:getValue(GameSettings.SETTING.VOICE_MODE))
	g_lifetimeStats:reload()

	if g_extraContentSystem ~= nil then
		g_extraContentSystem:reset()
		g_extraContentSystem:loadFromProfile()
	end
end

function registerGlobalActionEvents(inputManager)
	local function onTakeScreenShot()
		if g_screenshotsDirectory ~= nil then
			local screenshotName = g_screenshotsDirectory .. "fsScreen_" .. getDate("%Y_%m_%d_%H_%M_%S") .. ".png"

			print("Saving screenshot: " .. screenshotName)
			saveScreenshot(screenshotName)
		else
			print("Unable to find screenshot directory!")
		end
	end

	local eventAdded, eventId = inputManager:registerActionEvent(InputAction.TAKE_SCREENSHOT, InputBinding.NO_EVENT_TARGET, onTakeScreenShot, false, true, false, true)

	if eventAdded then
		inputManager:setActionEventTextVisibility(eventId, false)
	end

	local function onPushToTalk(_, _, isActive)
		VoiceChatUtil.setIsPushToTalkPressed(isActive == 1)
	end

	local _ = nil
	_, eventId = inputManager:registerActionEvent(InputAction.PUSH_TO_TALK, InputBinding.NO_EVENT_TARGET, onPushToTalk, true, true, false, true)

	inputManager:setActionEventTextVisibility(eventId, false)

	if g_addTestCommands and Platform.isPC then
		g_noteManager:registerInputActionEvent()
	end
end

function updateAspectRatio(aspect)
	local referenceAspect = g_referenceScreenWidth / g_referenceScreenHeight

	if aspect > referenceAspect then
		g_aspectScaleX = referenceAspect / aspect
		g_aspectScaleY = 1
	else
		g_aspectScaleX = 1
		g_aspectScaleY = aspect / referenceAspect
	end
end

g_postAnimationUpdateCallbacks = {}

function addPostAnimationCallback(callbackFunc, callbackTarget, callbackArguments)
	local callbackData = {
		callbackFunc = callbackFunc,
		callbackTarget = callbackTarget,
		callbackArguments = callbackArguments
	}

	table.insert(g_postAnimationUpdateCallbacks, callbackData)

	return callbackData
end

function removePostAnimationCallback(callbackDataToRemove)
	for i, callbackData in pairs(g_postAnimationUpdateCallbacks) do
		if callbackData == callbackDataToRemove then
			table.remove(g_postAnimationUpdateCallbacks, i)
		end
	end
end

function updateLoadingBarProgress(isLast)
	g_curNumLoadingBarStep = g_curNumLoadingBarStep + 1
	local ratio = g_curNumLoadingBarStep / g_maxNumLoadingBarSteps

	if isLast and ratio < 1 or ratio > 1 then
		print("Invalid g_maxNumLoadingBarSteps. Last step number is " .. g_curNumLoadingBarStep)
	end

	updateLoadingBar(ratio)
end

function onShowDeepLinkingErrorMsg()
	g_deepLinkingInfo = nil

	g_gui:showConnectionFailedDialog({
		text = g_i18n:getText("ui_failedToConnectToGame"),
		callback = OnInGameMenuMenu
	})

	g_showDeeplinkingFailedMessage = false
end

function startDevServer(savegameId, uniqueUserId)
	if StartParams.getIsSet("restart") then
		print("Skipping server auto start due to restart")

		return
	end

	print("Start developer mp server (Savegame-Id: " .. tostring(savegameId) .. ")")
	g_mainScreen:onMultiplayerClick()
	g_multiplayerScreen:onClickCreateGame()

	local savegameController = g_careerScreen.savegameController
	local savegame = savegameController:getSavegame(tonumber(savegameId))

	if savegame == SavegameController.NO_SAVEGAME or not savegame.isValid then
		print("    Savegame not found! Please select savegame manually!")

		return
	end

	g_careerScreen.savegameList.selectedIndex = tonumber(savegameId)

	g_careerScreen:onStartAction()

	if g_gui.currentGuiName == "ModSelectionScreen" then
		g_modSelectionScreen:onClickOk()
	end

	g_autoDevMP = {
		serverName = "InternalTest_" .. getUserName()
	}

	g_createGameScreen.serverNameElement:setText(g_autoDevMP.serverName)

	g_createGameScreen.autoAccept = true

	g_createGameScreen:onClickOk()
end

function startDevClient(uniqueUserId)
	if StartParams.getIsSet("restart") then
		print("Skipping client auto join due to restart")

		return
	end

	print("Start developer mp client")
	g_mainScreen:onMultiplayerClick()

	g_autoDevMP = {
		serverName = "InternalTest_" .. getUserName()
	}

	g_multiplayerScreen:onContinue()
end

function autoStartLocalSavegame(savegameId)
	print("Auto start local savegame (Id: " .. tostring(savegameId) .. ")")
	g_gui:setIsMultiplayer(false)
	g_gui:showGui("CareerScreen")
	g_careerScreen.savegameList:setSelectedIndex(tonumber(savegameId), true)

	local savegameController = g_careerScreen.savegameController
	local savegame = savegameController:getSavegame(tonumber(savegameId))

	if savegame == SavegameController.NO_SAVEGAME or not savegame.isValid then
		print("    Savegame not found! Please select savegame manually!")

		return
	end

	g_careerScreen.currentSavegame = savegame

	g_careerScreen:onStartAction()

	if g_gui.currentGuiName == "ModSelectionScreen" then
		g_modSelectionScreen:onClickOk()
	end
end

function connectToServer(platformServerId)
	if storeHaveDlcsChanged() or haveModsChanged() or g_forceNeedsDlcsAndModsReload then
		g_forceNeedsDlcsAndModsReload = false

		reloadDlcsAndMods()
	end

	if storeAreDlcsCorrupted() then
		g_gui:showInfoDialog({
			text = g_i18n:getText("ui_dlcsCorruptRedownload"),
			callback = g_mainScreen.onDlcCorruptClick,
			target = g_mainScreen
		})
	else
		g_deepLinkingInfo = {
			platformServerId = platformServerId
		}

		g_masterServerConnection:disconnectFromMasterServer()
		g_connectionManager:shutdownAll()
		g_gui:changeScreen(nil, CareerScreen)
		g_mainScreen:onMultiplayerClick()
		g_multiplayerScreen:onClickJoinGame()
	end
end
