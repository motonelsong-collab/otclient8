-- chunkname: @/modules/game_market/helpers.lua

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

local formatTime = formatTime or function(value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	local hours = math.floor(value / 3600)
	local minutes = math.floor((value % 3600) / 60)
	local seconds = value % 60

	if hours > 0 then
		return string.format('%02d:%02d:%02d', hours, minutes, seconds)
	end

	return string.format('%02d:%02d', minutes, seconds)
end
OffersProps = {
	idx = function(widget, value)
		widget:setText(value)
	end,
	name = function(widget, value)
		widget:setText(value)
	end,
	item = function(widget, value)
		widget:setItem(value)
	end,
	count = function(widget, value)
		widget:setText(value)
	end,
	price = function(widget, value)
		widget:setText(formatMoney(value))
	end,
	playerName = function(widget, value)
		widget:setText(value)
	end
}
SalesProps = {
	idx = function(widget, value)
		widget:setText(value)
	end,
	name = function(widget, value)
		widget:setText(value)
	end,
	item = function(widget, value)
		widget:setItem(value)
	end,
	count = function(widget, value)
		widget:setText(value)
	end,
	price = function(widget, value)
		widget:setText(formatMoney(value))
	end,
	created = function(widget, value)
		onTimer(widget, value)
	end
}
HistoricProps = {
	description = function(widget, value)
		widget:setText(value)
	end
}
ItemProps = {
	item = function(widget, value)
		widget:setItem(value)
	end,
	count = function(widget, value)
		widget:setRange(1, value)
	end
}

function addWidget(widget, data, propList)
	for key, fn in pairs(propList) do
		local child = widget.getChildById and widget:getChildById(key) or widget[key]

		if child then
			fn(child, data[key])
		end
	end
end

function onTimer(widget, timer)
	removeEvent(widget.event)
	widget:setText(timer > 0 and formatTime(timer) or "Expired")

	if timer > 0 then
		widget.event = scheduleEvent(function()
			onTimer(widget, timer - 1)
		end, 1000)
	end
end

