-- chunkname: @/modules/game_cam/streamingPanel.lua

StreamingPanel = {}

local protocol = runinsandbox("protocol")

function StreamingPanel:new(params)
	local window = g_ui.createWidget("StreamingCamWindow", modules.game_interface.getRightPanel())
	local obj = {
		panel = window.contentsPanel,
		cam = Streaming:new(params)
	}
	local instance = setmetatable(obj, {
		__index = self
	})

	window.cam = instance

	instance:setup()
	window:setup()

	return window
end

function StreamingPanel:setup()
	self:registerControls()
	self:updateViews()
	self:updateName()
	self:onTimer()
end

function StreamingPanel:registerControls()
	function self.panel.edit.onClick()
		self:edit()
	end

	function self.panel.views.onClick()
		self:showSpectators()
	end

	function self.panel.close()
		self:onClose()
	end
end

function StreamingPanel:updateName()
	self.panel.name:setText(self.cam:getName())
end

function StreamingPanel:updateViews()
	self.panel.views:setText(self.cam:getViews())
end

function StreamingPanel:updateTimer()
	self.panel.timer:setText(self.cam:getTimer())
end

function StreamingPanel:showSpectators()
	if self.cam:getViews() > 0 then
		protocol.sendShowSpectators()
	end
end

function StreamingPanel:edit()
	modules.client_textedit.edit(self.cam:getName(), {
		width = 410,
		title = tr("Change Title"),
		description = tr("Write a name for your broadcast title")
	}, function(text)
		if text:trim():len() > 0 and text:len() < 21 then
			protocol.sendChangeName(text)
		end
	end)
end

function StreamingPanel:onClose()
	self.cam:removeEventId()
	modules.game_console.removeTab(modules.game_console.getChannelTab(self.cam:getChannelId()))
end

function StreamingPanel:onTimer()
	self:updateTimer()
	self.cam:removeEventId()
	self.cam:setEventId(scheduleEvent(function()
		self:onTimer()
	end, 1000))
end

function StreamingPanel:onUpdate(params)
	local update = {
		name = self.updateName,
		views = self.updateViews
	}

	self.cam:update(params)

	for key, fn in pairs(update) do
		if params[key] then
			fn(self)
		end
	end
end
