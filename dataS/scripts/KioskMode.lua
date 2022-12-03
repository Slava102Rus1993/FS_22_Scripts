KioskMode = {
	GAMEPAD_NAME = "JoyWarrior Gamepad 32",
	BIT_TO_BUTTON_ID = {
		7,
		6,
		5,
		4,
		3,
		2,
		1,
		0,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		8,
		9,
		10
	},
	EMPTY_FUNC = function ()
	end
}
local KioskMode_mt = Class(KioskMode)

function KioskMode.new(customMt)
	local self = setmetatable({}, customMt or KioskMode_mt)
	local path = "kioskMode/"
	self.configPaths = {
		"dataS/" .. path,
		"data/" .. path,
		getUserProfileAppPath() .. path
	}
	self.profileSelectorGamepadId = nil
	self.currentProfile = nil
	self.profiles = {}
	self.maskToProfile = {}
	self.settings = {}
	self.nextLanguageRestartTimer = nil
	self.nextLanguageIndex = nil
	self.maps = {}

	return self
end

function KioskMode:generateBitmasks()
	local mapping = {
		1,
		2,
		3,
		4,
		5,
		6,
		7,
		8,
		15,
		16,
		17
	}
	local generatedMasks = {}
	local hashedMasks = {}

	local function printResult(target, n)
		local bitMask = 0

		for k, v in ipairs(target) do
			if v == 1 then
				bitMask = Utils.setBit(bitMask, mapping[k])
			end
		end

		if hashedMasks[bitMask] == nil then
			table.insert(generatedMasks, bitMask)

			hashedMasks[bitMask] = true
		else
			Logging.warning("Mask %s already exists", table.concat(target, ""))
		end
	end

	local function bitmask(n, target, i)
		if i == n then
			printResult(target, n)

			return
		end

		target[i] = 0

		bitmask(n, target, i + 1)

		target[i] = 1

		bitmask(n, target, i + 1)
	end

	local masks = {}

	bitmask(12, masks, 1)

	for i, mask in ipairs(generatedMasks) do
		local str = ""

		for k = 1, 20 do
			if (k - 1) % 5 == 0 then
				str = str .. " "
			end

			if k ~= 18 then
				if KioskMode.BIT_TO_BUTTON_ID[k] ~= nil then
					str = str .. (Utils.isBitSet(mask, k) and 1 or 0)
				else
					str = str .. (math.random() > 0.5 and 1 or 0)
				end
			else
				str = str .. "0"
			end
		end

		log(string.format("%s", str))
	end
end

function KioskMode:delete()
	self:disposeVideo()
end

function KioskMode:load()
	local isLoaded = false

	for _, path in ipairs(self.configPaths) do
		if self:loadFromPath(path) then
			isLoaded = true
		end
	end

	if not isLoaded then
		return false
	end

	InGameMenu.makeIsAIEnabledPredicate = KioskMode.inj_inGameMenu_makeIsAIEnabledPredicate
	InGameMenu.makeIsPricesEnabledPredicate = KioskMode.inj_inGameMenu_makeIsPricesEnabledPredicate
	InGameMenu.makeIsAnimalsEnabledPredicate = KioskMode.inj_inGameMenu_makeIsAnimalsEnabledPredicate
	InGameMenu.makeIsContractsEnabledPredicate = KioskMode.inj_inGameMenu_makeIsContractsEnabledPredicate
	InGameMenu.makeIsGarageEnabledPredicate = KioskMode.inj_inGameMenu_makeIsGarageEnabledPredicate
	InGameMenu.makeIsControlsSettingsEnabledPredicate = KioskMode.inj_inGameMenu_makeIsControlsSettingsEnabledPredicate
	InGameMenu.makeIsHelpEnabledPredicate = KioskMode.inj_inGameMenu_makeIsHelpEnabledPredicate
	InGameMenuGameSettingsFrame.initializeButtons = Utils.overwrittenFunction(InGameMenuGameSettingsFrame.initializeButtons, KioskMode.inj_inGameMenuGameSettingsFrame_initializeButtons)
	MapManager.addMapItem = Utils.overwrittenFunction(MapManager.addMapItem, KioskMode.inj_mapManager_addMapItem)

	function loadMods()
		haveModsChanged()
	end

	return true
end

