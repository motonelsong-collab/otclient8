-- chunkname: @/modules/game_pokebar/pokebar.lua

PokeBar = {}

local panelBar, currentSlotBar, pokeBarButton
local hasKeybindManager = KeybindManager ~= nil
local protocol = runinsandbox("protocol")
local pokemonOrder = {}
local slotBarAssociationsHotkeys = {}
local abilities = {
	fly = {
		tooltip = "Fly",
		imageClip = "0 0 20 20",
		callback = function()
			g_game.getLocalPlayer():doUseSelfOrder()
		end
	},
	teleport = {
		tooltip = "Teleport",
		imageClip = "20 0 20 20",
		callback = function()
			modules.game_minimap.toggleFullMap()
		end
	}
}

local function syncTopButtonState()
	if pokeBarButton and panelBar then
		pokeBarButton:setOn(panelBar:isVisible())
	end
end

local function getPokemonPortraitSafe(name)
	if type(getPokemonPortrait) == "function" then
		local ok, result = pcall(getPokemonPortrait, name)
		if ok and result then
			return result
		end
	end

	return ""
end

local function getPokemonNameSafe(name)
	if type(getPokemonName) == "function" then
		local ok, result = pcall(getPokemonName, name)
		if ok and result then
			return result
		end
	end

	return name or ""
end

local function getHealthColorSafe(health)
	if type(getHealthColor) == "function" then
		local ok, result = pcall(getHealthColor, health)
		if ok and result then
			return result
		end
	end

	if health <= 8 then
		return "#C0392B"
	elseif health <= 30 then
		return "#E67E22"
	elseif health <= 60 then
		return "#F1C40F"
	end

	return "#00B700"
end

local function getPokedexPokemon(slotBar)
	local pokemonName = getPokemonNameSafe(slotBar.pokemon.name):lower()
	if Pokedex_PokemonsByName then
		return Pokedex_PokemonsByName[pokemonName]
	end
	return nil
end

local function doUpdateHotkey(slotBar)
	if not hasKeybindManager then
		if slotBar and slotBar.keyCombo then
			slotBar.keyCombo:setText("")
		end
		return
	end

	local keybind = KeybindManager:getKeybindByName("Chamar " .. panelBar:getChildIndex(slotBar), "Pokemon")

	if keybind then
		slotBar.keyCombo:setText(keybind.keyCombo)
		slotBarAssociationsHotkeys[keybind.name] = slotBar
	end
end

local function doEditOrder()
	panelBar.isEditingMode = not panelBar.isEditingMode

	for i, slotBar in ipairs(panelBar:getChildren()) do
		local opacityEdit = panelBar.isEditingMode and 0.8 or 1
		slotBar:setOpacity(opacityEdit)
	end

	g_mouse.popCursor("target")
end

local function doUpdateOrder()
	local children = panelBar:getChildren()

	table.sort(children, function(a, b)
		return (pokemonOrder[a.pokemon.name] or 100) < (pokemonOrder[b.pokemon.name] or 100)
	end)
	panelBar:reorderChildren(children)

	for i, slotBar in pairs(panelBar:getChildren()) do
		doUpdateHotkey(slotBar)
	end
end

local function doUpdateResizeBar()
	local height = 20

	for i, slotBar in ipairs(panelBar:getChildren()) do
		height = height + slotBar:getHeight() + slotBar:getMarginTop()
	end

	panelBar:resize(199, height)
end

local function doUpdateElementSlotBar(slotBar)
	slotBar.elements:destroyChildren()

	local width = slotBar.elements:getWidth()
	local pokemon = getPokedexPokemon(slotBar)

	if pokemon and Pokedex_Types then
		for i, name in pairs(pokemon.Types or {}) do
			local info = Pokedex_Types[name]

			if info then
				g_ui.createWidget(("Element%sIcon-%dpx"):format(info.Text, width), slotBar.elements):setTooltip(info.Text)
			end
		end
	end

	slotBar.elements:setHeight(slotBar.elements:getChildCount() * width)
end

local function doUpdateTimerBall(slotBar)
	if slotBar.pokemon.cooldown > -1 then
		slotBar.timer:setOn(true)
		removeEvent(slotBar.eventId)

		slotBar.eventId = scheduleEvent(function()
			slotBar.timer:setOn(false)
		end, slotBar.pokemon.cooldown * 1000)
	end
end

local function doUpdateAbilities(slotBar)
	local isInUse = slotBar.pokemon.text == tr("USE")

	slotBar.abilities:setVisible(isInUse)
	slotBar.timer:setVisible(slotBar.pokemon.cooldown > -1)

	if isInUse then
		slotBar.abilities:destroyChildren()

		local pokemon = getPokedexPokemon(slotBar)

		if pokemon and pokemon.Abilities and #pokemon.Abilities > 0 then
			local width = 0

			for i, name in ipairs(pokemon.Abilities) do
				local value = abilities[name]

				if value then
					local icon = g_ui.createWidget("SlotBarAbilitiesIcon", slotBar.abilities)
					icon:setImageClip(value.imageClip)
					icon:setTooltip(value.tooltip)
					icon.onClick = value.callback
					width = width + 20
				end
			end

			slotBar.abilities:setWidth(width)
		end
	end
