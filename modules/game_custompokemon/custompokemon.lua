PokemonCustom = PokemonCustom or {}

local TAB_ADDONS = 'addonsPanel'
local TAB_SHADERS = 'shadersPanel'
local TAB_NICKNAME = 'nicknamePanel'

local window
local confirmWindow
local protocol = runinsandbox('protocol')
local panels = {}
local tabWidgets = {}
local state = {}

local function resetState()
  state = {
    speciesName = '',
    currentNickname = '',
    selectedAddonId = 0,
    selectedShaderId = 'outfit_default',
    baseLookType = 0,
    baseOutfit = {
      type = 0,
      head = 0,
      body = 0,
      legs = 0,
      feet = 0,
      addons = 0,
      mount = 0,
      wings = 0,
      aura = 0,
      shader = 'outfit_default'
    },
    addonEntries = {},
    shaderEntries = {}
  }
end

resetState()

local function trimText(text)
  if type(text) ~= 'string' then
    return ''
  end

  return text:gsub('^%s+', ''):gsub('%s+$', '')
end

local function destroyConfirmWindow()
  if confirmWindow then
    confirmWindow:destroy()
    confirmWindow = nil
  end
end

local function getCurrentTabId()
  if not window then
    return nil
  end

  local currentPanel = window.mainTabBar:getCurrentTabPanel()
  return currentPanel and currentPanel:getId() or nil
end

local function getCurrentDisplayName()
  local nicknameText = panels.nickname and trimText(panels.nickname.nickInput:getText()) or ''
  if getCurrentTabId() == TAB_NICKNAME and nicknameText ~= '' then
    return nicknameText
  end

  if state.currentNickname ~= '' then
    return state.currentNickname
  end

  return state.speciesName
end

local function setNicknameHelper(text, color)
  if not panels.nickname then
    return
  end

  panels.nickname.helperNickInput:setText(text or '')
  panels.nickname.helperNickInput:setColor(color or '#9B9B9B')
end

local function findListChildByValue(widget, fieldName, fieldValue)
  if not widget then
    return nil
  end

  for _, child in ipairs(widget:getChildren()) do
    local data = child.data
    if data and data[fieldName] == fieldValue then
      return child
    end
  end

  return nil
end

local function focusAddon(addonId)
  local child = findListChildByValue(panels.addons and panels.addons.list, 'id', addonId)
  if child then
    child:focus()
    return true
  end

  local firstChild = panels.addons and panels.addons.list:getFirstChild()
  if firstChild then
    firstChild:focus()
    return true
  end

  return false
end

local function focusShader(shaderId)
  local child = findListChildByValue(panels.shaders and panels.shaders.list, 'id', shaderId)
  if child then
    child:focus()
    return true
  end

  local firstChild = panels.shaders and panels.shaders.list:getFirstChild()
  if firstChild then
    firstChild:focus()
    return true
  end

  return false
end

function updatePreview()
  if not window then
    return
  end

  local previewOutfit = table.copy(state.baseOutfit)
  local previewName = state.speciesName ~= '' and state.speciesName or 'Pokemon'
  local isLocked = false
  local currentTab = getCurrentTabId()

  previewOutfit.type = state.selectedAddonId > 0 and state.selectedAddonId or previewOutfit.type
  previewOutfit.shader = state.selectedShaderId or 'outfit_default'

  if currentTab == TAB_ADDONS then
    local addonEntry = state.addonEntries[state.selectedAddonId]
    if addonEntry then
      previewName = addonEntry.name or previewName
      isLocked = addonEntry.lock == true
    end
  elseif currentTab == TAB_SHADERS then
    local shaderEntry = state.shaderEntries[state.selectedShaderId]
    if shaderEntry then
      previewName = shaderEntry.name or previewName
      isLocked = shaderEntry.lock == true
    end
  else
    previewName = getCurrentDisplayName()
  end

  window.previewPanel.confirm:setEnabled(not isLocked)
  window.previewPanel.locked:setVisible(isLocked)
  window.previewPanel.name:setText(previewName)
  window.previewPanel.outfit:setOutfit(previewOutfit)
end

