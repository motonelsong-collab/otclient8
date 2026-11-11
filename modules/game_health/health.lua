Icons = {}
Icons[1] = { tooltip = tr('You are poisoned'), path = '/images/game/states/poisoned', id = 'condition_poisoned' }
Icons[2] = { tooltip = tr('You are burning'), path = '/images/game/states/burning', id = 'condition_burning' }
Icons[4] = { tooltip = tr('You are electrified'), path = '/images/game/states/electrified', id = 'condition_electrified' }
Icons[8] = { tooltip = tr('You are drunk'), path = '/images/game/states/drunk', id = 'condition_drunk' }
Icons[16] = { tooltip = tr('You are protected by a magic shield'), path = '/images/game/states/magic_shield', id = 'condition_magic_shield' }
Icons[32] = { tooltip = tr('You are paralysed'), path = '/images/game/states/slowed', id = 'condition_slowed' }
Icons[64] = { tooltip = tr('You are hasted'), path = '/images/game/states/haste', id = 'condition_haste' }
Icons[128] = { tooltip = tr('You may not logout during a fight'), path = '/images/game/states/logout_block', id = 'condition_logout_block' }
Icons[256] = { tooltip = tr('You are drowning'), path = '/images/game/states/drowning', id = 'condition_drowning' }
Icons[512] = { tooltip = tr('You are freezing'), path = '/images/game/states/freezing', id = 'condition_freezing' }
Icons[1024] = { tooltip = tr('You are dazzled'), path = '/images/game/states/dazzled', id = 'condition_dazzled' }
Icons[2048] = { tooltip = tr('You are cursed'), path = '/images/game/states/cursed', id = 'condition_cursed' }
Icons[4096] = { tooltip = tr('You are strengthened'), path = '/images/game/states/strengthened', id = 'condition_strengthened' }
Icons[8192] = { tooltip = tr('You may not logout or enter a protection zone'), path = '/images/game/states/protection_zone_block', id = 'condition_protection_zone_block' }
Icons[16384] = { tooltip = tr('You are within a protection zone'), path = '/images/game/states/protection_zone', id = 'condition_protection_zone' }
Icons[32768] = { tooltip = tr('You are bleeding'), path = '/images/game/states/bleeding', id = 'condition_bleeding' }
Icons[65536] = { tooltip = tr('You are hungry'), path = '/images/game/states/hungry', id = 'condition_hungry' }

healthInfoWindow = nil
nameLabel = nil
imagePlayer = nil
healthBar = nil
healthLabel = nil
levelLabel = nil
manaBar = nil
manaLabel = nil
experienceBar = nil
experienceLabel = nil
capLabel = nil
experienceTooltip = 'You have %d%% to advance to level %d.'
healthTooltip = 'Your character health is %d out of %d.'
manaTooltip = 'Your Pokemon energy is %d out of %d.'
local PLAYER_HUD_OPCODE = 72

function init()
	connect(g_game, { onGameEnd   = offline, onGameStart = refresh })
	connect(LocalPlayer, { onHealthChange = onHealthChange,
						   onManaChange = onManaChange,
						   onLevelChange = onLevelChange,
						   onFreeCapacityChange = onFreeCapacityChange,
						   onStaminaChange = onStaminaChange,
						    onStatesChange = onStatesChange, })
	
	healthInfoWindow = g_ui.displayUI('health.otui')
	healthInfoWindow:hide()
	ProtocolGame.registerExtendedOpcode(PLAYER_HUD_OPCODE, onPlayerHudOpcode)
	
	healthInfoButton = modules.client_topmenu.addTopGameToggleButton('healthInfoButton', tr('Health Information'), '/images/topbuttons/healthinfo', toggle) 
	
	nameLabel   = healthInfoWindow:getChildById('nameLabel')
	imagePlayer   = healthInfoWindow:getChildById('imagePlayer')
	levelLabel  = healthInfoWindow:getChildById('levelLabel')
	healthBar   = healthInfoWindow:getChildById('healthBar')
	manaBar = healthInfoWindow:recursiveGetChildById('manaBar')
	healthLabel = healthInfoWindow:getChildById('healthLabel')
    experienceBar = healthInfoWindow:recursiveGetChildById('experienceBar')
	experienceLabel = healthInfoWindow:getChildById('experienceLabel')
    capLabel = healthInfoWindow:recursiveGetChildById('capLabel')
	
		  if g_game.isOnline() then		
		  onStatesChange(g_game.getLocalPlayer(), g_game.getLocalPlayer():getStates(), 0)
    local localPlayer = g_game.getLocalPlayer()
    onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
    onManaChange(localPlayer, localPlayer:getMana(), localPlayer:getMaxMana())
    onLevelChange(localPlayer, localPlayer:getLevel(), localPlayer:getLevelPercent())
    onStatesChange(localPlayer, localPlayer:getStates(), 0)
    onSoulChange(localPlayer, localPlayer:getSoul())
    onFreeCapacityChange(localPlayer, localPlayer:getFreeCapacity())
  end
	refresh()
end

