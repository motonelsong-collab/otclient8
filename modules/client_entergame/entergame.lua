EnterGame = { }

-- private variables
local loadBox
local enterGame
local enterGameButton
local clientBox
local protocolLogin
local server = nil
local versionsFound = false

local customServerSelectorPanel
local serverSelectorPanel
local serverSelector
local clientVersionSelector
local serverHostTextEdit
local rememberPasswordBox
local createAccountWindow
local protos = {"740", "760", "772", "792", "800", "810", "854", "860", "870", "910", "961", "1000", "1077", "1090", "1096", "1098", "1099", "1100", "1200", "1220"}

local checkedByUpdater = {}
local waitingForHttpResults = 0
local creationOptions = nil
local creationOptionsUrl = nil

local function resolveLoginConfig(host, version)
  local resolvedServer = ''
  local resolvedHost = host or ''
  local resolvedVersion = tonumber(version) or 0

  if serverSelector then
    resolvedServer = serverSelector:getText():trim()
  end

  if resolvedServer == '' then
    resolvedServer = g_settings.get('server') or ''
  end

  if resolvedHost == '' and serverHostTextEdit then
    resolvedHost = serverHostTextEdit:getText()
  end

  if resolvedVersion == 0 and clientVersionSelector then
    resolvedVersion = tonumber(clientVersionSelector:getText()) or 0
  end

  if Servers and next(Servers) then
    local selectedServer = resolvedServer
    if selectedServer == '' or Servers[selectedServer] == nil then
      for name, _ in pairs(Servers) do
        selectedServer = name
        break
      end
    end

    if selectedServer ~= '' and Servers[selectedServer] ~= nil then
      resolvedServer = selectedServer
      local serverData = Servers[selectedServer]
      local serverEntry = type(serverData) == 'table' and serverData[1] or serverData
      if resolvedHost == '' and type(serverEntry) == 'string' and serverEntry:len() > 0 then
        resolvedHost = serverEntry
      end
    end
  end

  if resolvedHost == '' then
    resolvedHost = g_settings.get('host') or ''
  end

  if resolvedVersion == 0 then
    resolvedVersion = tonumber(g_settings.get('client-version')) or 0
  end

  if resolvedVersion == 0 and type(resolvedHost) == 'string' and resolvedHost:lower():find('http') == nil then
    local serverParams = resolvedHost:split(':')
    if #serverParams >= 3 then
      resolvedVersion = tonumber(serverParams[3]) or resolvedVersion
    end
  end

  if resolvedHost == '' then
    resolvedHost = '127.0.0.1:7171:854'
  end

  if resolvedVersion == 0 then
    resolvedVersion = 854
  end

  return resolvedServer, resolvedHost, resolvedVersion
end

local function normalizeBaseUrl(url)
  if type(url) ~= 'string' then
    return ''
  end

  url = url:trim()
  if url == '' then
    return ''
  end

  if url:lower():find('http://') ~= 1 and url:lower():find('https://') ~= 1 then
    url = 'http://' .. url
  end

  return url:gsub('/+$', '')
end

local function getCreationApiUrl()
  local _, resolvedHost = resolveLoginConfig()
  if type(resolvedHost) == 'string' and resolvedHost:lower():find('http') == 1 then
    local sanitizedHost = resolvedHost:gsub('%?.*$', '')
    if sanitizedHost:match('%.php$') then
      return sanitizedHost:gsub('/[^/]*$', '') .. '/client_entergame.php'
    end
    return normalizeBaseUrl(sanitizedHost) .. '/API/client_entergame.php'
  end

  local website = normalizeBaseUrl(Services and Services.website or '')
  if website == '' then
    website = 'http://127.0.0.1'
  end

  return website .. '/API/client_entergame.php'
end

local function showCreationError(message)
  displayErrorBox(tr('Criacao'), message)
end

local function showCreationInfo(message)
  displayInfoBox(tr('Criacao'), message)
end

local function findWindowChild(window, childId)
  if not window then
    return nil
  end

  local child = window:getChildById(childId)
  if child then
    return child
  end

  if window.recursiveGetChildById then
    return window:recursiveGetChildById(childId)
  end

  return nil
