PlayerInfoStorage = {
	MAX_NUM_SAVED_PLAYERS = 250,
	MAX_NUM_DAYS_OFFLINE = 30
}
local PlayerInfoStorage_mt = Class(PlayerInfoStorage)

function PlayerInfoStorage.new(isServer, userManager, customMt)
	local self = setmetatable({}, customMt or PlayerInfoStorage_mt)
	self.isServer = isServer
	self.userManager = userManager
	self.players = {}
	self.playerByUniqueUserId = {}

	return self
end

function PlayerInfoStorage:delete()
end

function PlayerInfoStorage:loadFromXMLFile(xmlFilename)
	local xmlFile = XMLFile.load("TempXML", xmlFilename)

	if xmlFile == nil then
		return false
	end

	xmlFile:iterate("players.player", function (index, key)
		local player = {
			uniqueUserId = xmlFile:getString(key .. "#uniqueUserId"),
			timeLastConnected = xmlFile:getString(key .. "#timeLastConnected") or getDate("%Y/%m/%d %H:%M"),
			playerStyle = PlayerStyle.new()
		}

		player.playerStyle:loadFromXMLFile(xmlFile, key .. ".style")

		if player.playerStyle:isValid() then
			table.insert(self.players, player)

			self.playerByUniqueUserId[player.uniqueUserId] = player
		end
	end)
	xmlFile:delete()

	return true
end

function PlayerInfoStorage:saveToXMLFile(xmlFilename)
	local xmlFile = XMLFile.create("TempXML", xmlFilename, "players")

	if xmlFile == nil then
		return false
	end

	local playersToSave = table.copy(self.players)

	table.sort(playersToSave, function (a, b)
		return b.timeLastConnected < a.timeLastConnected
	end)

	local yearCur, monthCur, dayCur, hourCur, minuteCur = string.match(getDate("%Y/%m/%d %H:%M"), "(%d+)/(%d+)/(%d+) (%d+):(%d+)")
	minuteCur = tonumber(minuteCur)
	hourCur = tonumber(hourCur)
	dayCur = tonumber(dayCur)
	monthCur = tonumber(monthCur)
	yearCur = tonumber(yearCur)
	local maxTimeSinceLastConnectionSec = PlayerInfoStorage.MAX_NUM_DAYS_OFFLINE * 24 * 60 * 60
	local xmlIndex = 0

	for i, player in ipairs(playersToSave) do
		if PlayerInfoStorage.MAX_NUM_SAVED_PLAYERS <= xmlIndex then
			local year, month, day, hour, minute = string.match(player.timeLastConnected, "(%d+)/(%d+)/(%d+) (%d+):(%d+)")
			minute = tonumber(minute)
			hour = tonumber(hour)
			day = tonumber(day)
			month = tonumber(month)
			year = tonumber(year)

			if year and maxTimeSinceLastConnectionSec < math.abs(getDateDiffSeconds(year, month, day, hour, minute, 0, yearCur, monthCur, dayCur, hourCur, minuteCur, 0)) then
				Logging.info("Excluded %d players from '%s': Limit reached and affected players did not join the server for more than %d days", #playersToSave - xmlIndex, xmlFilename, PlayerInfoStorage.MAX_NUM_DAYS_OFFLINE)

				break
			end
		end

		local key = string.format("players.player(%d)", xmlIndex)

		xmlFile:setString(key .. "#uniqueUserId", player.uniqueUserId)
		xmlFile:setString(key .. "#timeLastConnected", player.timeLastConnected)
		player.playerStyle:saveToXMLFile(xmlFile, key .. ".style")

		xmlIndex = xmlIndex + 1
	end

	xmlFile:save()
	xmlFile:delete()

	return true
end

function PlayerInfoStorage:addNewPlayer(uniqueUserId, style)
	if self:hasPlayerWithUniqueUserId(uniqueUserId) then
		return
	end

	local player = {
		uniqueUserId = uniqueUserId,
		playerStyle = PlayerStyle.new(),
		timeLastConnected = getDate("%Y/%m/%d %H:%M")
	}

	player.playerStyle:copyMinimalFrom(style)
	table.insert(self.players, player)

	self.playerByUniqueUserId[uniqueUserId] = player
end

function PlayerInfoStorage:hasPlayerWithUniqueUserId(uniqueUserId)
	return self.playerByUniqueUserId[uniqueUserId] ~= nil
end

function PlayerInfoStorage:getPlayerStyle(userId)
	local uuid = self.userManager:getUniqueUserIdByUserId(userId)

	if uuid ~= nil then
		local player = self.playerByUniqueUserId[uuid]

		if player ~= nil then
			player.timeLastConnected = getDate("%Y/%m/%d %H:%M")
			local playerStyle = PlayerStyle.new()

			playerStyle:copyMinimalFrom(player.playerStyle)

			return playerStyle
		end
	end

	return PlayerStyle.defaultStyle()
end

function PlayerInfoStorage:setPlayerStyle(userId, style)
	local uuid = self.userManager:getUniqueUserIdByUserId(userId)

	if uuid ~= nil then
		self.playerByUniqueUserId[uuid].playerStyle:copyFrom(style)
	end
end
