-- chunkname: @/modules/game_tv/tv.lua

local TV_OPCODE = 125
local TV_BLOCK_OPCODE = 126

local isWatchingTV = false
local isStreamingTV = false
local streamingWindow, watchingWindow, tvCamWindow, tvChannelsWindow, changeChannelPasswordWindow, changeChannelNameWindow, channelBannedListWindow
local channelList = {}
local protocolGame = nil
local streamingSeconds = 0
local streamingUpdateEvent = nil
local spectatorsCount = 0
local currentWatchedPlayer = nil
local currentWatchedChannelId = nil
local currentWatchedPosition = nil
local pendingWatchPlayer = nil
local streamingChannelName = nil
local streamingShowPokemons = true
local watchingFollowEvent = nil
local watchingPokemonNames = {}

local function safeHide(widget)
  if widget then
    widget:hide()
  end
end

local function safeLoadUI(path, parent)
  local ok, widget = pcall(g_ui.loadUI, path, parent)
  if ok then
    return widget
  end

  return nil
end

local function bindChild(window, fieldName)
  if not window then
    return nil
  end

  if window[fieldName] then
    return window[fieldName]
  end

  if window.recursiveGetChildById then
    window[fieldName] = window:recursiveGetChildById(fieldName)
  end

  return window[fieldName]
end

local function bindWindowFields(window, fieldNames)
  if not window then
    return
  end

  for _, fieldName in ipairs(fieldNames) do
    bindChild(window, fieldName)
  end
end


local function getMapPanel()
  return modules.game_interface and modules.game_interface.getMapPanel and modules.game_interface.getMapPanel()
end

local function clonePosition(pos)
  if not pos then
    return nil
  end

  return { x = pos.x, y = pos.y, z = pos.z }
end

local function parseWatchedPosition(payload)
  if not payload or payload == '' then
    return nil
  end

  local parts = string.explode(payload, ',')
  local x = tonumber(parts[1])
  local y = tonumber(parts[2])
  local z = tonumber(parts[3])
  if not x or not y or not z then
    return nil
  end

  return { x = x, y = y, z = z }
end

local function findCreatureNearPosition(name, position)
  if not name or name == '' or not position then
    return nil
  end

  local spectators = g_map.getSpectators(position, false)
  for _, creature in ipairs(spectators or {}) do
    if creature and creature.getName and creature:getName() == name then
      return creature
    end
  end

  return nil
end

local function findCreatureByName(name)
  if not name or name == '' then
    return nil
  end

  local localPlayer = g_game.getLocalPlayer()
  local mapPanel = getMapPanel()
  local searchPositions = {}

  if currentWatchedPosition then
    table.insert(searchPositions, currentWatchedPosition)
  end

  if localPlayer and localPlayer.getPosition then
    table.insert(searchPositions, localPlayer:getPosition())
  end

  if mapPanel and mapPanel.getCameraPosition then
    table.insert(searchPositions, mapPanel:getCameraPosition())
  end

  for _, position in ipairs(searchPositions) do
    local creature = findCreatureNearPosition(name, position)
    if creature then
      return creature
    end
  end

  return nil
end

local function applyWatchingCamera(watchedCreature)
  local mapPanel = getMapPanel()
  if not mapPanel then
    return false
  end

  if watchedCreature then
    if watchedCreature.getPosition then
      currentWatchedPosition = clonePosition(watchedCreature:getPosition())
    end

    if mapPanel.followCreature then
      mapPanel:followCreature(watchedCreature)
    end

    if currentWatchedPosition and mapPanel.setCameraPosition then
      mapPanel:setCameraPosition(currentWatchedPosition)
    end

    return true
  end

  if currentWatchedPosition and mapPanel.setCameraPosition then
    mapPanel:setCameraPosition(currentWatchedPosition)
    return true
  end

  return false
end

