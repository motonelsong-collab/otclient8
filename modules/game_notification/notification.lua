local NOTIFICATION_OPCODE = 81
local NOTIFICATION_ACTIONS = {
  Create = 1,
  Clear = 2
}

local notificationPanel

local iconFactories = {
  item = function(widget, value)
    g_ui.createWidget('ItemNotify', widget):setItemId(value)
  end,
  outfit = function(widget, value)
    g_ui.createWidget('OutfitNotify', widget):setOutfit(value)
  end,
  image = function(widget, value)
    g_ui.createWidget('ImageNotify', widget):setImageSource(value)
  end,
  pokemon = function(widget, value)
    local portrait = ''
    if type(getPokemonPortrait) == 'function' then
      local ok, result = pcall(getPokemonPortrait, value)
      if ok and type(result) == 'string' then
        portrait = result
      end
    end

    if portrait == '' then
      return
    end

    g_ui.createWidget('ImageNotify', widget):setImageSource(portrait)
  end
}

local function destroyNotification(widget)
  if not widget then
    return
  end

  if widget.notificationUpdateEvent then
    removeEvent(widget.notificationUpdateEvent)
    widget.notificationUpdateEvent = nil
  end

  if widget.notificationDestroyEvent then
    removeEvent(widget.notificationDestroyEvent)
    widget.notificationDestroyEvent = nil
  end

  g_effects.fadeOut(widget)
  widget.notificationDestroyEvent = scheduleEvent(function()
    if widget then
      widget:destroy()
    end
  end, 350)
end

local function setNotificationMessage(widget, message)
  widget.message:setText(message or '')
end

local function setNotificationTimer(widget, timer)
  local duration = math.max(1, tonumber(timer) or 5) * 1000
  local startedAt = g_clock.millis()

  local function updateProgress()
    if not widget then
      return
    end

    local elapsed = g_clock.millis() - startedAt
    local remainingPercent = math.max(0, 100 - math.floor((elapsed * 100) / duration))

    widget.progress:setPercent(remainingPercent)

    if elapsed >= duration then
      widget.notificationUpdateEvent = nil
      destroyNotification(widget)
      return
    end

    widget.notificationUpdateEvent = scheduleEvent(updateProgress, 100)
  end

  widget.progress:setPercent(100)
  updateProgress()
end

local function setNotificationIcon(widget, data)
  local iconType = data.pokemonName and 'pokemon' or data.image and 'image' or data.itemId and 'item' or data.outfit and 'outfit'
  local iconValue = data.pokemonName or data.image or data.itemId or data.outfit
  if not iconType or not iconValue then
    return
  end

  if iconType == 'pokemon' and type(getPokemonPortrait) == 'function' then
    local ok, result = pcall(getPokemonPortrait, iconValue)
    if not ok or type(result) ~= 'string' or result == '' then
      return
    end
  end

  widget.icon:setOn(true)
  widget.message:setOn(true)
  iconFactories[iconType](widget.icon, iconValue)
end

local function resizeNotification(widget)
  local horizontalPadding = 32
  local messageWidth = math.max(140, widget:getWidth() - horizontalPadding * 2)
  local iconHeight = widget.icon:isOn() and 34 or 0
  local contentTopSpacing = 10
  local spacingBetween = widget.icon:isOn() and 4 or 0

  widget.message:setWidth(messageWidth)
  widget.message:setTextWrap(true)
  widget.message:resizeToText()

  local messageSize = widget.message:getTextSize()
  local contentWidth = math.max(0, widget:getWidth() - horizontalPadding)
  local contentHeight = iconHeight + spacingBetween + messageSize.height

  widget.content:setWidth(contentWidth)
  widget.content:setHeight(contentHeight)
  local height = math.max(110, 58 + contentTopSpacing + contentHeight)

  widget:setHeight(height)
end

local function createNotification(data)
  if not notificationPanel or type(data) ~= 'table' or not data.message or data.message == '' then
    return
  end

  local widget = g_ui.createWidget('PanelNotify', notificationPanel)
  setNotificationMessage(widget, data.message)
  setNotificationTimer(widget, data.timer)
  setNotificationIcon(widget, data)
  resizeNotification(widget)
end

local function clearNotifications()
  if not notificationPanel then
    return
  end

  for _, child in ipairs(notificationPanel:getChildren()) do
    child:destroy()
  end
end

local function ensureNotificationPanel()
  if notificationPanel then
    return
  end

  local rootPanel = modules.game_interface.getRootPanel()
  if not rootPanel then
    return
  end

  notificationPanel = g_ui.createWidget('PanelNotification', rootPanel)
end

local function destroyNotificationPanel()
  if not notificationPanel then
    return
  end

  notificationPanel:destroy()
  notificationPanel = nil
end

local function onNotificationOpcode(protocol, opcode, payload)
  local action = payload.action or NOTIFICATION_ACTIONS.Create
  local handlers = {
    [NOTIFICATION_ACTIONS.Create] = createNotification,
    [NOTIFICATION_ACTIONS.Clear] = clearNotifications
  }
  local handler = handlers[action]

  if handler then
    handler(payload.data or {})
  end
end

function init()
  g_ui.importStyle('notification')
  connect(g_game, {
    onGameStart = ensureNotificationPanel,
    onGameEnd = clearNotifications
  })
  ProtocolGame.registerExtendedJSONOpcode(NOTIFICATION_OPCODE, onNotificationOpcode)
  ensureNotificationPanel()
end

function terminate()
  disconnect(g_game, {
    onGameStart = ensureNotificationPanel,
    onGameEnd = clearNotifications
  })
  ProtocolGame.unregisterExtendedJSONOpcode(NOTIFICATION_OPCODE)
  clearNotifications()
  destroyNotificationPanel()
end
