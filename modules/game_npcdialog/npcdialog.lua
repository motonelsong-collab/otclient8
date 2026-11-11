local NPC_DIALOG_OPCODE = 54
local NPC_DIALOG_ACTIONS = {
  Create = 1,
  Close = 2
}

local DEFAULT_NAME_COLOR = "#f7f0d0"
local DEFAULT_TEXT_COLOR = "#f6f1e3"
local HIGHLIGHT_TEXT_COLOR = "#ffe082"
local DEFAULT_IMAGE = "/modules/game_npcdialog/images/1"
local POKEMON_SPRITE_PREFIX = "/pokemon/sprites/sprites/"
local MAX_SELECTION_HEIGHT = 190
local EXTRA_PANEL_HEIGHT = 62

local NpcWindow
local npcOutfit
local npcImage
local npcName
local panelDialog
local panelSelections
local panelSelectionsScroll
local panelExtras
local panelExtrasWrapper
local panelExtrasScroll
local description
local gameEndCallback

local function trim(value)
  if type(value) ~= "string" then
    return ""
  end

  return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function copyTable(source)
  if type(source) ~= "table" then
    return nil
  end

  local clone = {}
  for key, value in pairs(source) do
    clone[key] = value
  end
  return clone
end

local function normalizeReplyText(text)
  return trim(tostring(text or "")):gsub("[%{%}]", "")
end

