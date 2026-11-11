-- chunkname: @/modules/game_cam/listCams.lua

ListCams = {}

function ListCams:new(params)
	local cams = {
		list = params
	}

	table.sort(cams.list, function(a, b)
		return a.views > b.views
	end)

	return setmetatable(cams, {
		__index = self
	})
end

function ListCams:getChannels()
	return self.list
end
