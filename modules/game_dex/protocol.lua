local PokemonPokedexOpcode = 115
local Actions = {
  View = 2,
  Data = 1,
  Open = 3,
  Update = 4,
  Loot = 5
}
local protocolGame

local function onGameStart()
  protocolGame = g_game.getProtocolGame()
end

local function onGameEnd()
  protocolGame = nil
end

local function sendAction(action, data)
  if protocolGame then
    protocolGame:sendExtendedJSONOpcode(PokemonPokedexOpcode, {
      action = action,
      data = data
    })
  end
end

local function parseData(params)
  signalcall(PokeDex.onData, params.UnlockedPokemons, params.CaughtPokemons, params.Entries, params.Details, {
    reset = params.Reset,
    batchIndex = params.BatchIndex,
    batchTotal = params.BatchTotal
  })
end

local function parseView(params)
  signalcall(PokeDex.onView, params)
end

local function parseOpen(params)
  signalcall(PokeDex.onOpen, params and params.Pokepedia)
end

local function parseUpdate(params)
  signalcall(PokeDex.onUpdate, params)
end

local function parseLoot(params)
  signalcall(PokeDex.onLoot, params.pokemonName, params.loots)
end

function sendViewPokemonLoot(pokemonName)
  sendAction(Actions.Loot, pokemonName)
end

function sendDataRequest()
  sendAction(Actions.Data, {})
end

function sendViewPokemonRequest(pokemonName, options)
  options = options or {}
  sendAction(Actions.View, {
    pokemonName = pokemonName,
    shinyPreview = options.shinyPreview and true or false
  })
end

function sendOpenPokedexRequest()
  sendAction(Actions.Open, {})
end

local ActionParser = {
  [Actions.Data] = parseData,
  [Actions.View] = parseView,
  [Actions.Open] = parseOpen,
  [Actions.Update] = parseUpdate,
  [Actions.Loot] = parseLoot
}

local function parseAction(protocol, opcode, jsonData)
  local parser = ActionParser[jsonData.action]
  if parser then
    parser(jsonData.data)
  end
end

function initProtocol()
  ProtocolGame.registerExtendedJSONOpcode(PokemonPokedexOpcode, parseAction)
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })

  if g_game.isOnline() then
    onGameStart()
  end
end

function terminateProtocol()
  ProtocolGame.unregisterExtendedJSONOpcode(PokemonPokedexOpcode)
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })
end

