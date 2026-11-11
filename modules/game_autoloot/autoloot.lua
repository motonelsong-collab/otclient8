local AUTOLOOT_OPCODE = 69
local AUTOLOOT_FADE_DELAY = 3200
local AUTOLOOT_DESTROY_DELAY = 4200

local autoLootItemsPanel
local activeLootWidgets = {}

local function clearLootWidget(key)
  local entry = activeLootWidgets[key]
  if not entry then
    return
  end

  if entry.fadeEvent then
    removeEvent(entry.fadeEvent)
    entry.fadeEvent = nil
  end

  if entry.destroyEvent then
    removeEvent(entry.destroyEvent)
    entry.destroyEvent = nil
  end

  if entry.widget then
    local widget = entry.widget
    entry.widget = nil
    widget:destroy()
  end

  activeLootWidgets[key] = nil
end

local function resetLootWidgetTimers(key)
  local entry = activeLootWidgets[key]
  if not entry or not entry.widget then
    return
  end

  if entry.fadeEvent then
    removeEvent(entry.fadeEvent)
  end

  if entry.destroyEvent then
    removeEvent(entry.destroyEvent)
  end

  entry.widget:setOpacity(1)
  entry.fadeEvent = scheduleEvent(function()
    if entry.widget then
      g_effects.fadeOut(entry.widget, 800)
    end
  end, AUTOLOOT_FADE_DELAY)

  entry.destroyEvent = scheduleEvent(function()
    clearLootWidget(key)
  end, AUTOLOOT_DESTROY_DELAY)
end

local function clearAllLootWidgets()
  for key in pairs(activeLootWidgets) do
    clearLootWidget(key)
  end
end

local function parseLootBuffer(buffer)
  local items = {}
  local values = {}

  for value in string.gmatch(buffer or '', '([^%-]+)') do
    table.insert(values, tonumber(value))
  end

  for index = 1, #values, 2 do
    local itemId = values[index]
    local count = values[index + 1]

    if itemId and count then
      table.insert(items, { id = itemId, count = count })
    end
  end

  return items
end

function init()
  connect(g_game, { onGameEnd = clearAllLootWidgets })

  autoLootItemsPanel = g_ui.loadUI('autoloot', modules.game_interface.getMapPanel())
  ProtocolGame.registerExtendedOpcode(AUTOLOOT_OPCODE, parseAutoLoot)
end

function terminate()
  disconnect(g_game, { onGameEnd = clearAllLootWidgets })
  ProtocolGame.unregisterExtendedOpcode(AUTOLOOT_OPCODE)

  clearAllLootWidgets()

  if autoLootItemsPanel then
    autoLootItemsPanel:destroy()
    autoLootItemsPanel = nil
  end
end

function parseAutoLoot(protocol, opcode, buffer)
  local items = parseLootBuffer(buffer)

  for _, item in ipairs(items) do
    showItem(item.id, item.count)
  end
end

function showItem(itemId, count)
  local key = 'autoloot_' .. itemId
  local entry = activeLootWidgets[key]

  if entry and entry.widget then
    entry.widget:setItemCount(entry.widget:getItemCount() + count)
    entry.widget:setOpacity(1)
    resetLootWidgetTimers(key)
    return
  end

  local widget = g_ui.createWidget('AutoLootItem', autoLootItemsPanel)
  widget:setId(key)
  widget:setItemId(itemId)
  widget:setItemCount(count)
  widget:setOpacity(0)

  activeLootWidgets[key] = { widget = widget }

  g_effects.fadeIn(widget, 250)
  resetLootWidgetTimers(key)
end