function KioskMode:loadFromPath(path)
	local configFileName = path .. "kioskMode.xml"

	if not fileExists(configFileName) then
		return false
	end

	local xmlFile = XMLFile.load("KioskMode", configFileName, nil)

	if xmlFile == nil then
		return false
	end

	local defaultConfigFile = Utils.getFilename(xmlFile:getString("kioskMode.defaultProfile.configFile", ""), path)

	if not fileExists(defaultConfigFile) then
		Logging.xmlWarning(xmlFile, "KioskMode:loadFromPath - default config file '%s' not found", defaultConfigFile)

		return false
	end

	self.defaultConfigFile = defaultConfigFile

	xmlFile:iterate("kioskMode.profiles.profile", function (_, key)
		local name = xmlFile:getString(key .. "#name", "")
		local configFile = Utils.getFilename(xmlFile:getString(key .. ".configFile", ""), path)

		if not fileExists(configFile) then
			Logging.xmlWarning(xmlFile, "KioskMode:loadFromPath - config file '%s' for profile '%s' not found", configFile, name)

			return false
		end

		local mask = 0
		local bitCount = 1
		local bitsStr = xmlFile:getString(key .. "#bits", "")
		local len = bitsStr:len()

		if len ~= 23 then
			Logging.xmlWarning(xmlFile, "KioskMode:loadFromPath - invalid bitsformat (##### ##### ##### #####) for profile '%s'", name)

			return false
		end

		for i = 1, bitsStr:len() do
			local bit = bitsStr:sub(i, i)

			if bit ~= " " then
				bit = tonumber(bit)

				if bit == 1 then
					if KioskMode.BIT_TO_BUTTON_ID[bitCount] ~= nil then
						mask = Utils.setBit(mask, bitCount)
					elseif bitCount == 18 then
						Logging.xmlWarning(xmlFile, "KioskMode:loadFromPath - Bit %d cannot be used. Please replace it with 0 for profile '%s'", bitCount, name)
					end
				end

				bitCount = bitCount + 1
			end
		end

		if self.maskToProfile[mask] ~= nil then
			local usedProfile = self.maskToProfile[mask]

			Logging.xmlWarning(xmlFile, "KioskMode:loadFromPath - %s mask already used for profile '%s'", name, usedProfile.name)

			return false
		end

		local profile = {
			id = #self.profiles + 1,
			name = name,
			mask = mask,
			configFile = configFile
		}
		self.maskToProfile[mask] = profile

		table.insert(self.profiles, profile)
	end)
	xmlFile:delete()

	if #self.profiles == 0 then
		return false
	end

	self.configFileName = configFileName

	table.insert(g_dlcsDirectories, {
		isLoaded = true,
		path = path .. "pdlc/"
	})

	return true
end

function KioskMode:loadInputBindings()
	if self.configFileName ~= nil then
		local xmlFileObj = XMLFile.load("KioskMode Inputs", self.configFileName)
		local xmlFile = xmlFileObj:getHandle()

		g_inputBinding:loadActionsFromXMLPath(xmlFile, "kioskMode.input.actions", g_i18n, nil)
		g_inputBinding:loadActionBindingsFromXMLPath(xmlFile, "kioskMode.input.bindings", true, nil, true, true)
		xmlFileObj:delete()
	end
end

function KioskMode:initializedGUIClasses()
	MainScreen.onOpen = Utils.appendedFunction(MainScreen.onOpen, KioskMode.inj_mainScreen_onOpen)
	MainScreen.update = Utils.overwrittenFunction(MainScreen.update, KioskMode.inj_mainScreen_update)
	MainScreen.onClose = Utils.appendedFunction(MainScreen.onClose, KioskMode.inj_mainScreen_onClose)
	MainScreen.inputEvent = Utils.overwrittenFunction(MainScreen.inputEvent, KioskMode.inj_mainScreen_inputEvent)
	MainScreen.updateStoreButtons = KioskMode.EMPTY_FUNC
	MPLoadingScreen.openWardrobe = KioskMode.EMPTY_FUNC
	InGameMenuMobileSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuMobileSettingsFrame.onFrameOpen, KioskMode.inj_inGameMenuMobileSettingsFrame_onFrameOpen)
	InGameMenu.onButtonSaveGame = KioskMode.EMPTY_FUNC
	CareerScreen.updateButtons = Utils.appendedFunction(CareerScreen.updateButtons, KioskMode.inj_careerScreen_updateButtons)
	CareerScreen.update = Utils.appendedFunction(CareerScreen.update, KioskMode.inj_careerScreen_update)
	ModSelectionScreen.update = Utils.appendedFunction(ModSelectionScreen.update, KioskMode.inj_modSelectionScreenn_update)
	DifficultyScreen.update = Utils.appendedFunction(DifficultyScreen.update, KioskMode.inj_difficultyScreen_update)
	MapSelectionScreen.update = Utils.appendedFunction(MapSelectionScreen.update, KioskMode.inj_mapSelectionScreen_update)
	InGameMenuMapFrame.updateInputGlyphs = Utils.appendedFunction(InGameMenuMapFrame.updateInputGlyphs, KioskMode.inj_inGameMenuMapFrame_updateInputGlyphs)
end

