local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

RollercoasterStateRideWaiting = {}
local RollercoasterStateRideWaiting_mt = Class(RollercoasterStateRideWaiting, RollercoasterState)

function RollercoasterStateRideWaiting.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.TIME, basePath .. "#duration", "Waiting duration between rides in seconds")
end

function RollercoasterStateRideWaiting.new(rollercoaster, customMt)
	local self = RollercoasterState.new(rollercoaster, customMt or RollercoasterStateRideWaiting_mt)
	self.infoBoxRideWaiting = {
		accentuate = true,
		title = g_i18n:getText("infohud_rideWaiting")
	}
	self.infoBoxRideStartingIn = {
		title = ""
	}
	self.textStartingIn = g_i18n:getText("infohud_rideStartingIn")
	self.hudBoxData = {}
	self.hudBox = g_currentMission.hud.infoDisplay:createBox(KeyValueInfoHUDBox)

	return self
end

function RollercoasterStateRideWaiting:load(xmlFile, key)
	RollercoasterStateRideWaiting:superClass().load(self, xmlFile, key)

	self.waitingDuration = 2500

	if g_currentMission.missionDynamicInfo.isMultiplayer then
		self.waitingDuration = xmlFile:getValue(key .. "#duration") or 20000
	end
end

function RollercoasterStateRideWaiting:delete()
	if self.hudBox ~= nil then
		g_currentMission.hud.infoDisplay:destroyBox(self.hudBox)
	end

	RollercoasterStateRideWaiting:superClass().delete(self)
end

function RollercoasterStateRideWaiting:isDone()
	if self.startTime ~= nil then
		return self.startTime < g_time and self.rollercoaster:getCanStart()
	end

	return false
end

function RollercoasterStateRideWaiting:raiseActive()
	return self.rollercoaster:getCanStart()
end

function RollercoasterStateRideWaiting:activate()
	RollercoasterStateRideWaiting:superClass().activate(self)
	self.rollercoaster:setPlayerTriggerState(true)
	self.rollercoaster:registerRidersChangedListener(self, function (numRiders, change, player)
		if self.rollercoaster:getIsSynchronized() and numRiders == 1 and change == 1 then
			self.startTime = g_time + self.waitingDuration
		end

		if player == g_currentMission.player then
			if change == 1 then
				g_currentMission:addDrawable(self)
			else
				g_currentMission:removeDrawable(self)
			end
		end

		if numRiders > 0 then
			self.rollercoaster:raiseActive()
		end
	end)
end

function RollercoasterStateRideWaiting:deactivate()
	RollercoasterStateRideWaiting:superClass().deactivate(self)
	self.rollercoaster:unregisterRidersChangedListener(self)

	self.startTime = nil

	g_currentMission:removeDrawable(self)
	self.rollercoaster:setPlayerTriggerState(false)
end

function RollercoasterStateRideWaiting:onReadStream(streamId, connection)
	if streamReadBool(streamId) then
		local timeLeft = streamReadUInt8(streamId)
		self.startTime = g_time + timeLeft * 1000
	end
end

function RollercoasterStateRideWaiting:onWriteStream(streamId, connection)
	if streamWriteBool(streamId, self.startTime ~= nil) then
		local timeLeft = MathUtil.round((self.startTime - g_time) / 1000)

		streamWriteUInt8(streamId, timeLeft)
	end
end

function RollercoasterStateRideWaiting:draw()
	if self.startTime and not self.rollercoaster.spec_infoTrigger.showInfo then
		local box = self.hudBox

		box:clear()
		box:setTitle(self.rollercoaster:getName())
		self:updateInfo(self.hudBoxData)

		if #self.hudBoxData > 0 then
			for i = 1, #self.hudBoxData do
				local element = self.hudBoxData[i]

				box:addLine(element.title, element.text, element.accentuate)

				self.hudBoxData[i] = nil
			end

			box:showNextFrame()
		end
	end
end

function RollercoasterStateRideWaiting:updateInfo(infoTable)
	table.insert(infoTable, self.infoBoxRideWaiting)

	if self.startTime ~= nil and g_time < self.startTime then
		self.infoBoxRideStartingIn.title = string.format(self.textStartingIn, (self.startTime - g_time) / 1000)

		table.insert(infoTable, self.infoBoxRideStartingIn)
	end
end
