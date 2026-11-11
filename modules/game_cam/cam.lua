-- chunkname: @/modules/game_cam/cam.lua

PokemonCam = PokemonCam or {}

local protocol = runinsandbox('protocol')

function init()
  protocol.initProtocol()
  connect(g_game, {
    onGameEnd = onGameEnd
  })
end

function terminate()
  protocol.terminateProtocol()
  disconnect(g_game, {
    onGameEnd = onGameEnd
  })
end

function onGameEnd()
  hideCamWindow()
  hideListCam()
end

function hideCamWindow()
  if modules.game_tv and modules.game_tv.isPlayerWatchingTV and modules.game_tv.isPlayerWatchingTV() then
    modules.game_tv.sendActionChannel('!tvclose')
  end
end

function hideListCam()
  return
end