function KioskMode:init()
	self:initProfileSelectorGamepad()

	HUD.createDisplayComponents = Utils.appendedFunction(HUD.createDisplayComponents, KioskMode.inj_hud_createDisplayComponents)
	Mission00.getIsTourSupported = Utils.overwrittenFunction(Mission00.getIsTourSupported, KioskMode.inj_mission00_getIsTourSupported)
	Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, KioskMode.inj_mission00_onStartMission)
	SpecializationManager.addSpecialization = Utils.appendedFunction(SpecializationManager.addSpecialization, KioskMode.inj_specializationManager_addSpecialization)
	FSBaseMission.onToggleMenu = Utils.overwrittenFunction(FSBaseMission.onToggleMenu, KioskMode.inj_fsBaseMission_onToggleMenu)
	FSBaseMission.onToggleStore = Utils.overwrittenFunction(FSBaseMission.onToggleStore, KioskMode.inj_fsBaseMission_onToggleStore)
	FSBaseMission.onToggleCharacterCreation = Utils.overwrittenFunction(FSBaseMission.onToggleCharacterCreation, KioskMode.inj_fsBaseMission_onToggleCharacterCreation)
	FSBaseMission.onToggleConstructionScreen = Utils.overwrittenFunction(FSBaseMission.onToggleConstructionScreen, KioskMode.inj_fsBaseMission_onToggleConstructionScreen)
	FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, KioskMode.inj_fsBaseMission_registerActionEvents)
	FSBaseMission.getIsAutoSaveSupported = Utils.appendedFunction(FSBaseMission.getIsAutoSaveSupported, KioskMode.inj_fsBaseMission_getIsAutoSaveSupported)
	FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, KioskMode.inj_fsBaseMission_update)
	AnimalLoadingTrigger.load = Utils.overwrittenFunction(AnimalLoadingTrigger.load, KioskMode.inj_animalLoadingTrigger_load)
	VehicleSellingPoint.load = Utils.overwrittenFunction(VehicleSellingPoint.load, KioskMode.inj_vehicleSellingPoint_load)
	ShopTrigger.new = Utils.overwrittenFunction(ShopTrigger.new, KioskMode.inj_shopTrigger_new)
	LoanTrigger.new = Utils.overwrittenFunction(LoanTrigger.new, KioskMode.inj_loanTrigger_new)
	Environment.load = Utils.overwrittenFunction(Environment.load, KioskMode.inj_environment_load)
	StoreManager.getDefaultStoreItemsFilename = Utils.overwrittenFunction(StoreManager.getDefaultStoreItemsFilename, KioskMode.inj_storeManager_getDefaultStoreItemsFilename)
	ProductionPointActivatable.run = Utils.overwrittenFunction(ProductionPointActivatable.run, KioskMode.inj_productionPointActivatable_run)
	Farm.setInitialEconomy = Utils.appendedFunction(Farm.setInitialEconomy, KioskMode.inj_Farm_setInitialEconomy)

	function MissionManager.update(dt)
	end

	function SavegameController.getCanDeleteGame()
		return false
	end

	function getNumOfNotifications()
		return 0
	end

	function areAchievementsAvailable()
		return false
	end

	self:loadProfileConfig(self.defaultConfigFile)
end

function KioskMode:initProfileSelectorGamepad()
	local numOfGamepads = getNumOfGamepads()

	for i = 0, numOfGamepads - 1 do
		local gamepadName = getGamepadName(i)

		if gamepadName == KioskMode.GAMEPAD_NAME then
			Logging.info("KioskMode:initProfileSelectorGamepad - Found Gaming Station with gamepad '%s'", gamepadName)

			self.profileSelectorGamepadId = i
		end
	end

	if self.profileSelectorGamepadId ~= nil then
		local oldGetIsDeviceSupported = InputDevice.getIsDeviceSupported

		function InputDevice.getIsDeviceSupported(engineDeviceId, deviceName)
			if not oldGetIsDeviceSupported(engineDeviceId, deviceName) then
				return false
			end

			if deviceName == KioskMode.GAMEPAD_NAME then
				return false
			end

			return true
		end
	end

	return self.profileSelectorGamepadId ~= nil
end

