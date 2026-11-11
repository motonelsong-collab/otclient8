-- chunkname: @/modules/game_dialog/dialog.lua

Dialog = {}

local dialogWindow
local protocol = runinsandbox("protocol")

local function resize(height)
  if dialogWindow then
    local newHeight = dialogWindow:getPaddingTop() + dialogWindow:getPaddingBottom() + dialogWindow:getPaddingLeft() + dialogWindow:getPaddingRight() + height
    dialogWindow:resize(dialogWindow:getWidth(), newHeight)
  end
end

local function setDialogText(widget, text)
  if not widget then
    return
  end

  if widget.setMultiColorText then
    widget:setMultiColorText(text)
  elseif widget.setColoredText and type(text) == 'table' then
    widget:setColoredText(text)
  else
    widget:setText(text)
  end
end

local function normalizeDialogItem(entry, fallbackCount, fallbackName)
  if type(entry) == 'table' then
    return {
      itemId = tonumber(entry.itemId or entry.itemid or entry.serverId or entry.serverid or entry.id) or 0,
      clientId = tonumber(entry.clientId or entry.clientid or entry.spriteId or entry.spriteid) or 0,
      count = tonumber(entry.count or entry.amount or fallbackCount) or 1,
      name = tostring(entry.name or entry.tooltipName or fallbackName or 'Item')
    }
  end

  return {
    itemId = tonumber(entry) or 0,
    clientId = 0,
    count = tonumber(fallbackCount) or 1,
    name = tostring(fallbackName or 'Item')
  }
end

local function setDialogItem(widget, itemData)
  if not widget then
    return false
  end

  local count = tonumber(itemData.count) or 1
  local tooltip = tr('%s (%sx).', tostring(itemData.name or 'Item'), count)

  widget:setTooltip(tooltip)
  widget:setItemCount(count)

  if tonumber(itemData.clientId) and tonumber(itemData.clientId) > 0 then
    widget:setItem(nil)
    widget:setItemId(tonumber(itemData.clientId))
    return true
  end

  if tonumber(itemData.itemId) and tonumber(itemData.itemId) > 0 then
    local tmpItem = Item.create(tonumber(itemData.itemId), count)
    if tmpItem then
      tmpItem:setTooltip(tooltip)
      widget:setItem(tmpItem)
      return true
    end
  end

  widget:setItem(nil)
  widget:setItemCount(0)
  return false
end

function addDialogOption(data)
  local keywords = data.keywords
  local pokemons = data.pokemons
  local items = data.items
  local height = 0

  dialogWindow.extra:setOn(pokemons or items)
  dialogWindow.extraScroll:setOn(pokemons or items)

  if keywords and #keywords > 0 then
    for i = 1, #keywords do
      local option = g_ui.createWidget("OptionDialog", dialogWindow.options)

      if i <= 3 then
        height = height + option:getHeight() + option:getMarginTop()
      end

      setDialogText(option, keywords[i])
    end

    dialogWindow.options.selectedWidget = dialogWindow.options:getFirstChild()
    if dialogWindow.options.selectedWidget then
      dialogWindow.options.selectedWidget:setChecked(true)
    end

    dialogWindow.optionsScroll:setVisible(#keywords > 3)
  end

  if pokemons and #pokemons > 0 then
    for i = 1, #pokemons, 2 do
      local pokemon = g_ui.createWidget("PokemonDialog", dialogWindow.extra)
      pokemon:setTooltip(pokemons[i])
      pokemon:setOutfit(pokemons[i + 1])
    end
  end

  if items and #items > 0 then
    local index = 1

    while index <= #items do
      local entry = items[index]
      local itemData

      if type(entry) == 'table' then
        itemData = normalizeDialogItem(entry)
        index = index + 1
      else
        itemData = normalizeDialogItem(entry, items[index + 1], items[index + 2])
        index = index + 3
      end

      if itemData and (itemData.clientId > 0 or itemData.itemId > 0) then
        local item = g_ui.createWidget("ItemDialog", dialogWindow.extra)
        setDialogItem(item, itemData)
      end
    end
  end

  local newHeight = 36 + height + dialogWindow.extra:getHeight() + dialogWindow.extra:getMarginTop() + dialogWindow.extraScroll:getHeight() + dialogWindow.extraScroll:getMarginTop() + dialogWindow.message:getTextSize().height
  resize(newHeight)
end

local function onOpen(params)
  onDialogGameEnd()

  dialogWindow = g_ui.createWidget("DialogWindow", rootWidget)

  local creature = g_map.getCreatureById(params.cid)
  dialogWindow.title:setText(creature and creature:getName() or tr("Dialogue"))
  setDialogText(dialogWindow.message, params.message)
  resize(dialogWindow.message:getTextSize().height + 5)
  addDialogOption(params.options)
end

local function onClose()
  onDialogGameEnd()
end

function init()
  g_ui.importStyle('/modules/game_dialog/dialog.otui')
  protocol.initProtocol()
  connect(g_game, {
    onGameEnd = onDialogGameEnd
  })
  connect(Dialog, {
    onOpen = onOpen,
    onClose = onClose
  })
end

function terminate()
  protocol.terminateProtocol()
  disconnect(g_game, {
    onGameEnd = onDialogGameEnd
  })
  disconnect(Dialog, {
    onOpen = onOpen,
    onClose = onClose
  })
  onDialogGameEnd()
end

function onDialogGameEnd()
  if dialogWindow then
    dialogWindow:destroy()
    dialogWindow = nil
  end
end