PokeDex = PokeDex or {}

local protocol = runinsandbox("protocol")
local dexWindow
local dexButton
local searchEdit
local listPanel
local infoName
local infoNumber
local infoStatus
local infoLevel
local infoAbility
local infoDescription
local infoPrice
local infoImage
local infoTypeIcon1
local infoTypeIcon2
local movesPanel
local statsPanel
local evolutionsPanel
local dropsPanel
local shinyToggleButton
local countLabel
local sectionTitle
local tabHintLabel
local mouseGrabberWidget
local preloadEvent
local renderList
local onOpen
local selectPokemon
local hasReceivedDexData = false
local currentTab = 'info'
local selectedPokemonName
local currentImageVariant = 'normal'
local POKEDEX_ITEM_ID = 2382
local POKEMON_NAME_ALIASES = {
  farfetch_d = "farfetch'd",
  ho_oh = "ho-oh",
  mime_jr = "mime jr.",
  mr_mime = "mr. mime",
  nidoran_f = "nidoran female",
  nidoran_m = "nidoran male"
}
local STAT_DEFINITIONS = {
  { key = 'vitality', label = 'Vitality', max = 30 },
  { key = 'offense', label = 'Offense', max = 20 },
  { key = 'defense', label = 'Defense', max = 20 },
  { key = 'specialattack', label = 'Special Attack', max = 20 },
  { key = 'agility', label = 'Agility', max = 450 }
}

local cacheData = {
  unlocked = {},
  caught = {},
  entries = {},
  details = {},
  shinyDetails = {},
  loots = {},
  lootLoaded = {},
  lootPending = {}
}

local TAB_TITLES = {
  info = 'Information',
  moves = 'Moves',
  stats = 'Status',
  evo = 'Evolutions',
  pokeball = 'Drops'
}

local function normalizeName(name)
  if not name then
    return ''
  end

  local pokemonName = tostring(name):lower()
  pokemonName = pokemonName:gsub('^shiny%s+', '')
  return pokemonName
end

local function formatDisplayName(name)
  local normalized = normalizeName(name)
  local displayName = POKEMON_NAME_ALIASES[normalized] or tostring(name or ''):gsub('_', ' ')
  return displayName:gsub("(%a)([%w_']*)", function(first, rest)
    return first:upper() .. rest
  end)
end

local function buildPokemonNameCandidates(pokemonName)
  local candidates = {}
  local seen = {}

  local function addCandidate(name)
    if not name or name == '' then
      return
    end

    local candidate = tostring(name):lower()
    if seen[candidate] then
      return
    end

    seen[candidate] = true
    table.insert(candidates, candidate)
  end

  local normalized = normalizeName(pokemonName)
  addCandidate(normalized)
  addCandidate(POKEMON_NAME_ALIASES[normalized])
  addCandidate(normalized:gsub('_', ' '))

  local alias = POKEMON_NAME_ALIASES[normalized]
  if alias then
    addCandidate(alias:gsub('_', ' '))
  end

  return candidates
end

local function resetDexCache()
  cacheData.unlocked = {}
  cacheData.caught = {}
  cacheData.entries = {}
  cacheData.details = {}
  cacheData.shinyDetails = {}
  cacheData.loots = {}
  cacheData.lootLoaded = {}
  cacheData.lootPending = {}
end

local function ensureEntry(details)
  if not details or not details.pokemonName then
    return
  end

  local normalized = normalizeName(details.pokemonName)
  for _, entry in ipairs(cacheData.entries) do
    if normalizeName(entry.pokemonName) == normalized then
      entry.id = details.id or entry.id or 0
      entry.formatedId = details.formatedId or entry.formatedId or '000'
      entry.name = details.displayName or details.name or entry.name or formatDisplayName(normalized)
      entry.pokemonName = normalized
      table.sort(cacheData.entries, function(a, b)
        return tonumber(a.formatedId or 0) < tonumber(b.formatedId or 0)
      end)
      return
    end
  end

  table.insert(cacheData.entries, {
    id = details.id or 0,
    formatedId = details.formatedId or '000',
    name = details.displayName or formatDisplayName(normalized),
    pokemonName = normalized
  })

  table.sort(cacheData.entries, function(a, b)
    return tonumber(a.formatedId or 0) < tonumber(b.formatedId or 0)
  end)
