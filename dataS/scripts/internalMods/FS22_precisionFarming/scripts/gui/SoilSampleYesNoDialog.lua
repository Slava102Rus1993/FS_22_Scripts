SoilSampleYesNoDialog = {
	MOD_NAME = g_currentModName,
	CONTROLS = {
		"numSamples",
		"sampleCosts",
		"serviceCosts",
		"dialogHeader",
		"dialogTextElement"
	}
}
local SoilSampleYesNoDialog_mt = Class(SoilSampleYesNoDialog, YesNoDialog)

function SoilSampleYesNoDialog.new(target, custom_mt)
	local self = SoilSampleYesNoDialog:superClass().new(target, custom_mt or SoilSampleYesNoDialog_mt)

	self:registerControls(SoilSampleYesNoDialog.CONTROLS)

	return self
end

function SoilSampleYesNoDialog:setData(fieldNumber, fieldSize, numSamples, sampleCost, serviceCost)
	self.numSamples:setValue(numSamples)
	self.sampleCosts:setValue(sampleCost)
	self.serviceCosts:setValue(serviceCost)

	local totalPrice = sampleCost + serviceCost

	self.dialogHeader:setText(string.format(g_i18n:getText("ui_economicAnalysisHeaderField", SoilSampleYesNoDialog.MOD_NAME), fieldNumber, fieldSize))
	self.dialogTextElement:setText(string.format(g_i18n:getText("ui_soilSampleDialogQuestion", SoilSampleYesNoDialog.MOD_NAME), g_i18n:formatMoney(totalPrice, 0, true, true)))
end
