-- chunkname: @/modules/game_cam/listCamPanel.lua

ListCamPanel = {}

local protocol = runinsandbox("protocol")

function ListCamPanel:new(params)
	local window = g_ui.createWidget("ListCamWindow", modules.game_interface.getRightPanel())
	local obj = {
		panel = window,
		list = ListCams:new(params)
	}
	local instance = setmetatable(obj, {
		__index = self
	})

	instance:setup()

	return window
end

function ListCamPanel:setup()
	self:registerControls()
	self:listCam()
end

function ListCamPanel:registerControls()
	return
end

function ListCamPanel:listCam()
	self.panel.list:destroyChildren()

	for i, channel in ipairs(self.list:getChannels()) do
		-- block empty
	end
end

function ListCamPanel:watchCam()
	return
end