end

local function getEntryByName(pokemonName)
  local normalized = normalizeName(pokemonName)
  for _, entry in ipairs(cacheData.entries) do
    if normalizeName(entry.pokemonName) == normalized then
      return entry
    end
  end
  return nil
end

local function getPokedexItem()
  local item = g_game.findPlayerItem(POKEDEX_ITEM_ID, -1)
  if item then
    return item
  end

  return nil
end

local function mergeEntries(entries)
  for _, entry in ipairs(entries or {}) do
    ensureEntry(entry)
  end
end

local function mergeDetails(details)
  for pokemonName, info in pairs(details or {}) do
    local normalized = normalizeName(pokemonName)
    cacheData.details[normalized] = info
    ensureEntry(info)
  end
end

local function stopChoosePokemon()
  if not mouseGrabberWidget then
    return
  end

  if g_ui.isMouseGrabbed() then
    mouseGrabberWidget:ungrabMouse()
    g_mouse.popCursor('target')
  end
end

local function openPokedexInstant(pokemonName)
  local normalized = pokemonName and normalizeName(pokemonName) or nil

  if normalized and normalized ~= '' then
    ensureEntry({
      pokemonName = normalized,
      displayName = formatDisplayName(normalized),
      formatedId = '000'
    })
    renderList()
    selectedPokemonName = normalized
  end

  onOpen()

  if normalized and normalized ~= '' then
    selectPokemon(normalized)
  end
end

local function requestPokemonScanByClick(clickedWidget, mousePosition)
  local creature = nil

  if clickedWidget:getClassName() == 'UIGameMap' then
    local tile = clickedWidget:getTile(mousePosition)
    if tile then
      creature = tile:getTopCreatureEx(clickedWidget:getPositionOffset(mousePosition))
    end
  elseif clickedWidget:getClassName() == 'UICreatureButton' then
    creature = clickedWidget:getCreature()
  end

  if creature and creature:getName() then
    openPokedexInstant(creature:getName())
    protocol.sendViewPokemonRequest(creature:getName())
    return true
  end

  onOpen()
  protocol.sendOpenPokedexRequest()
  return false
end

local function onChoosePokemonMouseRelease(self, mousePosition, mouseButton)
  if mouseButton == MouseTouch then
    return false
  end

  if mouseButton == MouseLeftButton then
    local rootPanel = modules.game_interface and modules.game_interface.getRootPanel and modules.game_interface.getRootPanel() or nil
    if rootPanel then
      local clickedWidget = rootPanel:recursiveGetChildByPos(mousePosition, false)
      if clickedWidget then
        requestPokemonScanByClick(clickedWidget, mousePosition)
      else
        protocol.sendOpenPokedexRequest()
      end
    end
  end

  stopChoosePokemon()
  return true
end

local function getPokemonImagePath(pokemonName, shiny)
  local prefix = shiny and 'shiny ' or ''
  local candidates = {}

  for _, candidate in ipairs(buildPokemonNameCandidates(pokemonName)) do
    table.insert(candidates, '/images/game/pokedex/' .. prefix .. candidate)
    table.insert(candidates, '/images/game/pokedex/pokemon/' .. prefix .. candidate)
    table.insert(candidates, '/images/game/pokemon/' .. prefix .. candidate)
  end

  for _, path in ipairs(candidates) do
    if g_resources.fileExists(path .. '.png') or g_resources.fileExists(path .. '.PNG') then
      return path
    end
  end

  return nil
end

local function normalizeTypeName(typeName)
  if not typeName or typeName == '' or typeName == false then
    return nil
  end

  local normalized = tostring(typeName):lower()
  return normalized:gsub('^(%l)', string.upper)
end

local function getMoveTypeIconPath(typeName)
  local normalized = normalizeTypeName(typeName)
  if not normalized then
    return '/images/game/pokedex/types/Normal'
  end

  local imagePath = '/images/game/pokedex/types/' .. normalized
  if g_resources.fileExists(imagePath .. '.png') then
    return imagePath
  end

  return '/images/game/pokedex/types/Normal'
end