local function stopWatchingFollow()
  if watchingFollowEvent then
    removeEvent(watchingFollowEvent)
    watchingFollowEvent = nil
  end

  local mapPanel = getMapPanel()
  local localPlayer = g_game.getLocalPlayer()
  if mapPanel and localPlayer and mapPanel.followCreature then
    mapPanel:followCreature(localPlayer)
  end
end

local function refreshWatchingFollow()
  if not isWatchingTV or not currentWatchedPlayer then
    stopWatchingFollow()
    return
  end

  local watchedCreature = findCreatureByName(currentWatchedPlayer)
  applyWatchingCamera(watchedCreature)
  watchingFollowEvent = scheduleEvent(refreshWatchingFollow, watchedCreature and 75 or 120)
end

local function startWatchingFollow()
  stopWatchingFollow()
  if isWatchingTV and currentWatchedPlayer then
    refreshWatchingFollow()
  end
end

local function updateWatchingPokemonPanel()
  if not watchingWindow then
    return
  end

  local pokemonPanel = bindChild(watchingWindow, 'watchingPokemonPanel')
  if not pokemonPanel then
    return
  end

  pokemonPanel:destroyChildren()

  if #watchingPokemonNames == 0 then
    pokemonPanel:hide()
    watchingWindow:setHeight(115)
    return
  end

  for index, pokemonName in ipairs(watchingPokemonNames) do
    if pokemonName and pokemonName ~= '' then
      local portrait = g_ui.createWidget('TVPokemonImage', pokemonPanel)
      local imageSource = type(getPokemonPortrait) == 'function' and getPokemonPortrait(pokemonName) or ''
      portrait:setImageSource(imageSource)
      portrait:setTooltip(pokemonName)
    end
  end

  pokemonPanel:show()
  watchingWindow:setHeight(175)
end
local function stopStreamingTimer()
  if streamingUpdateEvent then
    removeEvent(streamingUpdateEvent)
    streamingUpdateEvent = nil
  end
end

local function formatStreamingTime(totalSeconds)
  local hours = math.floor(totalSeconds / 3600)
  local minutes = math.floor((totalSeconds % 3600) / 60)
  local seconds = totalSeconds % 60
  return string.format('%02d:%02d:%02d', hours, minutes, seconds)
end

local function updateStreamingWindow()
  if not streamingWindow then
    return
  end

  local channelStatusLabel = bindChild(streamingWindow, 'channelStatusLabel')
  local channelTimeLabel = bindChild(streamingWindow, 'channelTimeLabel')
  local spectatorsButton = bindChild(streamingWindow, 'spectatorsButton')
  local channelName = streamingChannelName or '-'

  if channelStatusLabel then
    channelStatusLabel:setText(channelName)
  end

  if channelTimeLabel then
    channelTimeLabel:setText(formatStreamingTime(streamingSeconds))
  end

  if spectatorsButton then
    spectatorsButton:setText(tr('Spectators') .. ' (' .. spectatorsCount .. ')')
  end
end

local function updatePokemonToggleButton()
  local pokemonsButton = streamingWindow and bindChild(streamingWindow, 'pokemonsButton')
  if not pokemonsButton then
    return
  end

  pokemonsButton:setTooltip(streamingShowPokemons and tr('Hide pokemons from spectators') or tr('Show pokemons to spectators'))

  if pokemonsButton.setOn then
    pokemonsButton:setOn(streamingShowPokemons)
  end

  if pokemonsButton.setOpacity then
    pokemonsButton:setOpacity(streamingShowPokemons and 1 or 0.45)
  end
end

local function streamingTimerTick()

  if not isStreamingTV then
    stopStreamingTimer()
    return
  end

  streamingSeconds = streamingSeconds + 1
  updateStreamingWindow()
  streamingUpdateEvent = scheduleEvent(streamingTimerTick, 1000)
end

