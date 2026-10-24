-- 광석 바위: 섬 숲 땅의 빈 자리에 시간이 지나면 광석 바위(블록 하나 + 받침 돌)가 솟는다. 광석 종류는 그 땅 바이옴의 획득물 표
-- (Shared/Loot: 시작 섬은 섬 컨셉, 산 청크는 저마다의 바이옴 — 메사는 금, 얼음 봉우리는 철처럼)에서 뽑는다.
-- 바위를 눌러 Ores[종류].Hits번 두드리면 캐지고 사라진다. 섬마다 최대 Max개, 모자라면 SPAWN_EVERY초마다 하나 솟는다.
-- 섬을 지으면(접속·연합 이동) 절반을 바로 채운다. 바위는 저장하지 않는다(다시 들어오면 새 자리에 솟는다).
-- 명세: design/gdd/mining.md
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blocks = require(ReplicatedStorage.Shared.Blocks)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Ores = require(ReplicatedStorage.Shared.Ores)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local DexService = require(script.Parent.DexService)
local Inventory = require(script.Parent.Inventory)
local IslandGen = require(script.Parent.IslandGen)
local IslandService = require(script.Parent.IslandService)
local PartyPlayService = require(script.Parent.PartyPlayService)

local REACH = 22 -- 캐릭터에서 광석까지(스터드)
local HIT_GAP = 0.22 -- 타격 사이 최소 간격(초, 연타 매크로 방지)
local RESET = 4 -- 이 시간 동안 안 치면 친 횟수가 처음으로
local VANISH_DELAY = 0.3 -- 곡괭이가 닿는 순간(클라이언트 연출 0.28초) 뒤에 사라진다
local RARE = { Gold = true, Amethyst = true, Diamond = true }
local SPAWN_EVERY = { 20, 40 } -- 모자랄 때 다음 바위까지(초)
local MAX_BASE, MAX_CAP = 4, 12 -- 섬마다 바위 수 = 4 + 숲 청크 수의 절반(최대 12)
local GAP = 10 -- 바위끼리·스폰에서 떨어진 거리(스터드)
local CELL = IslandGen.CELL

local MineService = {}
local mines = {} -- [player] = { Island, Folder, Nodes = { [key] = Part }, Hits = { [key] = { Count, At } }, LastHit, NextAt, Serial }
local oreBlocks = {} -- [광석 Id] = 블록 정의(색·재질)
for _, block in Blocks.List do
	if block.Ore then
		oreBlocks[block.Ore] = block
	end
end
local loots = {} -- ["시드:바이옴"] = 획득물 표
local rng = Random.new()

local function wildChunks(island)
	local list = {}
	for _, c in island.Gen.Chunks do
		if c.Zone == "Wild" then
			table.insert(list, c)
		end
	end
	return list
end