local function getMoveIconPath(moveName)
  if not moveName or moveName == '' then
    return '/images/game/pokedex/types/Normal'
  end

  local baseName = tostring(moveName)
  local candidates = {
    '/images/game/pokedex/moves_icon/' .. baseName .. '_on',
    '/images/game/pokedex/moves_icon/' .. baseName .. '_off',
    '/images/game/pokedex/moves_icon/' .. baseName,
  }

  for _, path in ipairs(candidates) do
    if g_resources.fileExists(path .. '.png') or g_resources.fileExists(path .. '.PNG') then
      return path
    end
  end

  return '/images/game/pokedex/types/Normal'
end

local function formatMoveCooldown(cooldown)
  local seconds = tonumber(cooldown) or 0
  return string.format('Cooldown: %ss', seconds)
end

local function clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end

  if value > maximum then
    return maximum
  end

  return value
end

local function formatStatValue(value)
  local numericValue = tonumber(value) or 0
  if numericValue == math.floor(numericValue) then
    return tostring(math.floor(numericValue))
  end

  return string.format('%.1f', numericValue)
end

local function setInfoLabelsVisible(visible)
  local widgets = { infoLevel, infoAbility, infoDescription, infoPrice }
  for _, widget in ipairs(widgets) do
    if widget then
      widget:setVisible(visible)
    end
  end

  if statsPanel then
    statsPanel:setVisible(not visible and currentTab == 'stats')
  end

  if evolutionsPanel then
    evolutionsPanel:setVisible(not visible and currentTab == 'evo')
  end

  if dropsPanel then
    dropsPanel:setVisible(not visible and currentTab == 'pokeball')
  end
end

local function renderMoves(details, unlocked)
  if not movesPanel then
    return
  end

  movesPanel:setVisible(currentTab == 'moves')
  setInfoLabelsVisible(currentTab ~= 'moves')

  movesPanel:destroyChildren()

  if currentTab ~= 'moves' then
    return
  end

  if not unlocked then
    local row = g_ui.createWidget('PokedexMoveRow', movesPanel)
    row.icon:setImageSource('/images/game/pokedex/types/Normal')
    row.name:setText('Scan this pokemon to unlock its moves')
    row.cooldown:setText('')
    row.typeIcon:setImageSource('/images/game/pokedex/types/Normal')
    return
  end

  local moves = details.moves or {}
  if #moves == 0 then
    local row = g_ui.createWidget('PokedexMoveRow', movesPanel)
    row.icon:setImageSource('/images/game/pokedex/types/Normal')
    row.name:setText('No moves available')
    row.cooldown:setText('')
    row.typeIcon:setImageSource('/images/game/pokedex/types/Normal')
    return
  end

  for _, move in ipairs(moves) do
    local row = g_ui.createWidget('PokedexMoveRow', movesPanel)
    row.icon:setImageSource(getMoveIconPath(move.name))
    row.name:setText(tostring(move.name or 'Unknown Move'))
    row.cooldown:setText(formatMoveCooldown(move.cooldown))
    row.typeIcon:setImageSource(getMoveTypeIconPath(move.type))
  end
end

local function renderStats(details, unlocked)
  if not statsPanel then
    return
  end

  statsPanel:setVisible(currentTab == 'stats')
  statsPanel:destroyChildren()

  if currentTab ~= 'stats' then
    return
  end

  for _, stat in ipairs(STAT_DEFINITIONS) do
    local row = g_ui.createWidget('PokedexStatRow', statsPanel)
    local value = unlocked and (tonumber(details[stat.key]) or 0) or 0
    local percent = math.floor(clamp((value / stat.max) * 100, 0, 100))
    local nameLabel = row:recursiveGetChildById('name')
    local progressBar = row:recursiveGetChildById('progress')

    if nameLabel then
      nameLabel:setText(stat.label)
    end

    if progressBar then
      progressBar:setPercent(percent)
      progressBar:setTooltip(string.format('%s: %s', stat.label, unlocked and formatStatValue(value) or 'Unknown'))
    end
  end
end

