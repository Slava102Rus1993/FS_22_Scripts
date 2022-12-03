IAPSimulator = {
	IS_LOADED = false,
	CURRENT_PURCHASE = nil,
	PRODUCTS = {},
	PENDING_PURCHASES = {}
}

function IAPSimulator.init()
	local oldKeyEvent = keyEvent

	function keyEvent(unicode, sym, modifier, isDown)
		if isDown then
			if sym == Input.KEY_1 then
				Logging.devInfo("IAPSimulator: Finishing IAP with FAILED...")
				IAPSimulator.handleNextPurchase(InAppPurchase.ERROR_FAILED)
			elseif sym == Input.KEY_2 then
				Logging.devInfo("IAPSimulator: Finishing IAP with CANCELLED...")
				IAPSimulator.handleNextPurchase(InAppPurchase.ERROR_CANCELLED)
			elseif sym == Input.KEY_3 then
				Logging.devInfo("IAPSimulator: Finishing IAP with IN PROGRESS...")
				IAPSimulator.handleNextPurchase(InAppPurchase.ERROR_PURCHASE_IN_PROGRESS)
			elseif sym == Input.KEY_4 then
				Logging.devInfo("IAPSimulator: Finishing IAP with OK...")
				IAPSimulator.handleNextPurchase(InAppPurchase.ERROR_OK)
			elseif sym == Input.KEY_5 then
				Logging.devInfo("IAPSimulator: Finishing IAP with NETWORK_UNAVAILABLE...")
				IAPSimulator.handleNextPurchase(InAppPurchase.ERROR_NETWORK_UNAVAILABLE)
			elseif sym == Input.KEY_6 then
				Logging.devInfo("IAPSimulator: Adding pending IAP...")
				IAPSimulator.addPendingPurchase()
			end
		end

		oldKeyEvent(unicode, sym, modifier, isDown)
	end

	function inAppInit(xmlFileName)
		local xmlFile = loadXMLFile("IAPProducts", xmlFileName)

		if xmlFile ~= 0 then
			local i = 0

			while true do
				local key = string.format("inAppPurchases.inAppPurchase(%d)", i)

				if not hasXMLProperty(xmlFile, key) then
					break
				end

				local productId = getXMLInt(xmlFile, key .. "#productId")

				if productId ~= nil then
					local coins = getXMLInt(xmlFile, key .. "#coins")
					local imageFilename = getXMLString(xmlFile, key .. "#imageFilename")
					local product = {
						productId = productId,
						coins = coins,
						imageFilename = imageFilename
					}
					IAPSimulator.PRODUCTS[productId] = product
				end

				i = i + 1
			end

			delete(xmlFile)
		end

		IAPSimulator.IS_LOADED = true
	end

	function inAppIsLoaded()
		return IAPSimulator.IS_LOADED
	end

	function inAppGetProductPrice(productId)
		local product = IAPSimulator.PRODUCTS[productId]

		if product ~= nil then
			return "$ " .. productId .. ".00"
		end

		return nil
	end

	function inAppGetProductDescription(productId)
		local product = IAPSimulator.PRODUCTS[productId]

		if product ~= nil then
			return "Product description " .. productId
		end

		return nil
	end

	function inAppStartPurchase(productId, callbackName, target)
		if IAPSimulator.CURRENT_PURCHASE ~= nil then
			target[callbackName](target, InAppPurchase.ERROR_PURCHASE_IN_PROGRESS, productId)

			return
		end

		IAPSimulator.CURRENT_PURCHASE = {
			productId = productId,
			target = target,
			callbackName = callbackName
		}
	end

	function inAppFinishPurchase(productId)
		IAPSimulator.CURRENT_PURCHASE = nil
	end

	function inAppGetNumPendingPurchases()
		return #IAPSimulator.PENDING_PURCHASES
	end

	function inAppGetPendingPurchaseProductId(pendingIndex)
		return IAPSimulator.PENDING_PURCHASES[pendingIndex + 1].productId
	end

	function inAppFinishPendingPurchase(pendingIndex)
		table.remove(IAPSimulator.PENDING_PURCHASES, pendingIndex + 1)
	end

	print([[


  ##################   Warning: IAP Simulator active!   ##################

]])
end

function IAPSimulator.handleNextPurchase(err)
	local purchase = IAPSimulator.CURRENT_PURCHASE

	if purchase == nil then
		Logging.devInfo("IAPSimulator: No purchase active!")

		return
	end

	local target = purchase.target
	local callbackName = purchase.callbackName
	local productId = purchase.productId
	IAPSimulator.CURRENT_PURCHASE = nil

	target[callbackName](target, err, productId)
end

function IAPSimulator.addPendingPurchase()
	local purchase = {
		productId = math.random(1, #IAPSimulator.PRODUCTS) - 1
	}

	table.insert(IAPSimulator.PENDING_PURCHASES, purchase)
end
