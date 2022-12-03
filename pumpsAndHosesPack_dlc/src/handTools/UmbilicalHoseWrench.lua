UmbilicalHoseWrench = {
	DEFAULT_SEARCH_DISTANCE = 2,
	INTERACTION_DELAY = 1000
}
local UmbilicalHoseWrench_mt = Class(UmbilicalHoseWrench, HandTool)

InitObjectClass(UmbilicalHoseWrench, "UmbilicalHoseWrench")

function UmbilicalHoseWrench.new(isServer, isClient, customMt)
	local self = UmbilicalHoseWrench:superClass().new(isServer, isClient, customMt or UmbilicalHoseWrench_mt)
	self.umbilicalHoseQueryInfo1 = {}
	self.umbilicalHoseBufferQuery1 = {}
	self.umbilicalHoseQueryInfo2 = {}
	self.umbilicalHoseBufferQuery2 = {}
	self.searchDistance = UmbilicalHoseWrench.DEFAULT_SEARCH_DISTANCE
	self.interactionDelay = UmbilicalHoseWrench.INTERACTION_DELAY
	self.umbilicalHose = nil

	return self
end

function UmbilicalHoseWrench:onActivate(allowInput)
	UmbilicalHoseWrench:superClass().onActivate(self, allowInput)

	self.interactionDelay = UmbilicalHoseWrench.INTERACTION_DELAY
	self.originalPlayerInputText = nil

	self:setPlayerInputText(g_i18n:getText("action_attachUmbilicalHose"))
end

function UmbilicalHoseWrench:onDeactivate(allowInput)
	UmbilicalHoseWrench:superClass().onDeactivate(self, allowInput)
	self:setPlayerInputText(self.originalPlayerInputText)

	local query1 = self.umbilicalHoseQueryInfo1
	local query2 = self.umbilicalHoseQueryInfo2

	self:resetQuery(query1)
	self:resetQuery(query2)

	if self.umbilicalHose ~= nil then
		self:detachUmbilicalHose(self.connectorType)
	end
end

function UmbilicalHoseWrench:update(dt, allowInput)
	UmbilicalHoseWrench:superClass().update(self, dt, allowInput)

	if self.isActive and allowInput then
		local hasHosesInRange = self:hasHosesInRange()
		local hasSingleHoseInRange = self:hasSingleHoseInRange()
		local hasUmbilicalHose = self:hasUmbilicalHose()
		local hosesAreConnected = self:hosesAreConnected()

		if hasUmbilicalHose or hasHosesInRange or hasSingleHoseInRange then
			if hasUmbilicalHose then
				self:setPlayerInputText(g_i18n:getText("action_detachUmbilicalHose"))
			else
				local connectedKey = hosesAreConnected and "action_detachUmbilicalHose" or "action_attachUmbilicalHose"

				self:setPlayerInputText(g_i18n:getText(connectedKey))

				if not hosesAreConnected and (hasHosesInRange or hasSingleHoseInRange) then
					g_currentMission.manure:showHoseContext(g_i18n:getText("info_attachUmbilicalHoseContext"), true)
				end
			end
		else
			self:setPlayerInputText(g_i18n:getText("action_attachUmbilicalHose"))
		end

		if self.activatePressed and self.interactionDelay <= 0 then
			local query1 = self.umbilicalHoseQueryInfo1
			local query2 = self.umbilicalHoseQueryInfo2

			if hasHosesInRange and not hasUmbilicalHose then
				if hosesAreConnected then
					self:disconnect(query1.hose, query1.type)
				elseif not self:hosesAreAlreadyConnected() then
					self:connect(query1.hose, query2.hose, query1.type, query2.type)
				end
			elseif hasSingleHoseInRange or hasUmbilicalHose then
				if hasUmbilicalHose then
					self:detachUmbilicalHose(UmbilicalHoseOrchestrator.TYPE_HEAD)
				else
					self:attachUmbilicalHose(query1.hose, UmbilicalHoseOrchestrator.TYPE_HEAD, query1.type)
				end
			else
				g_currentMission:showBlinkingWarning(g_i18n:getText("function_umbilical_wrench"))
			end

			self.interactionDelay = UmbilicalHoseWrench.INTERACTION_DELAY
		end
	end

	self.interactionDelay = self.interactionDelay - dt
	self.activatePressed = false

	if self.umbilicalHose ~= nil and self.connectorType ~= nil and self.isServer and self.umbilicalHose:hasControlPoints() then
		self.umbilicalHose:updatePositionByNode(self.handNode, 0, true, self.connectorType, false, false)
	end
end