end

local function getCurrentComboValue(comboBox)
  local option = comboBox and comboBox:getCurrentOption()
  return option and option.data or nil
end

local function populateCreationCombo(comboBox, entries)
  if not comboBox then
    return
  end

  comboBox:clearOptions()
  for _, entry in ipairs(entries or {}) do
    comboBox:addOption(entry.name, entry.id)
  end
end

local function populateCreationWindow(window, options)
  if not window or not options then
    return
  end

  populateCreationCombo(findWindowChild(window, 'worldComboBox'), options.worlds)
  populateCreationCombo(findWindowChild(window, 'cityComboBox'), options.cities)
  populateCreationCombo(findWindowChild(window, 'vocationComboBox'), options.vocations)
  populateCreationCombo(findWindowChild(window, 'sexComboBox'), options.sexes)
end

local function withCreationOptions(callback)
  local apiUrl = getCreationApiUrl()
  if apiUrl == '' then
    return showCreationError('Configure o endereco do site em Services.website ou utilize um login via HTTP.')
  end

  if creationOptions and creationOptionsUrl == apiUrl then
    return callback(creationOptions, apiUrl)
  end

  local waitBox = displayCancelBox(tr('Please wait'), tr('Carregando opcoes de criacao...'))
  waitBox.onCancel = function()
    waitBox = nil
  end

  HTTP.getJSON(apiUrl .. '?action=options', function(data, err)
    if waitBox then
      waitBox:destroy()
      waitBox = nil
    end

    if err then
      return showCreationError(err)
    end

    if type(data) ~= 'table' or not data.success then
      return showCreationError(data and data.error or 'Nao foi possivel carregar as opcoes de criacao.')
    end

    creationOptions = data
    creationOptionsUrl = apiUrl
    callback(data, apiUrl)
  end)
end

local function focusWindowField(window, fieldId)
  if not window then
    return
  end

  local field = findWindowChild(window, fieldId)
  window:show()
  window:raise()
  window:focus()
  if field then
    field:focus()
  end
end

local function getWindowText(window, fieldId)
  local field = findWindowChild(window, fieldId)
  if not field or not field.getText then
    return ''
  end
  return field:getText():trim()
end

local function fillLoginFields(account, password)
  if not enterGame then
    return
  end

  enterGame:getChildById('accountNameTextEdit'):setText(account or '')
  enterGame:getChildById('accountPasswordTextEdit'):setText(password or '')
end

-- private functions
local function onProtocolError(protocol, message, errorCode)
  if errorCode then
    return EnterGame.onError(message)
  end
  return EnterGame.onLoginError(message)
end

local function onSessionKey(protocol, sessionKey)
  G.sessionKey = sessionKey
end

local function onCharacterList(protocol, characters, account, otui)
  if rememberPasswordBox:isChecked() then
    local account = g_crypt.encrypt(G.account)
    local password = g_crypt.encrypt(G.password)

    g_settings.set('account', account)
    g_settings.set('password', password)
  else
    EnterGame.clearAccountFields()
  end

  for _, characterInfo in pairs(characters) do
    if characterInfo.previewState and characterInfo.previewState ~= PreviewState.Default then
      characterInfo.worldName = characterInfo.worldName .. ', Preview'
    end
  end

  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  CharacterList.create(characters, account, otui)
  CharacterList.show()

  g_settings.save()
end

local function onUpdateNeeded(protocol, signature)
  return EnterGame.onError(tr('Your client needs updating, try redownloading it.'))
end

local function onProxyList(protocol, proxies)
  for _, proxy in ipairs(proxies) do
    g_proxy.addProxy(proxy["host"], proxy["port"], proxy["priority"])
  end
end

local function parseFeatures(features)
  for feature_id, value in pairs(features) do
      if value == "1" or value == "true" or value == true then
        g_game.enableFeature(feature_id)
      else
        g_game.disableFeature(feature_id)
      end
  end
end