end

local function doUpdateStateSlotBar(slotBar, state)
	slotBar:setChecked(state)

	for i, child in pairs(slotBar:getChildren()) do
		child:setChecked(state)
	end

	doUpdateElementSlotBar(slotBar)
end

local function doRemoveSlotBar(slotBar)
	if slotBar == currentSlotBar then
		currentSlotBar = nil
	end

	slotBarAssociationsHotkeys[slotBar.keyCombo:getText()] = nil
	pokemonOrder[slotBar.pokemon.name] = nil
	panelBar[slotBar:getId()] = nil

	removeEvent(slotBar.eventId)
	slotBar:destroy()
	doUpdateResizeBar()
end

local function doUpdateSlotBar(slotBar, pokemon)
	local isAlive = pokemon.health > 0

	slotBar.pokemon = pokemon
	slotBar:setOn(not isAlive)
	slotBar.image:setEnabled(isAlive)
	slotBar.keyCombo:setOn(not isAlive)
	slotBar.progress:setPercent(pokemon.health)
	slotBar.progress:setText(("%d%%"):format(pokemon.health))
	if slotBar.name then
		slotBar.name:setText(pokemon.name or "")
	end
	slotBar.image:setImageSource(getPokemonPortraitSafe(pokemon.name))
	slotBar.progress:setBackgroundColor(getHealthColorSafe(pokemon.health))
	doUpdateTimerBall(slotBar)
	doUpdateAbilities(slotBar)
	doUpdateElementSlotBar(slotBar)

	if pokemon.text == tr("USE") then
		currentSlotBar = slotBar
		doUpdateStateSlotBar(slotBar, true)
	elseif slotBar == currentSlotBar then
		currentSlotBar = nil
		doUpdateStateSlotBar(slotBar, false)
	else
		doUpdateStateSlotBar(slotBar, false)
	end
end

local function onDragEnter(slotBar, mousePosition)
	if panelBar.isEditingMode then
		slotBar.drag = true
		g_mouse.pushCursor("target")
	else
		panelBar:breakAnchors()
		slotBar.movingReference = {
			x = mousePosition.x - panelBar:getX(),
			y = mousePosition.y - panelBar:getY()
		}
	end

	return not panelBar:isOn()
end

local function onDragMove(slotBar, mousePosition, mouseMoved)
	if not panelBar.isEditingMode then
		local pos = {
			x = mousePosition.x - slotBar.movingReference.x,
			y = mousePosition.y - slotBar.movingReference.y
		}

		panelBar:setPosition(pos)
		panelBar:bindRectToParent()
	end

	return not panelBar:isOn()
end

local function onDragLeave(slotBar, droppedWidget, mousePosition)
	if panelBar.isEditingMode then
		local move = panelBar:getChildByPos(mousePosition)

		if move and move ~= slotBar and move.moveSlot then
			local moveIndex = panelBar:getChildIndex(move)
			local selfIndex = panelBar:getChildIndex(slotBar)

			pokemonOrder[move.pokemon.name] = selfIndex
			pokemonOrder[slotBar.pokemon.name] = moveIndex

			panelBar:moveChildToIndex(move, selfIndex)
			panelBar:moveChildToIndex(slotBar, moveIndex)
			doUpdateHotkey(move)
			doUpdateHotkey(slotBar)
		end

		slotBar.drag = false
		slotBar:setOpacity(0.8)
		g_mouse.popCursor("target")
	else
		slotBar.dragLeave = g_clock.millis() + 2
	end
end

local function onMouseRelease(slotBar, mousePosition, mouseButton)
	if mouseButton == MouseLeftButton and g_clock.millis() > slotBar.dragLeave and not panelBar.isEditingMode then
		g_game.talkChannel(MessageModes.None, 0, "/pb " .. slotBar.pokemon.fastcallNumber)
	end

	return true
end

local function onHoverChange(slotBar, hovered)
	if panelBar.isEditingMode then
		if hovered then
			slotBar:setOpacity(1)
		elseif not slotBar.drag then
			slotBar:setOpacity(0.8)
		end
	end
end

local function onClick(widget)
	if not hasKeybindManager then
		return
	end

	local slotBar = widget:getParent()
	local keybind = KeybindManager:getKeybindByName("Chamar " .. panelBar:getChildIndex(slotBar), "Pokemon")

	if keybind then
		keybind:capture(KEYCOMBO_PRIMARY)
	end
end

