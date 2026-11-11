local topMenu
local leftButtonsPanel
local rightButtonsPanel
local leftGameButtonsPanel
local rightGameButtonsPanel
local topButtonsPanel
local topGameButtonsPanel
local pingLabel
local fpsLabel

local function addButton(id, description, icon, callback, panel, toggle, front)
  if not panel then
    return nil
  end

  local class = toggle and 'TopToggleButton' or 'TopButton'
  local button = panel:getChildById(id)
  if not button then
    button = g_ui.createWidget(class, panel)
    if front then
      panel:moveChildToIndex(button, 1)
    end
  end

  if not button then
    return nil
  end

  button:setId(id)
  button:setTooltip(description)
  button:setIcon(resolvepath(icon, 3))
  button.onMouseRelease = function(widget, mousePos, mouseButton)
    if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
      if type(callback) == 'function' then
        callback()
      end
      return true
    end
  end

  return button
end

function init()
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onPingBack = updatePing
  })
  connect(g_app, { onFps = updateFps })

  g_ui.importStyle('/data/styles/20-topmenu.otui')
  topMenu = g_ui.displayUI('topmenu')

  leftButtonsPanel = topMenu:getChildById('leftButtonsPanel')
  rightButtonsPanel = topMenu:getChildById('rightButtonsPanel')
  leftGameButtonsPanel = topMenu:getChildById('leftGameButtonsPanel')
  rightGameButtonsPanel = topMenu:getChildById('rightGameButtonsPanel')
  topButtonsPanel = topMenu:getChildById('topButtonsPanel')
  topGameButtonsPanel = topMenu:getChildById('topGameButtonsPanel')
  pingLabel = topMenu:getChildById('pingLabel')
  fpsLabel = topMenu:getChildById('fpsLabel')

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onPingBack = updatePing
  })
  disconnect(g_app, { onFps = updateFps })

  if topMenu then
    topMenu:destroy()
    topMenu = nil
  end
end

function online()
  showGameButtons()

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
  hideGameButtons()
  if pingLabel then
    pingLabel:hide()
  end
end

function updateFps(fps)
  if fpsLabel then
    fpsLabel:setText('FPS: ' .. fps)
  end
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

function setFpsVisible(enable)
  if fpsLabel then
    fpsLabel:setVisible(enable)
  end
end

function addLeftButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, leftButtonsPanel, false, front)
end

function addLeftToggleButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, leftButtonsPanel, true, front)
end

function addRightButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, rightButtonsPanel, false, front)
end

function addRightToggleButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, rightButtonsPanel, true, front)
end

function addTopButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, topButtonsPanel, false, front)
end

function addTopToggleButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, topButtonsPanel, true, front)
end

function addTopGameButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, topGameButtonsPanel, false, front)
end

function addTopGameToggleButton(id, description, icon, callback, front)
  return addButton(id, description, icon, callback, topGameButtonsPanel, true, front)
end

function addLeftGameButton(id, description, icon, callback, front)
  return addTopGameButton(id, description, icon, callback, front)
end

function addLeftGameToggleButton(id, description, icon, callback, front)
  return addTopGameToggleButton(id, description, icon, callback, front)
end

function addRightGameButton(id, description, icon, callback, front)
  return addTopGameButton(id, description, icon, callback, front)
end

function addRightGameToggleButton(id, description, icon, callback, front)
  return addTopGameToggleButton(id, description, icon, callback, front)
end

function showGameButtons()
  if leftGameButtonsPanel then
    leftGameButtonsPanel:hide()
  end
  if rightGameButtonsPanel then
    rightGameButtonsPanel:hide()
  end
  if topGameButtonsPanel then
    topGameButtonsPanel:show()
  end
end

function hideGameButtons()
  if leftGameButtonsPanel then
    leftGameButtonsPanel:hide()
  end
  if rightGameButtonsPanel then
    rightGameButtonsPanel:hide()
  end
  if topGameButtonsPanel then
    topGameButtonsPanel:hide()
  end
end

function getButton(id)
  if not topMenu then
    return nil
  end
  return topMenu:recursiveGetChildById(id)
end

function getTopMenu()
  return topMenu
end