local function validateThings(things)
  local incorrectThings = ""
  local missingFiles = false
  local versionForMissingFiles = 0
  if things ~= nil then
    local thingsNode = {}
    for thingtype, thingdata in pairs(things) do
      thingsNode[thingtype] = thingdata[1]
      if not g_resources.fileExists("/things/" .. thingdata[1]) then
        incorrectThings = incorrectThings .. "Missing file: " .. thingdata[1] .. "\n"
        missingFiles = true
        versionForMissingFiles = thingdata[1]:split("/")[1]
      else
        local localChecksum = g_resources.fileChecksum("/things/" .. thingdata[1]):lower()
        if localChecksum ~= thingdata[2]:lower() and #thingdata[2] > 1 then
          if g_resources.isLoadedFromArchive() then
            incorrectThings = incorrectThings .. "Invalid checksum of file: " .. thingdata[1] .. " (is " .. localChecksum .. ", should be " .. thingdata[2]:lower() .. ")\n"
          end
        end
      end
    end
    g_settings.setNode("things", thingsNode)
  else
    g_settings.setNode("things", {})
  end
  if missingFiles then
    incorrectThings = incorrectThings .. "\nYou should open data/things and create directory " .. versionForMissingFiles ..
    ".\nIn this directory (data/things/" .. versionForMissingFiles .. ") you should put missing\nfiles (Tibia.dat and Tibia.spr/Tibia.cwm) " ..
    "from correct Tibia version."
  end
  return incorrectThings
end

local function onTibia12HTTPResult(session, playdata)
  local characters = {}
  local worlds = {}
  local account = {
    status = 0,
    subStatus = 0,
    premDays = 0
  }
  if session["status"] ~= "active" then
    account.status = 1
  end
  if session["ispremium"] then
    account.subStatus = 1
  end
  if session["premiumuntil"] > g_clock.seconds() then
    account.subStatus = math.floor((session["premiumuntil"] - g_clock.seconds()) / 86400)
  end

  local things = {
    data = {G.clientVersion .. "/Tibia.dat", ""},
    sprites = {G.clientVersion .. "/Tibia.cwm", ""},
  }

  local incorrectThings = validateThings(things)
  if #incorrectThings > 0 then
    things = {
      data = {G.clientVersion .. "/Tibia.dat", ""},
      sprites = {G.clientVersion .. "/Tibia.spr", ""},
    }
    incorrectThings = validateThings(things)
  end

  if #incorrectThings > 0 then
    g_logger.error(incorrectThings)
    if Updater and not checkedByUpdater[G.clientVersion] then
      checkedByUpdater[G.clientVersion] = true
      return Updater.check({
        version = G.clientVersion,
        host = G.host
      })
    else
      return EnterGame.onError(incorrectThings)
    end
  end

  onSessionKey(nil, session["sessionkey"])

  for _, world in pairs(playdata["worlds"]) do
    worlds[world.id] = {
      name = world.name,
      port = world.externalportunprotected or world.externalportprotected or world.externaladdress,
      address = world.externaladdressunprotected or world.externaladdressprotected or world.externalport
    }
  end

  for _, character in pairs(playdata["characters"]) do
    local world = worlds[character.worldid]
    if world then
      table.insert(characters, {
        name = character.name,
        worldName = world.name,
        worldIp = world.address,
        worldPort = world.port
      })
    end
  end

  if g_proxy then
    g_proxy.clear()
    if playdata["proxies"] then
      for i, proxy in ipairs(playdata["proxies"]) do
        g_proxy.addProxy(proxy["host"], tonumber(proxy["port"]), tonumber(proxy["priority"]))
      end
    end
  end

  g_game.setCustomProtocolVersion(0)
  g_game.chooseRsa(G.host)
  g_game.setClientVersion(G.clientVersion)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(G.clientVersion))
  g_game.setCustomOs(-1)
  if not g_game.getFeature(GameExtendedOpcode) then
    g_game.setCustomOs(5)
  end

  onCharacterList(nil, characters, account, nil)
end