local function renderEvolutions(details, unlocked)
  if not evolutionsPanel then
    return
  end

  evolutionsPanel:setVisible(currentTab == 'evo')
  evolutionsPanel:destroyChildren()

  if currentTab ~= 'evo' then
    return
  end

  local evolutions = unlocked and (details.evolutions or {}) or {}
  if #evolutions == 0 then
    local row = g_ui.createWidget('PokedexEvolutionRow', evolutionsPanel)
    local numberLabel = row:recursiveGetChildById('number')
    local nameLabel = row:recursiveGetChildById('name')
    local levelLabel = row:recursiveGetChildById('level')
    local imageWidget = row:recursiveGetChildById('image')

    if numberLabel then numberLabel:setText('') end
    if nameLabel then nameLabel:setText(unlocked and 'This pokemon has no further evolutions' or 'Scan this pokemon to unlock its evolutions') end
    if levelLabel then levelLabel:setText('') end
    if imageWidget then imageWidget:setImageSource('') end
    return
  end

  for _, evolution in ipairs(evolutions) do
    local row = g_ui.createWidget('PokedexEvolutionRow', evolutionsPanel)
    local imageWidget = row:recursiveGetChildById('image')
    local numberLabel = row:recursiveGetChildById('number')
    local nameLabel = row:recursiveGetChildById('name')
    local levelLabel = row:recursiveGetChildById('level')
    local imagePath = getPokemonImagePath(evolution.displayName or evolution.pokemonName, evolution.isShiny)

    if imageWidget then
      imageWidget:setImageSource(imagePath or '')
    end

    if numberLabel then
      numberLabel:setText('#' .. tostring(evolution.formatedId or '000'))
    end

    if nameLabel then
      nameLabel:setText(tostring(evolution.displayName or 'Unknown'))
    end

    if levelLabel then
      levelLabel:setText('Need Level: ' .. tostring(evolution.level or 0))
    end
  end
end

local function formatDropChance(chance)
  local numericChance = tonumber(chance) or 0

  if numericChance > 100 then
    numericChance = numericChance / 100
  end

  if numericChance >= 1 then
    return string.format('%.0f%%', numericChance)
  end

  if numericChance > 0 then
    return string.format('%.2f%%', numericChance)
  end

  return '0%'
end

local function renderDrops(details, unlocked)
  if not dropsPanel then
    return
  end

  dropsPanel:setVisible(currentTab == 'pokeball')
  dropsPanel:destroyChildren()

  if currentTab ~= 'pokeball' then
    return
  end

  if not unlocked then
    local row = g_ui.createWidget('PokedexDropRow', dropsPanel)
    row.item:setItem(nil)
    row.name:setText('Scan this pokemon to unlock its drops')
    row.count:setText('')
    row.chance:setText('')
    return
  end

  local normalized = normalizeName(details.pokemonName)
  local loots = cacheData.loots[normalized] or {}
  local lootLoaded = cacheData.lootLoaded[normalized]

  if not lootLoaded then
    if not cacheData.lootPending[normalized] then
      cacheData.lootPending[normalized] = true
      protocol.sendViewPokemonLoot(details.pokemonName)
    end

    local row = g_ui.createWidget('PokedexDropRow', dropsPanel)
    row.item:setItem(nil)
    row.name:setText('Loading drops...')
    row.count:setText('')
    row.chance:setText('')
    return
  end

  if #loots == 0 then
    local row = g_ui.createWidget('PokedexDropRow', dropsPanel)
    row.item:setItem(nil)
    row.name:setText('No drops available')
    row.count:setText('')
    row.chance:setText('')
    return
  end

  for index, loot in ipairs(loots) do
    local row = g_ui.createWidget('PokedexDropRow', dropsPanel)
    row:setOn(index % 2 == 0)
    local clientId = tonumber(loot.clientId) or 0
    local displayId = clientId
    row.item:setItemId(displayId)
    row.name:setText(tostring(loot.name or 'Unknown item'))
    row.count:setText((tonumber(loot.count) or 1) > 1 and ('Amount: ' .. tostring(loot.count)) or '')
    row.chance:setText(formatDropChance(loot.chance))
  end
end

