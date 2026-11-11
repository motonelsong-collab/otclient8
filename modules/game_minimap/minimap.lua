minimapWidget = nil
minimapWindow = nil
minimapPanel = nil
minimapContent = nil
fullMapOverlay = nil
pingLabel = nil
posLabel = nil
toggleChaseModeBtn = nil
otmm = true
preloaded = false
fullmapView = false
oldZoom = nil
oldPos = nil
minimapWindowWasVisible = true

local function setMinimapWindowVisible(visible)
  if not minimapWindow then
    return
  end

  if visible then
    minimapWindow:show()
  else
    minimapWindow:hide()
  end
end

function init()
  local gameRootPanel = modules.game_interface.getRootPanel()

  minimapWindow = g_ui.loadUI('minimap', gameRootPanel)
  minimapPanel = minimapWindow:recursiveGetChildById('minimapPanel')
  minimapContent = minimapPanel:recursiveGetChildById('minimapContents')
  minimapWidget = minimapPanel:recursiveGetChildById('minimap')
  pingLabel = minimapWindow:recursiveGetChildById('pingLabel')
  posLabel = minimapWindow:recursiveGetChildById('posLabel')

  fullMapOverlay = g_ui.createWidget('UIWidget', gameRootPanel)
  fullMapOverlay:fill('parent')
  fullMapOverlay:setBackgroundColor('#000000')
  fullMapOverlay:setOpacity(0.92)
  fullMapOverlay:hide()

  g_keyboard.bindKeyPress('Alt+Left', function() minimapWidget:move(1, 0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Right', function() minimapWidget:move(-1, 0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Up', function() minimapWidget:move(0, 1) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Down', function() minimapWidget:move(0, -1) end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+M', toggle)
  g_keyboard.bindKeyDown('Ctrl+Tab', toggleFullMap)

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onPingBack = updatePing
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  else
    if type(hideGameButtons) == 'function' then
      hideGameButtons()
    end
    if pingLabel then
      pingLabel:hide()
    end
  end
end

function terminate()
  if g_game.isOnline() then
    saveMap()
  end

  if fullmapView then
    toggleFullMap()
  end

  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onPingBack = updatePing
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyPress('Alt+Left', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Right', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Up', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Down', gameRootPanel)
  g_keyboard.unbindKeyDown('Ctrl+M')
  g_keyboard.unbindKeyDown('Ctrl+Tab')

  fullMapOverlay:destroy()
  minimapWindow:destroy()
end

function updatePing(ping)
  if not pingLabel then
    return
  end

  local text = 'Ping: '
  local color
  if ping < 0 then
    text = text .. '??'
    color = 'yellow'
  else
    text = text .. ping .. ' ms'
    if ping >= 500 then
      color = 'red'
    elseif ping >= 250 then
      color = 'yellow'
    else
      color = 'green'
    end
  end

  pingLabel:setColor(color)
  pingLabel:setText(text)
end

function setPingVisible(enable)
  if pingLabel then
    pingLabel:setVisible(enable)
  end
end

function preload()
  loadMap(false)
  preloaded = true
end

function online()
  if type(showGameButtons) == 'function' then
    showGameButtons()
  end
  loadMap(not preloaded)
  preloaded = true
  updateCameraPosition()

  addEvent(function()
    if not pingLabel then
      return
    end

    if modules.client_options.getOption('showPing') and
      (g_game.getFeature(GameClientPing) or g_game.getFeature(GameExtendedClientPing)) then
      pingLabel:show()
    else
      pingLabel:hide()
    end
  end)
end

function offline()
  if fullmapView then
    toggleFullMap()
  end

  if type(hideGameButtons) == 'function' then
    hideGameButtons()
  end

  if pingLabel then
    pingLabel:hide()
  end

  saveMap()
end

function toggle()
  if fullmapView then
    toggleFullMap()
    return
  end

  setMinimapWindowVisible(not minimapWindow:isVisible())
end

function onMiniWindowClose()
  if fullmapView then
    toggleFullMap()
  end
end

function updatePos(pos)
  if not posLabel or not pos then
    return
  end

  posLabel:setText(string.format('X: %d Y: %d Z: %d', pos.x, pos.y, pos.z))
end

function loadMap(clean)
  local clientVersion = g_game.getClientVersion()

  if clean then
    g_minimap.clean()
  end

  if otmm then
    local minimapFile = '/minimap.otmm'
    if g_resources.fileExists(minimapFile) then
      g_minimap.loadOtmm(minimapFile)
    end
  else
    local minimapFile = '/minimap_' .. clientVersion .. '.otcm'
    if g_resources.fileExists(minimapFile) then
      g_map.loadOtcm(minimapFile)
    end
  end

  minimapWidget:load()
end

function saveMap()
  if not minimapWidget then
    return
  end

  local clientVersion = g_game.getClientVersion()
  if otmm then
    local minimapFile = '/minimap.otmm'
    g_minimap.saveOtmm(minimapFile)
  else
    local minimapFile = '/minimap_' .. clientVersion .. '.otcm'
    g_map.saveOtcm(minimapFile)
  end

  minimapWidget:save()
end

function updateCameraPosition()
  local player = g_game.getLocalPlayer()
  if not player then
    return
  end

  local pos = player:getPosition()
  if not pos then
    return
  end

  updatePos(pos)

  if not minimapWidget:isDragging() then
    if not fullmapView then
      minimapWidget:setCameraPosition(pos)
    end
    minimapWidget:setCrossPosition(pos)
  end
end

function toggleFullMap()
  if not minimapWidget or not minimapContent or not fullMapOverlay then
    return
  end

  local zoom = oldZoom or 0
  local pos = oldPos or minimapWidget:getCameraPosition()
  oldZoom = minimapWidget:getZoom()
  oldPos = minimapWidget:getCameraPosition()

  if not fullmapView then
    fullmapView = true
    minimapWindowWasVisible = minimapWindow:isVisible()
    fullMapOverlay:show()
    fullMapOverlay:raise()
    minimapWidget:setParent(fullMapOverlay)
    minimapWidget:fill('parent')
    minimapWidget:setAlternativeWidgetsVisible(true)
    minimapWidget:setOpacity(1.0)
    minimapWidget:raise()
    minimapWindow:hide()
  else
    fullmapView = false
    minimapWidget:setParent(minimapContent)
    minimapWidget:fill('parent')
    minimapWidget:setAlternativeWidgetsVisible(false)
    minimapWidget:setOpacity(1.0)
    fullMapOverlay:hide()
    setMinimapWindowVisible(minimapWindowWasVisible)
  end

  minimapWidget:setZoom(zoom)
  minimapWidget:setCameraPosition(pos)
end

function getMinimapWidget()
  return minimapWidget
end