local function onHTTPResult(data, err)
  if waitingForHttpResults == 0 then
    return
  end

  waitingForHttpResults = waitingForHttpResults - 1
  if err and waitingForHttpResults > 0 then
    return
  end

  if err then
    return EnterGame.onError(err)
  end
  waitingForHttpResults = 0
  if data['error'] and data['error']:len() > 0 then
    return EnterGame.onLoginError(data['error'])
  elseif data['errorMessage'] and data['errorMessage']:len() > 0 then
    return EnterGame.onLoginError(data['errorMessage'])
  end

  if type(data["session"]) == "table" and type(data["playdata"]) == "table" then
    return onTibia12HTTPResult(data["session"], data["playdata"])
  end

  local characters = data["characters"]
  local account = data["account"]
  local session = data["session"]

  local version = data["version"]
  local things = data["things"]
  local customProtocol = data["customProtocol"]

  local features = data["features"]
  local settings = data["settings"]
  local rsa = data["rsa"]
  local proxies = data["proxies"]

  local incorrectThings = validateThings(things)
  if #incorrectThings > 0 then
    g_logger.info(incorrectThings)
    return EnterGame.onError(incorrectThings)
  end

  g_game.setCustomProtocolVersion(0)
  if customProtocol ~= nil then
    customProtocol = tonumber(customProtocol)
    if customProtocol ~= nil and customProtocol > 0 then
      g_game.setCustomProtocolVersion(customProtocol)
    end
  end

  if settings ~= nil then
    for option, value in pairs(settings) do
      modules.client_options.setOption(option, value, true)
    end
  end

  G.clientVersion = version
  g_game.setClientVersion(version)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(version))
  g_game.setCustomOs(-1)

  if rsa ~= nil then
    g_game.setRsa(rsa)
  end

  if features ~= nil then
    parseFeatures(features)
  end

  if session ~= nil and session:len() > 0 then
    onSessionKey(nil, session)
  end

  if g_proxy then
    g_proxy.clear()
    if proxies then
      for i, proxy in ipairs(proxies) do
        g_proxy.addProxy(proxy["host"], tonumber(proxy["port"]), tonumber(proxy["priority"]))
      end
    end
  end

  onCharacterList(nil, characters, account, nil)
end

