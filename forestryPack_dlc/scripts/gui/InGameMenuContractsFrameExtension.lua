local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

local function overwrittenUpdateFieldContractInfo(self, superFunc, mission)
	if mission:isa(DeadwoodMission) or mission:isa(TreeTransportMission) or mission:isa(DestructibleRockMission) then
		local missionInfo = mission:getData()

		self.titleText:setText(g_i18n:getText("fieldJob_contract") .. ": " .. missionInfo.jobType)
		self.actionText:setText(missionInfo.action)
		self.rewardText:setText(g_i18n:formatMoney(mission:getReward(), 0, true, true))
		self.fieldBigText:setText("")
		self.contractDescriptionText:setText(missionInfo.description)
	else
		superFunc(self, mission)
	end
end

InGameMenuContractsFrame.updateFieldContractInfo = Utils.overwrittenFunction(InGameMenuContractsFrame.updateFieldContractInfo, overwrittenUpdateFieldContractInfo)

local function postUpdateDetailContents(self, section, index)
	local contract = nil
	local sectionContracts = self.sectionContracts[section]

	if sectionContracts ~= nil then
		contract = sectionContracts.contracts[index]
	end

	if contract ~= nil and contract.finished then
		local mission = contract.mission
		local text = g_i18n:getText("fieldJob_tally_stealing")

		if mission:isa(DeadwoodMission) then
			text = g_i18n:getText("deadwoodMission_tally_wronglyCut")
		elseif mission:isa(TreeTransportMission) then
			text = g_i18n:getText("treeTransportMission_tally_wronglyDelivered")
		elseif mission:isa(DestructibleRockMission) then
			text = g_i18n:getText("destructibleRockMission_tally_wronglyRemoved")
		end

		self.tallyBox:getDescendantByName("stealingText"):setText(text)
	end
end

InGameMenuContractsFrame.updateDetailContents = Utils.appendedFunction(InGameMenuContractsFrame.updateDetailContents, postUpdateDetailContents)
