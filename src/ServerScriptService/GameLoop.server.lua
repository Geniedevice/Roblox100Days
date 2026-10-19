-- 진입점. 낮 → 밤(웨이브) → 증강 → 다음 날을 100일 동안 반복한다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = script.Parent:WaitForChild("Services")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DayManager = require(Services.DayManager)
local BaseService = require(Services.BaseService)
local PlayerService = require(Services.PlayerService)
local WaveManager = require(Services.WaveManager)
local ZombieAI = require(Services.ZombieAI)
local SurvivalStats = require(Services.SurvivalStats)
local AugmentService = require(Services.AugmentService)
local InventoryService = require(Services.InventoryService)
local ResourceService = require(Services.ResourceService)

BaseService.GetCore()
PlayerService.Start()
ZombieAI.Start()
SurvivalStats.Start()
AugmentService.Start()
InventoryService.Start()
ResourceService.Start()
Players.PlayerAdded:Connect(DayManager.SyncPlayer)

local function isLost()
	if BaseService.IsDestroyed() then
		return true
	end
	return #Players:GetPlayers() > 0 and not PlayerService.AnyAlive()
end

-- 1초마다 패배 조건을 확인하며 기다린다. 패배하면 false.
local function waitPhase(seconds)
	local endsAt = os.clock() + seconds
	while os.clock() < endsAt do
		task.wait(1)
		if isLost() then
			return false
		end
	end
	return true
end

local function resetGame()
	WaveManager.Clear()
	BaseService.Reset()
	AugmentService.Reset()
	ResourceService.Reset()
	DayManager.Reset()
	PlayerService.ResetAll()
end

local function runGame()
	for day = 1, Config.TOTAL_DAYS do
		WaveManager.Clear()
		PlayerService.ReviveAll()
		DayManager.StartDay(day)
		if not waitPhase(Config.DAY_LENGTH) then
			return false
		end

		DayManager.StartNight()
		task.spawn(WaveManager.Spawn, day)
		local survived = waitPhase(Config.NIGHT_LENGTH)
		WaveManager.Stop()
		if not survived then
			return false
		end

		if day < Config.TOTAL_DAYS and day % Config.Augment.EveryDays == 0 then
			AugmentService.Offer(day)
		end
	end
	return true
end

while true do
	while #Players:GetPlayers() == 0 do
		task.wait(1)
	end

	resetGame()
	local won = runGame()
	WaveManager.Stop()

	if won then
		Remotes.GameMessage:FireAllClients("100일 생존 성공!")
	else
		Remotes.GameMessage:FireAllClients(string.format("%d일차에 쓰러졌습니다... 10초 후 다시 시작", DayManager.Day))
	end
	task.wait(10)
end
