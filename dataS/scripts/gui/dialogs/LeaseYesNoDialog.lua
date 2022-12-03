LeaseYesNoDialog = {
	CONTROLS = {
		"costsBaseValue",
		"costsPerDayValue",
		"costsPerOperatingHourValue"
	}
}
local LeaseYesNoDialog_mt = Class(LeaseYesNoDialog, YesNoDialog)

function LeaseYesNoDialog.new(target, custom_mt)
	local self = LeaseYesNoDialog:superClass().new(target, custom_mt or LeaseYesNoDialog_mt)

	self:registerControls(LeaseYesNoDialog.CONTROLS)

	return self
end

function LeaseYesNoDialog:setPrices(costsBase, initialCosts, costsPerOperatingHour, costsPerDay)
	self.costsBaseValue:setValue(costsBase)
	self.costsPerDayValue:setValue(costsPerDay)
	self.costsPerOperatingHourValue:setValue(costsPerOperatingHour)
	self.dialogTextElement:setText(string.format(g_i18n:getText("shop_doYouWantToLease"), g_i18n:formatMoney(initialCosts, 0, true, true)))
end
