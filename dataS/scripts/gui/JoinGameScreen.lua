JoinGameScreen = {
	CONTROLS = {
		"mainBox",
		"numServersText",
		"serverList",
		"mapSelectionElement",
		"passwordElement",
		"capacityElement",
		"modDlcElement",
		"serverNameElement",
		"allowCrossPlayElement",
		"maxNumPlayersElement",
		"languageElement",
		"buttonBox",
		"settingsBox",
		"detailButtonElement",
		"startButtonElement",
		"changeButton",
		"sortButton",
		"loadingText"
	},
	REFRESH_TIME = 25000,
	FILTER_CHANGE_REFRESH_TIME = 500
}
local JoinGameScreen_mt = Class(JoinGameScreen, ScreenElement)

function JoinGameScreen.new(target, custom_mt, startMissionInfo, messageCenter, inputManager)
	local self = ScreenElement.new(target, custom_mt or JoinGameScreen_mt)

	self:registerControls(JoinGameScreen.CONTROLS)

	self.startMissionInfo = startMissionInfo
	self.messageCenter = messageCenter
	self.inputManager = inputManager
	self.servers = {}
	self.serversBuffer = {}
	self.displayServers = {}
	self.requestedDetailsServerId = -1
	self.serverDetailsPending = false
	self.sortKey = "name"
	self.sortOrder = TableHeaderElement.SORTING_ASC
	self.totalNumServers = 0
	self.numServers = 0
	self.maxNumPlayersStates = {}
	self.maxNumPlayersNumbers = {}

	for i = g_serverMinCapacity, g_joinServerMaxCapacity do
		table.insert(self.maxNumPlayersStates, tostring(i))
		table.insert(self.maxNumPlayersNumbers, i)
	end

	self.maxNumPlayersState = #self.maxNumPlayersNumbers
	self.selectedMaxNumPlayers = self.maxNumPlayersNumbers[self.maxNumPlayersState]
	self.hasNoPassword = false
	self.isNotFull = false
	self.onlyWithAllModsAvailable = false
	self.allowCrossPlay = false
	self.selectedMap = ""
	self.selectedLanguageId = 0
	self.serverName = ""
	self.lastUserName = ""
	self.returnScreenClass = MultiplayerScreen
	self.lastSelectedServerName = nil
	self.lastSelectedServerMapName = nil

	if g_isDevelopmentVersion then
		JoinGameScreen.REFRESH_TIME = 10000
	end

	return self
end

function JoinGameScreen:onOpen()
	JoinGameScreen:superClass().onOpen(self)
	self.allowCrossPlayElement:setVisible(getAllowCrossPlay())
	self.settingsBox:invalidateLayout()

	self.mapTable = {}
	self.mapIds = {}

	table.insert(self.mapTable, g_i18n:getText("ui_anyMap"))
	table.insert(self.mapIds, "")

	for i = 1, g_mapManager:getNumOfMaps() do
		local map = g_mapManager:getMapDataByIndex(i)
		local title = map.title
		title = Utils.limitTextToWidth(title, 0.025, 0.245, false, "..")

		table.insert(self.mapTable, title)
		table.insert(self.mapIds, map.title)
	end

	self.mapSelectionElement:setTexts(self.mapTable)

	if self.showingDeepLinkingPassword then
		self.showingDeepLinkingPassword = nil
		g_deepLinkingInfo = nil
	end

	g_gui:showMessageDialog({
		visible = g_deepLinkingInfo ~= nil,
		text = g_i18n:getText("ui_connectingPleaseWait"),
		dialogType = DialogElement.TYPE_LOADING
	})
	self.mainBox:setVisible(g_deepLinkingInfo == nil)

	local reloadFilterSettings = not self.settingsLoaded

	if GS_IS_CONSOLE_VERSION and self.lastUserName ~= g_gameSettings:getValue(GameSettings.SETTING.ONLINE_PRESENCE_NAME) then
		self.lastUserName = g_gameSettings:getValue(GameSettings.SETTING.ONLINE_PRESENCE_NAME)
		reloadFilterSettings = true
	end

	if reloadFilterSettings then
		self:loadFilterSettings()
	end

	self.isRequestPending = false
	self.serverDetailsPending = false

	g_masterServerConnection:setCallbackTarget(self)
	self.startButtonElement:setDisabled(true)
	self.detailButtonElement:setDisabled(true)
	self.numServersText:setText("")

	self.refreshTimer = JoinGameScreen.REFRESH_TIME
	self.servers = {}
	self.isInitialLoad = true

	self.serverList:reloadData()

	if not g_masterServerConnection.isInit then
		g_connectionManager:startupWithWorkingPort(g_gameSettings:getValue("defaultServerPort"))
		g_masterServerConnection:connectToMasterServer(g_masterServerConnection.lastBackServerIndex)
	end

	self.loadingText:setVisible(self.serverList:getItemCount() == 0)

	if g_deepLinkingInfo ~= nil then
		masterServerRequestServerDetailsWithPlatformServerId(g_deepLinkingInfo.platformServerId)
	else
		self:getServers()
	end

	self.canShowSortButton = GS_IS_CONSOLE_VERSION or g_inputBinding:getInputHelpMode() == GS_INPUT_HELP_MODE_GAMEPAD

	self.messageCenter:subscribe(MessageType.INPUT_MODE_CHANGED, self.onInputModeChanged, self)
	self:showSortButton(false)