local function applyTypeIcons(details, unlocked)
  local typeWidgets = { infoTypeIcon1, infoTypeIcon2 }
  local typeNames = {
    normalizeTypeName(details.type1),
    normalizeTypeName(details.type2)
  }

  for index, widget in ipairs(typeWidgets) do
    if widget then
      local typeName = typeNames[index]
      local imagePath = typeName and '/images/game/pokedex/types/' .. typeName or nil
      if unlocked and imagePath and g_resources.fileExists(imagePath .. '.png') then
        widget:setImageSource(imagePath)
        widget:show()
      else
        widget:setImageSource('')
        widget:hide()
      end
    end
  end
end

local function updateShinyButton(details, unlocked)
  if not shinyToggleButton then
    return
  end

  local shinyImagePath = details and getPokemonImagePath(details.pokemonName, true) or nil
  shinyToggleButton:setVisible(unlocked)
  shinyToggleButton:setOn(unlocked and currentImageVariant == 'shiny')
  shinyToggleButton:setOpacity(shinyImagePath and 1 or 0.45)
end

local function toggleDexImageVariant()
  if not selectedPokemonName then
    return
  end

  local details = cacheData.details[selectedPokemonName] or { pokemonName = selectedPokemonName }
  local shinyImagePath = getPokemonImagePath(details.pokemonName, true)
  if not shinyImagePath then
    currentImageVariant = 'normal'
    renderInfo(selectedPokemonName)
    return
  end

  currentImageVariant = currentImageVariant == 'shiny' and 'normal' or 'shiny'

  if currentImageVariant == 'shiny' and not cacheData.shinyDetails[selectedPokemonName] then
    protocol.sendViewPokemonRequest(selectedPokemonName, { shinyPreview = true })
  end

  renderInfo(selectedPokemonName)
end

local function updateCounters()
  if not countLabel then
    return
  end

  local unlocked = 0
  local caught = 0
  for _ in pairs(cacheData.unlocked) do unlocked = unlocked + 1 end
  for _ in pairs(cacheData.caught) do caught = caught + 1 end
  countLabel:setText(string.format('Seen %d   Caught %d', unlocked, caught))
end

local function updateListSelectionState()
  if not listPanel then
    return
  end

  for _, child in ipairs(listPanel:getChildren()) do
    local isSelected = child:getId() == selectedPokemonName
    child:setOn(isSelected)
    if child.label then
      child.label:setColor(isSelected and '#4d7cff' or '#f4f4f5')
    end
  end
end

local function applyTabState()
  if not dexWindow then
    return
  end

  local buttons = {
    info = dexWindow:recursiveGetChildById('infoTabButton'),
    moves = dexWindow:recursiveGetChildById('movesTabButton'),
    stats = dexWindow:recursiveGetChildById('statsTabButton'),
    evo = dexWindow:recursiveGetChildById('evoTabButton'),
    pokeball = dexWindow:recursiveGetChildById('pokeballTabButton')
  }

  for tab, button in pairs(buttons) do
    if button then
      local isActive = tab == currentTab
      button:setOn(isActive)
      button:setColor(isActive and '#4d7cff' or '#7f7f7f')
      button:setImageColor(isActive and '#4d7cff' or '#7f7f7f')
    end
  end

  if sectionTitle then
    sectionTitle:setText(TAB_TITLES[currentTab] or 'Information')
  end
end

local function bindTabHoverHandlers()
  if not dexWindow then
    return
  end

  local buttons = {
    info = dexWindow:recursiveGetChildById('infoTabButton'),
    moves = dexWindow:recursiveGetChildById('movesTabButton'),
    stats = dexWindow:recursiveGetChildById('statsTabButton'),
    evo = dexWindow:recursiveGetChildById('evoTabButton'),
    pokeball = dexWindow:recursiveGetChildById('pokeballTabButton')
  }

  for tab, button in pairs(buttons) do
    if button then
      button.onHoverChange = function(widget, hovered)
        local isActive = tab == currentTab
        if hovered and not isActive then
          widget:setColor('#ededed')
          widget:setImageColor('#ededed')
        else
          widget:setColor(isActive and '#4d7cff' or '#7f7f7f')
          widget:setImageColor(isActive and '#4d7cff' or '#7f7f7f')
        end
      end
    end
  end
end

