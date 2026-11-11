-- chunkname: @/modules/game_cam/streaming.lua

Streaming = {}

function Streaming:new(params)
	local streaming = {
		channelId = params.channelId,
		name = params.name,
		start = params.start,
		views = params.views
	}

	return setmetatable(streaming, {
		__index = self
	})
end

function Streaming:getChannelId()
	return self.channelId
end

function Streaming:getName()
	return self.name
end

function Streaming:getTimer()
	self.start = self.start + 1

	return formatTime(self.start)
end

function Streaming:getViews()
	return self.views
end

function Streaming:setName(name)
	self.name = name
end

function Streaming:setEventId(eventId)
	self.eventId = eventId
end

function Streaming:removeEventId()
	removeEvent(self.eventId)
end

function Streaming:update(params)
	for key, value in pairs(self) do
		if params[key] then
			self[key] = params[key]
		end
	end
end
