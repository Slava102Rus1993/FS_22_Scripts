local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

PlayerSuperStrength = {
	CUSTOM_ENVIRONMENT = g_currentModName,
	NUM_RIDES = 15
}

function PlayerSuperStrength.updatePlayer(player, noEventSend)
	local rollercoaster = PlaceableRollercoaster.INSTANCE

	if rollercoaster ~= nil then
		local userId = player.userId
		local user = g_currentMission.userManager:getUserByUserId(userId)

		if user ~= nil then
			local uniqueUserId = user:getUniqueUserId()
			local rideCount = rollercoaster:getNumRides(uniqueUserId)

			if PlayerSuperStrength.NUM_RIDES <= rideCount then
				PlayerSuperStrength.apply(player)

				if noEventSend == nil or not noEventSend then
					local connection = user:getConnection()

					connection:sendEvent(PlayerSuperStrengthEvent.new(player))
				end
			end
		end
	end
end

function PlayerSuperStrength.apply(player)
	player.hasSuperPower = true
	player.maxPickableMass = 1
end

function postReadStream(player, streamId, connection, objectId)
	if connection:getIsServer() then
		player.hasSuperPower = streamReadBool(streamId)

		if player.hasSuperPower then
			PlayerSuperStrength.apply(player)
		end
	end
end

Player.readStream = Utils.appendedFunction(Player.readStream, postReadStream)

function postWriteStream(player, streamId, connection)
	if not connection:getIsServer() then
		streamWriteBool(streamId, player.hasSuperPower)
	end
end

Player.writeStream = Utils.appendedFunction(Player.writeStream, postWriteStream)

function postCreatePlayer(mission, superFunc, connection, isOwner, farmId, userId)
	local player = superFunc(mission, connection, isOwner, farmId, userId)
	player.hasSuperPower = false

	PlayerSuperStrength.updatePlayer(player, true)

	return player
end

FSBaseMission.createPlayer = Utils.overwrittenFunction(FSBaseMission.createPlayer, postCreatePlayer)
PlayerSuperStrengthEvent = {}
local PlayerSuperStrengthEvent_mt = Class(PlayerSuperStrengthEvent, Event)

InitEventClass(PlayerSuperStrengthEvent, "PlayerSuperStrengthEvent")

function PlayerSuperStrengthEvent.emptyNew()
	local self = Event.new(PlayerSuperStrengthEvent_mt)

	return self
end

function PlayerSuperStrengthEvent.new()
	local self = PlayerSuperStrengthEvent.emptyNew()

	return self
end

function PlayerSuperStrengthEvent:readStream(streamId, connection)
	self:run(connection)
end

function PlayerSuperStrengthEvent:writeStream(streamId, connection)
end

function PlayerSuperStrengthEvent:run(connection)
	if g_currentMission.player ~= nil then
		PlayerSuperStrength.apply(g_currentMission.player)
		g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, g_i18n:getText("ingameNotification_playerSuperStrengthActivated", PlayerSuperStrength.CUSTOM_ENVIRONMENT))
	end
end
