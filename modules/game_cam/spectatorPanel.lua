-- chunkname: @/modules/game_cam/spectatorPanel.lua

SpectatorPanel = {}

local protocol = runinsandbox("protocol")

function SpectatorPanel:new(params)
	local window = g_ui.createWidget("SpectatorCamWindow", modules.game_interface.getRightPanel())
	local obj = {
		panel = window.contentsPanel,
		cam = Spectator:new(params)
	}
	local instance = setmetatable(obj, {
		__index = self
	})

	window.cam = instance

	instance:setup()
	window:setup()

	return window
end

function SpectatorPanel:setup()
	local hasTimer = self.cam:hasStreamingTimer()
	local parent = self.panel:getParent()

	if hasTimer then
		self:onTimer()
	end

	self.panel.views:setVisible(self.cam:getStreamingViews())
	self.panel.timer:setVisible(hasTimer)
	parent:setChecked(hasTimer)
	self:registerControls()
	self:updatePokemons()
	self:updateViews()
	self:updateName()
	g_keyboard.bindKeyDown("Left", function()
		self:prevChannel()
	end)
	g_keyboard.bindKeyDown("Right", function()
		self:nextChannel()
	end)
end

function SpectatorPanel:registerControls()
	function self.panel.prev.onClick()
		self:nextChannel()
	end

	function self.panel.next.onClick()
		self:prevChannel()
	end

	function self.panel.close()
		self:onClose()
	end
end

function SpectatorPanel:updateName()
	self.panel.name:setText(self.cam:getStreamingName())
end

function SpectatorPanel:updateViews()
	self.panel.views:setText(self.cam:getStreamingViews())
end

function SpectatorPanel:updateTimer()
	self.panel.timer:setText(self.cam:getStreamingTimer())
end

function SpectatorPanel:updatePokemons()
	local pokemons = self.cam:getStreamingPokemons()

	self.panel.pokemons:destroyChildren()

	for i, pokemon in pairs(pokemons) do
		local portrait = g_ui.createWidget("SpectatorCamPokemon", self.panel.pokemons)

		portrait:setImageSource(pokemon.image)
		portrait:setTooltip(pokemon.tooltip)
	end

	self.panel:updatePanel(pokemons)
end

function SpectatorPanel:nextChannel()
	protocol.sendNext()
end

function SpectatorPanel:prevChannel()
	protocol.sendPrev()
end

function SpectatorPanel:onClose()
	g_keyboard.unbindKeyDown("Left")
	g_keyboard.unbindKeyDown("Right")
	self.cam:removeEventId()
	modules.game_console.removeTab(modules.game_console.getChannelTab(self.cam:getStreamingChannelId()))
end

function SpectatorPanel:onTimer()
	self:updateTimer()
	self.cam:removeEventId()
	self.cam:setEventId(scheduleEvent(function()
		self:onTimer()
	end, 1000))
end

function SpectatorPanel:onUpdate(params)
	local update = {
		name = self.updateName,
		views = self.updateViews,
		pokemon = self.updatePokemons
	}

	self.cam:update(params)

	for key, fn in pairs(update) do
		if params[key] then
			fn(self)
		end
	end
end