local function startStreaming(channelName)
  if not streamingWindow then
    return
  end

  isStreamingTV = true
  streamingChannelName = channelName ~= '' and channelName or '-'
  streamingShowPokemons = true
  streamingSeconds = 0
  spectatorsCount = 0
  updateStreamingWindow()
  updatePokemonToggleButton()
  stopStreamingTimer()
  streamingUpdateEvent = scheduleEvent(streamingTimerTick, 1000)
  streamingWindow:show()
  streamingWindow:raise()
  streamingWindow:focus()
end

local function stopStreaming()
  stopStreamingTimer()
  isStreamingTV = false
  streamingSeconds = 0
  spectatorsCount = 0
  streamingChannelName = nil
  streamingShowPokemons = true
  safeHide(streamingWindow)
end

local function resetWatchingState()
  isWatchingTV = false
  currentWatchedPlayer = nil
  currentWatchedChannelId = nil
  pendingWatchPlayer = nil
  watchingPokemonNames = {}
  updateWatchingPokemonPanel()
  safeHide(watchingWindow)
  stopWatchingFollow()
  unlockWalk()
end

local function resetState()
  stopStreaming()
  resetWatchingState()
  safeHide(tvCamWindow)
  safeHide(tvChannelsWindow)
  safeHide(changeChannelPasswordWindow)
  safeHide(changeChannelNameWindow)
  safeHide(channelBannedListWindow)
  channelList = {}
end

local function sendTvOpcode(message)
  if protocolGame then
    protocolGame:sendExtendedOpcode(TV_OPCODE, message)
  end
end

local function hideUnsupportedStreamingControls()
  if not streamingWindow then
    return
  end

  if streamingWindow.changeNameButton then streamingWindow.changeNameButton:hide() end
  if streamingWindow.changePasswordButton then streamingWindow.changePasswordButton:hide() end
  if streamingWindow.bannedListButton then streamingWindow.bannedListButton:hide() end
end

local function getTvChannelTabByChannelId(channelId)
  if not channelId or channelId <= 0 then
    return nil
  end

  if modules.game_console and modules.game_console.getChannelTab then
    local tab = modules.game_console.getChannelTab(channelId)
    if tab then
      return tab
    end
  end

  if modules.game_chat and modules.game_chat.getChannelTab then
    local tab = modules.game_chat.getChannelTab(channelId)
    if tab then
      return tab
    end
  end

  return nil
end

local function getTvChannelTabByName(playerName)
  if not playerName or playerName == '' then
    return nil
  end

  if modules.game_console and modules.game_console.getTab then
    local tab = modules.game_console.getTab(playerName)
    if tab then
      return tab
    end
  end

  if modules.game_chat and modules.game_chat.getTab then
    local tab = modules.game_chat.getTab(playerName)
    if tab then
      return tab
    end
  end

  return nil
end

local function getTvChannelTab()
  return getTvChannelTabByChannelId(currentWatchedChannelId) or getTvChannelTabByName(currentWatchedPlayer)
end

local function focusTvChannelTab(retries)
  retries = retries or 6

  local tab = getTvChannelTab()
  if tab and tab.tabBar and tab.tabBar.selectTab then
    tab.tabBar:selectTab(tab)
    return
  end

  if retries > 0 then
    scheduleEvent(function()
      focusTvChannelTab(retries - 1)
    end, 120)
  end
end

local function closeWatchingChannel()
  if not isWatchingTV then
    safeHide(watchingWindow)
    return
  end

  sendTvOpcode('leave')

  local tab = getTvChannelTab()
  if tab and tab.channelId then
    g_game.leaveChannel(tab.channelId)
    return
  end

  resetWatchingState()
end

local function closeStreamingChannel()
  if isStreamingTV then
    sendTvOpcode('close')
  else
    safeHide(streamingWindow)
  end
end

