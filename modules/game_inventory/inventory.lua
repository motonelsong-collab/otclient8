function init()
  g_keyboard.bindKeyDown('Ctrl+I', toggle)
  inventoryButton = modules.client_topmenu.addTopGameToggleButton('inventoryButton', tr('Inventory') .. ' (Ctrl+I)', '/images/topbuttons/inventory', toggle)
end

function terminate()
  inventoryButton:destroy()
  g_keyboard.unbindKeyDown('Ctrl+I')
end

function toggle()
  g_game.open(g_game.getLocalPlayer():getInventoryItem(3))
end

function getInventoryButton()
  return inventoryButton
end