function terminate()
	disconnect(g_game, { onGameEnd   = offline, onGameStart = refresh })
	disconnect(LocalPlayer, { onHealthChange = onHealthChange,
						      onLevelChange = onLevelChange,
							  onFreeCapacityChange = onFreeCapacityChange,
						      onStatesChange = onStatesChange })
	ProtocolGame.unregisterExtendedOpcode(PLAYER_HUD_OPCODE, onPlayerHudOpcode)
	healthInfoWindow:destroy()
	healthInfoButton:destroy()
end

function toggle()
  if healthInfoWindow:isVisible() then
    healthInfoWindow:hide()
  else
    healthInfoWindow:show()
	refresh()
  end
end

function offline()
	healthInfoWindow:hide()
	local panelCondition = healthInfoWindow and healthInfoWindow:recursiveGetChildById('panelCondition')
	if panelCondition then
		panelCondition:destroyChildren()
	end
end

function refresh()
	if g_game.isOnline() then
		healthInfoWindow:show()
		local localPlayer = g_game.getLocalPlayer()
		nameLabel:setText('Nome: '..localPlayer:getName())
		onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
		onLevelChange(localPlayer, localPlayer:getLevel(), localPlayer:getLevelPercent())
		if localPlayer.getSex then
			updatePlayerHud(localPlayer:getSex())
		else
			updatePlayerHud(nil)
		end
	end
end

function updatePlayerHud(sex, currentPokeballs, maxPokeballs)
  if tonumber(sex) == 0 then
    SexFemale()
  elseif tonumber(sex) == 1 then
    SexMale()
  end

  if capLabel then
    local current = tonumber(currentPokeballs) or 0
    local max = tonumber(maxPokeballs) or 6
    capLabel:setText(string.format('%d / %d', current, max))
  end
end

function onPlayerHudOpcode(protocol, opcode, buffer)
  if opcode ~= PLAYER_HUD_OPCODE or not buffer or buffer == '' then
    return
  end

  local sex, currentPokeballs, maxPokeballs = buffer:match('^(%d+)|(%d+)|(%d+)$')
  if sex then
    updatePlayerHud(sex, currentPokeballs, maxPokeballs)
    return
  end

  updatePlayerHud(buffer)
end


function SexMale()
	local imagePlayer = healthInfoWindow:recursiveGetChildById('imagePlayer')
	imagePlayer:setImageSource("img/male.png")
end

function SexFemale()
	local imagePlayer = healthInfoWindow:recursiveGetChildById('imagePlayer')
	imagePlayer:setImageSource("img/female.png")
end

-- function setOutfitBox(outfit)
	-- outfitBox:setOutfit(outfit)
-- end

function onHealthChange(localPlayer, health, maxHealth)
  healthBar:setText(health .. ' / ' .. maxHealth)
  healthBar:setTooltip(tr(healthTooltip, health, maxHealth))
  healthBar:setValue(health, 0, maxHealth)
end

function onManaChange(localPlayer, mana, maxMana)
  manaBar:setText(mana .. ' / ' .. maxMana)
  manaBar:setTooltip(tr(manaTooltip, mana, maxMana))
  manaBar:setValue(mana, 0, maxMana)
end

function onLevelChange(localPlayer, value, percent)
  experienceBar:setText(percent .. '%')
  levelLabel:setText('Lv.'..localPlayer:getLevel())
  experienceBar:setTooltip(tr(experienceTooltip, percent, value+1))
  experienceBar:setPercent(percent)
end

function onFreeCapacityChange(localPlayer, freeCapacity)
  return true
end

function onSoulChange(localPlayer, soul)
  return true
end

function onStaminaChange(localPlayer, stamina)
  return true
end

function onStatesChange(localPlayer, now, old)
  if now == old then return end
  local bitsChanged = bit32.bxor(now, old)
  for i = 1, 32 do
    local pow = math.pow(2, i-1)
    if pow > bitsChanged then break end
    local bitChanged = bit32.band(bitsChanged, pow)
    if bitChanged ~= 0 then
      toggleIcon(bitChanged)
    end
  end
end

function setExperienceTooltip(tooltip)
  experienceTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    experienceBar:setTooltip(tr(experienceTooltip, localPlayer:getLevelPercent(), localPlayer:getLevel()+1))
  end
end

function setHealthTooltip(tooltip)
  healthTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    healthBar:setTooltip(tr(healthTooltip, localPlayer:getHealth(), localPlayer:getMaxHealth()))
  end
end

function setManaTooltip(tooltip)
  manaTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    manaBar:setTooltip(tr(manaTooltip, localPlayer:getMana(), localPlayer:getMaxMana()))
  end
end



function toggleIcon(bitChanged)
  local content = healthInfoWindow:recursiveGetChildById('panelCondition')
  if not content or not Icons[bitChanged] then
    return
  end

  local icon = content:getChildById(Icons[bitChanged].id)
  if icon then
    icon:destroy()
  else
    icon = g_ui.createWidget('ConditionWidget', content)
    icon:setId(Icons[bitChanged].id)
    icon:setImageSource(Icons[bitChanged].path)
    icon:setTooltip(Icons[bitChanged].tooltip)
  end
end
