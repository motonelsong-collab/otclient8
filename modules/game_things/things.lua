filename =  nil
loaded = false

function setFileName(name)
  filename = name
end

function isLoaded()
  return loaded
end

function load()
  local version = g_game.getClientVersion()
  local things = g_settings.getNode('things')
  
  local datPath, sprPath, otmlPath
  if filename then
    datPath = resolvepath('/things/' .. filename)
    sprPath = resolvepath('/things/' .. filename)
    otmlPath = resolvepath('/things/' .. filename)
  else
    datPath = resolvepath('/things/' .. version .. '/Tibia')
    sprPath = resolvepath('/things/' .. version .. '/Tibia')
    otmlPath = resolvepath('/things/' .. version .. '/Tibia')
  end

  local errorMessage = ''
  if not g_things.loadDat(datPath) then
    if not g_game.getFeature(GameSpritesU32) then
      g_game.enableFeature(GameSpritesU32)
      if not g_things.loadDat(datPath) then
        errorMessage = errorMessage .. tr("Unable to load dat file, please place a valid dat in '%s'", datPath) .. '\n'
      end
    else
      errorMessage = errorMessage .. tr("Unable to load dat file, please place a valid dat in '%s'", datPath) .. '\n'
    end
  end
  if not g_sprites.loadSpr(sprPath) then
    errorMessage = errorMessage .. tr("Unable to load spr file, please place a valid spr in '%s'", sprPath)
  end
  
  if not g_things.loadOtml(otmlPath) then
    errorMessage = errorMessage .. tr("Unable to load otml file, please place a valid otml in '%s'", otmlPath)
  end

  loaded = (errorMessage:len() == 0)

  if errorMessage:len() > 0 then
    local messageBox = displayErrorBox(tr('Error'), errorMessage)
    addEvent(function() messageBox:raise() messageBox:focus() end)

    g_game.setClientVersion(0)
    g_game.setProtocolVersion(0)
  end
end
