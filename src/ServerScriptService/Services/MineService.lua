-- 광산: 섬의 광석 블록(IslandBuilder가 Ore·Key 속성을 단 Part)을 눌러 Ores[종류].Hits번 두드리면 캐진다.
-- 캔 광석은 돌처럼 보이다가 Respawn초 뒤 다시 차오른다(섬을 비운 동안에도 시간은 흐른다).
-- 저장은 profile.Mined["x,y,z"] = 캔 시각뿐. 어떤 광석이 박히는지는 섬 시드의 획득물 표(Shared/Loot)가 정한다.
-- 명세: design/gdd/mining.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ores = require(ReplicatedStorage.Shared.Ores)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local DexService = require(script.Parent.DexService)
local Inventory = require(script.Parent.Inventory)
local IslandService = require(script.Parent.IslandService)

local REACH = 22 -- 캐릭터에서 광석까지(스터드)
local HIT_GAP = 0.22 -- 타격 사이 최소 간격(초, 연타 매크로 방지)
local RESET = 4 -- 이 시간 동안 안 치면 친 횟수가 처음으로
local DEPLETED_COLOR = Color3.fromRGB(118, 116, 112)
local RARE = { Gold = true, Amethyst = true, Diamond = true }

local MineService = {}
local mines = {} -- [player] = { Island, Nodes = { [key] = Part }, Hits = { [key] = { Count, At } }, LastHit }

local function deplete(part)
	part:SetAttribute("Depleted", true)
	part:SetAttribute("OreColor", part.Color)
	part:SetAttribute("OreMaterial", part.Material.Name)
	part.Color = DEPLETED_COLOR
	part.Material = Enum.Material.Slate
end

local function restore(part)
	part:SetAttribute("Depleted", nil)
	part.Color = part:GetAttribute("OreColor") or part.Color
	part.Material = Enum.Material[part:GetAttribute("OreMaterial") or "Slate"]
end

-- 섬 지형의 광석 Part를 모으고 저장된 캔 상태를 입힌다(지형을 다시 지으면 다시 부른다)
function MineService.Load(player, island)
	local profile = DataService.Get(player)
	local nodes = {}
	local now = os.time()
	for _, part in island.Blocks:GetChildren() do
		local key = part:GetAttribute("Key")
		local ore = key and Ores[part:GetAttribute("Ore")]
		if ore then
			nodes[key] = part
			local minedAt = profile.Mined[key]
			if minedAt and now < minedAt + ore.Respawn then
				deplete(part)
			else
				profile.Mined[key] = nil
			end
		end
	end
	mines[player] = { Island = island, Nodes = nodes, Hits = {}, LastHit = 0 }
end

function MineService.Unload(player)
	mines[player] = nil
end

local function onHit(player, part)
	local entry = mines[player]
	local profile = DataService.Get(player)
	local key = part:GetAttribute("Key")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not entry or not profile or not key or entry.Nodes[key] ~= part or part:GetAttribute("Depleted") or not root
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
	profile.Mined[key] = os.time()
	deplete(part)
	Inventory.Add(player, "Ore_" .. id, 1)
	info.Item = id
	info.Rare = RARE[id] == true
	info.Special = entry.Island.Gen.Loot.SpecialOre == id
	info.Text = "+1 " .. ore.Name .. (if info.Special then " · 섬 명물!" else "")
	Remotes.Feedback:FireAllClients("MineBreak", info)
	DexService.Record(player, "Ores", id)
end

function MineService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target)
		if kind == "Mine" and typeof(target) == "Instance" and target:IsA("BasePart") then
			onHit(player, target)
		end
	end)
	IslandService.Rebuilt.Event:Connect(MineService.Load) -- 광산 땅을 사면 광석이 는다

	-- 캔 광석이 다시 차오른다(5초마다 확인)
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for player, entry in mines do
				local profile = DataService.Get(player)
				for key, part in entry.Nodes do
					local minedAt = profile and profile.Mined[key]
					if minedAt and now >= minedAt + Ores[part:GetAttribute("Ore")].Respawn then
						profile.Mined[key] = nil
						restore(part)
						Remotes.Feedback:FireAllClients("OreRespawn", { Player = player, Position = part.Position, Part = part })
					end
				end
			end
		end
	end)
end

return MineService