function onAddonSelect(list, focusedChild)
  if not focusedChild or not focusedChild.data then
    return
  end

  state.selectedAddonId = focusedChild.data.id or state.selectedAddonId
  updatePreview()
end

function onShaderSelect(list, focusedChild)
  if not focusedChild or not focusedChild.data then
    return
  end

  state.selectedShaderId = focusedChild.data.id or state.selectedShaderId
  updatePreview()
end

local function populateAddons(addonList)
  panels.addons.list.onChildFocusChange = nil
  panels.addons.list:destroyChildren()
  state.addonEntries = {}

  for index, addon in ipairs(addonList or {}) do
    local button = g_ui.createWidget('PokemonCustomAddon', panels.addons.list)
    local addonId = tonumber(addon.id) or 0
    local buttonOutfit = table.copy(state.baseOutfit)

    button.data = {
      id = addonId,
      name = addon.name or ('Addon ' .. index),
      lock = addon.lock == true or tonumber(addon.lock) == 1
    }

    buttonOutfit.type = addonId > 0 and addonId or state.baseOutfit.type
    buttonOutfit.shader = state.selectedShaderId

    button:setId('addon' .. index)
    button:setTooltip(button.data.name)
    button.locked:setVisible(button.data.lock)
    button.outfit:setOutfit(buttonOutfit)

    state.addonEntries[addonId] = button.data
  end

  panels.addons.scroll:setVisible(#(addonList or {}) > 15)
  panels.addons.list.onChildFocusChange = onAddonSelect
  focusAddon(state.selectedAddonId)
end

local function populateShaders(shaderList)
  panels.shaders.list.onChildFocusChange = nil
  panels.shaders.list:destroyChildren()
  state.shaderEntries = {}

  for index, shader in ipairs(shaderList or {}) do
    local button = g_ui.createWidget('PokemonCustomPulseAura', panels.shaders.list)
    local shaderId = shader.id or 'outfit_default'

    button.data = {
      id = shaderId,
      name = shader.name or ('Shader ' .. index),
      lock = shader.lock == true or tonumber(shader.lock) == 1
    }

    button:setId('shader' .. index)
    button:setTooltip(button.data.name)
    button.locked:setVisible(button.data.lock)
    button.color:setImageColor(shader.color or '#626262')

    state.shaderEntries[shaderId] = button.data
  end

  panels.shaders.scroll:setVisible(#(shaderList or {}) > 28)
  panels.shaders.list.onChildFocusChange = onShaderSelect
  focusShader(state.selectedShaderId)
end

local function applyOpenData(data)
  data = data or {}

  state.speciesName = data.name or 'Pokemon'
  state.currentNickname = trimText(data.nick)
  state.selectedAddonId = tonumber(data.addons and data.addons.current) or 0
  state.selectedShaderId = data.shaders and data.shaders.current or 'outfit_default'
  state.baseLookType = tonumber(data.addons and data.addons.base) or 0

  if state.baseLookType <= 0 and data.addons and data.addons.list and data.addons.list[1] then
    state.baseLookType = tonumber(data.addons.list[1].id) or 0
  end

  state.baseOutfit = {
    type = state.baseLookType,
    head = 0,
    body = 0,
    legs = 0,
    feet = 0,
    addons = 0,
    mount = 0,
    wings = 0,
    aura = 0,
    shader = state.selectedShaderId
  }

  panels.nickname.name:setText(state.currentNickname ~= '' and state.currentNickname or state.speciesName)
  panels.nickname.erase:setEnabled(state.currentNickname ~= '')
  panels.nickname.nickInput:clearText()
  setNicknameHelper('Leave empty to remove the nickname.', '#9B9B9B')

  populateAddons(data.addons and data.addons.list or {})
  populateShaders(data.shaders and data.shaders.list or {})

  local currentPanel = window.mainTabBar:getCurrentTabPanel()
  if tabWidgets.addons and (not currentPanel or currentPanel:getId() ~= TAB_ADDONS) then
    window.mainTabBar:selectTab(tabWidgets.addons)
  end

  updatePreview()
end

local function validateNickname()
  local nickname = trimText(panels.nickname.nickInput:getText())
  local currentName = trimText(state.currentNickname ~= '' and state.currentNickname or state.speciesName)

  if nickname == '' then
    setNicknameHelper('Leave empty to remove the nickname.', '#9B9B9B')
    return true
  end

  if nickname == currentName then
    setNicknameHelper('The new nickname must be different from the current one.', '#D96C6C')
    return false
  end

  if nickname:len() < 3 or nickname:len() > 15 then
    setNicknameHelper('Use between 3 and 15 characters.', '#D96C6C')
    return false
  end

  if nickname:find('[^%w%s%-]') then
    setNicknameHelper('Use only letters, numbers, spaces or hyphen.', '#D96C6C')
    return false
  end

  setNicknameHelper('Nickname ready to save.', '#7AD67A')
  return true
end

local function onTabChange(tabBar, tab)
  if not tab or not tab.tabPanel then
    return
  end

  if tab.tabPanel:getId() == TAB_NICKNAME then
    setNicknameHelper('Leave empty to remove the nickname.', '#9B9B9B')
  end

  updatePreview()
end

function init()
  protocol.initProtocol()
  resetState()

  connect(g_game, {
    onGameEnd = hide
  })

  connect(PokemonCustom, {
    onOpenData = applyOpenData
  })

  window = g_ui.displayUI('custompokemon')
  window.mainTabBar:setContentWidget(window.mainTabContent)

  panels.addons = g_ui.loadUI('ui/addonsPanel')
  panels.shaders = g_ui.loadUI('ui/shadersPanel')
  panels.nickname = g_ui.loadUI('ui/nicknamePanel')

  tabWidgets.nickname = window.mainTabBar:addTab(tr('Nickname'), panels.nickname)
  tabWidgets.addons = window.mainTabBar:addTab(tr('Addons'), panels.addons)
  tabWidgets.shaders = window.mainTabBar:addTab(tr('Auras'), panels.shaders)
  window.mainTabBar.onTabChange = onTabChange
end

function terminate()
  protocol.terminateProtocol()

  disconnect(g_game, {
    onGameEnd = hide
  })

  disconnect(PokemonCustom, {
    onOpenData = applyOpenData
  })

  destroyConfirmWindow()

  if window then
    window:destroy()
    window = nil
  end

  panels = {}
  tabWidgets = {}
  resetState()
end

function hide()
  destroyConfirmWindow()

  if window then
    window:hide()
  end
end

function show()
  if not window then
    return
  end

  destroyConfirmWindow()
  window:show()
  window:raise()
  window:focus()
  protocol.sendOpen()
end

function confirmChoose()
  local currentTab = getCurrentTabId()

  if currentTab == TAB_NICKNAME then
    if validateNickname() then
      confirmUpdateNickname(trimText(panels.nickname.nickInput:getText()))
    end
    return
  end

  if currentTab == TAB_ADDONS then
    protocol.sendChooseAddon(state.selectedAddonId)
    hide()
    return
  end

  if currentTab == TAB_SHADERS then
    protocol.sendChooseShader(state.selectedShaderId)
    hide()
  end
end

function confirmUpdateNickname(nickname)
  destroyConfirmWindow()

  local function confirmCallback()
    protocol.sendUpdateNickname(nickname)
    panels.nickname.nickInput:clearText()
    setNicknameHelper('Leave empty to remove the nickname.', '#9B9B9B')
    hide()
  end

  local title = nickname ~= '' and 'Change nickname' or 'Erase nickname'
  local message = nickname ~= '' and 'Do you really want to update this nickname?' or 'Do you really want to remove this nickname?'

  confirmWindow = displayGeneralBox(tr(title), tr(message), {
    {
      color = 'Blue',
      text = tr('Yes'),
      callback = confirmCallback
    },
    {
      color = 'Red',
      text = tr('No'),
      callback = destroyConfirmWindow
    },
    anchor = AnchorHorizontalCenter
  }, confirmCallback, destroyConfirmWindow)

  if confirmWindow then
    confirmWindow:show()
    confirmWindow:raise()
    confirmWindow:focus()
  end
end

function isValidateNickname()
  return validateNickname()
end