end

function JoinGameScreen:onClose()
	JoinGameScreen:superClass().onClose(self)

	self.settingsLoaded = false
	self.servers = {}
	self.serversBuffer = {}
	self.displayServers = {}
	self.mapTable = {}
	self.mapIds = {}

	self.messageCenter:unsubscribeAll(self)
end

function JoinGameScreen:triggerRebuildOnFilterChange()
	self:updateDisplayedServers()
end

function JoinGameScreen:onServerInfoDetails(id, name, language, capacity, numPlayers, mapName, mapId, hasPassword, isLanServer, modTitles, modHashes, allowCrossPlay, platformId, password)
	if g_isDevelopmentVersion then
		log(string.format([[
JoinGameScreen Id: %d
name: %s
language: %d
capacity: %d
numPlayers: %d
mapName: %s
mapId: %s
hasPassword: %s
isLanServer: %s
modTitles: %s
modHashes: %s
allowCrossPlay: %s
platformId :%s
]], id, name, language, capacity, numPlayers, mapName, mapId, tostring(hasPassword), tostring(isLanServer), modTitles, modHashes, allowCrossPlay, getDeviceTypeFromPlatformId(platformId)))

		for k, t in ipairs(modTitles) do
			log("    ", t, "> Hash:", modHashes[k])
		end
	end

	if g_deepLinkingInfo ~= nil then
		if g_deepLinkingInfo.platformServerId ~= "" then
			if hasPassword then
				self.showingDeepLinkingPassword = true

				g_gui:showPasswordDialog({
					defaultPassword = "",
					callback = self.onPasswordEntered,
					target = self,
					args = {
						serverId = id
					}
				})
			else
				self:startGame(password, id)
			end
		end
	elseif id == self.requestedDetailsServerId then
		g_serverDetailScreen:setServerInfo(id, name, language, capacity, numPlayers, mapName, mapId, hasPassword, isLanServer, modTitles, modHashes, g_modManager:getAreAllModsAvailable(modHashes), allowCrossPlay, platformId)
		g_gui:showGui("ServerDetailScreen")
	end

	self.serverDetailsPending = false
end

function JoinGameScreen:onServerInfoDetailsFailed()
	if g_deepLinkingInfo ~= nil then
		g_deepLinkingInfo = nil

		g_gui:showConnectionFailedDialog({
			text = g_i18n:getText("ui_failedToConnectToGame"),
			callback = g_connectionFailedDialog.onOkCallback,
			target = g_connectionFailedDialog,
			args = {
				"JoinGameScreen"
			}
		})
	else
		self.requestedDetailsServerId = -1
	end

	self.serverDetailsPending = false

	self:getServers()
end

function JoinGameScreen:onMasterServerConnectionReady()
	self:getServers()
end

function JoinGameScreen:onMasterServerConnectionFailed(reason)
	g_masterServerConnection:disconnectFromMasterServer()
	g_connectionManager:shutdownAll()
	ConnectionFailedDialog.showMasterServerConnectionFailedReason(reason, "MultiplayerScreen")
end

function JoinGameScreen:onServerInfoStart(numServers, totalNumServers)
	self.totalNumServers = totalNumServers
	self.numServers = numServers
	self.serversBufferNextIndex = 1
end