function KioskMode:loadProfileConfig(configFileName)
	Logging.info("KioskMode:loadProfileConfig - Loading profile config '%s'", configFileName)

	local xmlFile = XMLFile.load("KioskMode Profile", configFileName)
	local path = Utils.getDirectory(configFileName)
	self.settings.canSelectSavegame = xmlFile:getBool("config.canSelectSavegame", false)
	self.settings.canSelectMods = xmlFile:getBool("config.canSelectMods", false)

	if not self.settings.canSelectSavegame then
		local savegamePath = xmlFile:getString("config.savegame")

		if savegamePath ~= nil then
			savegamePath = Utils.getFilename(savegamePath, path)
		end

		self:setSavegame(savegamePath)

		self.settings.savegame = savegamePath
	end

	local logo = xmlFile:getString("config.logo")

	if logo ~= nil then
		self.settings.logoFilename = Utils.getFilename(logo, path)
		self.settings.logoWidth = xmlFile:getInt("config.logo#width", 600)
		self.settings.logoHeight = xmlFile:getInt("config.logo#height", 150)
	end

	self.settings.logoEnabled = logo ~= nil
	self.settings.tourEnabled = xmlFile:getBool("config.tourEnabled", false)
	self.settings.aiEnabled = xmlFile:getBool("config.aiEnabled", true)
	self.settings.mainMenuEnabled = xmlFile:getBool("config.mainMenuEnabled", false)
	self.settings.watermarkEnabled = xmlFile:getBool("config.watermarkEnabled", false)
	self.settings.ingameMenuEnabled = xmlFile:getBool("config.ingameMenuEnabled", true)
	self.settings.reloadEnabled = xmlFile:getBool("config.reloadEnabled", false)
	self.settings.animalShopEnabled = xmlFile:getBool("config.shopsEnabled.animals", false)
	self.settings.vehicleShopEnabled = xmlFile:getBool("config.shopsEnabled.vehicles", false)
	self.settings.farmlandShopEnabled = xmlFile:getBool("config.shopsEnabled.farmlands", false)
	self.settings.placeableShopEnabled = xmlFile:getBool("config.shopsEnabled.placeables", false)
	self.settings.wardrobeShopEnabled = xmlFile:getBool("config.shopsEnabled.wardrobe", false)
	self.settings.productionEnabled = xmlFile:getBool("config.productionEnabled", true)
	self.settings.helpLineTriggerEnabled = xmlFile:getBool("config.helpLineTriggerEnabled", true)
	self.settings.extendedDrivingHelp = xmlFile:getBool("config.extendedDrivingHelp", false)
	self.settings.alwaysDay = xmlFile:getBool("config.alwaysDay", false)
	self.settings.startMoney = xmlFile:getInt("config.startMoney", 1000000)
	self.settings.skipMainMenu = xmlFile:getBool("config.skipMainMenu", false)
	self.settings.startVehicleIndex = xmlFile:getInt("config.startVehicleIndex", nil)

	if KioskMode.TIMESCALE_BACKUP == nil then
		KioskMode.TIMESCALE_BACKUP = Platform.gameplay.timeScaleSettings
		KioskMode.TIMESCALE_DEV_BACKUP = Platform.gameplay.timeScaleDevSettings
	end

	Platform.gameplay.timeScaleSettings = KioskMode.TIMESCALE_BACKUP
	Platform.gameplay.timeScaleDevSettings = KioskMode.TIMESCALE_DEV_BACKUP
	local timescales = xmlFile:getString("config.timescales", nil)

	if timescales ~= nil then
		local newTimescales = {}
		local parts = {
			string.getVector(timescales)
		}

		for _, part in ipairs(parts) do
			table.insert(newTimescales, tonumber(part))
		end

		if #newTimescales > 0 then
			Platform.gameplay.timeScaleSettings = newTimescales
			Platform.gameplay.timeScaleDevSettings = {}
		end
	end

	local mapsStr = xmlFile:getString("config.maps", "")
	local mapIds = string.split(mapsStr, " ")
	self.settings.maps = nil

	for _, id in ipairs(mapIds) do
		if self.settings.maps == nil then
			self.settings.maps = {}
		end

		self.settings.maps[id] = true
	end

	self:updateAvailableMaps()

	local storeItems = xmlFile:getString("config.storeItems", "")

	if storeItems ~= "" then
		storeItems = Utils.getFilename(storeItems, path)
	else
		storeItems = nil
	end

	self.settings.storeItems = storeItems
	local videos, duration = nil
	local videosDirectory = xmlFile:getString("config.videos", "")

	if videosDirectory ~= "" then
		videosDirectory = Utils.getFilename(videosDirectory, path)
		local files = Files.new(videosDirectory).files

		for _, file in ipairs(files) do
			local videoPath = videosDirectory .. "/" .. file.filename

			if fileExists(videoPath) then
				if videos == nil then
					videos = {}
				end

				table.insert(videos, videosDirectory .. "/" .. file.filename)
			end
		end

		duration = xmlFile:getInt("config.videos#inactiveDurationSeconds", 180) * 1000

		if videos == nil or #videos == 0 then
			videos, duration = nil

			Logging.warning("KioskMode: No videos found in '%s'", videosDirectory)
		end
	end

	self.settings.videos = videos
	self.settings.videoTimer = duration
	local playtimeSeconds = xmlFile:getFloat("config.playtimeSeconds")

	if playtimeSeconds ~= nil then
		self.settings.playtimeDuration = playtimeSeconds * 1000
	end

	self.settings.playtimeEnabled = playtimeSeconds ~= nil
	local mods = {}

	xmlFile:iterate("config.mods.mod", function (_, key)
		local modId = xmlFile:getString(key)

		if modId ~= nil then
			table.insert(mods, modId)
		end
	end)

	self.settings.mods = mods

	self:openMainMenu()
	self:setupMainMenu()
	xmlFile:delete()
end

function KioskMode:update(dt)
	if (self.profileSelectorGamepadId ~= nil or StartParams.getIsSet("kioskProfileId")) and g_gui.currentGuiName == "MainScreen" and self.currentProfile == nil then
		local profile = self:getProfile()

		if profile ~= nil then
			self:loadProfileConfig(profile.configFile)

			self.currentProfile = profile
		end
	end

	if GS_PLATFORM_PC and self.nextLanguageRestartTimer ~= nil and self.nextLanguageRestartTimer < g_time then
		doRestart(false, "")
	end

	if g_currentMission ~= nil and self.playtimeReloadTimer ~= nil then
		self.playtimeReloadTimer = self.playtimeReloadTimer - dt

		if self.playtimeReloadTimer <= 0 then
			self:onReloadSavegame()
		end
	end

	if self.currentVideoIndex == nil then
		if self.videoStartTimer ~= nil then
			self.videoStartTimer = self.videoStartTimer - dt

			if self.videoStartTimer < 0 then
				self:nextVideo()
			end
		end
	elseif self.videoOverlay ~= nil and isVideoOverlayPlaying(self.videoOverlay) then
		updateVideoOverlay(self.videoOverlay)
	elseif self.videoOverlay ~= nil then
		self:disposeVideo()
		self:nextVideo()
	end
end