local function showPasswordRequest(playerName)
  if not changeChannelPasswordWindow then
    return
  end

  local channelPasswordLabel = bindChild(changeChannelPasswordWindow, 'channelPasswordLabel')
  local textEdit = bindChild(changeChannelPasswordWindow, 'channelPasswordTextEdit')
  local okButton = bindChild(changeChannelPasswordWindow, 'okButton')
  local cancelButton = bindChild(changeChannelPasswordWindow, 'cancelButton')
  if not channelPasswordLabel or not textEdit or not okButton or not cancelButton then
    return
  end

  changeChannelPasswordWindow:setText(tr('Channel Password'))
  channelPasswordLabel:setText(tr('Password for %s', playerName))
  textEdit:setText('')
  textEdit:focus()

  okButton.onClick = function()
    local password = textEdit:getText():trim()
    if password == '' then
      displayErrorBox(tr('TV Cam'), tr('Enter the channel password.'))
      return
    end

    pendingWatchPlayer = playerName
    sendTvOpcode('watchWithPass/' .. playerName .. '/' .. password)
    changeChannelPasswordWindow:hide()
  end

  cancelButton.onClick = function()
    pendingWatchPlayer = nil
    changeChannelPasswordWindow:hide()
  end

  changeChannelPasswordWindow:show()
  changeChannelPasswordWindow:raise()
  changeChannelPasswordWindow:focus()
end

local function showCreateWindow()
  if not tvCamWindow then
    return
  end

  local channelNameTextEdit = bindChild(tvCamWindow, 'channelNameTextEdit')
  local channelPasswordCheckbox = bindChild(tvCamWindow, 'channelPasswordCheckbox')
  local channelPasswordTextEdit = bindChild(tvCamWindow, 'channelPasswordTextEdit')
  if not channelNameTextEdit or not channelPasswordCheckbox or not channelPasswordTextEdit then
    return
  end

  channelNameTextEdit:setText('')
  channelPasswordCheckbox:setChecked(false)
  channelPasswordTextEdit:setText('')
  channelPasswordTextEdit:setEnabled(false)
  tvCamWindow:show()
  tvCamWindow:raise()
  tvCamWindow:focus()
  channelNameTextEdit:focus()
end

local function createChannel()
  if not protocolGame or not tvCamWindow then
    return
  end

  local channelNameTextEdit = bindChild(tvCamWindow, 'channelNameTextEdit')
  local channelPasswordCheckbox = bindChild(tvCamWindow, 'channelPasswordCheckbox')
  local channelPasswordTextEdit = bindChild(tvCamWindow, 'channelPasswordTextEdit')
  if not channelNameTextEdit or not channelPasswordCheckbox or not channelPasswordTextEdit then return end
  local channelName = channelNameTextEdit:getText():trim()
  if #channelName < 6 or #channelName > 11 then
    displayErrorBox(tr('TV Cam'), tr('The channel name must contain 6 to 11 characters.'))
    return
  end

  local password = 'notASSenha'
  if channelPasswordCheckbox:isChecked() then
    password = channelPasswordTextEdit:getText():trim()
    if password == '' then
      displayErrorBox(tr('TV Cam'), tr('Enter a password or disable password protection.'))
      return
    end
  end

  sendTvOpcode('create/' .. channelName .. '/' .. password)
  tvCamWindow:hide()
end

local function parseChannelList(buffer)
  channelList = {}

  for _, entry in ipairs(string.explode(buffer or '', '|')) do
    local parts = string.explode(entry, '/')
    local broadcaster = parts[1]
    local channelName = parts[2] or ''
    local password = parts[3] or 'notASSenha'

    if broadcaster and broadcaster ~= '' then
      table.insert(channelList, {
        broadcaster = broadcaster,
        name = channelName ~= '' and channelName or broadcaster,
        password = password,
        protected = password ~= '' and password ~= 'notASSenha',
        search = (broadcaster .. ' ' .. channelName):lower()
      })
    end
  end
end