function JoinGameScreen:onServerInfo(id, name, language, capacity, numPlayers, mapName, hasPassword, allModsAvailable, isLanServer, isFriendServer, allowCrossPlay, platformId)
	local server = self.serversBuffer[self.serversBufferNextIndex] or {}
	server.id = id
	server.name = name
	server.hasPassword = hasPassword
	server.language = language
	server.capacity = capacity
	server.numPlayers = numPlayers
	server.mapName = mapName
	server.allModsAvailable = allModsAvailable
	server.isLanServer = isLanServer
	server.isFriendServer = isFriendServer
	server.allowCrossPlay = allowCrossPlay
	server.platformId = platformId
	server.fullness = numPlayers / capacity
	self.serversBuffer[self.serversBufferNextIndex] = server
	self.serversBufferNextIndex = self.serversBufferNextIndex + 1
end

function JoinGameScreen:onServerInfoEnd()
	for i = #self.serversBuffer, self.serversBufferNextIndex, -1 do
		self.serversBuffer[i] = nil
	end

	self.servers = self.serversBuffer
	self.isRequestPending = false

	self:updateDisplayedServers()
end

function JoinGameScreen:getServers()
	if self.isRequestPending then
		return
	end

	masterServerAddAvailableModStart()

	for _, mod in ipairs(g_modManager:getMultiplayerMods()) do
		masterServerAddAvailableMod(mod.fileHash)
	end

	masterServerAddAvailableModEnd()

	self.isRequestPending = true

	masterServerRequestFilteredServers(self.selectedLanguageId, self.allowCrossPlay)
end

function JoinGameScreen:buildSortFunc()
	return function (a, b)
		if a.isLanServer ~= b.isLanServer then
			return not b.isLanServer and a.isLanServer
		elseif a.isFriendServer ~= b.isFriendServer then
			return not b.isFriendServer and a.isFriendServer
		end

		if self.sortOrder == TableHeaderElement.SORTING_ASC then
			return a[self.sortKey] < b[self.sortKey]
		else
			return b[self.sortKey] < a[self.sortKey]
		end
	end
end

