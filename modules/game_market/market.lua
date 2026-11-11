-- chunkname: @/modules/game_market/market.lua

Market = {}

local MarketSortType = {
	Asc = 1,
	Desc = 2
}

local MarketCategory = {
	All = 0,
	Items = 1,
	Stones = 2,
	Pokeballs = 3,
	Coins = 4,
	Addons = 5,
	Outfits = 6,
	Pokemon = 7,
	Cards = 8,
	Helds = 9,
	Furnitures = 10,
	Supplies = 11
}

local MarketCategoryStrings = {
	[0] = "All",
	"Items",
	"Stones",
	"Pokeballs",
	"Coins",
	"Addons",
	"Outfits",
	"Pokemon",
	"Cards",
	"Helds",
	"Furnitures",
	"Supplies"
}
local protocol = runinsandbox("marketprotocol")
local marketWindow, acceptWindow, sellWindow, messageWindow, mainTabBar, categoryList, pagePanel, pageFirstButton, pagePrevButton, pageNextButton, pageLastButton, pageLabel, searchText, headerOffer, offerList, sellList, historicList, dragArea, selectedItem
local currentPage = 1
local maxPage = 1
local currentOfferIndex = 1

local formatMoney = formatMoney or function(value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	local formatted = tostring(value)

	while true do
		local replaced, count = formatted:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end

	return formatted
end

function refreshOffers(page)
	local sortButton = headerOffer:getFocusedChild()
	local data = {
		page = page or currentPage,
		search = searchText:getText(),
		sortField = sortButton:getId(),
		sortType = sortButton:isOn() and MarketSortType.Desc or MarketSortType.Asc,
		categoryId = categoryList:getCurrentOption().data
	}

	currentOfferIndex = 1

	sendRefreshOffers(data)
end

local function showMarket()
	marketWindow:show()
end

local function hideMarket()
	currentOfferIndex = 1

	marketWindow:hide()
end

local function getChild(widget, childId)
	if not widget then
		return nil
	end

	if widget.recursiveGetChildById then
		local child = widget:recursiveGetChildById(childId)

		if child then
			return child
		end
	end

	if widget.getChildById then
		local child = widget:getChildById(childId)

		if child then
			return child
		end
	end

	return widget[childId]
end

local function findItemSelectionFromWidget(widget)
	while widget do
		if widget.getItem then
			local item = widget:getItem()
			if item then
				local position = widget.position or item:getPosition()
				local stackpos = position and position.stackpos or item:getStackPos()
				return {
					item = item,
					position = position,
					stackpos = stackpos
				}
			end
		end

		widget = widget.getParent and widget:getParent() or nil
	end

	return nil
end

local function destroyAcceptWindow()
	if acceptWindow then
		acceptWindow:destroy()

		acceptWindow = nil
	end
end

local function destroySellWindow()
	if sellWindow then
		sellWindow:destroy()

		sellWindow = nil
	end
end

local function destroyMessageWindow()
	if messageWindow then
		messageWindow:destroy()

		messageWindow = nil
	end
end

local function clearEvents()
	for i, child in pairs(sellList:getChildren()) do
		local createdLabel = getChild(child, "created")

		if createdLabel and createdLabel.event then
			removeEvent(createdLabel.event)
		end
	end
end

local function clearAllList()
	offerList:destroyChildren()
	sellList:destroyChildren()
	historicList:destroyChildren()
end

local function refreshSell()
	sendRefreshSales()
end

local function refreshHistory()
	sendRefreshHistoric()
end

local function setupConfiguration(page, pageSize)
	currentPage = page
	maxPage = pageSize
end

local function updatePaginationControls()
	local isEnabledLeftButtons = currentPage > 1

	pageFirstButton:setEnabled(isEnabledLeftButtons)
	pagePrevButton:setEnabled(isEnabledLeftButtons)

	local isEnabledRightButtons = currentPage < maxPage

	pageNextButton:setEnabled(isEnabledRightButtons)
	pageLastButton:setEnabled(isEnabledRightButtons)
	pageLabel:setText(("%s de %s"):format(("%02d"):format(currentPage), ("%02d"):format(maxPage)))
end

local function initInterface()
	mainTabBar = getChild(marketWindow, "mainTabBar") or rootWidget:recursiveGetChildById("mainTabBar")
	local mainTabContent = getChild(marketWindow, "mainTabContent") or rootWidget:recursiveGetChildById("mainTabContent")

	marketWindow = getChild(marketWindow, "marketWindow") or rootWidget:recursiveGetChildById("marketWindow") or marketWindow
	dragArea = getChild(marketWindow, "dragArea") or rootWidget:recursiveGetChildById("dragArea")

	mainTabBar:setContentWidget(mainTabContent)

	local offersPanel = g_ui.loadUI("ui/offersPanel")
	local buyTab = mainTabBar:addTab(tr("Buy"), offersPanel, "/images/game/market/icon_buy")

	local sellPanel = g_ui.loadUI("ui/sellPanel")
	local sellTab = mainTabBar:addTab(tr("Sell"), sellPanel, "/images/game/market/icon_sell")

	local historicPanel = g_ui.loadUI("ui/historicPanel")
	local historicTab = mainTabBar:addTab(tr("Historic"), historicPanel)

	for _, tab in ipairs({ buyTab, sellTab, historicTab }) do
		if tab then
			tab:setWidth(150)
		end
	end

	pagePanel = getChild(offersPanel, "pagePanel")
	pageFirstButton = getChild(pagePanel, "firstButton")
	pagePrevButton = getChild(pagePanel, "prevButton")
	pageNextButton = getChild(pagePanel, "nextButton")
	pageLastButton = getChild(pagePanel, "lastButton")
	pageLabel = getChild(pagePanel, "page")
	searchText = getChild(offersPanel, "searchText")
	categoryList = getChild(offersPanel, "categoryList")
	headerOffer = getChild(offersPanel, "headerOffer")
	offerList = getChild(offersPanel, "offerList")
	sellList = getChild(sellPanel, "sellList")
	historicList = getChild(historicPanel, "historicList")
	dragArea = getChild(marketWindow, "dragArea")

	if not mainTabBar or not mainTabContent or not pagePanel or not pageFirstButton or not pagePrevButton or not pageNextButton or not pageLastButton or not pageLabel or not searchText or not categoryList or not headerOffer or not offerList or not sellList or not historicList then
		return
	end

	local refresh = {
		offersPanel = refreshOffers,
		sellPanel = refreshSell,
		historicPanel = refreshHistory
	}

	function mainTabBar.onTabChange(widget, tab)
		if marketWindow:isVisible() then
			refresh[tab.tabPanel:getId()]()
		end
	end

	for i = 0, #MarketCategoryStrings do
		categoryList:addOption(tr(MarketCategoryStrings[i]), i)
	end
end

function Market.onMarketOpen()
	mainTabBar:selectTab(mainTabBar:getTab(tr("Buy")))
	headerOffer:focusChild(headerOffer:getFirstChild())
	showMarket()
	refreshOffers(1)
end

function Market.onMarketOffers(data, page, pageSize, search, sortType, sortField, categoryId)
	offerList:destroyChildren()

	for i, offer in pairs(data) do
		local widget = g_ui.createWidget("MarketOffer", offerList)

		widget:setId(i)

		widget.offer = offer

		addWidget(widget, offer, OffersProps)
	end

	local selectedOffer = offerList:getChildByIndex(currentOfferIndex)

	if selectedOffer then
		offerList:focusChild(selectedOffer)
	end

	setupConfiguration(page, pageSize)
	updatePaginationControls()
end

function Market.onMarketSales(data)
	clearEvents()
	sellList:destroyChildren()

	for i, sale in pairs(data) do
		local widget = g_ui.createWidget("MarketSale", sellList)

		widget.sale = sale

		addWidget(widget, sale, SalesProps)
	end

	local verticalScrollBar = sellList.getVerticalScrollBar and sellList:getVerticalScrollBar() or nil

	if verticalScrollBar then
		verticalScrollBar:setVisible(#data > 9)
	end
end

function Market.onMarketHistoric(data)
	historicList:destroyChildren()

	for i, historic in pairs(data) do
		local widget = g_ui.createWidget("MarketHistoric", historicList)

		addWidget(widget, historic, HistoricProps)
	end
end

function Market.onMarketMessage(message)
	destroyMessageWindow()

	local function defaultCallback()
		messageWindow:ok()
		showMarket()
	end

	messageWindow = displayGeneralBox(marketWindow:getText(), message, {
		{
			text = "Ok",
			color = "Blue",
			callback = defaultCallback
		}
	}, defaultCallback, defaultCallback)

	messageWindow:show()
	messageWindow:raise()
	messageWindow:focus()
end

function Market.onMarketRequestItem(item)
	if selectedItem == nil then
		return
	end

	destroySellWindow()

	sellWindow = g_ui.createWidget("MarketSellWindow", rootWidget)

	if sellWindow.onVisibilityChange then
		sellWindow:onVisibilityChange(true)
	end

	sellWindow:show()
	sellWindow:raise()
	sellWindow:focus()

	local scrollBar = getChild(sellWindow, "count")
	local expire = getChild(sellWindow, "expire")
	local spinBox = getChild(sellWindow, "price")
	local cancelButton = getChild(sellWindow, "cancel")
	local confirmButton = getChild(sellWindow, "confirm")
	local feeLabel = getChild(sellWindow, "fee")
	local itemWidget = getChild(sellWindow, "item")
	local totalPriceLabel = getChild(sellWindow, "totalPrice")
	local priceUnitLabel = getChild(sellWindow, "priceUnit")
	local expectedProfitLabel = getChild(sellWindow, "expectedProfit")

	local function cancelFunc()
		destroySellWindow()
		showMarket()
	end


	local function confirmFunc()
		sendCreateOffer(selectedItem, scrollBar:getValue(), spinBox:getValue(), expire:getCurrentOption().data)
		cancelFunc()
	end

	confirmButton.onClick = confirmFunc
	cancelButton.onClick = cancelFunc

	local function onValueChange(widget, value)
		local totalPrice = scrollBar:getValue() * spinBox:getValue()
		local fee = item.fee > 0 and math.min(item.maxFee, math.max(1, totalPrice * item.fee)) or 0

		feeLabel:setText(formatMoney(fee))
		itemWidget:setItemCount(scrollBar:getValue())
		totalPriceLabel:setText(formatMoney(totalPrice))
		priceUnitLabel:setText(formatMoney(spinBox:getValue()))
		expectedProfitLabel:setText(formatMoney(totalPrice - fee))
	end

	spinBox.onValueChange = onValueChange
	scrollBar.onValueChange = onValueChange

	addWidget(sellWindow, item, ItemProps)
end

function init()
	g_ui.importStyle("ui/sellWindow")
	protocol.initProtocol()
	connect(g_game, {
		onGameStart = onGameEnd,
		onGameEnd = onGameEnd
	})
	connect(LocalPlayer, {
		onPositionChange = onMarketPositionChange
	})

	marketWindow = g_ui.loadUI("market", rootWidget)

	if not marketWindow then
		return
	end

	marketWindow = getChild(marketWindow, "marketWindow") or rootWidget:recursiveGetChildById("marketWindow") or marketWindow

	initInterface()
end

function terminate()
	protocol.terminateProtocol()
	disconnect(g_game, {
		onGameStart = onGameEnd,
		onGameEnd = onGameEnd
	})
	disconnect(LocalPlayer, {
		onPositionChange = onMarketPositionChange
	})
	onGameEnd()
	if marketWindow then
		marketWindow:destroy()
		marketWindow = nil
	end

	Market = nil
end
function onGameEnd()
	if not marketWindow or not categoryList or not searchText or not offerList or not sellList or not historicList then
		selectedItem = nil
		currentPage = 1
		maxPage = 1
		destroySellWindow()
		destroyAcceptWindow()
		destroyMessageWindow()
		return
	end

	categoryList:setCurrentOptionByData(MarketCategory.All, true)
	searchText:clearText()

	selectedItem = nil
	currentPage = 1
	maxPage = 1

	hideMarket()
	clearEvents()
	clearAllList()
	destroySellWindow()
	destroyAcceptWindow()
	destroyMessageWindow()
end
function onMarketPositionChange()
	if marketWindow and marketWindow:isVisible() then
		onGameEnd()
	end
end
function updatePagination(widget)
	local pageButtonsValue = {
		firstButton = 1,
		prevButton = math.max(1, currentPage - 1),
		nextButton = math.min(maxPage, currentPage + 1),
		lastButton = maxPage
	}

	currentPage = pageButtonsValue[widget:getId()]

	refreshOffers()
end

function openAcceptWindow()
	local selectedOffer = offerList:getFocusedChild()

	if not selectedOffer then
		return
	end

	destroyAcceptWindow()
	hideMarket()

	acceptWindow = g_ui.createWidget("CountWindow", rootWidget)

	acceptWindow:setText(tr("Buy"))
	if acceptWindow.onVisibilityChange then
		acceptWindow:onVisibilityChange(true)
	end

	acceptWindow:show()
	acceptWindow:raise()
	acceptWindow:focus()

	local offer = selectedOffer.offer
	local extraLabel = getChild(acceptWindow, "extraLabel")

	if extraLabel then
		extraLabel:show()
	end

	local itemBox = getChild(acceptWindow, "item")

	itemBox:setItem(offer.item)

	local scrollBar = getChild(acceptWindow, "countScrollBar")

	function scrollBar.onValueChange(widget, value)
		if extraLabel then
			extraLabel:setText(tr("Total price") .. ": " .. formatMoney(value * offer.price))
		end
		itemBox:setItemCount(value)
	end

	scrollBar:setRange(1, offer.count)
	scrollBar:setValue(1)

	local cancelButton = getChild(acceptWindow, "buttonCancel")

	local function cancelFunc()
		destroyAcceptWindow()
		showMarket()
	end

	local okButton = getChild(acceptWindow, "buttonOk")

	local function okFunc()
		local sortButton = headerOffer:getFocusedChild()
		local settings = {
			page = currentPage,
			search = searchText:getText(),
			sortField = sortButton:getId(),
			sortType = sortButton:isOn() and MarketSortType.Desc or MarketSortType.Asc,
			categoryId = categoryList:getCurrentOption().data
		}

		currentOfferIndex = tonumber(selectedOffer:getId())

		sendAcceptOffer(offer, scrollBar:getValue(), settings)
		cancelFunc()
	end

	acceptWindow.onEnter = okFunc
	acceptWindow.onEscape = cancelFunc
	okButton.onClick = okFunc
	cancelButton.onClick = cancelFunc
end

function startChooseSellItem()
	local interface = modules.game_interface
	local mouseGrabberWidget = interface.mouseGrabberWidget

	mouseGrabberWidget:grabMouse()
	g_mouse.pushCursor("target")
	hideMarket()

	function mouseGrabberWidget:onMouseRelease(mousePosition, mouseButton)
		if mouseButton == MouseLeftButton then
			local widget = interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
			local selection = findItemSelectionFromWidget(widget)

			if selection then
				selectedItem = selection
				sendRequestItem(selectedItem)
			else
				showMarket()
			end
		end

		while g_mouse.isCursorChanged() do
			g_mouse.popCursor("target")
		end

		self:ungrabMouse()

		mouseGrabberWidget.onMouseRelease = nil
		mouseGrabberWidget.onMouseRelease = interface.onMouseGrabberRelease
	end
end

function onDraggingItem(item, mousePos, dragType)	if not marketWindow or not marketWindow:isVisible() then
		return
	end

	if dragType == "enter" then
		if dragArea then
			dragArea:show()
		end
	elseif dragType == "leave" then
		local child = rootWidget:recursiveGetChildByPos(mousePos)

		if dragArea and child and child == dragArea then
			hideMarket()

			selectedItem = item

			sendRequestItem(item)
		end

		if dragArea then
			dragArea:hide()
		end
	end
end


