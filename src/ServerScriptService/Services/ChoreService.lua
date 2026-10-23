-- 집안일: 섬에 잡초·낙엽·돌멩이가 저절로 생기고, 누르면 치워 +3코인. 벌칙은 없다(아늑함 정돈 보너스만 빠진다).
-- 섬을 비운 30분마다 1개(최대 6, 처음 섬은 3개), 접속 중 10분마다 1개(섬에 최대 8개).
-- 저장은 남은 개수(profile.Chores)만, 자리는 섬을 지을 때마다 새로 고른다. 명세: design/gdd/housekeeping.md
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local DecorService = require(script.Parent.DecorService)
local Inventory = require(script.Parent.Inventory)
local IslandGen = require(script.Parent.IslandGen)

local OFFLINE_EVERY, OFFLINE_MAX, FIRST_ISLAND = 1800, 6, 3
local ONLINE_EVERY, MAX = 600, 8
local REWARD = 3
local REACH = 20

-- 종류별 모양: { 크기, 위치(바닥 기준), 색, 기울기(도) }
local KINDS = {
	Weed = {
		{ Vector3.new(0.3, 1.3, 0.7), Vector3.new(0, 0.55, 0), Color3.fromRGB(95, 150, 60), 15 },
		{ Vector3.new(0.3, 1.1, 0.6), Vector3.new(0.35, 0.45, 0.2), Color3.fromRGB(110, 165, 70), -25 },
		{ Vector3.new(0.3, 1, 0.6), Vector3.new(-0.3, 0.4, -0.2), Color3.fromRGB(85, 140, 55), 30 },
	},
	Leaves = {
		{ Vector3.new(1.1, 0.15, 0.8), Vector3.new(0, 0.1, 0), Color3.fromRGB(220, 140, 60), 0 },
		{ Vector3.new(0.9, 0.15, 0.7), Vector3.new(0.4, 0.22, 0.3), Color3.fromRGB(200, 90, 50), 20 },
		{ Vector3.new(0.9, 0.15, 0.7), Vector3.new(-0.35, 0.3, -0.25), Color3.fromRGB(235, 185, 80), -15 },
	},
	Pebble = {
		{ Vector3.new(0.9, 0.6, 0.8), Vector3.new(0, 0.25, 0), Color3.fromRGB(150, 150, 155), 0 },
		{ Vector3.new(0.6, 0.45, 0.6), Vector3.new(0.6, 0.2, 0.3), Color3.fromRGB(125, 125, 130), 0 },
	},
}
local KIND_NAMES = { "Weed", "Leaves", "Pebble" }

local ChoreService = {}
local chores = {} -- [player] = { Island, Folder, Rng, NextAt, Models = { [모델] = true } }

-- 집안일이 생기는 구역: 집터·숲·상점 거리(농장 밭·낚시터 물·광산 광석 위에는 생기지 않는다)
local ZONES = { House = true, Wild = true, Plaza = true }

-- 그 구역 청크 윗면의 빈 자리(평평한 땅, 나무·물 위 제외). 30번 찾아 못 찾으면 nil
local function findSpot(entry)
	local island = entry.Island
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { island.Blocks, island.Plants, island.Water }
	local chunks = {}
	for _, c in island.Gen.Chunks do
		if ZONES[c.Zone] then
			table.insert(chunks, c)
		end
	end
	local size = IslandGen.CHUNK * IslandGen.CELL
	for _ = 1, 30 do
		local c = chunks[entry.Rng:NextInteger(1, #chunks)]
		local x = (c.X + entry.Rng:NextNumber(0.1, 0.9)) * size
		local z = (c.Z + entry.Rng:NextNumber(0.1, 0.9)) * size
		local hit = workspace:Raycast(island.Origin + Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
		if hit and hit.Instance.Parent == island.Blocks and hit.Normal.Y > 0.75 then -- 나무 위·물 위는 버린다
			return hit.Position
		end
	end
	return nil
end

local function spawnChore(player)
	local entry = chores[player]
	local position = entry and findSpot(entry)
	if not position then
		return false
	end
	local kind = KIND_NAMES[entry.Rng:NextInteger(1, #KIND_NAMES)]
	local model = Instance.new("Model")
	model.Name = kind
	local base = CFrame.new(position) * CFrame.Angles(0, entry.Rng:NextNumber(0, 2 * math.pi), 0)
	for _, spec in KINDS[kind] do
		local part = Instance.new("Part")
		part.Anchored, part.CanCollide = true, false
		part.Size = spec[1]
		part.CFrame = base * CFrame.new(spec[2]) * CFrame.Angles(0, 0, math.rad(spec[4]))
		part.Color = spec[3]
		part.Material = if kind == "Pebble" then Enum.Material.Slate else Enum.Material.Grass
		part.Parent = model
	end
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Kind", kind)
	CollectionService:AddTag(model, "Chore")
	model.Parent = entry.Folder
	entry.Models[model] = true
	return true
end

local function onClean(player, model)
	local entry = chores[player]
	local profile = DataService.Get(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not entry or not entry.Models[model] or not profile or not root
		or (root.Position - model:GetPivot().Position).Magnitude > REACH then
		return
	end
	entry.Models[model] = nil
	local position = model:GetPivot().Position
	local kind = model:GetAttribute("Kind")
	model:Destroy()
	profile.Chores = math.max(0, profile.Chores - 1)
	Inventory.AddCoins(player, REWARD)
	Remotes.Feedback:FireAllClients("Clean", { Player = player, Position = position + Vector3.new(0, 1, 0), Text = "+" .. REWARD .. " 코인",
		Kind = kind, Last = profile.Chores == 0 })
	DecorService.UpdateCozy(player)
end

function ChoreService.Load(player, island)
	local profile = DataService.Get(player)
	local folder = Instance.new("Folder")
	folder.Name = "Chores"
	folder.Parent = island.Model
	chores[player] = { Island = island, Folder = folder, Rng = Random.new(), NextAt = os.clock() + ONLINE_EVERY, Models = {} }

	local added = if profile.LastSeen == 0 then FIRST_ISLAND
		else math.min(OFFLINE_MAX, math.floor((os.time() - profile.LastSeen) / OFFLINE_EVERY))
	local count = math.min(MAX, profile.Chores + added)
	local spawned = 0
	for _ = 1, count do
		spawned += if spawnChore(player) then 1 else 0
	end
	profile.Chores = spawned
	DecorService.UpdateCozy(player)
end

function ChoreService.Unload(player)
	chores[player] = nil
end

function ChoreService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target)
		if kind == "Chore" and typeof(target) == "Instance" then
			onClean(player, target)
		end
	end)

	-- 접속 중에도 10분마다 하나씩(섬에 8개까지)
	task.spawn(function()
		while true do
			task.wait(10)
			local now = os.clock()
			for player, entry in chores do
				local profile = DataService.Get(player)
				if profile and now >= entry.NextAt then
					entry.NextAt = now + ONLINE_EVERY
					if profile.Chores < MAX and spawnChore(player) then
						profile.Chores += 1
						DecorService.UpdateCozy(player)
					end
				end
			end
		end
	end)
end

return ChoreService