-- public functions
function EnterGame.init()
  if USE_NEW_ENERGAME then return end
  enterGame = g_ui.displayUI('entergame')
  g_ui.importStyle('accountcreation')

  serverSelectorPanel = enterGame:getChildById('serverSelectorPanel')
  customServerSelectorPanel = enterGame:getChildById('customServerSelectorPanel')

  serverSelector = serverSelectorPanel and serverSelectorPanel:getChildById('serverSelector')
  rememberPasswordBox = enterGame:getChildById('rememberPasswordBox')
  serverHostTextEdit = customServerSelectorPanel and customServerSelectorPanel:getChildById('serverHostTextEdit')
  clientVersionSelector = customServerSelectorPanel and customServerSelectorPanel:getChildById('clientVersionSelector')

  if serverSelector then
    if Servers ~= nil then
      for name, serverData in pairs(Servers) do
        serverSelector:addOption(name)
      end
    end
    if serverSelector:getOptionsCount() == 0 or ALLOW_CUSTOM_SERVERS then
      serverSelector:addOption(tr('Another'))
    end
  end

  if clientVersionSelector then
    for i, proto in pairs(protos) do
      clientVersionSelector:addOption(proto)
    end
  end

  if serverSelector and serverSelector:getOptionsCount() == 1 and serverSelectorPanel then
    enterGame:setHeight(enterGame:getHeight() - serverSelectorPanel:getHeight())
    serverSelectorPanel:setOn(false)
  end

  enterGame:setHeight(enterGame:getHeight() + 30)

  createAccountWindow = g_ui.createWidget('CreateAccountWindow', rootWidget)
  createAccountWindow:hide()
  createAccountWindow:getChildById('confirmButton').onClick = EnterGame.submitCreateAccount

  local account = g_crypt.decrypt(g_settings.get('account'))
  local password = g_crypt.decrypt(g_settings.get('password'))
  local savedServer = g_settings.get('server')
  local host = g_settings.get('host')
  local clientVersion = g_settings.get('client-version')

  if serverSelector and serverSelector:isOption(savedServer) then
    serverSelector:setCurrentOption(savedServer, false)
    if (Servers == nil or Servers[savedServer] == nil) and serverHostTextEdit then
      serverHostTextEdit:setText(host)
    end
    if clientVersionSelector and clientVersion then
      clientVersionSelector:setOption(clientVersion)
    end
  else
    if serverHostTextEdit and host then
      serverHostTextEdit:setText(host)
    end
    if clientVersionSelector and clientVersion then
      clientVersionSelector:setOption(clientVersion)
    end
  end

  enterGame:getChildById('accountPasswordTextEdit'):setText(password)
  enterGame:getChildById('accountNameTextEdit'):setText(account)
  rememberPasswordBox:setChecked(#account > 0)

  findWindowChild(createAccountWindow, 'accountNameTextEdit'):setMaxLength(32)
  findWindowChild(createAccountWindow, 'nicknameTextEdit'):setMaxLength(32)
  findWindowChild(createAccountWindow, 'emailTextEdit'):setMaxLength(255)
  findWindowChild(createAccountWindow, 'passwordTextEdit'):setMaxLength(255)
  findWindowChild(createAccountWindow, 'repeatPasswordTextEdit'):setMaxLength(255)
  findWindowChild(createAccountWindow, 'characterNameTextEdit'):setMaxLength(32)

  g_keyboard.bindKeyDown('Ctrl+G', EnterGame.openWindow)

  if g_game.isOnline() then
    return EnterGame.hide()
  end

  scheduleEvent(function()
    EnterGame.show()
  end, 100)
end

function EnterGame.terminate()
  if not enterGame then return end
  g_keyboard.unbindKeyDown('Ctrl+G')

  enterGame:destroy()
  if createAccountWindow then
    createAccountWindow:destroy()
    createAccountWindow = nil
  end
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
  if protocolLogin then
    protocolLogin:cancelLogin()
    protocolLogin = nil
  end
  EnterGame = nil
end

function EnterGame.show()
  if not enterGame then return end
  enterGame:show()
  enterGame:raise()
  enterGame:focus()
  enterGame:getChildById('accountNameTextEdit'):focus()
end

function EnterGame.hide()
  if not enterGame then return end
  enterGame:hide()
end

function EnterGame.hideCreateAccountWindow()
  if createAccountWindow then
    createAccountWindow:hide()
  end
end

function EnterGame.openWindow()
  if g_game.isOnline() then
    CharacterList.show()
  elseif not g_game.isLogging() and not CharacterList.isVisible() then
    EnterGame.show()
  end
end

function EnterGame.clearAccountFields()
  enterGame:getChildById('accountNameTextEdit'):clearText()
  enterGame:getChildById('accountPasswordTextEdit'):clearText()
  local tokenTextEdit = enterGame:getChildById('accountTokenTextEdit')
  if tokenTextEdit then
    tokenTextEdit:clearText()
  end
  enterGame:getChildById('accountNameTextEdit'):focus()
  g_settings.remove('account')
  g_settings.remove('password')
end

function EnterGame.showCreateAccountWindow()
  withCreationOptions(function(options)
    populateCreationWindow(createAccountWindow, options)
    findWindowChild(createAccountWindow, 'accountNameTextEdit'):setText(getWindowText(enterGame, 'accountNameTextEdit'))
    findWindowChild(createAccountWindow, 'passwordTextEdit'):setText(getWindowText(enterGame, 'accountPasswordTextEdit'))
    findWindowChild(createAccountWindow, 'repeatPasswordTextEdit'):setText(getWindowText(enterGame, 'accountPasswordTextEdit'))
    focusWindowField(createAccountWindow, 'accountNameTextEdit')
  end)
end

function EnterGame.submitCreateAccount()
  if not createAccountWindow then
    return
  end

  local account = getWindowText(createAccountWindow, 'accountNameTextEdit')
  local nickname = getWindowText(createAccountWindow, 'nicknameTextEdit')
  local email = getWindowText(createAccountWindow, 'emailTextEdit')
  local password = getWindowText(createAccountWindow, 'passwordTextEdit')
  local repeatPassword = getWindowText(createAccountWindow, 'repeatPasswordTextEdit')
  local characterName = getWindowText(createAccountWindow, 'characterNameTextEdit')
  local sex = getCurrentComboValue(findWindowChild(createAccountWindow, 'sexComboBox'))
  local vocation = getCurrentComboValue(findWindowChild(createAccountWindow, 'vocationComboBox'))
  local city = getCurrentComboValue(findWindowChild(createAccountWindow, 'cityComboBox'))
  local world = getCurrentComboValue(findWindowChild(createAccountWindow, 'worldComboBox'))
  local apiUrl = getCreationApiUrl()

  if account == '' or nickname == '' or email == '' or password == '' or repeatPassword == '' or characterName == '' then
    return showCreationError('Preencha todos os campos para criar a conta.')
  end

  if password ~= repeatPassword then
    return showCreationError('As senhas nao conferem.')
  end

  if apiUrl == '' then
    return showCreationError('Nao foi possivel localizar a API de criacao do site.')
  end

  local waitBox = displayCancelBox(tr('Please wait'), tr('Criando conta e personagem...'))
  waitBox.onCancel = function()
    waitBox = nil
  end

  HTTP.postJSON(apiUrl, {
    action = 'createAccount',
    account = account,
    nickname = nickname,
    email = email,
    password = password,
    characterName = characterName,
    sex = sex,
    vocation = vocation,
    city = city,
    world = world
  }, function(data, err)
    if waitBox then
      waitBox:destroy()
      waitBox = nil
    end

    if err then
      return showCreationError(err)
    end

    if type(data) ~= 'table' or not data.success then
      return showCreationError(data and data.error or 'Nao foi possivel criar a conta.')
    end

    fillLoginFields(data.account or account, data.password or password)
    EnterGame.hideCreateAccountWindow()
    showCreationInfo(data.message or 'Conta criada com sucesso.')
  end)
end

function EnterGame.onServerChange()
  if not serverSelector or not customServerSelectorPanel then
    return
  end

  server = serverSelector:getText()
  if server == tr('Another') then
    if not customServerSelectorPanel:isOn() then
      if serverHostTextEdit then
        serverHostTextEdit:setText('')
      end
      customServerSelectorPanel:setOn(true)
      enterGame:setHeight(enterGame:getHeight() + customServerSelectorPanel:getHeight())
    end
  elseif customServerSelectorPanel:isOn() then
    enterGame:setHeight(enterGame:getHeight() - customServerSelectorPanel:getHeight())
    customServerSelectorPanel:setOn(false)
  end
  if serverHostTextEdit and Servers and Servers[server] ~= nil then
    if type(Servers[server]) == 'table' then
      serverHostTextEdit:setText(Servers[server][1])
    else
      serverHostTextEdit:setText(Servers[server])
    end
  end
end

function EnterGame.doLogin(account, password, token, host, version)
  if g_game.isOnline() then
    local errorBox = displayErrorBox(tr('Login Error'), tr('Cannot login while already in game.'))
    connect(errorBox, { onOk = EnterGame.show })
    return
  end

  local tokenTextEdit = enterGame:getChildById('accountTokenTextEdit')
  local resolvedServer, resolvedHost, resolvedVersion = resolveLoginConfig(host, version)

  G.account = account or enterGame:getChildById('accountNameTextEdit'):getText()
  G.password = password or enterGame:getChildById('accountPasswordTextEdit'):getText()
  G.authenticatorToken = token or (tokenTextEdit and tokenTextEdit:getText() or '')
  G.stayLogged = true
  G.server = resolvedServer
  G.host = resolvedHost
  G.clientVersion = resolvedVersion

  if not rememberPasswordBox:isChecked() then
    g_settings.set('account', G.account)
    g_settings.set('password', G.password)
  end
  g_settings.set('host', G.host)
  g_settings.set('server', G.server)
  g_settings.set('client-version', G.clientVersion)
  g_settings.save()

  local server_params = G.host:split(':')
  if G.host:lower():find('http') ~= nil then
    if #server_params >= 4 then
      G.host = server_params[1] .. ':' .. server_params[2] .. ':' .. server_params[3]
      G.clientVersion = tonumber(server_params[4])
    elseif #server_params >= 3 then
      if tostring(tonumber(server_params[3])) == server_params[3] then
        G.host = server_params[1] .. ':' .. server_params[2]
        G.clientVersion = tonumber(server_params[3])
      end
    end
    return EnterGame.doLoginHttp()
  end

  local server_ip = server_params[1]
  local server_port = 7171
  if #server_params >= 2 then
    server_port = tonumber(server_params[2])
  end
  if #server_params >= 3 then
    G.clientVersion = tonumber(server_params[3])
  end
  if type(server_ip) ~= 'string' or server_ip:len() <= 3 or not server_port or not G.clientVersion then
    return EnterGame.onError('Invalid server, it should be in format IP:PORT or it should be http url to login script')
  end

  local things = {
    data = {G.clientVersion .. '/Tibia.dat', ''},
    sprites = {G.clientVersion .. '/Tibia.cwm', ''},
  }

  local incorrectThings = validateThings(things)
  if #incorrectThings > 0 then
    things = {
      data = {G.clientVersion .. '/Tibia.dat', ''},
      sprites = {G.clientVersion .. '/Tibia.spr', ''},
    }
    incorrectThings = validateThings(things)
  end
  if #incorrectThings > 0 then
    g_logger.error(incorrectThings)
    if Updater and not checkedByUpdater[G.clientVersion] then
      checkedByUpdater[G.clientVersion] = true
      return Updater.check({
        version = G.clientVersion,
        host = G.host
      })
    else
      return EnterGame.onError(incorrectThings)
    end
  end

  protocolLogin = ProtocolLogin.create()
  protocolLogin.onLoginError = onProtocolError
  protocolLogin.onSessionKey = onSessionKey
  protocolLogin.onCharacterList = onCharacterList
  protocolLogin.onUpdateNeeded = onUpdateNeeded
  protocolLogin.onProxyList = onProxyList

  EnterGame.hide()
  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  protocolLogin:cancelLogin()
                                  EnterGame.show()
                                end })

  if G.clientVersion == 1000 then
    G.clientVersion = 1100
  end
  g_game.setClientVersion(G.clientVersion)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(G.clientVersion))
  g_game.setCustomProtocolVersion(0)
  g_game.setCustomOs(-1)
  g_game.chooseRsa(G.host)
  if #server_params <= 3 and not g_game.getFeature(GameExtendedOpcode) then
    g_game.setCustomOs(2)
  end

  for i = 4, #server_params do
    g_game.enableFeature(tonumber(server_params[i]))
  end

  if g_proxy then
    g_proxy.clear()
  end

  if modules.game_things.isLoaded() then
    g_logger.info('Connecting to: ' .. server_ip .. ':' .. server_port)
    protocolLogin:login(server_ip, server_port, G.account, G.password, G.authenticatorToken, G.stayLogged)
  else
    loadBox:destroy()
    loadBox = nil
    EnterGame.show()
  end