local function renderTabContent(details, unlocked, caught)
  local priceText = string.format('NPC Price ($%s).', tostring(details.price or 0))

  if currentTab == 'moves' then
    renderMoves(details, unlocked)
    return
  end

  renderMoves(details, unlocked)

  if currentTab == 'stats' then
    setInfoLabelsVisible(false)
    renderStats(details, unlocked)
    return
  end

  renderStats(details, unlocked)

  if currentTab == 'evo' then
    setInfoLabelsVisible(false)
    renderEvolutions(details, unlocked)
    return
  end

  renderEvolutions(details, unlocked)

  if currentTab == 'pokeball' then
    setInfoLabelsVisible(false)
    renderDrops(details, unlocked)
    return
  end

  renderDrops(details, unlocked)

  infoStatus:setText(caught and 'Status: caught' or (unlocked and 'Status: registered' or 'Status: unknown'))
  infoLevel:setText('Level: ' .. tostring(details.level or 0) .. '.')
  infoAbility:setText('Ability: ' .. tostring(details.abilities or 'None') .. '.')
  infoDescription:setText(unlocked and tostring(details.description or 'No description.') or 'Scan this pokemon with the pokedex to unlock its information.')
  infoPrice:setText(priceText)
end

function renderInfo(pokemonName)
  local key = normalizeName(pokemonName)
  local entry = getEntryByName(key) or {}
  local normalDetails = cacheData.details[key] or {
    pokemonName = key,
    displayName = entry.name or formatDisplayName(key),
    baseDisplayName = entry.name or formatDisplayName(key),
    formatedId = entry.formatedId or '000',
    level = 0,
    abilities = 'None',
    description = 'No description.',
    price = 0
  }
  local details = currentImageVariant == 'shiny' and (cacheData.shinyDetails[key] or normalDetails) or normalDetails

  local caught = cacheData.caught[key] or details.catch
  local unlocked = cacheData.unlocked[key] or caught
  local wantsShinyImage = currentImageVariant == 'shiny'
  local imagePath = getPokemonImagePath(details.pokemonName or key, wantsShinyImage)

  if not imagePath and wantsShinyImage then
    imagePath = getPokemonImagePath(key, false)
  end

  infoName:setText(unlocked and (details.displayName or details.baseDisplayName or formatDisplayName(key)) or '???')
  infoNumber:setText('#' .. tostring(details.formatedId or '000'))
  if tabHintLabel then
    tabHintLabel:setText(unlocked and 'Ctrl+D to scan another pokemon' or 'Use the pokedex on this pokemon to unlock its data')
  end

  renderTabContent(details, unlocked, caught)

  if imagePath and unlocked then
    infoImage:setImageSource(imagePath)
    infoImage:show()
  else
    infoImage:setImageSource('')
    infoImage:hide()
  end

  applyTypeIcons(details, unlocked)
  updateShinyButton(details, unlocked)
end

selectPokemon = function(pokemonName)
  currentImageVariant = 'normal'
  selectedPokemonName = normalizeName(pokemonName)
  updateListSelectionState()

  if cacheData.unlocked[selectedPokemonName] or cacheData.caught[selectedPokemonName] then
    if not cacheData.details[selectedPokemonName] then
      protocol.sendViewPokemonRequest(selectedPokemonName)
      return
    end
  end

  renderInfo(selectedPokemonName)
end

local function getInitialSelection()
  for _, entry in ipairs(cacheData.entries) do
    local normalized = normalizeName(entry.pokemonName)
    if cacheData.caught[normalized] or cacheData.unlocked[normalized] then
      return normalized
    end
  end

  if cacheData.entries[1] then
    return normalizeName(cacheData.entries[1].pokemonName)
  end

  return nil
end

renderList = function()
  if not listPanel then
    return
  end

  local search = ''
  if searchEdit then
    search = searchEdit:getText():lower()
  end

  listPanel:destroyChildren()

  for _, entry in ipairs(cacheData.entries) do
    local normalized = normalizeName(entry.pokemonName)
    local isKnown = cacheData.unlocked[normalized] or cacheData.caught[normalized]
    local displayName = isKnown and entry.name or '???'
    local rowText = string.format('#%s %s', entry.formatedId or '000', displayName)

    if search == '' or string.find(normalized, search, 1, true) or string.find(string.lower(entry.name or ''), search, 1, true) then
      local row = g_ui.createWidget('PokedexEntryRow', listPanel)
      row:setId(normalized)
      row:setWidth(listPanel:getWidth())
      row.label:setText(rowText)
      local selectEntry = function()
        selectPokemon(normalized)
      end
      row.onMouseRelease = function(widget, mousePosition, mouseButton)
        if mouseButton == MouseLeftButton then
          selectEntry()
          return true
        end
        return false
      end
      if row.label then
        row.label.onMouseRelease = function(widget, mousePosition, mouseButton)
          if mouseButton == MouseLeftButton then
            selectEntry()
            return true
          end
          return false
        end
      end
    end
  end

  updateListSelectionState()
