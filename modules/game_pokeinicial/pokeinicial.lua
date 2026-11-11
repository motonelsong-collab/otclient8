-- chunkname: @/modules/game_pokeinicial/pokeinicial.lua

local window, confirmWindow
local ExtendsOpcodes = {
	ParseMsg = 2,
	PokeInit = 82,
	ParseOpen = 1
}

local function reallocatePanel(panel, index, numColumn)
	local parent = panel:getParent()

	if index == 1 or index <= numColumn then
		panel:addAnchor(AnchorTop, "parent", AnchorTop)
	elseif index % numColumn == 1 then
		panel:setMarginTop(22)
		panel:addAnchor(AnchorTop, "prev", AnchorBottom)
	else
		panel:addAnchor(AnchorTop, "prev", AnchorTop)
	end

	if index == 1 or index % numColumn == 1 then
		panel:addAnchor(AnchorLeft, "parent", AnchorLeft)
	else
		panel:setMarginLeft(16)
		panel:addAnchor(AnchorLeft, "prev", AnchorRight)
	end
end

function init()
	connect(g_game, {
		onGameEnd = destroy
	})
	connect(LocalPlayer, {
		onPositionChange = onPokeInitPositionChange
	})
	ProtocolGame.registerExtendedJSONOpcode(ExtendsOpcodes.PokeInit, function(protocol, opcode, json_data)
		local action = json_data.action
		local data = json_data.data
		local executeAction = {
			[ExtendsOpcodes.ParseOpen] = showChoosePokemon,
			[ExtendsOpcodes.ParseMsg] = displayMessage
		}

		if executeAction[action] then
			executeAction[action](data)
		end
	end)
end

function terminate()
	disconnect(g_game, {
		onGameEnd = destroy
	})
	disconnect(LocalPlayer, {
		onPositionChange = onPokeInitPositionChange
	})
	ProtocolGame.unregisterExtendedJSONOpcode(ExtendsOpcodes.PokeInit)
	destroy()
end

function onPokeInitPositionChange()
	if window and window:isVisible() then
		destroy()
	end
end

function destroy()
	if window then
		window:destroy()

		window = nil
	end

	destroyConfirmWindow()
end

function destroyConfirmWindow()
	if confirmWindow then
		confirmWindow:destroy()

		confirmWindow = nil
	end
end

function showChoosePokemon(pokemon)
	if window and not window:isHidden() then
		return
	end

	destroy()

	window = g_ui.displayUI("pokeinicial")

	createOptions(pokemon)
end

function createOptions(data)
	for index, value in pairs(data) do
		local panel = g_ui.createWidget("ChoosePanel", window.pokemonList)

		reallocatePanel(panel, index, 2)

		for _, pokemon in pairs(value.pokemons) do
			local choosePokemon = g_ui.createWidget("ChoosePokemon", panel)

			choosePokemon.name:setText(pokemon.name)
			choosePokemon:setTooltip(pokemon.description)
			choosePokemon.image:setImageSource(getPokemonPortrait(pokemon.name))
		end

		panel:setText(value.title)
		panel:setWidth(#value.pokemons * 97)

		if index == #data then
			panel:breakAnchors()
			panel:setMarginBottom(20)
			panel:addAnchor(AnchorBottom, "parent", AnchorBottom)
			panel:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
		end
	end
end

function choosePokemon()
	scheduleEvent(function()
		if confirmWindow then
			destroyConfirmWindow()
		end

		local selectedWidget = window.pokemonList.selectedWidget

		if not selectedWidget then
			return displayMessage(tr("Choose you pokemon"))
		end

		local pokeName = selectedWidget.name:getText()
		local msg = tr("Do you really want to choose %s as your first pokemon?", pokeName)

		local function confirmCallback()
			g_game.talkChannel(MessageModes.None, 0, ("!inicial %s"):format(pokeName))
			destroy()
		end

		confirmWindow = displayGeneralBox(window:getText(), msg, {
			{
				color = "Blue",
				text = tr("Yes"),
				callback = confirmCallback
			},
			{
				color = "Red",
				text = tr("No"),
				callback = destroyConfirmWindow
			},
			anchor = AnchorHorizontalCenter
		}, confirmCallback, destroyConfirmWindow)

		confirmWindow:show()
		confirmWindow:raise()
	end, 50)
end

function displayMessage(message)
	if window then
		displayInfoBox(window:getText(), message)
	end
end
