-- chunkname: @/modules/game_cam/spectator.lua

Spectator = {}

function Spectator:new(params)
	local spectator = {
		channelId = params.channelId,
		name = params.name,
		start = params.start,
		views = params.views,
		pokemon = {}
	}

	for i, pokemon in pairs(params.pokemon or {}) do
		spectator.pokemon[pokemon.fastcallNumber] = pokemon
	end

	return setmetatable(spectator, {
		__index = self
	})
end

function Spectator:getStreamingChannelId()
	return self.channelId
end

function Spectator:getStreamingName()
	return self.name
end

function Spectator:hasStreamingTimer()
	return self.start ~= nil
end

function Spectator:getStreamingTimer()
	self.start = self.start + 1

	return formatTime(self.start)
end

function Spectator:getStreamingViews()
	return self.views
end

function Spectator:getStreamingPokemons()
	local pokemons = {}

	for i, pokemon in pairs(self.pokemon) do
		pokemons[i] = {
			image = getPokemonPortrait(pokemon.name),
			tooltip = pokemon.description
		}
	end

	return pokemons
end

function Spectator:setEventId(eventId)
	self.eventId = eventId
end

function Spectator:removeEventId()
	removeEvent(self.eventId)
end

function Spectator:update(params)
	if params.pokemon then
		if self.pokemon[params.pokemon] then
			self.pokemon[params.pokemon] = nil
		else
			self.pokemon[params.pokemon.fastcallNumber] = params.pokemon
		end

		return
	end

	for key, value in pairs(self) do
		if params[key] then
			self[key] = params[key]
		end
	end
end
