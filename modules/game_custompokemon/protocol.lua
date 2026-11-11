local PokemonCustomOpcode = 120
local Actions = {
  Request = 1,
  Addons = 2,
  Shaders = 3,
  Capsules = 4,
  Paintings = 5,
  Nickname = 6
}

local protocolGame

local function onGameStart()
  protocolGame = g_game.getProtocolGame()
end

local function onGameEnd()
  protocolGame = nil
end

local function sendAction(action, data)
  if not protocolGame then
    return
  end

  protocolGame:sendExtendedJSONOpcode(PokemonCustomOpcode, {
    action = action,
    data = data
  })
end

function sendOpen()
  sendAction(Actions.Request, true)
end

function sendChooseAddon(addonId)
  sendAction(Actions.Addons, addonId)
end

function sendChooseShader(shaderId)
  sendAction(Actions.Shaders, shaderId)
end

function sendChooseCapsule(capsuleId)
  sendAction(Actions.Capsules, capsuleId)
end

function sendChoosePainting(paintingId)
  sendAction(Actions.Paintings, paintingId)
end

function sendUpdateNickname(nickname)
  sendAction(Actions.Nickname, nickname)
end

local ResponseParsers = {
  [Actions.Request] = function(data)
    signalcall(PokemonCustom.onOpenData, data or {})
  end
}

local function parseAction(protocol, opcode, jsonData)
  if type(jsonData) ~= 'table' then
    return
  end

  local parser = ResponseParsers[tonumber(jsonData.action)]
  if parser then
    parser(jsonData.data)
  end
end

function initProtocol()
  ProtocolGame.registerExtendedJSONOpcode(PokemonCustomOpcode, parseAction)
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })

  if g_game.isOnline() then
    onGameStart()
  end
end

function terminateProtocol()
  ProtocolGame.unregisterExtendedJSONOpcode(PokemonCustomOpcode)
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })
end