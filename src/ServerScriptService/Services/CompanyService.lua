-- 로비 컴퍼니. 기간(Config.Company.PeriodDays일)마다: 컴퍼니(대기·상점) → 세상 하나로 출발 → 생존 → 귀환·정산.
-- 귀환하면 모은 고물을 팔고 그 기간의 생존비를 낸다. 못 내면 해고(판 종료).
-- 공유 상태는 workspace 속성: Phase("Lobby"|"Expedition"), Credits(팀 공용), Period, Quota, ActiveWorld, NextWorld, LobbyEndsAt.
-- 컴퍼니 건물은 Workspace.Company(tools/BuildCompany.lua). 그 안의 Terminal·Lever 파츠에 ProximityPrompt를 단다.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AugmentData = require(ReplicatedStorage.Shared.AugmentData)
local AugmentService = require(script.Parent.AugmentService)
local CombatService = require(script.Parent.CombatService)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local PlayerService = require(script.Parent.PlayerService)
local WaveManager = require(script.Parent.WaveManager)

local CompanyService = {}
local shopOffers = {} -- [player] = 이번 컴퍼니 방문에서 살 수 있는 증강 Id 목록
local launchRequested = false

local WORLDS, EQUIPMENT = {}, {}
for _, world in Config.Worlds do
	WORLDS[world.Id] = world
end
for _, item in Config.Shop.Equipment do
	EQUIPMENT[item.Id] = item
end

function CompanyService.QuotaFor(period)
	return Config.Company.FirstQuota + Config.Company.QuotaStep * (period - 1)
end

local function credits()
	return workspace:GetAttribute("Credits") or 0
end

local function spend(amount)
	if credits() < amount then
		return false
	end
	workspace:SetAttribute("Credits", credits() - amount)
	return true
end

local function inLobby(player)
	return workspace:GetAttribute("Phase") == "Lobby" and player.Character ~= nil
end

local function moveAll(cframe)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			character:PivotTo(cframe + Vector3.new(math.random(-3, 3), 4, math.random(-3, 3)))
		end
	end
end

local function setAtmosphere(settings)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and settings then
		atmosphere.Density = settings.Density
		atmosphere.Color = settings.Color
		atmosphere.Haze = settings.Haze
	end
end

local function rollShop(player)
	shopOffers[player] = AugmentService.Roll(player, workspace:GetAttribute("Period") or 1, Config.Shop.AugmentOffers)
	Remotes.ShopOffers:FireClient(player, shopOffers[player])
end

local function buyEquipment(player, item)
	if item.Weapon and player:GetAttribute("Has" .. item.Weapon) then
		return false, "이미 가지고 있습니다"
	end
	if not spend(item.Price) then
		return false, "크레딧이 부족합니다"
	end
	if item.Weapon then
		player:SetAttribute("Has" .. item.Weapon, true)
		CombatService.GiveWeapon(player)
	end
	for name, count in item.Items or {} do
		InventoryService.Add(player, name, count)
	end
	return true, item.Name .. " 구매!"
end

local function buyAugment(player, id)
	local offers = shopOffers[player]
	local index = offers and table.find(offers, id)
	local data = AugmentData[id]
	if not index or not data then
		return false, "판매 중이 아닙니다"
	end
	if (player:GetAttribute("Aug_" .. id) or 0) >= data.MaxStack then
		return false, "최대 레벨입니다"
	end
	if not spend(Config.Shop.AugmentPrice[data.Rarity]) then
		return false, "크레딧이 부족합니다"
	end
	table.remove(offers, index)
	AugmentService.Give(player, id)
	Remotes.ShopOffers:FireClient(player, offers)
	return true, data.Name .. " 구매!"
end

-- 판을 시작할 때(이어하기면 RunSaveService가 Credits·NextWorld를 덮어쓴다)
function CompanyService.Reset()
	workspace:SetAttribute("Credits", Config.Company.StartCredits)
	workspace:SetAttribute("NextWorld", Config.Worlds[1].Id)
	workspace:SetAttribute("ActiveWorld", nil)
	workspace:SetAttribute("Period", 0)
	workspace:SetAttribute("Quota", 0)
end

-- 기간이 끝나면 부른다: 컴퍼니로 귀환 → 고물 판매 → 생존비 납부. 못 내면 false(해고).
function CompanyService.Return(period)
	WaveManager.Clear()
	workspace:SetAttribute("Phase", "Lobby")
	setAtmosphere(Config.Company.Atmosphere)
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	moveAll(spawn and spawn.CFrame or CFrame.new(Config.Company.Origin))
	PlayerService.ReviveAll()

	local scrap = 0
	for _, player in Players:GetPlayers() do
		scrap += InventoryService.Get(player, "Scrap")
		player:SetAttribute("Scrap", 0)
	end
	local earned = scrap * Config.Company.ScrapValue
	local quota = CompanyService.QuotaFor(period)
	workspace:SetAttribute("Credits", credits() + earned)
	local paid = spend(quota)
	Remotes.GameMessage:FireAllClients(string.format("고물 %d개 → %d 크레딧. 생존비 %d %s", scrap, earned, quota,
		paid and "납부 완료!" or "납부 실패... 해고되었습니다"))
	return paid
