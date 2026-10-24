-- 진입점. 접속하면 데이터를 불러와 그 플레이어의 시드 하늘섬(4×4 청크 + 산 땅)을 짓고(연합이면 멤버 섬 옆에)
-- 밭·NPC·가구·집안일·광석·생물·도우미 동물을 채운 뒤 섬에서 태어나게 한다. 나가면 섬을 지우고 저장한다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Services = script.Parent:WaitForChild("Services")
local ChoreService = require(Services.ChoreService)
local CreatureService = require(Services.CreatureService)
local DataService = require(Services.DataService)
local DecorService = require(Services.DecorService)
local DexService = require(Services.DexService)
local EventService = require(Services.EventService)
local FarmService = require(Services.FarmService)
local FishService = require(Services.FishService)
local IslandService = require(Services.IslandService)
local Inventory = require(Services.Inventory)
local MineService = require(Services.MineService)
local NpcService = require(Services.NpcService)
local PartyPlayService = require(Services.PartyPlayService)
local PartyService = require(Services.PartyService)
local PetService = require(Services.PetService)
local UnionService = require(Services.UnionService)

local function unload(player)
	FarmService.Unload(player)
	DecorService.Unload(player)
	ChoreService.Unload(player)
	MineService.Unload(player)
	FishService.Unload(player)
	CreatureService.Unload(player)
	PetService.Unload(player)
	EventService.Unload(player)
	NpcService.Forget(player)
end

-- 섬을 채운다. moved = 섬만 옮겼다(연합)
local function fill(player, island, moved)
	FarmService.Load(player, island)
	DecorService.Load(player, island)
	ChoreService.Load(player, island, moved) -- 오프라인 동안 생긴 집안일(LastSeen 기준)이라 첫 저장 전에 부른다
	MineService.Load(player, island)
	CreatureService.Load(player, island)
	PetService.Load(player, island)
	NpcService.Spawn(island) -- NPC 모델을 만드는 동안 기다린다(그 사이 나갈 수 있다)
end

-- 섬 연합: 섬을 place 자리(nil = 빈 슬롯)로 옮겨 다시 짓는다. 밭·가구·광석은 섬 원점 기준이라 그대로다
local function moveIsland(player, place)
	unload(player)
	IslandService.Remove(player) -- 놀러 와 있던 사람은 집으로
	local island = IslandService.Spawn(player, DataService.Get(player), place)
	IslandService.MoveTo(player, island)
	fill(player, island, true)
	return island
end

DataService.Start()
IslandService.Start()
FarmService.Start()
NpcService.Start()
DexService.Start()
DecorService.Start()
ChoreService.Start()
MineService.Start()
FishService.Start()
CreatureService.Start()
PartyService.Start()
PartyPlayService.Start()
PetService.Start()
EventService.Start()
UnionService.Start(moveIsland)

-- 설정(움직임 줄이기·떠오르는 글자·콤보·효과음 크기, 섬 방문 파티원만·파티원 수확): 저장하고 속성 Setting_<이름>으로 돌려준다
local SETTINGS = { ReduceMotion = "boolean", FloatText = "boolean", Combo = "boolean", Volume = "number",
	VisitParty = "boolean", HarvestParty = "boolean" }
local function applySettings(player, settings)
	for key, kind in SETTINGS do
		local value = settings[key]
		if type(value) == kind then
			player:SetAttribute("Setting_" .. key, if kind == "number" then math.clamp(value, 0, 1) else value)
		end
	end
end
Remotes.Interact.OnServerEvent:Connect(function(player, kind, _, settings)
	local profile = DataService.Get(player)
	if kind ~= "Settings" or not profile or type(settings) ~= "table" then
		return
	end
	for key, valueKind in SETTINGS do
		if type(settings[key]) == valueKind then
			profile.Settings[key] = if valueKind == "number" then math.clamp(settings[key], 0, 1) else settings[key]
		end
	end
	applySettings(player, profile.Settings)
end)

local function onPlayerAdded(player)
	local profile = DataService.Load(player)
	if not profile then
		return
	end
	Inventory.Sync(player)
	applySettings(player, profile.Settings)
	local island = UnionService.Spawn(player, profile)
	DexService.Record(player, "Islands", island.Concept)
	fill(player, island)
	if player.Parent then
		player:LoadCharacter()
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player)
	unload(player)
	PartyService.Unload(player)
	PartyPlayService.Unload(player)
	UnionService.Unload(player)
	IslandService.Remove(player)
	DataService.Release(player)
end)
