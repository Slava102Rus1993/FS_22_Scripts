InGameMenuFinancesFrame = {}
local InGameMenuFinancesFrame_mt = Class(InGameMenuFinancesFrame, TabbedMenuFrameElement)
InGameMenuFinancesFrame.CONTROLS = {
	"financesList",
	TOTAL_TEXTS = "totalText",
	MAIN_BOX = "mainBox",
	BALANCE_TEXT = "balanceText",
	PAST_DAY_HEADERS = "pastDayHeader",
	LOAN_TEXT = "loanText"
}
InGameMenuFinancesFrame.PAST_PERIOD_COUNT = GS_IS_MOBILE_VERSION and 3 or 4
InGameMenuFinancesFrame.MAX_ITEMS = GS_IS_MOBILE_VERSION and 4 or 10
InGameMenuFinancesFrame.LOAN_STEP = 5000

function InGameMenuFinancesFrame.new(customMt, messageCenter, l10n, inputManager)
	local self = InGameMenuFinancesFrame:superClass().new(nil, customMt or InGameMenuFinancesFrame_mt)

	self:registerControls(InGameMenuFinancesFrame.CONTROLS)

	self.messageCenter = messageCenter
	self.l10n = l10n
	self.inputManager = inputManager
	self.client = nil
	self.environment = nil
	self.playerFarm = nil
	self.currentMoneyUnitText = ""
	self.updateTimeFinancesStats = 0

	if Platform.gameplay.hasLoans then
		self.backButtonInfo = {
			inputAction = InputAction.MENU_BACK
		}
		self.borrowButtonInfo = {
			text = "",
			inputAction = InputAction.MENU_ACTIVATE,
			callback = function ()
				self:onButtonBorrow()
			end
		}
		self.repayButtonInfo = {
			text = "",
			inputAction = InputAction.MENU_CANCEL,
			callback = function ()
				self:onButtonRepay()
			end
		}
		self.menuButtonInfo = {
			self.backButtonInfo,
			self.borrowButtonInfo,
			self.repayButtonInfo
		}
		self.hasCustomMenuButtons = true
	end

	return self
end

function InGameMenuFinancesFrame.createFromExistingGui(gui, guiName)
	local newGui = InGameMenuFinancesFrame.new(nil, gui.messageCenter, gui.l10n, gui.inputManager)

	g_gui.frames[gui.name].target:delete()
	g_gui.frames[gui.name]:delete()
	g_gui:loadGui(gui.xmlFilename, guiName, newGui, true)

	return newGui
end

function InGameMenuFinancesFrame:copyAttributes(src)
	InGameMenuFinancesFrame:superClass().copyAttributes(self, src)

	self.messageCenter = src.messageCenter
	self.l10n = src.l10n
	self.inputManager = src.inputManager
end

function InGameMenuFinancesFrame:onFrameOpen(element)
	InGameMenuFinancesFrame:superClass().onFrameOpen(self)
	self:updateMoneyUnit()
	self:updateFinances()
	self:updateFinancesLoanButtons()
	self.messageCenter:subscribe(PlayerPermissionsEvent, self.updateFinancesLoanButtons, self)
	self.messageCenter:subscribe(ChangeLoanEvent, self.updateFinances, self)
end

function InGameMenuFinancesFrame:onFrameClose()
	InGameMenuFinancesFrame:superClass().onFrameClose(self)
	self.messageCenter:unsubscribeAll(self)
end

function InGameMenuFinancesFrame:onClose()
	InGameMenuFinancesFrame:superClass().onClose(self)
	g_currentMission:showMoneyChange(MoneyType.LOAN)
end

function InGameMenuFinancesFrame:update(dt)
	InGameMenuFinancesFrame:superClass().update(self, dt)

	if not g_currentMission:getIsServer() and self.updateTimeFinancesStats < g_currentMission.time then
		self.updateTimeFinancesStats = g_currentMission.time + 5000
		local farm = g_farmManager:getFarmById(g_currentMission.player.farmId)

		if farm.stats.financesHistoryVersionCounter ~= farm.stats.financesHistoryVersionCounterLocal then
			farm.stats.financesHistoryVersionCounterLocal = farm.stats.financesHistoryVersionCounter

			for i = 1, InGameMenuFinancesFrame.PAST_PERIOD_COUNT do
				self.client:getServerConnection():sendEvent(FinanceStatsEvent.new(i, farm.farmId))
			end
		end
	end