end

function EnterGame.doLoginHttp()
  if G.host == nil or G.host:len() < 10 then
    return EnterGame.onError('Invalid server url: ' .. G.host)
  end

  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  EnterGame.show()
                                end })

  local data = {
    type = 'login',
    account = G.account,
    accountname = G.account,
    email = G.account,
    password = G.password,
    accountpassword = G.password,
    token = G.authenticatorToken,
    version = APP_VERSION,
    uid = G.UUID,
    stayloggedin = true
  }

  local selectedServer = serverSelector and serverSelector:getText() or G.server
  if Servers and selectedServer and Servers[selectedServer] ~= nil and type(Servers[selectedServer]) == 'table' then
    local urls = Servers[selectedServer]
    waitingForHttpResults = #urls
    for _, url in ipairs(urls) do
      HTTP.postJSON(url, data, onHTTPResult)
    end
  else
    waitingForHttpResults = 1
    HTTP.postJSON(G.host, data, onHTTPResult)
  end
  EnterGame.hide()
end

function EnterGame.onError(err)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
  local errorBox = displayErrorBox(tr('Login Error'), err)
  errorBox.onOk = EnterGame.show
end

function EnterGame.onLoginError(err)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
  local errorBox = displayErrorBox(tr('Login Error'), err)
  errorBox.onOk = EnterGame.show
  if err:lower():find('invalid') or err:lower():find('not correct') or err:lower():find('or password') then
    EnterGame.clearAccountFields()
  end
end