local function showChannelListWindow()
  if not tvChannelsWindow then
    return
  end

  if #channelList == 0 then
    displayInfoBox(tr('TV Cam'), tr('There are no channels online right now.'))
    unlockWalk()
    return
  end

  local searchTextEdit = bindChild(tvChannelsWindow, 'searchTextEdit')
  if not searchTextEdit then
    return
  end

  searchTextEdit:setText('')
  tvChannelsWindow:show()
  tvChannelsWindow:raise()
  tvChannelsWindow:focus()
  lockWalk()
  searchTextEdit:focus()
  tvChannelsSearchOnTextChange(searchTextEdit, '', '')
end

local function enterWatchingMode()
  if not watchingWindow then
    return
  end

  isWatchingTV = true
  currentWatchedPlayer = pendingWatchPlayer or currentWatchedPlayer
  pendingWatchPlayer = nil

  local watchedName = currentWatchedPlayer or '-'
  local statusLabel = bindChild(watchingWindow, 'channelStatusLabel')
  if statusLabel then
    statusLabel:setText(tr('Watching: %s', watchedName))
  end

  updateWatchingPokemonPanel()
  watchingWindow:show()
  watchingWindow:raise()
  watchingWindow:focus()
  lockWalk()
  startWatchingFollow()
  focusTvChannelTab()
end

