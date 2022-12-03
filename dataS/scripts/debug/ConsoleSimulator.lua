ConsoleSimulator = {
	MP_AVAILABILITY = nil,
	NETWORK_ERROR = nil,
	ACHIEVEMENTS_AVAILABLE = true,
	NEW_DLCS = false,
	STORE_DLC_CHANGED = false
}

function ConsoleSimulator.init()
	local oldKeyEvent = keyEvent

	function keyEvent(unicode, sym, modifier, isDown)
		if isDown then
			if sym == Input.KEY_1 then
				Logging.devInfo("ConsoleSimulator: NETWORK_ERROR - Error")

				ConsoleSimulator.NETWORK_ERROR = "ERROR"
			elseif sym == Input.KEY_2 then
				Logging.devInfo("ConsoleSimulator: NETWORK_ERROR - Nil")

				ConsoleSimulator.NETWORK_ERROR = nil
			elseif sym == Input.KEY_3 then
				Logging.devInfo("ConsoleSimulator: MP_AVAILABILITY - nil")

				ConsoleSimulator.MP_AVAILABILITY = nil
			elseif sym == Input.KEY_4 then
				Logging.devInfo("ConsoleSimulator: MP_AVAILABILITY - AVAILABILITY_UNKNOWN")

				ConsoleSimulator.MP_AVAILABILITY = MultiplayerAvailability.AVAILABILITY_UNKNOWN
			elseif sym == Input.KEY_5 then
				Logging.devInfo("ConsoleSimulator: MP_AVAILABILITY - NOT_AVAILABLE")

				ConsoleSimulator.MP_AVAILABILITY = MultiplayerAvailability.NOT_AVAILABLE
			elseif sym == Input.KEY_6 then
				Logging.devInfo("ConsoleSimulator: MP_AVAILABILITY - NO_PRIVILEGES")

				ConsoleSimulator.MP_AVAILABILITY = MultiplayerAvailability.NO_PRIVILEGES
			elseif sym == Input.KEY_7 then
				Logging.devInfo("ConsoleSimulator: finishedUserProfileSync")
				finishedUserProfileSync()
			elseif sym == Input.KEY_9 then
				Logging.devInfo("ConsoleSimulator: onMasterServerConnectionFailed - conenction lost")
				g_currentMission:onMasterServerConnectionFailed(MasterServerConnection.FAILED_CONNECTION_LOST)
			elseif sym == Input.KEY_0 then
				Logging.devInfo("ConsoleSimulator: NEW_DLCS")

				ConsoleSimulator.NEW_DLCS = true
				ConsoleSimulator.STORE_DLC_CHANGED = true
			elseif sym == Input.KEY_KP_1 then
				ConsoleSimulator.ACHIEVEMENTS_AVAILABLE = not ConsoleSimulator.ACHIEVEMENTS_AVAILABLE

				Logging.devInfo("ConsoleSimulator: ACHIEVEMENTS_AVAILABLE: %s", tostring(ConsoleSimulator.ACHIEVEMENTS_AVAILABLE))
			end
		end

		oldKeyEvent(unicode, sym, modifier, isDown)
	end

	local oldGetNetworkError = getNetworkError

	function getNetworkError()
		if ConsoleSimulator.NETWORK_ERROR ~= nil then
			return ConsoleSimulator.NETWORK_ERROR
		end

		return oldGetNetworkError()
	end

	local oldGetMultiplayerAvailability = getMultiplayerAvailability

	function getMultiplayerAvailability()
		if ConsoleSimulator.MP_AVAILABILITY ~= nil then
			return ConsoleSimulator.MP_AVAILABILITY, false
		end

		return oldGetMultiplayerAvailability()
	end

	function areAchievementsAvailable()
		return ConsoleSimulator.ACHIEVEMENTS_AVAILABLE
	end

	local oldStartFrameRepeatMode = startFrameRepeatMode

	function startFrameRepeatMode()
		Logging.devInfo("ConsoleSimulator: startFrameRepeatMode")

		return oldStartFrameRepeatMode()
	end

	local oldEndFrameRepeatMode = endFrameRepeatMode

	function endFrameRepeatMode()
		Logging.devInfo("ConsoleSimulator: endFrameRepeatMode")

		return oldEndFrameRepeatMode()
	end

	local oldForceEndFrameRepeatMode = forceEndFrameRepeatMode

	function forceEndFrameRepeatMode()
		Logging.devInfo("ConsoleSimulator: forceEndFrameRepeatMode")
		oldForceEndFrameRepeatMode()
	end

	local oldCheckForNewDlcs = checkForNewDlcs

	function checkForNewDlcs()
		if ConsoleSimulator.NEW_DLCS then
			ConsoleSimulator.NEW_DLCS = false

			return true
		end

		return oldCheckForNewDlcs()
	end

	local oldStoreHaveDlcsChanged = storeHaveDlcsChanged

	function storeHaveDlcsChanged()
		if ConsoleSimulator.STORE_DLC_CHANGED then
			ConsoleSimulator.STORE_DLC_CHANGED = false

			return true
		end

		return oldStoreHaveDlcsChanged()
	end

	local oldOpenMpFriendInvitation = openMpFriendInvitation

	function openMpFriendInvitation(num, capacity)
		Logging.devInfo("ConsoleSimulator: Open friend invitation. Currently online: %d . Capacity: %d", num, capacity)
		oldOpenMpFriendInvitation(num, capacity)
	end

	addConsoleCommand("gsConsoleAcceptInvite", "Console simulator accept invitation", "acceptedGameInvite", ConsoleSimulator)
	print([[


  ##################   Warning: Console Simulator active!   ##################

]])
end

function ConsoleSimulator.acceptedGameInvite(_, platformServerId, requestUserName)
	platformServerId = platformServerId or "2"
	requestUserName = requestUserName or "test -user"

	acceptedGameInvite(platformServerId, requestUserName)
end
