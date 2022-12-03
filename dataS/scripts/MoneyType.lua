MoneyType = {}
local moneyTypeId = 0
local moneyTypeIdToType = {}

function MoneyType.register(statistic, title, customEnv)
	moneyTypeId = moneyTypeId + 1
	local value = {
		id = moneyTypeId,
		statistic = statistic,
		title = title,
		customEnv = customEnv
	}
	moneyTypeIdToType[moneyTypeId] = value

	return value
end

function MoneyType.registerWithId(id, statistic, title, customEnv)
	local moneyType = moneyTypeIdToType[id]

	if moneyType == nil then
		moneyType = {
			id = id,
			statistic = statistic,
			title = title,
			customEnv = customEnv
		}
		moneyTypeIdToType[id] = moneyType
	end

	moneyTypeId = math.max(moneyTypeId, id)

	return moneyType
end

function MoneyType.getMoneyTypeById(id)
	return moneyTypeIdToType[id]
end

function MoneyType.getMoneyTypeByName(name)
	if name ~= nil then
		name = string.upper(name)

		return MoneyType[name]
	end

	return nil
end

function MoneyType.reset()
	moneyTypeId = MoneyType.LAST_ID
end

MoneyType.OTHER = MoneyType.register("other", "finance_other")
MoneyType.SHOP_VEHICLE_BUY = MoneyType.register("newVehiclesCost", "finance_newVehiclesCost")
MoneyType.SHOP_VEHICLE_SELL = MoneyType.register("soldVehicles", "finance_soldVehicles")
MoneyType.SHOP_PROPERTY_BUY = MoneyType.register("constructionCost", "finance_constructionCost")
MoneyType.SHOP_PROPERTY_SELL = MoneyType.register("soldBuildings", "finance_soldBuildings")
MoneyType.SOLD_MILK = MoneyType.register("soldMilk", "finance_soldMilk")
MoneyType.HARVEST_INCOME = MoneyType.register("harvestIncome", "finance_harvestIncome")
MoneyType.AI = MoneyType.register("wagePayment", "finance_wagePayment")
MoneyType.MISSIONS = MoneyType.register("missionIncome", "finance_missionIncome")
MoneyType.SOLD_ANIMALS = MoneyType.register("soldAnimals", "finance_soldAnimals")
MoneyType.NEW_ANIMALS_COST = MoneyType.register("newAnimalsCost", "finance_newAnimalsCost")
MoneyType.ANIMAL_UPKEEP = MoneyType.register("animalUpkeep", "finance_animalUpkeep")
MoneyType.PURCHASE_SEEDS = MoneyType.register("purchaseSeeds", "finance_purchaseSeeds")
MoneyType.PURCHASE_FERTILIZER = MoneyType.register("purchaseFertilizer", "finance_purchaseFertilizer")
MoneyType.PURCHASE_FUEL = MoneyType.register("purchaseFuel", "finance_purchaseFuel")
MoneyType.PURCHASE_SAPLINGS = MoneyType.register("purchaseSaplings", "finance_purchaseSaplings")
MoneyType.PURCHASE_WATER = MoneyType.register("purchaseWater", "finance_purchaseWater")
MoneyType.PURCHASE_BALES = MoneyType.register("purchaseBales", "finance_purchaseBales")
MoneyType.PURCHASE_PALLETS = MoneyType.register("purchasePallets", "finance_purchasePallets")
MoneyType.FIELD_BUY = MoneyType.register("fieldPurchase", "finance_fieldPurchase")
MoneyType.FIELD_SELL = MoneyType.register("fieldSelling", "finance_fieldSelling")
MoneyType.LEASING_COSTS = MoneyType.register("vehicleLeasingCost", "finance_vehicleLeasingCost")
MoneyType.LOAN_INTEREST = MoneyType.register("loanInterest", "finance_loanInterest")
MoneyType.VEHICLE_RUNNING_COSTS = MoneyType.register("vehicleRunningCost", "finance_vehicleRunningCost")
MoneyType.VEHICLE_REPAIR = MoneyType.register("vehicleRunningCost", "finance_vehicleRunningCost")
MoneyType.PROPERTY_MAINTENANCE = MoneyType.register("propertyMaintenance", "finance_propertyMaintenance")
MoneyType.PROPERTY_INCOME = MoneyType.register("propertyIncome", "finance_propertyIncome")
MoneyType.LOAN = MoneyType.register("loan", "finance_other")
MoneyType.PRODUCTION_COSTS = MoneyType.register("productionCosts", "finance_productionCosts")
MoneyType.SOLD_PRODUCTS = MoneyType.register("soldProducts", "finance_soldProducts")
MoneyType.INCOME_BGA = MoneyType.register("incomeBga", "finance_incomeBga")
MoneyType.SOLD_WOOD = MoneyType.register("soldWood", "finance_soldWood")
MoneyType.SOLD_BALES = MoneyType.register("soldBales", "finance_soldBales")
MoneyType.BOUGHT_MATERIALS = MoneyType.register("expenses", "finance_other")
MoneyType.TRANSFER = MoneyType.register("other", "finance_transfer")
MoneyType.COLLECTIBLE = MoneyType.register("other", "finance_collectible")
MoneyType.LAST_ID = moneyTypeId
