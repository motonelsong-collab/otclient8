-- chunkname: @/modules/game_pokebar/protocol.lua

local PokemonPokebarOpcode = 86
local Actions = {
	Add = 1,
	Remove = 2,
	Update = 3
}

local function parseAdd(pokemon)
	signalcall(PokeBar.onAddSlotBar, pokemon)
end

local function parseRemove(fastcallNumber)
	signalcall(PokeBar.onRemoveSlotBar, fastcallNumber)
end

local function parseUpdate(pokemon)
	signalcall(PokeBar.onUpdateSlotBar, pokemon)
end

local ActionParser = {
	[Actions.Add] = parseAdd,
	[Actions.Remove] = parseRemove,
	[Actions.Update] = parseUpdate
}

local function parseAction(protocol, opcode, jsonData)
	local parser = ActionParser[jsonData.action]

	if parser then
		parser(jsonData.data)
	end
end

function initProtocol()
	ProtocolGame.registerExtendedJSONOpcode(PokemonPokebarOpcode, parseAction)
end

function terminateProtocol()
	ProtocolGame.unregisterExtendedJSONOpcode(PokemonPokebarOpcode)
end