end

local function startPokedexCrosshair()
  if not g_game.isOnline() then
    return
  end

  if g_ui.isMouseGrabbed() then
    return
  end

  if not mouseGrabberWidget then
    return
  end

  mouseGrabberWidget:grabMouse()
  g_mouse.pushCursor('target')
end

local function onData(unlockedPokemons, caughtPokemons, entries, details, meta)
  meta = meta or {}
  hasReceivedDexData = true

  if meta.reset then
    resetDexCache()
    cacheData.unlocked = unlockedPokemons or {}
    cacheData.caught = caughtPokemons or {}
  else
    if unlockedPokemons then
      cacheData.unlocked = unlockedPokemons
    end

    if caughtPokemons then
      cacheData.caught = caughtPokemons
    end
  end

  mergeEntries(entries)
  mergeDetails(details)
  updateCounters()
  renderList()

  if not selectedPokemonName then
    local initialSelection = getInitialSelection()
    if initialSelection then
      selectPokemon(initialSelection)
    end
  else
    renderInfo(selectedPokemonName)
  end
end

onOpen = function()
  if dexWindow then
    if not hasReceivedDexData and #cacheData.entries == 0 then
      requestInitialDexData()
    end

    if not selectedPokemonName then
      local initialSelection = getInitialSelection()
      if initialSelection then
        selectPokemon(initialSelection)
      end
    end

    dexWindow:show()
    dexWindow:raise()
    dexWindow:focus()
  end
end

local function onView(params)
  if not params or not params.pokemonName then
    return
  end

  local normalized = normalizeName(params.pokemonName)
  if params.isShiny then
    cacheData.shinyDetails[normalized] = params
  else
    cacheData.details[normalized] = params
    cacheData.unlocked[normalized] = true
    if params.catch then
      cacheData.caught[normalized] = true
    end
  end

  ensureEntry(params)
  updateCounters()
  renderList()

  if params.isShiny then
    if selectedPokemonName == normalized then
      renderInfo(normalized)
    end
    return
  end

  if dexWindow and dexWindow:isVisible() then
    selectPokemon(normalized)
  elseif selectedPokemonName == normalized then
    renderInfo(normalized)
  end
end

local function onUpdate(params)
  if not params or not params.pokemonName then
    return
  end

  local normalized = normalizeName(params.pokemonName)
  if params.isShiny then
    cacheData.shinyDetails[normalized] = params
    if selectedPokemonName == normalized then
      renderInfo(normalized)
    end
    return
  end

  cacheData.details[normalized] = params
  cacheData.unlocked[normalized] = true
  if params.catch then
    cacheData.caught[normalized] = true
  end

  ensureEntry(params)
  updateCounters()
  renderList()

  if selectedPokemonName == normalized then
    renderInfo(normalized)
  elseif not selectedPokemonName then
    local initialSelection = getInitialSelection()
    if initialSelection then
      selectedPokemonName = initialSelection
      renderInfo(selectedPokemonName)
    end
  end
end

local function onLoot(pokemonName, loots)
  local normalized = normalizeName(pokemonName)
  cacheData.loots[normalized] = loots or {}
  cacheData.lootLoaded[normalized] = true
  cacheData.lootPending[normalized] = nil

  if selectedPokemonName == normalized and currentTab == 'pokeball' then
    renderInfo(normalized)
  end
end

local function onSearch()
  renderList()
end

local function onGameStart()
end

local function requestInitialDexData()
  if not g_game.isOnline() then
    return
  end

  if hasReceivedDexData then
    return
  end

  protocol.sendDataRequest()
end