function UmbilicalHoseWrench:updateTick(dt, allowInput)
	UmbilicalHoseWrench:superClass().updateTick(self, dt, allowInput)

	local query1 = self.umbilicalHoseQueryInfo1
	local buffer1 = self.umbilicalHoseBufferQuery1
	local query2 = self.umbilicalHoseQueryInfo2
	local buffer2 = self.umbilicalHoseBufferQuery2

	if self.isActive and allowInput and not self:hasUmbilicalHose() then
		self:searchHose(buffer1, query1)
		self:searchHose(buffer2, query2, query1.hose)
	else
		self:resetQuery(query1)
		self:resetQuery(query2)
	end

	self:raiseActive()
end

function UmbilicalHoseWrench:setPlayerInputText(text)
	local info = self.player.inputInformation.registrationList[InputAction.ACTIVATE_HANDTOOL]

	if self.originalPlayerInputText == nil then
		self.originalPlayerInputText = info.text
	end

	g_inputBinding:setActionEventText(info.eventId, text)
end

function UmbilicalHoseWrench:searchHose(buffer, query, exclude)
	g_currentMission.manure:getClosestUmbilicalHose(self.handNode, self.searchDistance, buffer, exclude, true)

	query.hose = buffer.hose
	query.node = buffer.node
	query.type = buffer.type
	buffer.hose = nil
	buffer.node = nil
	buffer.type = nil
end

function UmbilicalHoseWrench:resetQuery(query)
	query.hose = nil
	query.node = nil
	query.type = nil
end

function UmbilicalHoseWrench:hasHosesInRange()
	local hose1 = self.umbilicalHoseQueryInfo1.hose
	local hose2 = self.umbilicalHoseQueryInfo2.hose

	return hose1 ~= nil and hose2 ~= nil and hose1 ~= hose2
end

function UmbilicalHoseWrench:hasSingleHoseInRange()
	local hose1 = self.umbilicalHoseQueryInfo1.hose
	local hose2 = self.umbilicalHoseQueryInfo2.hose

	return (hose1 ~= nil or hose2 ~= nil) and hose1 ~= hose2
end

function UmbilicalHoseWrench:hasUmbilicalHose()
	return self.umbilicalHose ~= nil
end

function UmbilicalHoseWrench:hosesAreConnected()
	local hose1 = self.umbilicalHoseQueryInfo1.hose
	local type1 = self.umbilicalHoseQueryInfo1.type
	local hose2 = self.umbilicalHoseQueryInfo2.hose
	local type2 = self.umbilicalHoseQueryInfo2.type

	if hose1 == nil or hose2 == nil then
		return false
	end

	return hose1.connectorsInfo[type1] ~= nil and hose2.connectorsInfo[type2] ~= nil
end

function UmbilicalHoseWrench:hosesAreAlreadyConnected()
	local hose1 = self.umbilicalHoseQueryInfo1.hose
	local type1 = self.umbilicalHoseQueryInfo1.type
	local hose2 = self.umbilicalHoseQueryInfo2.hose
	local type2 = self.umbilicalHoseQueryInfo2.type

	if hose1 == nil or hose2 == nil then
		return false
	end

	return hose1.connectorsInfo[type1] ~= nil or hose2.connectorsInfo[type2] ~= nil
end

function UmbilicalHoseWrench:connect(fromUmbilicalHose, toUmbilicalHose, fromConnectorType, toConnectorType)
	fromUmbilicalHose:attachUmbilicalHose(toUmbilicalHose, fromConnectorType, toConnectorType, false)
end

function UmbilicalHoseWrench:disconnect(fromUmbilicalHose, fromConnectorType)
	fromUmbilicalHose:detachUmbilicalHose(fromConnectorType, false)
end

function UmbilicalHoseWrench:attachUmbilicalHose(umbilicalHose, type, connectorType, noEventSend)
	UmbilicalHoseWrenchAttachEvent.sendEvent(self.player, umbilicalHose, type, connectorType, noEventSend)
	umbilicalHose:onAttach(self, connectorType, false)

	self.umbilicalHose = umbilicalHose
	self.connectorType = connectorType

	umbilicalHose:raiseActive()
end

function UmbilicalHoseWrench:detachUmbilicalHose(type, noEventSend)
	local umbilicalHose = self.umbilicalHose

	UmbilicalHoseWrenchDetachEvent.sendEvent(self.player, type, noEventSend)

	if umbilicalHose ~= nil then
		if self.isServer then
			umbilicalHose:updatePositionByNode(self.referenceNode or self.handNode, 1, true, self.connectorType, true)
		end

		umbilicalHose:onDetach(self)
	end

	self.umbilicalHose = nil
	self.connectorType = nil
end
