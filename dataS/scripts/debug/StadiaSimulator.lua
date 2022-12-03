StadiaSimulator = {
	IS_HDR_ACTIVE = false,
	HAS_RECORDING_DEVICE = false,
	ACTIVE_GAMEPAD_INDEX = 0
}

function StadiaSimulator.init()
	local oldGetNumOfGamepads = getNumOfGamepads
	local oldGetGamepadId = getGamepadId
	local oldGetGamepadButtonLabel = getGamepadButtonLabel
	local oldGetGamepadName = getGamepadName
	local oldGetInputButton = getInputButton
	local oldGetGamepadAxisLabel = getGamepadAxisLabel
	local oldGetInputAxis = getInputAxis
	local oldKeyEvent = keyEvent

	function keyEvent(unicode, sym, modifier, isDown)
		if isDown then
			if sym == Input.KEY_1 then
				Logging.devInfo("StadiaSimulator: onMultiplayerInviteSent")
				onMultiplayerInviteSent()
			elseif sym == Input.KEY_2 then
				Logging.devInfo("StadiaSimulator: onWaitForPendingGameSession")
				onWaitForPendingGameSession()
			elseif sym == Input.KEY_3 then
				Logging.devInfo("StadiaSimulator: onRemovedFromInvite")
				onRemovedFromInvite()
			elseif sym == Input.KEY_5 then
				StadiaSimulator.IS_HDR_ACTIVE = not StadiaSimulator.IS_HDR_ACTIVE

				Logging.devInfo("StadiaSimulator: isHDRActive: %s", tostring(StadiaSimulator.IS_HDR_ACTIVE))
			elseif sym == Input.KEY_6 then
				StadiaSimulator.HAS_RECORDING_DEVICE = not StadiaSimulator.HAS_RECORDING_DEVICE

				Logging.devInfo("StadiaSimulator: hasRecordingDevice: %s", tostring(StadiaSimulator.HAS_RECORDING_DEVICE))
			elseif sym == Input.KEY_7 then
				StadiaSimulator.ACTIVE_GAMEPAD_INDEX = StadiaSimulator.ACTIVE_GAMEPAD_INDEX + 1

				if oldGetNumOfGamepads() <= StadiaSimulator.ACTIVE_GAMEPAD_INDEX then
					StadiaSimulator.ACTIVE_GAMEPAD_INDEX = 0
				end

				Logging.devInfo("StadiaSimulator: activeGamepadIndex: %d", StadiaSimulator.ACTIVE_GAMEPAD_INDEX)
			end
		end

		oldKeyEvent(unicode, sym, modifier, isDown)
	end

	function getHdrAvailable()
		return StadiaSimulator.IS_HDR_ACTIVE
	end

	function voiceChatGetHasRecordingDevice()
		return StadiaSimulator.HAS_RECORDING_DEVICE
	end

	function getNumOfGamepads()
		return 1
	end

	function getGamepadId(deviceIndex)
		return oldGetGamepadId(StadiaSimulator.ACTIVE_GAMEPAD_INDEX)
	end

	function getGamepadButtonLabel(buttonIndex, deviceIndex)
		return oldGetGamepadButtonLabel(buttonIndex, StadiaSimulator.ACTIVE_GAMEPAD_INDEX)
	end

	function getGamepadName(deviceIndex)
		return oldGetGamepadName(StadiaSimulator.ACTIVE_GAMEPAD_INDEX)
	end

	function getInputButton(buttonIndex, deviceIndex)
		return oldGetInputButton(buttonIndex, StadiaSimulator.ACTIVE_GAMEPAD_INDEX)
	end

	function getGamepadAxisLabel(axisIndex, deviceIndex)
		return oldGetGamepadAxisLabel(axisIndex, StadiaSimulator.ACTIVE_GAMEPAD_INDEX)
	end

	function getInputAxis(axisIndex, deviceIndex)
		return oldGetInputAxis(axisIndex, StadiaSimulator.ACTIVE_GAMEPAD_INDEX)
	end

	addConsoleCommand("gsStadiaAcceptInvite", "Stadia simulator accept invitation", "acceptedGameInvite", StadiaSimulator)
	print([[


  ##################   Warning: Stadia Simulator active!   ##################

]])
end

function StadiaSimulator.acceptedGameInvite(platformServerId, requestUserName)
	platformServerId = platformServerId or "2"
	requestUserName = requestUserName or "test -user"

	acceptedGameInvite(platformServerId, requestUserName)
end