function KioskMode:draw()
	if self.nextLanguageIndex ~= nil then
		setTextAlignment(RenderText.ALIGN_CENTER)
		setTextBold(true)
		setTextColor(0, 0, 0, 1)

		local timeLeft = math.ceil((self.nextLanguageRestartTimer - g_time) / 1000)
		local langName = getLanguageName(self.nextLanguageIndex)

		renderText(0.5 + 2 / g_screenWidth, 0.75 - 1 / g_screenHeight, 0.025, string.format("Changing Language.\nNew language after restart will be '%s'. \nRestarting in %d seconds...", langName, timeLeft))
		setTextColor(1, 1, 1, 1)
		renderText(0.5, 0.75, 0.025, string.format("Changing Language.\nNew language after restart will be '%s'. \nRestarting in %d seconds...", langName, timeLeft))
		setTextAlignment(RenderText.ALIGN_LEFT)
		setTextBold(false)
	end

	if g_gui.currentGuiName == "MainScreen" and self.currentProfile ~= nil then
		setTextAlignment(RenderText.ALIGN_LEFT)

		local name = self.currentProfile.name

		setTextColor(0, 0, 0, 0.75)
		renderText(0.01, 0.9585, 0.011, name)
		setTextColor(1, 1, 1, 1)
		renderText(0.01, 0.96, 0.011, name)
	end

	if g_currentMission ~= nil then
		local isNotFading = not g_currentMission.hud:getIsFading()
		local isUIVisible = g_gui:getIsGuiVisible()

		if self:getSetting("logoEnabled") and not isUIVisible and isNotFading then
			g_currentMission.hud.kioskModeLogoElement:draw()
		end

		if self.playtimeReloadTimer ~= nil then
			local left = string.format("%0.1d:", self.playtimeReloadTimer / 60000)
			local right = string.format("%0.2d", self.playtimeReloadTimer / 1000 % 60)

			setTextBold(true)
			setTextAlignment(RenderText.ALIGN_RIGHT)
			renderText(0.5, isUIVisible and 0.85 or 0.932, 0.05, left)
			setTextAlignment(RenderText.ALIGN_LEFT)
			renderText(0.5, isUIVisible and 0.85 or 0.932, 0.05, right)
			setTextBold(false)
		end
	end

	if self:getSetting("watermarkEnabled") then
		setTextAlignment(RenderText.ALIGN_CENTER)
		setTextBold(true)
		setTextColor(1, 1, 1, 0.5)
		renderText(0.5, 0.75, getCorrectTextSize(0.075), "INTERNAL USE ONLY")
		renderText(0.5, 0.73, getCorrectTextSize(0.03), "Copyright GIANTS Software GmbH")
		setTextColor(1, 1, 1, 1)
		setTextBold(false)
		setTextAlignment(RenderText.ALIGN_LEFT)
	end

	if self.videoOverlay ~= nil and isVideoOverlayPlaying(self.videoOverlay) then
		new2DLayer()
		renderOverlay(self.videoOverlay, 0, 0, 1, 1)
	end
end

function KioskMode:getSetting(name)
	return self.settings[name]
end

function KioskMode:getProfile()
	if StartParams.getIsSet("kioskProfileId") then
		local profileId = tonumber(StartParams.getValue("kioskProfileId"))
		local profile = self.profiles[profileId]

		if profile ~= nil then
			return profile
		end

		return nil
	end

	if self.profileSelectorGamepadId ~= nil then
		local mask = 0

		for bit, buttonId in pairs(KioskMode.BIT_TO_BUTTON_ID) do
			local value = getInputButton(buttonId, self.profileSelectorGamepadId)

			if value > 0 then
				mask = Utils.setBit(mask, bit)
			end
		end

		local profile = self.maskToProfile[mask]

		if profile ~= nil then
			return profile
		end
	end

	return nil
end

function KioskMode:setSavegame(path)
	if path ~= nil then
		if GS_IS_CONSOLE_VERSION then
			saveSetFixedSavegame(path)
		else
			local savegamePath = getUserProfileAppPath() .. "savegame1"

			deleteFolder(savegamePath)
			createFolder(savegamePath)

			local newFiles = Files.new(path).files

			for _, file in ipairs(newFiles) do
				copyFile(path .. "/" .. file.filename, savegamePath .. "/" .. file.filename, true)
			end

			if not fileExists(savegamePath .. "/careerSavegame.xml") then
				Logging.error("Failed to copy savegame from '%s' to '%s'!", path, savegamePath)
			end
		end
	elseif not GS_IS_CONSOLE_VERSION then
		local savegamePath = getUserProfileAppPath() .. "savegame1"

		deleteFolder(savegamePath)
	end
end

function KioskMode:onReloadSavegame()
	OnInGameMenuMenu()
end

function KioskMode:setupMainMenu()
	local mainMenuEnabled = self:getSetting("mainMenuEnabled")
	local areButtonsDisabled = not mainMenuEnabled

	g_mainScreen.multiplayerButton:setDisabled(areButtonsDisabled)
	g_mainScreen.downloadModsButton:setDisabled(areButtonsDisabled)
	g_mainScreen.achievementsButton:setDisabled(areButtonsDisabled)

	if not Platform.isConsole then
		g_mainScreen.settingsButton:setDisabled(areButtonsDisabled)
	else
		g_mainScreen.settingsButton:setDisabled(true)
	end

	g_mainScreen.quitButton:setDisabled(areButtonsDisabled)
	g_mainScreen.storeButton:setDisabled(areButtonsDisabled)
	g_mainScreen.buttonBox:invalidateLayout()
