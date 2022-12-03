PalletShop = {
	MOD_DIRECTORY = g_currentModDirectory,
	CONTROLS = {
		"textElement",
		"palletIconElement",
		"itemsElement",
		"quantityElement",
		"basePriceText",
		"totalPriceText"
	}
}
local PalletShop_mt = Class(PalletShop, YesNoDialog)

function PalletShop.register()
	local palletShop = PalletShop.new()

	if g_gui ~= nil then
		local filename = Utils.getFilename("gui/PalletShop.xml", PalletShop.MOD_DIRECTORY)

		g_gui:loadGui(filename, "PalletShop", palletShop)
	end

	PalletShop.INSTANCE = palletShop
end

function PalletShop.show(callback, target, items, maxQuantity)
	if PalletShop.INSTANCE ~= nil then
		local dialog = PalletShop.INSTANCE

		dialog:setCallback(callback, target)
		dialog:setText(nil)
		dialog:setItems(items, maxQuantity)
		g_gui:showDialog("PalletShop")
	end
end

function PalletShop.new(target, custom_mt)
	local self = YesNoDialog.new(target, custom_mt or PalletShop_mt)
	self.selectedFillType = nil
	self.areButtonsDisabled = false
	self.lastSelectedFillType = nil

	self:registerControls(PalletShop.CONTROLS)

	return self
end

function PalletShop.createFromExistingGui(gui, guiName)
	PalletShop.register()

	local callback = gui.callbackFunc
	local target = gui.target
	local items = gui.items
	local maxQuantity = gui.maxQuantity

	PalletShop.show(callback, target, items, maxQuantity)
end

function PalletShop:onOpen()
	PalletShop:superClass().onOpen(self)
	FocusManager:setFocus(self.itemsElement)
end

function PalletShop:onClickOk()
	if self.areButtonsDisabled then
		return true
	else
		self:sendCallback(self.lastSelectedIndex, self.quantityElement:getState())

		return false
	end
end

function PalletShop:onClickBack(forceBack, usedMenuButton)
	self:sendCallback(nil, )

	return false
end

function PalletShop:sendCallback(index, quantity)
	if self.inputDelay < self.time then
		self:close()

		if self.callbackFunc ~= nil then
			if self.target ~= nil then
				self.callbackFunc(self.target, index, quantity, self.callbackArgs)
			else
				self.callbackFunc(index, quantity, self.callbackArgs)
			end
		end
	end
end

function PalletShop:onClickItems(state)
	self:setButtonDisabled(false)

	local item = self.items[state]
	self.lastSelectedIndex = state

	self.palletIconElement:setImageFilename(item.imageFilename)
	self:updatePrices()
end

function PalletShop:onClickQuantity()
	self:updatePrices()
end

function PalletShop:updatePrices()
	local item = self.items[self.lastSelectedIndex]
	local quantity = self.quantityElement:getState()
	local price = item.price
	local total = item.price * quantity

	self.basePriceText:setText(g_i18n:formatMoney(price, 0, true, false))
	self.totalPriceText:setText(g_i18n:formatMoney(total, 0, true, false))
end

function PalletShop:setItems(items, maxQuantity)
	self.items = items
	self.maxQuantity = maxQuantity
	self.itemsMapping = {}
	local selectedId = 1
	local itemTitles = {}

	for k, item in ipairs(items) do
		table.insert(itemTitles, item.title)

		if k == self.lastSelectedIndex then
			selectedId = k
		end
	end

	self.itemsElement:setTexts(itemTitles)
	self.itemsElement:setState(selectedId, true)

	local quantities = {}

	for i = 1, maxQuantity do
		table.insert(quantities, tostring(i) .. "x")
	end

	self.quantityElement:setTexts(quantities)
end

function PalletShop:setButtonDisabled(disabled)
	self.areButtonsDisabled = disabled

	self.yesButton:setDisabled(disabled)
end

PalletShop.register()