local function offline()
  if preloadEvent then
    removeEvent(preloadEvent)
    preloadEvent = nil
  end

  if dexWindow then
    dexWindow:hide()
  end

  hasReceivedDexData = false
  selectedPokemonName = nil
  currentImageVariant = 'normal'
  currentTab = 'info'
  resetDexCache()

  if searchEdit then
    searchEdit:setText('')
  end

  applyTabState()
  updateCounters()
  renderList()
end

function toggleDexVariant()
  toggleDexImageVariant()
end

function onDexTabChange(tab)
  currentTab = tab
  applyTabState()
  if not selectedPokemonName or selectedPokemonName == '' then
    local initialSelection = getInitialSelection()
    if initialSelection then
      selectedPokemonName = initialSelection
    end
  end

  if selectedPokemonName and selectedPokemonName ~= '' then
    renderInfo(selectedPokemonName)
  end
end

function init()
  protocol.initProtocol()

  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = offline
  })
  connect(PokeDex, {
    onData = onData,
    onOpen = onOpen,
    onView = onView,
    onUpdate = onUpdate,
    onLoot = onLoot
  })

  dexWindow = g_ui.displayUI('dex')
  dexWindow:hide()

  mouseGrabberWidget = g_ui.createWidget('UIWidget')
  mouseGrabberWidget:setVisible(false)
  mouseGrabberWidget:setFocusable(false)
  mouseGrabberWidget.onMouseRelease = onChoosePokemonMouseRelease

  searchEdit = dexWindow:recursiveGetChildById('searchTextEdit')
  listPanel = dexWindow:recursiveGetChildById('uiPokemonList')
  infoName = dexWindow:recursiveGetChildById('uiPokemonName')
  infoNumber = dexWindow:recursiveGetChildById('uiPokemonNumber')
  infoStatus = dexWindow:recursiveGetChildById('uiPokemonStatus')
  infoLevel = dexWindow:recursiveGetChildById('uiPokemonLevel')
  infoAbility = dexWindow:recursiveGetChildById('uiPokemonAbility')
  infoDescription = dexWindow:recursiveGetChildById('uiPokemonDescription')
  infoPrice = dexWindow:recursiveGetChildById('uiPokemonPrice')
  infoImage = dexWindow:recursiveGetChildById('uiPokemonImage')
  infoTypeIcon1 = dexWindow:recursiveGetChildById('uiPokemonType1')
  infoTypeIcon2 = dexWindow:recursiveGetChildById('uiPokemonType2')
  movesPanel = dexWindow:recursiveGetChildById('uiPokemonMovesPanel')
  statsPanel = dexWindow:recursiveGetChildById('uiPokemonStatsPanel')
  evolutionsPanel = dexWindow:recursiveGetChildById('uiPokemonEvolutionsPanel')
  dropsPanel = dexWindow:recursiveGetChildById('uiPokemonDropsPanel')
  shinyToggleButton = dexWindow:recursiveGetChildById('shinyToggleButton')
  countLabel = dexWindow:recursiveGetChildById('uiCountLabel')
  sectionTitle = dexWindow:recursiveGetChildById('sectionTitle')
  tabHintLabel = dexWindow:recursiveGetChildById('tabHintLabel')

  searchEdit.onTextChange = function()
    onSearch()
  end

  bindTabHoverHandlers()
  applyTabState()
  updateCounters()

  dexButton = modules.client_topmenu.addTopGameToggleButton('pokedexButton', tr('Pokedex (Ctrl+D)'), '/images/topbuttons/pokedex', startPokedexCrosshair, false, 3)
  g_keyboard.bindKeyDown('Ctrl+D', startPokedexCrosshair)

end

function terminate()
  protocol.terminateProtocol()
  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = offline
  })
  disconnect(PokeDex, {
    onData = onData,
    onOpen = onOpen,
    onView = onView,
    onUpdate = onUpdate,
    onLoot = onLoot
  })
  g_keyboard.unbindKeyDown('Ctrl+D')
  stopChoosePokemon()

  if dexButton then dexButton:destroy() dexButton = nil end
  if mouseGrabberWidget then mouseGrabberWidget:destroy() mouseGrabberWidget = nil end
  if dexWindow then dexWindow:destroy() dexWindow = nil end
end