function JoinGameScreen:updateDisplayedServers()
	local lastServerName = self.lastSelectedServerName
	local lastServerMapName = self.lastSelectedServerMapName
	self.displayServers = {}

	for _, server in ipairs(self.servers) do
		if self:filterServer(server) then
			table.insert(self.displayServers, server)
		end
	end

	table.sort(self.displayServers, self:buildSortFunc())
	self.numServersText:setText(string.format("%d / %d %s", #self.displayServers, self.totalNumServers, g_i18n:getText("ui_games")))
	self.numServersText.parent:invalidateLayout()
	self.serverList:reloadData()
	self.loadingText:setVisible(false)

	if self.isInitialLoad then
		if #self.displayServers > 0 then
			FocusManager:setFocus(self.serverList)
		else
			FocusManager:setFocus(self.mapSelectionElement)
		end
	end

	self.isInitialLoad = false

	self:updateButtons()

	if lastServerName ~= nil then
		local index = 1

		for i, server in ipairs(self.displayServers) do
			if server.name == lastServerName and server.mapName == lastServerMapName then
				index = i

				break
			end
		end

		self.serverList:setSelectedIndex(index)
	end

	if g_autoDevMP ~= nil then
		for k, server in ipairs(self.displayServers) do
			if server.name == g_autoDevMP.serverName then
				self.serverList:setSelectedIndex(k)
				self:onClickOk(true)

				return
			end
		end

		self.refreshTimer = 500
	end
end

function JoinGameScreen:filterServer(server)
	local pwOk = not self.hasNoPassword or not server.hasPassword
	local notFullOk = not self.isNotFull or server.numPlayers < server.capacity
	local mapOk = self.selectedMap == "" or server.mapName == self.selectedMap
	local modsOk = not self.onlyWithAllModsAvailable or server.allModsAvailable
	local languageOk = server.language == self.selectedLanguageId
	local capOk = server.capacity <= self.selectedMaxNumPlayers
	local serverNameOk = self.serverName and server.name and (self.serverName == "" or string.find(server.name:lower(), self.serverName:lower(), 1, true) ~= nil)

	return pwOk and notFullOk and mapOk and modsOk and languageOk and capOk and serverNameOk
end

function JoinGameScreen:onClickHeader(element)
	local sortingOrder = element:toggleSorting()

	if sortingOrder == TableHeaderElement.SORTING_OFF then
		self.sortKey = "name"
		self.sortOrder = TableHeaderElement.SORTING_ASC
	else
		self.sortKey = element.columnName
		self.sortOrder = sortingOrder
	end

	self:updateDisplayedServers()
end

function JoinGameScreen:onFocusHeader(headerElement)
	self.focusedHeaderElement = headerElement

	self:showSortButton(self.canShowSortButton)
end

function JoinGameScreen:onLeaveHeader(_)
	self.focusedHeaderElement = nil

	self:showSortButton(false)
end

function JoinGameScreen:onCreateLanguage(element)
	local languageTable = {}
	local numL = getNumOfLanguages()

	for i = 1, numL do
		table.insert(languageTable, getLanguageName(i - 1))
	end

	element:setTexts(languageTable)
end

function JoinGameScreen:onCreateMaxNumPlayers(element)
	element:setTexts(self.maxNumPlayersStates)
end

function JoinGameScreen:onFocusGameName(element)
	self.selectedInputElement = element

	self.startButtonElement:setText(g_i18n:getText("button_change"))
	self.startButtonElement:setDisabled(false)
end

function JoinGameScreen:onLeaveGameName(element)
	self.selectedInputElement = nil

	self.startButtonElement:setText(g_i18n:getText("button_start"))
	self:updateButtons()
end

function JoinGameScreen:onClickLanguage(state)
	self.selectedLanguageId = state - 1
	self.refreshTimer = JoinGameScreen.FILTER_CHANGE_REFRESH_TIME
end

function JoinGameScreen:onClickMaxNumPlayers(state)
	self.selectedMaxNumPlayers = self.maxNumPlayersNumbers[state]

	self:triggerRebuildOnFilterChange()
end

function JoinGameScreen:onClickMap(state)
	self.selectedMap = self.mapIds[self.mapSelectionElement.state]

	self:triggerRebuildOnFilterChange()
end

function JoinGameScreen:onClickPassword(element)
	self.hasNoPassword = self.passwordElement:getIsChecked()

	self:triggerRebuildOnFilterChange()
end

function JoinGameScreen:onClickCapacity(element)
	self.isNotFull = self.capacityElement:getIsChecked()

	self:triggerRebuildOnFilterChange()
end

function JoinGameScreen:onClickModsDlcs(element)
	self.onlyWithAllModsAvailable = self.modDlcElement:getIsChecked()

	self:triggerRebuildOnFilterChange()
end

function JoinGameScreen:onClickAllowCrossPlay(element)
	self.allowCrossPlay = self.allowCrossPlayElement:getIsChecked()
	self.refreshTimer = JoinGameScreen.FILTER_CHANGE_REFRESH_TIME
end

function JoinGameScreen:onServerNameChanged(element, text)
	self.serverName = text

	self:triggerRebuildOnFilterChange()
end

function JoinGameScreen:onClickOk(isMouseClick)
	if self.selectedInputElement ~= nil then
		self.serverNameElement:onFocusActivate()

		return
	end

	self:saveFilterSettings()
	JoinGameScreen:superClass().onClickOk(self)

	if self.serverList.selectedIndex > 0 then
		if self:isSelectedServerValid() then
			local server = self:getSelectedServer()

			if server ~= nil and server.allModsAvailable then
				if not server.hasPassword then
					self:startGame("", server.id)
				else
					local password = Utils.getNoNil(g_gameSettings:getTableValue("joinGame", "password"), "")

					g_gui:showPasswordDialog({
						callback = self.onPasswordEntered,
						target = self,
						defaultPassword = password,
						args = {
							serverId = server.id
						}
					})
				end
			end
		end

		if isMouseClick then
			self:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
		end
	end
end

function JoinGameScreen:onClickActivate()
	JoinGameScreen:superClass().onClickActivate(self)
	self:saveFilterSettings()

	local server = self:getSelectedServer()

	if server ~= nil and not self.serverDetailsPending then
		self.requestedDetailsServerId = server.id
		self.serverDetailsPending = true

		masterServerRequestServerDetails(server.id)
	end
end

function JoinGameScreen:onClickBack()
	self.startMissionInfo.canStart = false

	g_masterServerConnection:disconnectFromMasterServer()
	g_connectionManager:shutdownAll()
	self:saveFilterSettings()

	return JoinGameScreen:superClass().onClickBack(self)
end

function JoinGameScreen:onDoubleClick()
	self:onClickOk(true)
end

function JoinGameScreen:onClickSort()
	local eventUnused = JoinGameScreen:superClass().onClickMenuExtra1(self)

	if eventUnused then
		if self.focusedHeaderElement ~= nil then
			self:onClickHeader(self.focusedHeaderElement)
		end

		eventUnused = false
	end

	return eventUnused
end

function JoinGameScreen:onInputModeChanged(inputMode)
	local requireSortButton = GS_IS_CONSOLE_VERSION or inputMode[1] == GS_INPUT_HELP_MODE_GAMEPAD
	self.canShowSortButton = requireSortButton

	self:showSortButton(requireSortButton and self.focusedHeaderElement ~= nil)
end

function JoinGameScreen:getNumberOfItemsInSection(list, section)
	return #self.displayServers
end

function JoinGameScreen:populateCellForItemInSection(list, section, index, cell)
	local server = self.displayServers[index]

	cell:getAttribute("iconModsMissing"):setVisible(not server.allModsAvailable)
	cell:getAttribute("iconServerPassword"):setVisible(server.hasPassword)
	cell:getAttribute("iconServerInternet"):setVisible(not server.isFriendServer and not server.isLanServer)
	cell:getAttribute("iconServerLan"):setVisible(not server.isFriendServer and server.isLanServer)
	cell:getAttribute("iconFriends"):setVisible(server.isFriendServer)
	cell:getAttribute("iconPlatform"):setPlatformId(server.platformId)
	cell:getAttribute("gameName"):setText(server.name)
	cell:getAttribute("mapName"):setText(server.mapName)

	local numPlayers = string.format("%02d/%02d", server.numPlayers, server.capacity)

	cell:getAttribute("players"):setText(numPlayers)

	local isFull = server.numPlayers == server.capacity

	cell:getAttribute("iconSlotsFull"):setVisible(isFull)
	cell:getAttribute("iconSlotsAvailable"):setVisible(not isFull)
	cell:getAttribute("language"):setText(getLanguageCode(server.language):upper())
end

function JoinGameScreen:onListSelectionChanged(list, section, index)
	local server = self.displayServers[index]

	if server ~= nil then
		self.lastSelectedServerName = server.name
		self.lastSelectedServerMapName = server.mapName
	end

	self:updateButtons()
end

function JoinGameScreen:loadFilterSettings()
	self.settingsLoaded = true
	local selectedMapState = 1
	self.hasNoPassword = Utils.getNoNil(g_gameSettings:getTableValue("joinGame", "hasNoPassword"), false)
	self.isNotFull = Utils.getNoNil(g_gameSettings:getTableValue("joinGame", "isNotFull"), false)
	self.onlyWithAllModsAvailable = Utils.getNoNil(g_gameSettings:getTableValue("joinGame", "onlyWithAllModsAvailable"), false)
	self.allowCrossPlay = Utils.getNoNil(g_gameSettings:getTableValue("joinGame", "allowCrossPlay"), true) and getAllowCrossPlay()
	self.serverName = Utils.getNoNil(g_gameSettings:getTableValue("joinGame", "serverName"), "")

	if g_autoDevMP ~= nil then
		self.serverName = g_autoDevMP.serverName
	end

	self.maxNumPlayersState = #self.maxNumPlayersNumbers
	self.selectedLanguageId = g_gameSettings:getValue(GameSettings.SETTING.MP_LANGUAGE)
	self.selectedLanguageId = math.min(math.max(self.selectedLanguageId, 0), getNumOfLanguages() - 1)
	local mapId = g_gameSettings:getTableValue("joinGame", "mapId")

	if mapId ~= nil then
		for i, m in ipairs(self.mapIds) do
			if m == mapId then
				selectedMapState = i

				break
			end
		end
	end

	local capacity = g_gameSettings:getTableValue("joinGame", "capacity")

	if capacity ~= nil then
		for i, c in ipairs(self.maxNumPlayersNumbers) do
			if c == capacity then
				self.maxNumPlayersState = i

				break
			end
		end
	end

	local selectedLanguageId = g_gameSettings:getTableValue("joinGame", "language")

	if selectedLanguageId ~= nil and selectedLanguageId >= 0 and selectedLanguageId < getNumOfLanguages() then
		self.selectedLanguageId = selectedLanguageId
	end

	self.mapSelectionElement:setState(selectedMapState)

	self.selectedMap = self.mapIds[self.mapSelectionElement.state]

	self.passwordElement:setIsChecked(self.hasNoPassword)
	self.capacityElement:setIsChecked(self.isNotFull)
	self.modDlcElement:setIsChecked(self.onlyWithAllModsAvailable)
	self.allowCrossPlayElement:setIsChecked(self.allowCrossPlay)
	self.serverNameElement:setText(self.serverName)
	self.maxNumPlayersElement:setState(self.maxNumPlayersState)

	self.selectedMaxNumPlayers = self.maxNumPlayersNumbers[self.maxNumPlayersElement.state]
	local languageIndex = self.selectedLanguageId + 1

	self.languageElement:setState(languageIndex)
end

function JoinGameScreen:saveFilterSettings()
	g_gameSettings:setTableValue("joinGame", "hasNoPassword", self.passwordElement:getIsChecked())
	g_gameSettings:setTableValue("joinGame", "isNotEmpty", self.capacityElement:getIsChecked())
	g_gameSettings:setTableValue("joinGame", "onlyWithAllModsAvailable", self.modDlcElement:getIsChecked())
	g_gameSettings:setTableValue("joinGame", "allowCrossPlay", self.allowCrossPlayElement:getIsChecked())
	g_gameSettings:setTableValue("joinGame", "serverName", self.serverName)
	g_gameSettings:setTableValue("joinGame", "language", self.selectedLanguageId)
	g_gameSettings:setTableValue("joinGame", "capacity", self.maxNumPlayersNumbers[self.maxNumPlayersElement.state])
	g_gameSettings:setTableValue("joinGame", "mapId", self.mapIds[self.mapSelectionElement.state])
	g_gameSettings:saveToXMLFile(g_savegameXML)
end

function JoinGameScreen:showSortButton(show)
	self.sortButton:setVisible(show)
	self.buttonBox:invalidateLayout()
end

function JoinGameScreen:getSelectedServer()
	return self.displayServers[self.serverList.selectedIndex]
end

function JoinGameScreen:updateButtons()
	if self.startButtonElement ~= nil then
		local isValid = self:isSelectedServerValid()

		self.startButtonElement:setDisabled(not isValid)
	end

	self.detailButtonElement:setDisabled(self:getSelectedServer() == nil)
end

function JoinGameScreen:isSelectedServerValid()
	local selectedServer = self:getSelectedServer()

	return selectedServer and selectedServer.allModsAvailable and selectedServer.numPlayers < selectedServer.capacity
end

function JoinGameScreen:onPasswordEntered(password, clickOk, args)
	if clickOk then
		self.showingDeepLinkingPassword = nil

		if g_deepLinkingInfo == nil then
			g_gameSettings:setTableValue("joinGame", "password", password)
			g_gameSettings:saveToXMLFile(g_savegameXML)
		end

		local serverId = nil
		local serverIdRequested = args.serverId

		for _, server in ipairs(self.displayServers) do
			if server.id == serverIdRequested then
				serverId = serverIdRequested

				break
			end
		end

		if serverId == nil then
			local text = string.format("%s\n%s", g_i18n:getText("ui_connectionFailed"), g_i18n:getText("ui_serverWasShutdown"))

			g_gui:showInfoDialog({
				text = text,
				dialogType = DialogElement.TYPE_WARNING
			})

			return
		end

		self:startGame(password, serverId)
	end
end

function JoinGameScreen:startGame(password, serverId)
	g_maxUploadRate = 30.72
	local missionInfo = FSCareerMissionInfo.new("", nil, 0)

	missionInfo:loadDefaults()

	missionInfo.playerModelIndex = self.startMissionInfo.playerModelIndex
	local missionDynamicInfo = {
		serverId = serverId,
		isMultiplayer = true,
		isClient = true,
		password = password,
		allowOnlyFriends = false
	}

	g_mpLoadingScreen:setMissionInfo(missionInfo, missionDynamicInfo)
	g_gui:showGui("MPLoadingScreen")
	g_mpLoadingScreen:startClient()
end

function JoinGameScreen:update(dt)
	JoinGameScreen:superClass().update(self, dt)
	Platform.verifyMultiplayerAvailabilityInMenu()

	if not self.requestPending then
		self.refreshTimer = self.refreshTimer - dt

		if self.refreshTimer <= 0 then
			self.refreshTimer = JoinGameScreen.REFRESH_TIME

			self:getServers()
		end
	end
end