end

function InGameMenuFinancesFrame:setClient(client)
	self.client = client
end

function InGameMenuFinancesFrame:setEnvironment(environment)
	self.environment = environment
end

function InGameMenuFinancesFrame:setPlayerFarm(farm)
	self.playerFarm = farm
end

function InGameMenuFinancesFrame:updateFinances()
	local currentPeriod = self.environment.currentPeriod

	for i = 1, InGameMenuFinancesFrame.PAST_PERIOD_COUNT do
		local pastPeriod = currentPeriod - i

		self.pastDayHeader[i]:setText(g_i18n:formatPeriod(pastPeriod, false))
	end

	self.pastDayHeader[0]:setText(g_i18n:formatPeriod(currentPeriod, false))
	self.financesList:reloadData()

	local stats = self.playerFarm.stats

	self:updateFinancesFooter(stats.finances, stats.financesHistory)
	self:updateFinancesLoanButtons()
end

function InGameMenuFinancesFrame:updateFinancesLoanButtons()
	if Platform.gameplay.hasLoans then
		local allowChangeLoan = self:hasPlayerLoanPermission()
		local isBorrowEnabled = self.playerFarm.loan < self.playerFarm.loanMax and allowChangeLoan
		local isRepayEnabled = self.playerFarm.loan > 0 and InGameMenuFinancesFrame.LOAN_STEP <= self.playerFarm.money and allowChangeLoan
		self.borrowButtonInfo.disabled = not isBorrowEnabled
		self.repayButtonInfo.disabled = not isRepayEnabled

		self:setMenuButtonInfoDirty()
	end
end

function InGameMenuFinancesFrame:updateMoneyUnit()
	self.currentMoneyUnitText = self.l10n:getCurrencySymbol(true)

	if Platform.gameplay.hasLoans then
		local borrowTemplate = self.l10n:getText(InGameMenuFinancesFrame.L10N_SYMBOL.BUTTON_BORROW)
		local text = string.gsub(borrowTemplate, InGameMenuFinancesFrame.L10N_SYMBOL.CURRENCY, self.currentMoneyUnitText)
		self.borrowButtonInfo.text = text
		local repayTemplate = self.l10n:getText(InGameMenuFinancesFrame.L10N_SYMBOL.BUTTON_REPAY)
		text = string.gsub(repayTemplate, InGameMenuFinancesFrame.L10N_SYMBOL.CURRENCY, self.currentMoneyUnitText)
		self.repayButtonInfo.text = text
	end
end

function InGameMenuFinancesFrame:updateFinancesFooter(currentFinances, pastFinances)
	self:updateBalance()

	if Platform.gameplay.hasLoans then
		self:updateLoan()
	end

	self:updateDayTotals(currentFinances, pastFinances)
end

function InGameMenuFinancesFrame:updateBalance()
	local currentBalance = self.playerFarm:getBalance()
	local balanceMoneyText = self.l10n:formatMoney(currentBalance, 0, false)
	local balanceProfile = InGameMenuFinancesFrame.PROFILE.VALUE_CELL_NEUTRAL

	if math.floor(currentBalance) <= -1 then
		balanceProfile = InGameMenuFinancesFrame.PROFILE.VALUE_CELL_NEGATIVE
	end

	self.balanceText:applyProfile(balanceProfile, true)
	self.balanceText:setText(balanceMoneyText .. " " .. self.currentMoneyUnitText)
end

function InGameMenuFinancesFrame:updateDayTotals(currentFinances, pastFinances)
	for i = 1, InGameMenuFinancesFrame.PAST_PERIOD_COUNT + 1 do
		local dayFinances = currentFinances

		if i > 1 then
			local pastIndex = #pastFinances - (i - 2)
			dayFinances = pastFinances[pastIndex]
		end

		local dayTotalProfile = InGameMenuFinancesFrame.PROFILE.VALUE_CELL_NEUTRAL

		if dayFinances ~= nil then
			local dayTotal = 0

			for _, statName in pairs(dayFinances.statNames) do
				dayTotal = dayTotal + dayFinances[statName]
			end

			local totalMoneyText = self.l10n:formatMoney(dayTotal, 0, false)

			if math.floor(dayTotal) <= -1 then
				dayTotalProfile = InGameMenuFinancesFrame.PROFILE.VALUE_CELL_NEGATIVE
			end

			self.totalText[i]:setText(totalMoneyText .. " " .. self.currentMoneyUnitText)
		else
			self.totalText[i]:setText("")
		end

		self.totalText[i]:applyProfile(dayTotalProfile, true)
	end