local function parseTVOpcode(protocol, opcode, buffer)
  if buffer == 'doCreate' then
    showCreateWindow()
    return
  end

  local openAllPrefix = 'openAllTVS|'
  if buffer:sub(1, #openAllPrefix) == openAllPrefix then
    parseChannelList(buffer:sub(#openAllPrefix + 1))
    showChannelListWindow()
    return
  end

  local requestPassPrefix = 'requestPass|'
  if buffer:sub(1, #requestPassPrefix) == requestPassPrefix then
    local parts = string.explode(buffer, '|')
    local playerName = parts[3] or ''
    if playerName ~= '' then
      showPasswordRequest(playerName)
    end
    return
  end

  local channelName = buffer:match('^contar:(.*)$')
  if channelName then
    startStreaming(channelName)
    return
  end

  if buffer == 'closeGraveando' then
    stopStreaming()
    return
  end

  if buffer == 'add' then
    spectatorsCount = spectatorsCount + 1
    updateStreamingWindow()
    return
  end

  if buffer == 'remove' then
    spectatorsCount = math.max(0, spectatorsCount - 1)
    updateStreamingWindow()
    return
  end

  local pokemonVisibilityPrefix = 'pokemonVisibility|'
  if buffer:sub(1, #pokemonVisibilityPrefix) == pokemonVisibilityPrefix then
    streamingShowPokemons = buffer:sub(#pokemonVisibilityPrefix + 1) == '1'
    updatePokemonToggleButton()
    return
  end
end

local function onTvOpenChannel(channelId, channelName)
  local watchedName = pendingWatchPlayer or currentWatchedPlayer
  if not watchedName or watchedName == '' or channelName ~= watchedName then
    return
  end

  currentWatchedChannelId = channelId
  focusTvChannelTab()
end

local function onTvCloseChannel(channelId)
  if isWatchingTV and currentWatchedChannelId and currentWatchedChannelId == channelId then
    resetWatchingState()
  end
end

local function parseTVBlockOpcode(protocol, opcode, buffer)
  if buffer == 'nao' then
    resetWatchingState()
    return
  end

  local parts = string.explode(buffer or '', '|')
  if parts[1] == 'pokemons' then
    watchingPokemonNames = {}
    for _, pokemonName in ipairs(string.explode(parts[2] or '', ',')) do
      pokemonName = pokemonName:trim()
      if pokemonName ~= '' then
        table.insert(watchingPokemonNames, pokemonName)
      end
    end
    updateWatchingPokemonPanel()
    return
  end

  if parts[1] ~= 'sim' then
    return
  end

  currentWatchedPlayer = parts[2] ~= '' and parts[2] or currentWatchedPlayer
  currentWatchedChannelId = nil
  currentWatchedPosition = parseWatchedPosition(parts[4])
  watchingPokemonNames = {}

  for _, pokemonName in ipairs(string.explode(parts[3] or '', ',')) do
    pokemonName = pokemonName:trim()
    if pokemonName ~= '' then
      table.insert(watchingPokemonNames, pokemonName)
    end
  end

  enterWatchingMode()
end

function init()
  g_ui.importStyle('ui/tvstyles')

  streamingWindow = safeLoadUI('ui/channelcontrol_streaming', modules.game_interface.getRightPanel())
  if streamingWindow then
    streamingWindow:setup()
    streamingWindow:hide()
  end

  watchingWindow = safeLoadUI('ui/channelcontrol_watching', modules.game_interface.getRightPanel())
  if watchingWindow then
    watchingWindow:setup()
    watchingWindow:hide()
  end

  tvCamWindow = safeLoadUI('ui/tvcam', rootWidget)
  safeHide(tvCamWindow)

  tvChannelsWindow = safeLoadUI('ui/tvchannels', rootWidget)
  safeHide(tvChannelsWindow)

  changeChannelPasswordWindow = safeLoadUI('ui/changechannelpassword', rootWidget)
  safeHide(changeChannelPasswordWindow)

  changeChannelNameWindow = safeLoadUI('ui/changechannelname', rootWidget)
  safeHide(changeChannelNameWindow)

  channelBannedListWindow = safeLoadUI('ui/channelbannedlist', rootWidget)
  safeHide(channelBannedListWindow)

  bindWindowFields(tvCamWindow, {'cameraItem', 'createButton', 'cancelButton', 'channelNameTextEdit', 'channelPasswordCheckbox', 'channelPasswordTextEdit'})
  bindWindowFields(tvChannelsWindow, {'channelsPanel', 'searchTextEdit'})
  bindWindowFields(changeChannelPasswordWindow, {'channelPasswordLabel', 'channelPasswordTextEdit', 'okButton', 'cancelButton'})
  bindWindowFields(watchingWindow, {'channelStatusLabel', 'watchingPokemonPanel', 'previousChannelButton', 'nextChannelButton'})
  bindWindowFields(streamingWindow, {'channelStatusLabel', 'channelTimeLabel', 'spectatorsButton', 'changeNameButton', 'changePasswordButton', 'bannedListButton', 'pokemonsButton'})

  hideUnsupportedStreamingControls()

  if tvCamWindow and tvCamWindow.cameraItem and tvCamWindow.cameraItem.setItemId then
    tvCamWindow.cameraItem:setItemId(12330)
  end

  if tvCamWindow then
    if tvCamWindow.createButton then
      tvCamWindow.createButton.onClick = createChannel
    end

    if tvCamWindow.cancelButton then
      tvCamWindow.cancelButton.onClick = function()
        tvCamWindow:hide()
      end
    end
  end

  if streamingWindow then
    streamingWindow.onClose = closeStreamingChannel
    if streamingWindow.spectatorsButton then
      streamingWindow.spectatorsButton.onClick = function()
        displayInfoBox(tr('TV Cam'), tr('Spectators: %d', spectatorsCount))
      end
    end
    if streamingWindow.pokemonsButton then
      streamingWindow.pokemonsButton.onClick = function()
        sendTvOpcode('togglePokemons')
      end
      updatePokemonToggleButton()
    end
  end

  if watchingWindow then
    watchingWindow.onClose = closeWatchingChannel
    if watchingWindow.previousChannelButton then
      watchingWindow.previousChannelButton:setText(tr('Close'))
      watchingWindow.previousChannelButton.onClick = closeWatchingChannel
    end
    if watchingWindow.nextChannelButton then
      watchingWindow.nextChannelButton:setText(tr('Info'))
      watchingWindow.nextChannelButton.onClick = function()
        local watchedName = currentWatchedPlayer or '-'
        displayInfoBox(tr('TV Cam'), tr('Watching: %s', watchedName))
      end
    end
  end

  ProtocolGame.registerExtendedOpcode(TV_OPCODE, parseTVOpcode)
  ProtocolGame.registerExtendedOpcode(TV_BLOCK_OPCODE, parseTVBlockOpcode)

  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
    onOpenChannel = onTvOpenChannel,
    onCloseChannel = onTvCloseChannel
  })

  if g_game.isOnline() then
    onGameStart()
  end
end

function terminate()
  stopStreamingTimer()

  if streamingWindow then
    streamingWindow:destroy()
  end

  if watchingWindow then
    watchingWindow:destroy()
  end

  if tvCamWindow then
    tvCamWindow:destroy()
  end

  if tvChannelsWindow then
    tvChannelsWindow:destroy()
  end

  if changeChannelPasswordWindow then
    changeChannelPasswordWindow:destroy()
  end

  if changeChannelNameWindow then
    changeChannelNameWindow:destroy()
  end

  if channelBannedListWindow then
    channelBannedListWindow:destroy()
  end

  ProtocolGame.unregisterExtendedOpcode(TV_OPCODE)
  ProtocolGame.unregisterExtendedOpcode(TV_BLOCK_OPCODE)

  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
    onOpenChannel = onTvOpenChannel,
    onCloseChannel = onTvCloseChannel
  })

  stopWatchingFollow()
  protocolGame = nil
end

function lockWalk()
  local localPlayer = g_game.getLocalPlayer()

  if localPlayer then
    if localPlayer.stopAutoWalk then
      localPlayer:stopAutoWalk()
    end

    if localPlayer.lockAutoWalk then
      localPlayer:lockAutoWalk()
    end
  end

  if modules.game_walking and modules.game_walking.unbindKeys then
    modules.game_walking.unbindKeys()
  end
end

function unlockWalk()
  local localPlayer = g_game.getLocalPlayer()

  if localPlayer and localPlayer.unlockAutoWalk then
    localPlayer:unlockAutoWalk()
  end

  if modules.game_walking then
    if modules.game_walking.unbindKeys then
      modules.game_walking.unbindKeys()
    end
    if modules.game_walking.bindKeys then
      modules.game_walking.bindKeys()
    end
  end
end

function onGameStart()
  protocolGame = g_game.getProtocolGame()
  resetState()
end

function onGameEnd()
  resetState()
  stopWatchingFollow()
  protocolGame = nil
end

function tvChannelsSearchOnTextChange(widget, text, oldText)
  if not tvChannelsWindow then
    return
  end

  local channelsPanel = bindChild(tvChannelsWindow, 'channelsPanel')
  if not channelsPanel then return end
  channelsPanel:destroyChildren()

  local filter = (text or ''):trim():lower()
  for _, channel in ipairs(channelList) do
    if filter == '' or channel.search:find(filter, 1, true) then
      local entry = g_ui.createWidget('TVChannelListLabel', channelsPanel)
      entry.channelLabel:setText(string.format('%s (%s)', channel.name, channel.broadcaster))
      entry.viewLabel:setText(channel.protected and tr('Lock') or tr('Free'))
      entry.channelData = channel
    end
  end
end

function tvChannelsWatchOnClick(widget)
  currentWatchedChannelId = nil
  local channelsPanel = tvChannelsWindow and bindChild(tvChannelsWindow, 'channelsPanel')
  local selected = widget and widget.channelData and widget or channelsPanel and channelsPanel:getFocusedChild()
  if not selected or not selected.channelData or not protocolGame then
    return
  end

  pendingWatchPlayer = selected.channelData.broadcaster
  unlockWalk()
  sendTvOpcode('watch/' .. selected.channelData.broadcaster)
  tvChannelsWindow:hide()
end

function sendActionChannel(action)
  if action == '!tvclose' then
    closeWatchingChannel()
  end
end

function isPlayerWatchingTV()
  return isWatchingTV
end

function setWatchingTv(mode)
  isWatchingTV = mode
end