local function onAddSlotBar(pokemon)
	if type(pokemon) ~= "table" then
		return
	end

	if not pokemon.fastcallNumber or pokemon.fastcallNumber <= 0 then
		return
	end

	if not pokemon.name or pokemon.name == "" then
		return
	end

	local slotBar = g_ui.createWidget("SlotBar", panelBar)

	slotBar.onDragEnter = onDragEnter
	slotBar.onDragMove = onDragMove
	slotBar.onDragLeave = onDragLeave
	slotBar.onMouseRelease = onMouseRelease
	slotBar.onHoverChange = onHoverChange
	slotBar.keyCombo.onClick = onClick
	pokemonOrder[pokemon.name] = pokemonOrder[pokemon.name] or panelBar:getChildCount()

	g_mouse.bindPress(slotBar, createMenu, MouseRightButton)
	slotBar:setId(pokemon.fastcallNumber)
	doUpdateSlotBar(slotBar, pokemon)
	doUpdateHotkey(slotBar)
	doUpdateResizeBar()
end

local function onRemoveSlotBar(fastcallNumber)
	local slotBar = panelBar[fastcallNumber]

	if slotBar then
		doRemoveSlotBar(slotBar)
	end
end

local function onUpdateSlotBar(pokemon)
	local slotBar = panelBar[pokemon.fastcallNumber]

	if slotBar then
		doUpdateSlotBar(slotBar, pokemon)
	end
end

local function toggle()
	if not panelBar then
		return
	end

	local visible = not panelBar:isVisible()
	panelBar:setVisible(visible)
	syncTopButtonState()

	if modules.client_options and modules.client_options.setOption then
		modules.client_options.setOption("pokebar", visible, false)
	end
end

function init()
	protocol.initProtocol()
	connect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd
	})
	connect(PokeBar, {
		onAddSlotBar = onAddSlotBar,
		onRemoveSlotBar = onRemoveSlotBar,
		onUpdateSlotBar = onUpdateSlotBar
	})
	connect(Creature, {
		onHealthPercentChange = onCreatureHealthPercentChange
	})
	if hasKeybindManager then
		connect(KeybindManager, {
			onUpdateHotkey = onUpdateHotkey
		})
	end

	panelBar = g_ui.displayUI("pokebar", rootWidget)
	if not panelBar then
		panelBar = g_ui.loadUI("pokebar", rootWidget)
	end
	if not panelBar then
		return
	end

	if modules.client_topmenu and modules.client_topmenu.addRightGameToggleButton then
		pokeBarButton = modules.client_topmenu.addRightGameToggleButton("pokeBarButton", tr("Poke Bar"), "/images/topbuttons/buttons", toggle, false, 9)
	end

	syncTopButtonState()
end

function terminate()
	protocol.terminateProtocol()
	disconnect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd
	})
	disconnect(Creature, {
		onHealthPercentChange = onCreatureHealthPercentChange
	})
	if hasKeybindManager then
		disconnect(KeybindManager, {
			onUpdateHotkey = onUpdateHotkey
		})
	end
	if pokeBarButton then
		pokeBarButton:destroy()
		pokeBarButton = nil
	end
	if panelBar then
		panelBar:destroy()
		panelBar = nil
	end
end

function onGameStart()
	local settings = g_settings.getNode("pokebarConfig")

	if settings then
		if settings.orders then
			pokemonOrder = settings.orders
			scheduleEvent(doUpdateOrder, 100)
		end

		panelBar:breakAnchors()
		panelBar:setOn(settings.locked)
		panelBar:setPosition(settings.position)
	end

	panelBar:setVisible(not modules.client_options or not modules.client_options.getOption or modules.client_options.getOption("pokebar"))
	syncTopButtonState()
end

function onGameEnd()
	local settings = {
		position = pointtostring(panelBar:getPosition()),
		locked = panelBar:isOn(),
		orders = pokemonOrder
	}

	currentSlotBar = nil
	panelBar:destroyChildren()
	g_settings.setNode("pokebarConfig", settings)
end

function onCreatureHealthPercentChange(creature, health)
	-- A pokebar recebe a vida correta pelo opcode 86; atualizar por qualquer
	-- Creature.onHealthPercentChange fazia o slot ativo copiar a vida do alvo.
	return
end

function onUpdateHotkey(category, name, keyCombo, altKeyCombo)
	if category == "Pokemon" and slotBarAssociationsHotkeys[name] then
		slotBarAssociationsHotkeys[name].keyCombo:setText(keyCombo)
	end
end

function createMenu()
	local menu = g_ui.createWidget("PopupMenu")

	menu:addOption(panelBar:isOn() and tr("Unlocked") or tr("Locked"), function()
		panelBar:setOn(not panelBar:isOn())
	end)
	menu:addOption(panelBar.isEditingMode and tr("Save order") or tr("Edit order"), function()
		doEditOrder()
	end)
	menu:display()
end

function getPokemonBar()
	return panelBar
end

function doCallPokemon(index)
	local slotBar = panelBar:getChildByIndex(index)

	if slotBar then
		g_game.talkChannel(MessageModes.None, 0, ("/pb %d"):format(slotBar.pokemon.fastcallNumber))
	end
end