end

function InGameMenuFinancesFrame:updateLoan()
	local currentLoan = self.playerFarm:getLoan()
	local loanMoneyText = self.l10n:formatMoney(-currentLoan, 0, false)
	local loanProfile = InGameMenuFinancesFrame.PROFILE.VALUE_CELL_NEUTRAL

	if currentLoan > 0 then
		loanProfile = InGameMenuFinancesFrame.PROFILE.VALUE_CELL_NEGATIVE
	end

	self.loanText:applyProfile(loanProfile, true)
	self.loanText:setText(loanMoneyText .. " " .. self.currentMoneyUnitText)
end

function InGameMenuFinancesFrame:hasPlayerLoanPermission()
	return g_currentMission:getHasPlayerPermission("farmManager")
end

function InGameMenuFinancesFrame:getMainElementSize()
	return self.mainBox.size
end

function InGameMenuFinancesFrame:getMainElementPosition()
	return self.mainBox.absPosition
end

function InGameMenuFinancesFrame:onButtonBorrow()
	if self:hasPlayerLoanPermission() then
		self.client:getServerConnection():sendEvent(ChangeLoanEvent.new(InGameMenuFinancesFrame.LOAN_STEP, self.playerFarm.farmId))
	end
end

function InGameMenuFinancesFrame:onButtonRepay()
	if self:hasPlayerLoanPermission() then
		self.client:getServerConnection():sendEvent(ChangeLoanEvent.new(-InGameMenuFinancesFrame.LOAN_STEP, self.playerFarm.farmId))
	end
end

function InGameMenuFinancesFrame:getNumberOfItemsInSection(list, section)
	return #FinanceStats.statNames
end

function InGameMenuFinancesFrame:populateCellForItemInSection(list, section, index, cell)
	local stats = self.playerFarm.stats
	local currentFinances = stats.finances
	local pastFinances = stats.financesHistory
	local statsName = FinanceStats.statNames[index]
	local statsNameText = FinanceStats.statNamesI18n[statsName]

	cell:getAttribute("name"):setText(statsNameText)
	self:setPastDayFinances(cell:getAttribute("todayMinusFour"), pastFinances, 4, statsName)
	self:setPastDayFinances(cell:getAttribute("todayMinusThree"), pastFinances, 3, statsName)
	self:setPastDayFinances(cell:getAttribute("todayMinusTwo"), pastFinances, 2, statsName)
	self:setPastDayFinances(cell:getAttribute("todayMinusOne"), pastFinances, 1, statsName)
	self:setPastDayFinances(cell:getAttribute("today"), currentFinances, 0, statsName)
end

function InGameMenuFinancesFrame:setPastDayFinances(cell, financesData, dayIndex, statsName)
	if InGameMenuFinancesFrame.PAST_PERIOD_COUNT < dayIndex then
		return
	end

	local value = "-"
	local profile = InGameMenuFinancesFrame.PROFILE.VALUE_CELL_NEUTRAL
	local financeData = financesData

	if dayIndex > 0 then
		local pastIndex = #financesData - (dayIndex - 1)
		financeData = financesData[pastIndex]
	end

	if financeData ~= nil then
		local moneyValue = financeData[statsName]
		local moneyText = self.l10n:formatMoney(moneyValue, 0, false)
		value = moneyText .. " " .. self.currentMoneyUnitText

		if math.floor(moneyValue) <= -1 then
			profile = InGameMenuFinancesFrame.PROFILE.VALUE_CELL_NEGATIVE
		end
	end

	cell:applyProfile(profile, true)
	cell:setText(value)
end

InGameMenuFinancesFrame.L10N_SYMBOL = {
	WEEK_DAY_TEMPLATE = "ui_financesDay",
	BUTTON_REPAY = "button_repay5000",
	BUTTON_BORROW = "button_borrow5000",
	CURRENCY = "$CURRENCY_SYMBOL"
}
InGameMenuFinancesFrame.PROFILE = {
	VALUE_CELL_NEGATIVE = "ingameMenuFinancesListItemDayNegative",
	VALUE_CELL_NEUTRAL = "ingameMenuFinancesListItemDay"
}