end

function KioskMode:addRegisteredMaps(map)
	table.addElement(self.maps, map)
end

function KioskMode:updateAvailableMaps()
	local mapIds = self.settings.maps

	table.clear(g_mapManager.maps)

	for _, map in ipairs(self.maps) do
		if mapIds == nil or mapIds[map.id] == true then
			table.insert(g_mapManager.maps, map)

			g_mapManager.idToMap[map.id] = map
		end
	end
end

function KioskMode:resetVideoTimer()
	if self:getSetting("videos") ~= nil then
		local wasVideoPlaying = self.videoOverlay ~= nil
		self.videoStartTimer = self:getSetting("videoTimer")

		self:disposeVideo()

		self.currentVideoIndex = nil

		return wasVideoPlaying
	end

	return false
end

function KioskMode:openMainMenu()
	self:resetVideoTimer()
end

function KioskMode:closeMainMenu()
	self.videoStartTimer = nil
end

function KioskMode:disposeVideo()
	if self.videoOverlay ~= nil and isVideoOverlayPlaying(self.videoOverlay) then
		stopVideoOverlay(self.videoOverlay)
		delete(self.videoOverlay)

		self.videoOverlay = nil
	end
end

function KioskMode:nextVideo()
	self:disposeVideo()

	if self.currentVideoIndex == nil or self.currentVideoIndex >= #self:getSetting("videos") then
		self.currentVideoIndex = 1
	else
		self.currentVideoIndex = self.currentVideoIndex + 1
	end

	self.videoStartTimer = nil
	self.videoOverlay = createVideoOverlay(self.settings.videos[self.currentVideoIndex], false, 1)

	playVideoOverlay(self.videoOverlay)
end

