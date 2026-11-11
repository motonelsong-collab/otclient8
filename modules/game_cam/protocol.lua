-- chunkname: @/modules/game_cam/protocol.lua

local TV_OPCODE = 125
local protocolGame = nil

local function onGameStart()
  protocolGame = g_game.getProtocolGame()
end

local function onGameEnd()
  protocolGame = nil
end

local function showCompatibilityInfo(message)
  displayInfoBox(tr('TV Cam'), message)
end

local function sendTvOpcode(message)
  if protocolGame then
    protocolGame:sendExtendedOpcode(TV_OPCODE, message)
  end
end

function sendNext()
  showCompatibilityInfo(tr('Channel switching with previous/next is not supported by the current TV Cam protocol.'))
end

function sendPrev()
  showCompatibilityInfo(tr('Channel switching with previous/next is not supported by the current TV Cam protocol.'))
end

function sendShowSpectators()
  showCompatibilityInfo(tr('The spectator list is handled by the TV panel adapted to the current server protocol.'))
end

function sendChangeName(name)
  showCompatibilityInfo(tr('Changing the channel name from the old camera panel is not supported in the current TV Cam protocol.'))
end

function sendWatchCam(channelId)
  if type(channelId) == 'string' and channelId ~= '' then
    sendTvOpcode('watch/' .. channelId)
    return
  end

  showCompatibilityInfo(tr('This legacy camera panel expects numeric channel ids, but the current TV Cam watches by player name. Use the updated TV list instead.'))
end

function initProtocol()
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })

  if g_game.isOnline() then
    onGameStart()
  end
end

function terminateProtocol()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd
  })

  protocolGame = nil
end