-- 플레이어 기록 저장(DataStore). 지금은 최고 생존 일차(BestDay)만 저장한다.
-- publish 전(PlaceId 0)이거나 Studio API 접근이 꺼져 있으면 저장 없이 그대로 돈다.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}
local store
local profiles = {} -- [player] = { BestDay = number }

local function keyFor(player)
	return "player_" .. player.UserId
end

local function load(player)
	local data
	if store then
		local ok, result = pcall(store.GetAsync, store, keyFor(player))
		if ok then
			data = result
		else
			warn("[DataService] 불러오기 실패:", result)
		end
	end
	if not player.Parent then
		return
	end
	profiles[player] = { BestDay = data and data.BestDay or 0 }
	player:SetAttribute("BestDay", profiles[player].BestDay)
end

-- 다른 서버가 먼저 더 높은 기록을 썼을 수 있으니 큰 값을 남긴다.
local function save(player)
	local profile = profiles[player]
	if not store or not profile then
		return
	end
	local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function(old)
		old = old or {}
		old.BestDay = math.max(old.BestDay or 0, profile.BestDay)
		return old
	end)
	if not ok then
		warn("[DataService] 저장 실패:", err)
	end
end

-- 매일 아침 GameLoop가 부른다. 그날에 도달한 플레이어의 최고 기록을 올리고 저장한다.
function DataService.RecordDay(day)
	for _, player in Players:GetPlayers() do
		local profile = profiles[player]
		if profile and day > profile.BestDay then
			profile.BestDay = day
			player:SetAttribute("BestDay", day)
			task.spawn(save, player)
		end
	end
end

-- 저장을 쓸 수 없으면 nil (RunSaveService도 같은 DataStore를 쓴다)
function DataService.GetStore()
	return store
end

function DataService.Start()
	if game.PlaceId ~= 0 then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Config.Data.StoreName)
		store = ok and result or nil
	end

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)
	-- 서버가 닫힐 때 남은 플레이어를 모두 저장하고, 끝날 때까지 기다린다.
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

return DataService