function KioskMode.inj_mapManager_addMapItem(mapManager, superFunc, ...)
	local success = superFunc(mapManager, ...)

	if success then
		local map = table.remove(mapManager.maps, #mapManager.maps)
		mapManager.idToMap[map.id] = nil

		g_kioskMode:addRegisteredMaps(map)
	end

	g_kioskMode:updateAvailableMaps()

	return success
end

function KioskMode.inj_Farm_setInitialEconomy(farm, ...)
	if not farm.isSpectator then
		farm.money = g_kioskMode:getSetting("startMoney")

		Logging.xmlInfo("Set Kiosk-Mode farm startmoney: %d", farm.money)
	end
end

function KioskMode.inj_inGameMenuMapFrame_updateInputGlyphs(ingameMenu, ...)
	local farmlandShopEnabled = g_kioskMode:getSetting("farmlandShopEnabled")

	ingameMenu.buttonSwitchMapMode:setDisabled(not farmlandShopEnabled)
end

function KioskMode.inj_storeManager_getDefaultStoreItemsFilename(storeManager, superFunc, ...)
	local storeConfig = g_kioskMode:getSetting("storeItems")

	if storeConfig ~= nil then
		return storeConfig
	end

	return superFunc(storeManager, ...)
end

function KioskMode.inj_environment_load(environment, superFunc, ...)
	local success = superFunc(environment, ...)

	if g_kioskMode:getSetting("alwaysDay") then
		environment.dayNightCycle = false
	end

	return success
end

function KioskMode.inj_loanTrigger_new(id, superFunc, ...)
	local loanTrigger = superFunc(id)
	loanTrigger.isEnabled = g_kioskMode:getSetting("vehicleShopEnabled")

	return loanTrigger
end

function KioskMode.inj_shopTrigger_new(id, superFunc, ...)
	local shopTrigger = superFunc(id)
	shopTrigger.isEnabled = g_kioskMode:getSetting("vehicleShopEnabled")

	return shopTrigger
end

function KioskMode.inj_vehicleSellingPoint_load(vehicleSellingPoint, superFunc, ...)
	local ret = superFunc(vehicleSellingPoint, ...)
	vehicleSellingPoint.isEnabled = g_kioskMode:getSetting("vehicleShopEnabled")

	return ret
end

function KioskMode.inj_animalLoadingTrigger_load(animalTrigger, superFunc, ...)
	local ret = superFunc(animalTrigger, ...)
	animalTrigger.isEnabled = g_kioskMode:getSetting("animalShopEnabled")

	return ret
end

function KioskMode.inj_fsBaseMission_getIsAutoSaveSupported(mission)
	return false
end

function KioskMode.inj_fsBaseMission_registerActionEvents(mission)
	if g_kioskMode:getSetting("reloadEnabled") then
		local _, eventId = mission.inputManager:registerActionEvent(InputAction.KIOSK_MODE_RELOAD_GAME, g_kioskMode, g_kioskMode.onReloadSavegame, false, true, false, true)

		mission.inputManager:setActionEventTextVisibility(eventId, false)
	end
end

function KioskMode.inj_fsBaseMission_onToggleCharacterCreation(mission, superFunc)
	if not g_kioskMode:getSetting("wardrobeShopEnabled") then
		return
	end

	superFunc(mission)
end

function KioskMode.inj_fsBaseMission_onToggleConstructionScreen(mission, superFunc)
	if not g_kioskMode:getSetting("placeableShopEnabled") then
		return
	end

	superFunc(mission)
end

function KioskMode.inj_fsBaseMission_onToggleStore(mission, superFunc)
	if not g_kioskMode:getSetting("vehicleShopEnabled") then
		return
	end

	superFunc(mission)
end

function KioskMode.inj_fsBaseMission_onToggleMenu(mission, superFunc)
	if not g_kioskMode:getSetting("ingameMenuEnabled") then
		return
	end

	superFunc(mission)
end

function KioskMode.inj_fsBaseMission_update(mission, dt)
	if g_kioskMode.tryToEnterVehicle ~= nil then
		local playerStyle = mission.player:getStyle()

		if playerStyle ~= nil then
			g_currentMission:requestToEnterVehicle(g_kioskMode.tryToEnterVehicle)

			g_kioskMode.tryToEnterVehicle = nil
		end
	end
end

function KioskMode.inj_mission00_onStartMission()
	if g_kioskMode:getSetting("playtimeEnabled") then
		g_kioskMode.playtimeReloadTimer = g_kioskMode:getSetting("playtimeDuration")
	end

	g_currentMission:playerOwnsAllFields()

	local startVehicleIndex = g_kioskMode:getSetting("startVehicleIndex")

	if startVehicleIndex ~= nil then
		local vehicle = g_currentMission.enterables[startVehicleIndex]

		if vehicle ~= nil then
			g_kioskMode.tryToEnterVehicle = vehicle
		end
	end

	if not g_kioskMode:getSetting("helpLineTriggerEnabled") then
		g_currentMission:setShowHelpTrigger(false)
	end
end

function KioskMode.inj_inGameMenu_makeIsAIEnabledPredicate(ingameMenu)
	return function ()
		return g_kioskMode:getSetting("aiEnabled")
	end
end

function KioskMode.inj_inGameMenu_makeIsPricesEnabledPredicate(ingameMenu)
	return function ()
		return false
	end
end

function KioskMode.inj_inGameMenu_makeIsAnimalsEnabledPredicate(ingameMenu)
	return function ()
		return false
	end
end

function KioskMode.inj_inGameMenu_makeIsContractsEnabledPredicate(ingameMenu)
	return function ()
		return false
	end
end

function KioskMode.inj_inGameMenu_makeIsGarageEnabledPredicate(ingameMenu)
	return function ()
		return false
	end
end

function KioskMode.inj_inGameMenu_makeIsControlsSettingsEnabledPredicate(ingameMenu)
	return function ()
		return false
	end
end

function KioskMode.inj_inGameMenu_makeIsHelpEnabledPredicate(ingameMenu)
	return function ()
		return false
	end
end

function KioskMode.inj_inGameMenuGameSettingsFrame_initializeButtons(frame)
	frame.saveButton = nil
end

function KioskMode:inj_productionPointActivatable_run(superFunc)
	if not g_kioskMode:getSetting("productionEnabled") then
		g_gui:showInfoDialog({
			text = g_i18n:getText("ui_featureDisabled")
		})

		return
	end

	superFunc(self)
end

function KioskMode.inj_specializationManager_addSpecialization(specializationManager, name, className, ...)
	if specializationManager == g_specializationManager then
		if className == "AIJobVehicle" then
			if not g_kioskMode:getSetting("aiEnabled") then
				function AIJobVehicle.onRegisterActionEvents()
				end
			end
		elseif className == "Drivable" and g_kioskMode:getSetting("extendedDrivingHelp") then
			local old = Drivable.onRegisterActionEvents

			function Drivable.onRegisterActionEvents(vehicle, isActiveForInput, isActiveForInputIgnoreSelection)
				old(vehicle, isActiveForInput, isActiveForInputIgnoreSelection)

				local spec = vehicle.spec_drivable

				for inputAction, data in pairs(spec.actionEvents) do
					local actionEventId = data.actionEventId
					local event = g_inputBinding.events[actionEventId]

					if event.displayPriority == GS_PRIO_VERY_LOW then
						g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
					elseif event.displayPriority == GS_PRIO_LOW then
						g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
					end

					if not event.displayIsVisible then
						g_inputBinding:setActionEventTextVisibility(actionEventId, true)
					end
				end
			end
		end
	elseif specializationManager == g_placeableSpecializationManager and className == "PlaceableWardrobe" and not g_kioskMode:getSetting("wardrobeShopEnabled") then
		function PlaceableWardrobeActivatable.run()
			g_gui:showInfoDialog({
				text = g_i18n:getText("ui_featureDisabled")
			})
		end
	end
end

function KioskMode.inj_mission00_getIsTourSupported(mission, superFunc)
	if not g_kioskMode:getSetting("tourEnabled") then
		return false
	end

	return superFunc(mission)
end

function KioskMode.inj_hud_createDisplayComponents(hud, uiScale)
	if g_kioskMode:getSetting("logoEnabled") then
		hud.ingameMap:setIsVisible(false)

		local width = g_kioskMode:getSetting("logoWidth")
		local height = g_kioskMode:getSetting("logoHeight")
		local filename = g_kioskMode:getSetting("logoFilename")
		width, height = getNormalizedScreenValues(width, height)
		local overlay = Overlay.new(filename, g_safeFrameOffsetX, g_safeFrameOffsetY, width, height)
		hud.kioskModeLogoElement = HUDElement.new(overlay)

		table.insert(hud.displayComponents, hud.kioskModeLogoElement)
	end
end

function KioskMode.inj_inGameMenuMobileSettingsFrame_onFrameOpen(frame)
	frame.multiGraphics:setDisabled(true)
	frame.checkGyroscope:setDisabled(true)
	frame.checkTilt:setDisabled(true)
end

function KioskMode.inj_careerScreen_updateButtons(screen)
	if screen.buttonDelete then
		screen.buttonDelete:setDisabled(true)
	end
end

function KioskMode.inj_modSelectionScreenn_update(screen, dt)
	if g_kioskMode:getSetting("canSelectMods") then
		return
	end

	for _, modItem in pairs(screen.selectedMods) do
		screen:setItemState(modItem, false)
	end

	for _, modName in pairs(g_kioskMode:getSetting("mods")) do
		local modItem = g_modManager:getModByName(modName)

		if modItem ~= nil then
			if screen:shouldShowModInList(modItem) then
				screen:setItemState(modItem, true)
			else
				Logging.error("Mod '%s' is not available for current kiosk mode setup", modItem.title)
			end
		end
	end

	screen:onClickOk()
end

function KioskMode.inj_difficultyScreen_update(screen, dt)
	local info = screen.startMissionInfo or g_startMissionInfo
	info.difficulty = 1

	screen:onClickOk()
end

function KioskMode.inj_mapSelectionScreen_update(screen, dt)
	if g_mapManager:getNumOfMaps() == 1 then
		local info = screen.startMissionInfo or g_startMissionInfo
		local map = g_mapManager:getMapDataByIndex(1)
		info.mapId = map.id

		screen:onClickOk()
	end
end

function KioskMode.inj_careerScreen_update(screen, dt)
	if g_kioskMode:getSetting("canSelectSavegame") then
		return
	end

	screen.selectedIndex = 1
	local savegameController = screen.savegameController or g_savegameController
	local savegame = savegameController:getSavegame(screen.selectedIndex)

	screen:startSavegame(savegame)
end

function KioskMode.inj_mainScreen_inputEvent(screen, superFunc, action, value, eventUsed)
	if action == InputAction.KIOSK_MODE_START_VIDEOS then
		eventUsed = true
	elseif g_kioskMode:resetVideoTimer() then
		eventUsed = true
	end

	return superFunc(screen, action, value, eventUsed)
end

function KioskMode.inj_mainScreen_onClose(screen)
	if screen.toggleLanguageEventId ~= nil then
		g_inputBinding:removeActionEvent(screen.toggleLanguageEventId)

		screen.toggleLanguageEventId = nil
	end

	if screen.startVideosEventId ~= nil then
		g_inputBinding:removeActionEvent(screen.startVideosEventId)

		screen.startVideosEventId = nil
	end

	g_kioskMode:closeMainMenu()
end

function KioskMode.inj_mainScreen_update(screen, superFunc, dt)
	if g_kioskMode:getSetting("skipMainMenu") then
		screen:onCareerClick()

		return
	end

	superFunc(screen, dt)
end

function KioskMode.inj_mainScreen_onOpen(screen)
	if screen.toggleLanguageEventId ~= nil then
		g_inputBinding:removeActionEvent(screen.toggleLanguageEventId)

		screen.toggleLanguageEventId = nil
	end

	if screen.startVideosEventId ~= nil then
		g_inputBinding:removeActionEvent(screen.startVideosEventId)

		screen.startVideosEventId = nil
	end

	if GS_PLATFORM_PC then
		local function onToggleLanguage()
			if g_gui.currentGuiName == "MainScreen" then
				local currentLanguage = getLanguage()
				local nextIndex = nil

				for k, v in ipairs(g_availableLanguagesTable) do
					if v == currentLanguage then
						nextIndex = k + 1
					end
				end

				if nextIndex == nil or nextIndex > #g_availableLanguagesTable then
					nextIndex = 1
				end

				currentLanguage = g_availableLanguagesTable[nextIndex]
				g_kioskMode.nextLanguageIndex = currentLanguage
				g_kioskMode.nextLanguageRestartTimer = g_time + 5000

				setLanguage(currentLanguage)
				g_kioskMode:resetVideoTimer()
			end
		end

		local eventAdded, eventId = g_inputBinding:registerActionEvent(InputAction.KIOSK_MODE_TOGGLE_LANGUAGE, InputBinding.NO_EVENT_TARGET, onToggleLanguage, false, true, false, true)
		screen.toggleLanguageEventId = eventId

		if eventAdded then
			g_inputBinding:setActionEventTextVisibility(eventId, false)
		end
	end

	local function onStartVideos()
		if g_gui.currentGuiName == "MainScreen" then
			g_kioskMode:nextVideo()
		end
	end

	local eventAdded, eventId = g_inputBinding:registerActionEvent(InputAction.KIOSK_MODE_START_VIDEOS, InputBinding.NO_EVENT_TARGET, onStartVideos, false, true, false, true)
	screen.startVideosEventId = eventId

	if eventAdded then
		g_inputBinding:setActionEventTextVisibility(eventId, false)
	end

	g_kioskMode:openMainMenu()
end
