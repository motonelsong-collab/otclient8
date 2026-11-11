-- chunkname: @/modules/game_market/marketprotocol.lua

local protocol
local MarketOpcode = 88

local MarketParse = {
	Open = 1,
	Offers = 2,
	Sales = 3,
	Historic = 4,
	Item = 5,
	Message = 6
}

local MarketRequest = {
	Offers = 1,
	Sales = 2,
	Historic = 3,
	Item = 4,
	CreateOffer = 5,
	AcceptOffer = 6,
	CancelOffer = 7
}
local function sendAction(action, data)
	if protocol then
		protocol:sendExtendedJSONOpcode(MarketOpcode, {
			action = action,
			data = data
		})
	end
end

local function parseOpen()
	signalcall(Market.onMarketOpen)
end

local function parseOffers(data)
	local offersList = {}

	for i, offer in pairs(data.data) do
		local tmpItem = Item.create(offer.clientId, offer.count)

		tmpItem:setTooltip(offer.description)

		offer.idx = i
		offer.item = tmpItem
		offersList[#offersList + 1] = offer
	end

	signalcall(Market.onMarketOffers, offersList, data.page, data.pageSize, data.search, data.sortType, data.sortField, data.categoryId)
end

local function parseSales(offers)
	local offersSale = {}

	for i, sale in pairs(offers) do
		local tmpItem = Item.create(sale.clientId, sale.count)

		tmpItem:setTooltip(sale.description)

		sale.idx = i
		sale.item = tmpItem
		offersSale[#offersSale + 1] = sale
	end

	signalcall(Market.onMarketSales, offersSale)
end

local function parseHistoric(historic)
	signalcall(Market.onMarketHistoric, historic)
end

local function parseItem(item)
	local tmpItem = Item.create(item.clientId, item.count)

	tmpItem:setTooltip(item.description)

	item.item = tmpItem

	signalcall(Market.onMarketRequestItem, item)
end

local function parseMessage(message)
	signalcall(Market.onMarketMessage, message)
end

local parseMarketOpcodes = {
	[MarketParse.Open] = parseOpen,
	[MarketParse.Offers] = parseOffers,
	[MarketParse.Sales] = parseSales,
	[MarketParse.Historic] = parseHistoric,
	[MarketParse.Item] = parseItem,
	[MarketParse.Message] = parseMessage
}

local function parseMarket(protocol, opcode, json_data)
	local executeAction = parseMarketOpcodes[json_data.action]

	if executeAction then
		executeAction(json_data.data)
	end
end

function initProtocol()
	connect(g_game, {
		onGameStart = registerProtocol,
		onGameEnd = unregisterProtocol
	})

	if g_game.isOnline() then
		registerProtocol()
	end
end

function terminateProtocol()
	disconnect(g_game, {
		onGameStart = registerProtocol,
		onGameEnd = unregisterProtocol
	})
end

function updateProtocol(_protocol)
	protocol = _protocol
end

function registerProtocol()
	ProtocolGame.registerExtendedJSONOpcode(MarketOpcode, parseMarket)
	updateProtocol(g_game.getProtocolGame())
end

function unregisterProtocol()
	ProtocolGame.unregisterExtendedJSONOpcode(MarketOpcode)
	updateProtocol(nil)
end

function sendCancelOffer(offer)
	local data = {
		offerId = offer.id
	}

	sendAction(MarketRequest.CancelOffer, data)
end

function sendAcceptOffer(offer, count, settings)
	local data = {
		offerId = offer.id,
		count = count,
		settings = settings
	}

	sendAction(MarketRequest.AcceptOffer, data)
end

local function buildItemRequestData(selection)
	local item = selection and selection.item or selection
	if not item then
		return nil
	end

	local position = selection and selection.position or item:getPosition() or { x = 65535, y = 0, z = 0 }
	local stackpos = selection and selection.stackpos
	if stackpos == nil and position then
		stackpos = position.stackpos
	end
	if stackpos == nil then
		stackpos = item:getStackPos()
	end

	return {
		spriteId = item:getId(),
		position = position,
		stackpos = stackpos
	}
end

function sendCreateOffer(item, count, price, expire)
	local data = buildItemRequestData(item)
	if not data then
		return
	end

	data.count = count
	data.price = price
	data.expire = expire

	sendAction(MarketRequest.CreateOffer, data)
end

function sendRequestItem(item)
	local data = buildItemRequestData(item)
	if not data then
		return
	end

	sendAction(MarketRequest.Item, data)
end

function sendRefreshOffers(data)
	sendAction(MarketRequest.Offers, data)
end

function sendRefreshSales()
	local data = {}

	sendAction(MarketRequest.Sales, data)
end

function sendRefreshHistoric()
	local data = {}

	sendAction(MarketRequest.Historic, data)
end
