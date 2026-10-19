-- 진입점. 컴퍼니(상점) → 세상 탐사 PeriodDays일(낮 파밍, 밤 좀비 무리) → 귀환·생존비 납부를 100일까지 반복한다.
-- 전원 사망하거나 생존비를 못 내면 패배.
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
local LootService = require(Services.LootService)
local CraftingService = require(Services.CraftingService)
local CombatService = require(Services.CombatService)
local DataService = require(Services.DataService)
local RunSaveService = require(Services.RunSaveService)
local AbilityService = require(Services.AbilityService)
local CompanyService = require(Services.CompanyService)

PlayerService.Start()
ZombieAI.Start()
SurvivalStats.Start()
AugmentService.Start()
InventoryService.Start()
LootService.Start()
CraftingService.Start()
CombatService.Start()
DataService.Start()
RunSaveService.Start()
AbilityService.Start()
CompanyService.Start()
Players.PlayerAdded:Connect(DayManager.SyncPlayer)

local function isLost()
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
	LootService.Reset()
	DayManager.Reset()
	CompanyService.Reset()
	PlayerService.ResetAll()
end

local function runDay(day)
	WaveManager.Clear()
	PlayerService.ReviveAll()
	DayManager.StartDay(day)
	DataService.RecordDay(day)
	task.spawn(WaveManager.Spawn, day, false)
	if not waitPhase(Config.DAY_LENGTH) then
		return false
	end

	DayManager.StartNight()
	task.spawn(WaveManager.Spawn, day, true)
	local survived = waitPhase(Config.NIGHT_LENGTH)
	WaveManager.Stop()
	return survived
end

local function runGame(startDay)
	local length = Config.Company.PeriodDays
	for period = (startDay - 1) // length + 1, Config.TOTAL_DAYS // length do
		local firstDay = (period - 1) * length + 1
		RunSaveService.Save(firstDay) -- 컴퍼니에 있을 때만 저장한다(이어하면 이 기간 출발 전부터)
		CompanyService.Lobby(period)
		CompanyService.Launch()
		for day = firstDay, period * length do
			if not runDay(day) then
				return false
			end
		end
		if not CompanyService.Return(period) then
			return false
		end
	end
	return true
end

while true do
	while #Players:GetPlayers() == 0 do
		task.wait(1)
	end

	resetGame()
	local won = runGame(RunSaveService.Begin())
	WaveManager.Stop()
	RunSaveService.Clear()

	if won then
		Remotes.GameMessage:FireAllClients("100일 생존 성공! 컴퍼니가 당신을 인정했습니다")
	else
		Remotes.GameMessage:FireAllClients(string.format("%d일차에 끝났습니다... 10초 후 다시 시작", DayManager.Day))
	end
	task.wait(10)
	workspace:SetAttribute("Phase", "Lobby")
end