end

-- 컴퍼니에서 대기(상점). LobbyTime이 지나거나 누군가 출발하면 끝난다.
function CompanyService.Lobby(period)
	workspace:SetAttribute("Phase", "Lobby")
	workspace:SetAttribute("Period", period)
	workspace:SetAttribute("Quota", CompanyService.QuotaFor(period))
	setAtmosphere(Config.Company.Atmosphere)
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	for _, player in Players:GetPlayers() do
		rollShop(player)
	end
	launchRequested = false
	local endsAt = workspace:GetServerTimeNow() + Config.Company.LobbyTime
	workspace:SetAttribute("LobbyEndsAt", endsAt)
	while not launchRequested and workspace:GetServerTimeNow() < endsAt do
		task.wait(0.5)
	end
end

-- 고른 세상으로 출발한다. 이동비가 모자라면 첫 번째 세상(무료)으로 간다.
function CompanyService.Launch()
	local world = WORLDS[workspace:GetAttribute("NextWorld")] or Config.Worlds[1]
	if not spend(world.TravelCost) then
		Remotes.GameMessage:FireAllClients(world.Name .. " 이동비가 모자라 " .. Config.Worlds[1].Name .. "(으)로 갑니다")
		world = Config.Worlds[1]
	end
	workspace:SetAttribute("ActiveWorld", world.Id)
	workspace:SetAttribute("Phase", "Expedition")
	setAtmosphere(world.Atmosphere)
	table.clear(shopOffers)
	LootService.Reset()
	local worlds = workspace:FindFirstChild("Worlds")
	local spawn = worlds and worlds:FindFirstChild(world.Id) and worlds[world.Id]:FindFirstChild("Spawn")
	moveAll(spawn and spawn.CFrame or CFrame.new(world.Origin))
	Remotes.GameMessage:FireAllClients(world.Name .. " 도착! 고물을 모아 오세요")
end

function CompanyService.Start()
	workspace:SetAttribute("Phase", "Lobby")
	CompanyService.Reset()

	local company = workspace:FindFirstChild("Company")
	local terminal = company and company:FindFirstChild("Terminal", true)
	local lever = company and company:FindFirstChild("Lever", true)
	if terminal then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "상점 열기"
		prompt.ObjectText = "컴퍼니 단말기"
		prompt.RequiresLineOfSight = false
		prompt.Parent = terminal
		prompt.Triggered:Connect(function(player)
			Remotes.OpenShop:FireClient(player)
		end)
	end
	if lever then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "출발"
		prompt.ObjectText = "출발 레버"
		prompt.HoldDuration = 1
		prompt.RequiresLineOfSight = false
		prompt.Parent = lever
		prompt.Triggered:Connect(function(player)
			if inLobby(player) then
				launchRequested = true
			end
		end)
	end

	Remotes.Launch.OnServerEvent:Connect(function(player)
		if inLobby(player) then
			launchRequested = true
		end
	end)
	Remotes.SelectWorld.OnServerEvent:Connect(function(player, id)
		if inLobby(player) and typeof(id) == "string" and WORLDS[id] then
			workspace:SetAttribute("NextWorld", id)
			Remotes.GameMessage:FireAllClients(player.DisplayName .. "님이 다음 목적지를 " .. WORLDS[id].Name .. "(으)로 정했습니다")
		end
	end)
	Remotes.Buy.OnServerInvoke = function(player, kind, id)
		if not inLobby(player) or typeof(id) ~= "string" then
			return false, "컴퍼니에서만 살 수 있습니다"
		end
		if kind == "Equipment" and EQUIPMENT[id] then
			return buyEquipment(player, EQUIPMENT[id])
		elseif kind == "Augment" then
			return buyAugment(player, id)
		end
		return false, "알 수 없는 상품"
	end
	Remotes.RerollShop.OnServerInvoke = function(player)
		if not inLobby(player) or not spend(Config.Shop.RerollPrice) then
			return false
		end
		rollShop(player)
		return true
	end

	-- 컴퍼니에 있는 동안 들어온 플레이어도 증강 목록을 받는다
	Players.PlayerAdded:Connect(function(player)
		if workspace:GetAttribute("Phase") == "Lobby" and (workspace:GetAttribute("Period") or 0) > 0 then
			task.wait(2)
			rollShop(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		shopOffers[player] = nil
	end)
end

return CompanyService