local function normalizeMessageText(value)
  if type(value) == "string" then
    return value
  end

  if type(value) ~= "table" then
    return ""
  end

  local buffer = {}
  for _, line in ipairs(value) do
    if type(line) == "string" and line ~= "" then
      buffer[#buffer + 1] = line
    end
  end

  return table.concat(buffer, "\n")
end

local function sendNpcReply(text)
  local reply = normalizeReplyText(text)
  if reply == "" then
    return
  end

  g_game.talkChannel(MessageModes.NpcTo, 0, reply)
end

local function clearChildren(widget)
  if widget then
    widget:destroyChildren()
  end
end

local function splitHighlightedText(text, baseColor, highlightColor)
  local coloredText = {}
  local currentText = ""
  local activeColor = baseColor

  local function flush()
    if currentText ~= "" then
      table.insert(coloredText, currentText)
      table.insert(coloredText, activeColor)
      currentText = ""
    end
  end

  for index = 1, #text do
    local char = text:sub(index, index)
    if char == "{" then
      flush()
      activeColor = highlightColor
    elseif char == "}" then
      flush()
      activeColor = baseColor
    else
      currentText = currentText .. char
    end
  end

  flush()
  return coloredText
end

local function setWidgetText(widget, text, baseColor, highlightColor)
  if not widget then
    return
  end

  text = tostring(text or "")
  if text:find("{", 1, true) and text:find("}", 1, true) then
    local coloredText = splitHighlightedText(text, baseColor or DEFAULT_TEXT_COLOR, highlightColor or HIGHLIGHT_TEXT_COLOR)
    if widget.setMultiColorText then
      widget:setMultiColorText(coloredText)
      return
    end

    if widget.setColoredText then
      widget:setColoredText(coloredText)
      return
    end
  end

  widget:setText(text:gsub("[%{%}]", ""))
end

local function normalizeDialogItem(entry, fallbackCount, fallbackName)
  if type(entry) == "table" then
    return {
      itemId = tonumber(entry.itemId or entry.itemid or entry.serverId or entry.serverid or entry.id) or 0,
      clientId = tonumber(entry.clientId or entry.clientid or entry.spriteId or entry.spriteid) or 0,
      count = tonumber(entry.count or entry.amount or fallbackCount) or 1,
      name = tostring(entry.name or entry.tooltipName or fallbackName or "Item")
    }
  end

  return {
    itemId = tonumber(entry) or 0,
    clientId = 0,
    count = tonumber(fallbackCount) or 1,
    name = tostring(fallbackName or "Item")
  }
end

local function setDialogItem(widget, itemData)
  if not widget or not itemData then
    return false
  end

  local count = tonumber(itemData.count) or 1
  local tooltip = string.format("%s (%sx)", tostring(itemData.name or "Item"), count)

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

local function normalizePokemonOutfit(outfit)
  if type(outfit) ~= "table" then
    return nil
  end

  local normalized = copyTable(outfit)
  normalized.type = normalized.type or normalized.lookType
  return normalized
end

local function resolvePokemonSpriteSource(sprite)
  if sprite == nil then
    return nil
  end

  local spriteText = trim(tostring(sprite))
  if spriteText == "" then
    return nil
  end

  if spriteText:find("/", 1, true) or spriteText:find("%.") then
    return spriteText
  end

  return POKEMON_SPRITE_PREFIX .. spriteText
end

local function normalizePokemonEntry(entry, fallbackVisual, fallbackName)
  if type(entry) == "table" then
    return {
      name = tostring(entry.name or entry.poke or fallbackName or "Pokemon"),
      count = tonumber(entry.count or entry.amount) or 1,
      outfit = normalizePokemonOutfit(entry.outfit or entry.look or entry.lookType and entry),
      spriteSource = resolvePokemonSpriteSource(entry.sprite or entry.image or entry.id or entry.clientId)
    }
  end

  local pokemonData = {
    name = tostring(fallbackName or entry or "Pokemon"),
    count = 1,
    outfit = nil,
    spriteSource = nil
  }

  if type(fallbackVisual) == "table" then
    pokemonData.outfit = normalizePokemonOutfit(fallbackVisual)
  else
    pokemonData.spriteSource = resolvePokemonSpriteSource(fallbackVisual)
  end

  return pokemonData
end

local function setPokemonPreview(widget, pokemonData)
  if not widget or not pokemonData then
    return
  end

  local spriteWidget = widget.sprite or (widget.creature and not widget.creature.setOutfit and widget.creature or nil)
  local creatureWidget = widget.creature and widget.creature.setOutfit and widget.creature or nil
  local amountWidget = widget.amount or widget.count

  widget:setTooltip(tostring(pokemonData.name or "Pokemon"))
  if spriteWidget then
    spriteWidget:setVisible(false)
  end
  if creatureWidget then
    creatureWidget:setVisible(false)
  end

  if creatureWidget and pokemonData.outfit and pokemonData.outfit.type and pokemonData.outfit.type > 0 then
    creatureWidget:setOutfit(pokemonData.outfit)
    creatureWidget:setVisible(true)
  elseif spriteWidget and pokemonData.spriteSource then
    spriteWidget:setImageSource(pokemonData.spriteSource)
    spriteWidget:setVisible(true)
  else
    if spriteWidget then
      spriteWidget:setImageSource(DEFAULT_IMAGE)
      spriteWidget:setVisible(true)
    end
  end

  if amountWidget then
    if tonumber(pokemonData.count) and tonumber(pokemonData.count) > 1 then
      amountWidget:setText(tostring(tonumber(pokemonData.count)) .. "x")
      amountWidget:show()
    else
      amountWidget:setText("")
      amountWidget:hide()
    end
  end
end

local function setNpcVisuals(data)
  local creature = nil
  local cid = tonumber(data.cid or data.npcId)
  if cid and cid > 0 then
    creature = g_map.getCreatureById(cid)
  end

  local npcInfo = type(data.npcInfo) == "table" and data.npcInfo or {}
  local npcNameInfo = type(npcInfo.NpcName) == "table" and npcInfo.NpcName or {}
  local nameText = tostring(data.title or npcNameInfo.name or (creature and creature:getName()) or "NPC")
  local nameColor = tostring(data.nameColor or npcNameInfo.color or DEFAULT_NAME_COLOR)
  local outfit = normalizePokemonOutfit(data.outfit or npcInfo.outfit or (creature and creature:getOutfit()))
  local image = trim(tostring(data.image or npcInfo.image or ""))

  npcName:setText(nameText)
  npcName:setColor(nameColor)

  if image ~= "" then
    if not image:find("/", 1, true) then
      image = "/images/npcdialog/" .. image
    end
    npcImage:setImageSource(image)
    npcImage:show()
    npcOutfit:hide()
  elseif outfit and outfit.type and outfit.type > 0 then
    npcOutfit:setOutfit(outfit)
    npcOutfit:show()
    npcImage:hide()
  else
    npcImage:setImageSource(DEFAULT_IMAGE)
    npcImage:show()
    npcOutfit:hide()
  end
end

local function addSelectionWidget(widget)
  if not widget then
    return 0
  end

  widget:setWidth(panelSelections:getWidth() - 8)
  return widget:getHeight() + widget:getMarginTop() + widget:getMarginBottom()
end

local function createChoiceButton(text, replyText)
  local button = g_ui.createWidget("SelectionsWindow", panelSelections)
  setWidgetText(button, text, DEFAULT_TEXT_COLOR, HIGHLIGHT_TEXT_COLOR)
  button.onClick = function()
    sendNpcReply(replyText or text)
  end
  return button
end

local function createTextEditButton(buttonData)
  local row = g_ui.createWidget("NpcDialogTextEditRow", panelSelections)
  if buttonData.text and buttonData.text ~= "" then
    setWidgetText(row.label, buttonData.text, DEFAULT_TEXT_COLOR, HIGHLIGHT_TEXT_COLOR)
    row.label:show()
  else
    row.label:hide()
  end

  row.input:setText("")
  if buttonData.placeholder and row.input.setPlaceholder then
    row.input:setPlaceholder(buttonData.placeholder)
  elseif buttonData.Placeholder and row.input.setPlaceholder then
    row.input:setPlaceholder(buttonData.Placeholder)
  end

  local function submit()
    sendNpcReply(row.input:getText())
  end

  row.confirm.onClick = submit
  row.input.onKeyPress = function(widget, keyCode)
    if keyCode == KeyEnter or keyCode == KeyNumpadEnter then
      submit()
      return true
    end

    return false
  end
  return row
end

local function fillItemList(container, entries)
  for _, itemData in ipairs(entries) do
    local widget = g_ui.createWidget("NpcDialogItemSlot", container)
    setDialogItem(widget, itemData)
  end
end

local function fillPokemonList(container, entries)
  for _, pokemonData in ipairs(entries) do
    local widget = g_ui.createWidget("NpcDialogPokemonIcon", container)
    setPokemonPreview(widget, pokemonData)
  end
end

local function createCollectionRow(title, collectionType, entries)
  if not entries or #entries == 0 then
    return nil
  end

  local row = g_ui.createWidget("NpcDialogCollectionRow", panelSelections)
  setWidgetText(row.title, title or "", DEFAULT_TEXT_COLOR, HIGHLIGHT_TEXT_COLOR)

  if collectionType == "item" then
    fillItemList(row.content, entries)
  else
    fillPokemonList(row.content, entries)
  end

  return row
end

local function createStarterButton(buttonData)
  local row = g_ui.createWidget("SelectionsWindow", panelSelections)
  row:setHeight(38)
  local pokemonData = normalizePokemonEntry(buttonData, buttonData.id, buttonData.poke or buttonData.text)
  local preview = g_ui.createWidget("StarterNpc", row)
  preview:setId("preview")
  preview:addAnchor(AnchorLeft, "parent", AnchorLeft)
  preview:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
  preview:setMarginLeft(8)
  setPokemonPreview(preview, pokemonData)
  row:setText(buttonData.text or buttonData.poke or pokemonData.name)
  row:setTextOffset("60 0")
  row.onClick = function()
    sendNpcReply(buttonData.poke or buttonData.text or pokemonData.name)
  end
  return row
end

local function populateSelections(data)
  local totalHeight = 0
  local options = type(data.options) == "table" and data.options or {}
  local keywords = type(options.keywords) == "table" and options.keywords or {}
  local buttons = type(data.Buttons) == "table" and data.Buttons or type(options.buttons) == "table" and options.buttons or {}

  for _, keyword in ipairs(keywords) do
    totalHeight = totalHeight + addSelectionWidget(createChoiceButton(keyword, keyword))
  end

  for _, button in ipairs(buttons) do
    local widget = nil
    if button.type == "Button" then
      widget = createChoiceButton(button.text or "", button.reply or button.text)
    elseif button.type == "TextEdit" then
      widget = createTextEditButton(button)
    elseif button.type == "Reward" then
      local rewards = {}
      for _, reward in ipairs(button.rewards or {}) do
        rewards[#rewards + 1] = normalizeDialogItem(reward)
      end
      widget = createCollectionRow(button.text or "Rewards", "item", rewards)
    elseif button.type == "Defeat" then
      local creatures = {}
      for _, creature in ipairs(button.creatures or {}) do
        creatures[#creatures + 1] = normalizePokemonEntry(creature)
      end
      widget = createCollectionRow(button.text or "Pokemons", "pokemon", creatures)
    elseif button.type == "PokeStarter" then
      widget = createStarterButton(button)
    end

    if widget then
      totalHeight = totalHeight + addSelectionWidget(widget)
    end
  end

  return totalHeight
end

local function populateExtras(data)
  local options = type(data.options) == "table" and data.options or {}
  local items = type(options.items) == "table" and options.items or {}
  local pokemons = type(options.pokemons) == "table" and options.pokemons or {}
  local extrasCount = 0

  if #pokemons > 0 then
    local index = 1
    while index <= #pokemons do
      local entry = pokemons[index]
      local pokemonData = nil
      if type(entry) == "table" then
        pokemonData = normalizePokemonEntry(entry)
        index = index + 1
      else
        pokemonData = normalizePokemonEntry(entry, pokemons[index + 1], pokemons[index])
        index = index + 2
      end

      if pokemonData then
        extrasCount = extrasCount + 1
        local widget = g_ui.createWidget("NpcDialogPokemonIcon", panelExtras)
        setPokemonPreview(widget, pokemonData)
      end
    end
  end

  if #items > 0 then
    local index = 1
    while index <= #items do
      local entry = items[index]
      local itemData = nil
      if type(entry) == "table" then
        itemData = normalizeDialogItem(entry)
        index = index + 1
      else
        itemData = normalizeDialogItem(entry, items[index + 1], items[index + 2])
        index = index + 3
      end

      if itemData and (itemData.clientId > 0 or itemData.itemId > 0) then
        extrasCount = extrasCount + 1
        local widget = g_ui.createWidget("NpcDialogItemSlot", panelExtras)
        setDialogItem(widget, itemData)
      end
    end
  end

  return extrasCount > 0
end

local function refreshWindowLayout(selectionHeight, hasExtras)
  local messageHeight = math.max(description:getTextSize().height + 8, 28)
  panelDialog:setHeight(messageHeight)

  panelExtrasWrapper:setVisible(hasExtras)
  if hasExtras then
    panelExtrasWrapper:setHeight(EXTRA_PANEL_HEIGHT)
  else
    panelExtrasWrapper:setHeight(0)
  end

  local finalSelectionHeight = 0
  if selectionHeight > 0 then
    finalSelectionHeight = math.min(selectionHeight, MAX_SELECTION_HEIGHT)
    panelSelections:setHeight(finalSelectionHeight)
    panelSelectionsScroll:setVisible(selectionHeight > MAX_SELECTION_HEIGHT)
  else
    panelSelections:setHeight(0)
    panelSelectionsScroll:setVisible(false)
  end

  local baseHeight = 84 + messageHeight + finalSelectionHeight
  if hasExtras then
    baseHeight = baseHeight + EXTRA_PANEL_HEIGHT + 8
  end

  NpcWindow:setHeight(math.max(baseHeight, 158))
end

local function showWindow()
  NpcWindow:show()
  NpcWindow:raise()
  NpcWindow:focus()
  g_effects.fadeIn(NpcWindow, 180)
end

function close(sendFarewell)
  if not NpcWindow or not NpcWindow:isVisible() then
    return
  end

  if sendFarewell then
    sendNpcReply("bye")
  end

  NpcWindow:hide()
  description:setText("")
  clearChildren(panelSelections)
  clearChildren(panelExtras)
end

local function openDialog(data)
  if NpcWindow:isVisible() then
    NpcWindow:hide()
  end

  clearChildren(panelSelections)
  clearChildren(panelExtras)

  setNpcVisuals(data)
  setWidgetText(description, normalizeMessageText(data.message or data.lines or data.dialog or data.dialogs or ""), DEFAULT_TEXT_COLOR, HIGHLIGHT_TEXT_COLOR)

  local selectionHeight = populateSelections(data)
  local hasExtras = populateExtras(data)

  refreshWindowLayout(selectionHeight, hasExtras)
  showWindow()
end

local function parseAction(protocol, opcode, jsonData)
  if type(jsonData) ~= "table" then
    return
  end

  if jsonData.action == NPC_DIALOG_ACTIONS.Close then
    close(false)
    return
  end

  if jsonData.action == NPC_DIALOG_ACTIONS.Create then
    openDialog(jsonData.data or {})
    return
  end

  openDialog(jsonData)
end

function init()
  NpcWindow = g_ui.loadUI("npcdialog", modules.game_interface.getRootPanel())
  NpcWindow:hide()

  npcOutfit = NpcWindow.baseOutfit.NpcOutfit
  npcImage = NpcWindow.baseOutfit.image
  npcName = NpcWindow.NpcName
  panelDialog = NpcWindow.PanelDialog
  panelSelections = NpcWindow.PanelSelections
  panelSelectionsScroll = NpcWindow.ScrollBarDialog
  panelExtrasWrapper = NpcWindow.PanelExtrasWrapper
  panelExtras = NpcWindow.PanelExtras
  panelExtrasScroll = NpcWindow.ExtraScrollBar
  description = panelDialog.description

  gameEndCallback = function()
    close(false)
  end

  connect(g_game, { onGameEnd = gameEndCallback })
  ProtocolGame.registerExtendedJSONOpcode(NPC_DIALOG_OPCODE, parseAction)
end

function terminate()
  ProtocolGame.unregisterExtendedJSONOpcode(NPC_DIALOG_OPCODE)
  if gameEndCallback then
    disconnect(g_game, { onGameEnd = gameEndCallback })
    gameEndCallback = nil
  end

  if NpcWindow then
    NpcWindow:destroy()
    NpcWindow = nil
  end
end