function MineService.Max(island)
	return math.min(MAX_CAP, MAX_BASE + #wildChunks(island) // 2)
end

local function lootFor(island, chunk)
	local seed, biome = island.Gen.Seed, chunk.Biome or island.Concept
	local key = seed .. ":" .. biome
	loots[key] = loots[key] or Loot.ForIsland(seed, biome)
	return loots[key]
end

local function count(entry)
	local n = 0
	for _ in entry.Nodes do
		n += 1
	end
	return n
end

-- 숲 청크 땅 위 빈 자리(나무 아래·물·다른 바위·스폰에서 떨어져) → 블록 가운데에 맞춘 땅 윗면 위치, 그 청크
local function findSpot(entry)
	local island = entry.Island
	local wild = wildChunks(island)
	local size = IslandGen.CHUNK * CELL
	for _ = 1, 16 do
		local c = wild[rng:NextInteger(1, math.max(1, #wild))]
		if not c then
			return nil
		end
		local bx = math.floor((c.X + rng:NextNumber(0.1, 0.9)) * IslandGen.CHUNK)
		local bz = math.floor((c.Z + rng:NextNumber(0.1, 0.9)) * IslandGen.CHUNK)
		local ground = IslandService.Ground(island, island.Origin + Vector3.new((bx + 0.5) * CELL, 0, (bz + 0.5) * CELL))
		local free = ground ~= nil and (ground - island.Spawn.Position).Magnitude > GAP
		for _, node in entry.Nodes do
			free = free and (node.Position - ground).Magnitude > GAP
		end
		if free then
			return ground, c
		end
	end
	return nil
end

local function spawnNode(player, entry, quiet)
	local ground, chunk = findSpot(entry)
	if not ground then
		return
	end
	local loot = lootFor(entry.Island, chunk)
	local id = Loot.Pick(loot.Ores, loot.OreTotal, rng:NextNumber())
	local block = oreBlocks[id]
	entry.Serial += 1
	local key = tostring(entry.Serial)
	local part = Instance.new("Part")
	part.Name = "OreRock"
	part.Anchored = true
	part.Size = Vector3.one * CELL
	part.CFrame = CFrame.new(ground + Vector3.new(0, CELL / 2, 0))
	part.Material, part.Color = block.Material, block.Color
	for i = 1, 3 do -- 받침 돌(장식, 눌리지 않는다)
		local pebble = Instance.new("Part")
		pebble.Anchored, pebble.CanCollide, pebble.CanQuery, pebble.CanTouch = true, false, false, false
		pebble.Size = Vector3.new(1.3, 0.7, 1.1) * rng:NextNumber(0.8, 1.25)
		pebble.Material, pebble.Color = Enum.Material.Slate, Color3.fromRGB(125, 125, 130)
		local angle = (i / 3 + rng:NextNumber(-0.08, 0.08)) * math.pi * 2
		pebble.CFrame = CFrame.new(ground + Vector3.new(math.cos(angle) * 1.9, 0.3, math.sin(angle) * 1.9)) * CFrame.Angles(0, angle, 0.2)
		pebble.Parent = part
	end
	part:SetAttribute("Ore", id)
	part:SetAttribute("Key", key)
	CollectionService:AddTag(part, "Ore")
	part.Parent = entry.Folder
	entry.Nodes[key] = part
	if not quiet then
		Remotes.Feedback:FireAllClients("OreRespawn", { Player = player, Position = part.Position, Part = part })
	end
end

-- 섬을 지은 뒤(접속·연합 이동): 바위 폴더를 새로 만들고 절반을 바로 채운다
function MineService.Load(player, island)
	local old = island.Model:FindFirstChild("Ores")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Ores"
	folder.Parent = island.Model
	local entry = { Island = island, Folder = folder, Nodes = {}, Hits = {}, LastHit = 0, Serial = 0,
		NextAt = os.clock() + rng:NextNumber(SPAWN_EVERY[1], SPAWN_EVERY[2]) }
	mines[player] = entry
	for _ = 1, MineService.Max(island) // 2 do
		spawnNode(player, entry, true)
	end
end

function MineService.Unload(player)
	local entry = mines[player]
	mines[player] = nil
	if entry then
		entry.Folder:Destroy()
	end
end

local function onHit(player, part)
	local entry = mines[player]
	local key = part:GetAttribute("Key")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not entry or not DataService.Get(player) or not key or entry.Nodes[key] ~= part or not root
		or (root.Position - part.Position).Magnitude > REACH then
		return
	end
	local clock = os.clock()
	if clock - entry.LastHit < HIT_GAP then
		return
	end
	entry.LastHit = clock
	local id = part:GetAttribute("Ore")
	local ore = Ores[id]
	local hits = entry.Hits[key]
	if not hits or clock - hits.At > RESET then
		hits = { Count = 0 }
		entry.Hits = { [key] = hits } -- 다른 광석으로 옮기면 앞의 것은 처음으로
	end
	hits.Count += 1
	hits.At = clock
	local info = { Player = player, Position = part.Position, Part = part, Ore = id, Hit = hits.Count, Need = ore.Hits }
	if hits.Count < ore.Hits then
		return Remotes.Feedback:FireAllClients("MineHit", info)
	end
	entry.Hits[key] = nil
	entry.Nodes[key] = nil
	part:SetAttribute("Depleted", true)
	task.delay(VANISH_DELAY, part.Destroy, part)
	entry.NextAt = math.max(entry.NextAt, clock + rng:NextNumber(SPAWN_EVERY[1], SPAWN_EVERY[2])) -- 다음 바위는 조금 뒤 다른 곳에
	Inventory.Add(player, "Ore_" .. id, 1)
	info.Item = id
	info.Rare = RARE[id] == true
	info.Special = entry.Island.Gen.Loot.SpecialOre == id
	info.Text = "+1 " .. ore.Name .. (if info.Special then " · 섬 명물!" else "")
	Remotes.Feedback:FireAllClients("MineBreak", info)
	DexService.Record(player, "Ores", id)
	PartyPlayService.Count(player, "Ore")
end

function MineService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target)
		if kind == "Mine" and typeof(target) == "Instance" and target:IsA("BasePart") then
			onHit(player, target)
		end
	end)

	-- 모자라면 바위가 하나씩 솟는다(2초마다 확인)
	task.spawn(function()
		while true do
			task.wait(2)
			local clock = os.clock()
			for player, entry in mines do
				if clock >= entry.NextAt then
					entry.NextAt = clock + rng:NextNumber(SPAWN_EVERY[1], SPAWN_EVERY[2])
					if count(entry) < MineService.Max(entry.Island) then
						spawnNode(player, entry)
					end
				end
			end
		end
	end)
end

return MineService
