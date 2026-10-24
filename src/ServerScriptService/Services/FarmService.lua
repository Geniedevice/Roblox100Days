-- 농사: 농장 구역의 3×3 밭(청크마다 밭 자리 4개, IslandGen Fields 순서). 연 밭(profile.Fields)만 농지가 생기고,
-- 닫힌 밭 자리에는 반투명 판과 다음 밭 값 팻말이 있다(안내인 루미에게서 연다).
-- 농지를 누를 때마다 상태에 맞는 한 가지를 한다: 갈기 → 심기 → 물주기 → 수확.
-- 섬 명물 작물(Loot.SpecialCrop, 시드로 정해짐)은 거둘 때 25% 확률로 하나 더.
-- 작물은 실제 시간으로 자라고(섬을 비운 동안에도) 시들지 않는다. 저장은 profile.Tiles["번호"] =
-- { Tilled, Crop, PlantedAt, WateredAt }뿐이고, 자란 단계(0 씨앗 ~ 3 수확)는 시각으로 계산한다.
-- 물을 주면 그때부터 Grow/2초 동안 1.5배 빨리 자란다(작물마다 한 번). 섬 연합 이웃이 있으면 주인 UnionBonus만큼 더 빨리(island-union.md).
-- 남의 밭(party-visiting.md): 파티원은 물을 줄 수 있고, 주인이 "파티원 수확"을 켜면 거둘 수도 있다. 작물은 주인 것이다.
-- 도우미 동물(pets.md)은 FindJob으로 일을 찾고 Help로 주인 대신 한 번 누른다(연출은 주인 캐릭터 동작 없이).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Crops)
local Lines = require(ReplicatedStorage.Shared.Lines)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Models = require(ReplicatedStorage.Shared.Models)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local DexService = require(script.Parent.DexService)
local Inventory = require(script.Parent.Inventory)
local IslandGen = require(script.Parent.IslandGen)
local IslandService = require(script.Parent.IslandService)
local PartyService = require(script.Parent.PartyService)

local REACH = 20 -- 이 거리(스터드) 안에서만 농지를 만질 수 있다
local TILE = IslandGen.CELL * 0.9 -- 농지 한 칸 크기(블록보다 조금 작게 해서 틈이 보이게)

local FIELD_PRICE = 50 -- 밭 값 = 50 × 이미 연 밭 수(두 번째 50, 세 번째 100 …)

local COLORS = {
	Grass = Color3.fromRGB(175, 215, 135),
	Soil = Color3.fromRGB(135, 95, 65),
	Wet = Color3.fromRGB(90, 62, 45),
}

local FarmService = {}
local farms = {} -- [player] = { [번호] = 농지 Part }
local folders = {} -- [player] = Farm 폴더

-- 단계별 작물 모양(Shared/Models.Crop, 아이콘과 같은 모형). 모델은 태그 "Crop"(클라이언트가 흔들고 튀어 오르게 한다)
local function buildCrop(tile, cropId, stage)
	local model = Models.Crop(cropId, stage)
	model:PivotTo(tile.CFrame * CFrame.new(0, tile.Size.Y / 2, 0))
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanQuery = true, false -- 누르기는 농지 Part가 받는다
		end
	end
	model:SetAttribute("Stage", stage)
	CollectionService:AddTag(model, "Crop")
	model.Parent = tile
end

-- 성장 배수 = 1 + 연합 보너스(UnionService가 주인에게 단다)
local function rateOf(owner)
	return 1 + (owner:GetAttribute("UnionBonus") or 0)
end

-- 0..1 자란 정도
local function progress(state, crop, now, rate)
	local boost = state.WateredAt and math.clamp(now - state.WateredAt, 0, crop.Grow / 2) * 0.5 or 0
	return math.clamp((now - state.PlantedAt + boost) * rate / crop.Grow, 0, 1) -- 서버 시계가 뒤로 가도 0 아래로 가지 않게
end

local function stageOf(state, now, rate)
	local crop = state.Crop and Crops[state.Crop]
	if not crop then
		return nil
	end
	local p = progress(state, crop, now, rate)
	return if p >= 1 then 3 else math.floor(p * 3), crop, p
end

-- 다 자랄 때까지 남은 실제 초(물 효과가 남은 동안은 1.5배로 계산)
local function secondsLeft(state, crop, p, now, rate)
	local need = (1 - p) * crop.Grow / rate
	local boosted = if state.WateredAt then math.max(0, state.WateredAt + crop.Grow / 2 - now) else 0
	return if need <= boosted * 1.5 then need / 1.5 else boosted + (need - boosted * 1.5)
end

-- 농지 Part를 저장 상태에 맞춘다(바뀐 것만 다시 만든다)
local function refresh(tile, state, now, rate)
	local stage, crop = stageOf(state, now, rate)
	tile.Color = if not state.Tilled then COLORS.Grass elseif state.WateredAt and stage ~= 3 then COLORS.Wet else COLORS.Soil
	tile.Material = if state.Tilled then Enum.Material.Ground else Enum.Material.Grass
	tile:SetAttribute("Tilled", state.Tilled == true)
	tile:SetAttribute("Crop", state.Crop)
	tile:SetAttribute("Watered", state.WateredAt ~= nil)
	if tile:GetAttribute("Stage") ~= stage then
		tile:SetAttribute("Stage", stage)
		local old = tile:FindFirstChild("Crop")
		if old then
			old:Destroy()
		end
		if stage then
			buildCrop(tile, state.Crop, stage)
		end
	end
end

local function feedback(player, kind, tile, info)
	info = info or {}
	info.Player = player
	info.Position = tile.Position + Vector3.new(0, 1.5, 0)
	info.Part = tile -- 클라이언트 연출(번쩍임·찌그러짐) 대상
	Remotes.Feedback:FireAllClients(kind, info)
end

local function toast(player, text, tile) -- tile이 있으면 거절 연출(테두리 Coral 번쩍임)
	Remotes.Feedback:FireClient(player, "Toast", { Text = text, Part = tile })
end

-- 그 농지에서 지금 할 일(Till·Plant·Water·Harvest). 물 준 뒤 자라는 중이면 nil
local function jobOf(state, now, rate)
	local stage = stageOf(state, now, rate)
	if not state.Tilled then
		return "Till"
	elseif not stage then
		return "Plant"
	elseif stage == 3 then
		return "Harvest"
	end
	return if state.WateredAt then nil else "Water"
end

-- player = 누른 사람, owner = 밭 주인(같을 수 있다), byPet = 도우미 동물이 주인 대신 했다(주인 캐릭터는 움직이지 않는다)
local function onTile(player, owner, tile, seedId, byPet)
	local profile = DataService.Get(owner)
	local index = tile:GetAttribute("Index")
	local key = tostring(index)
	local state = profile.Tiles[key] or {}
	local now = os.time()
	local rate = rateOf(owner)
	local stage, crop, p = stageOf(state, now, rate)
	local helper = player ~= owner
	local who = if byPet then nil else player

	if helper and (not state.Tilled or not crop) then
		return toast(player, "친구 밭에서는 물주기만 도와줄 수 있어요", tile)
	elseif helper and stage < 3 and not state.WateredAt and not PartyService.Same(player, owner) then
		return toast(player, "파티원만 친구 밭에 물을 줄 수 있어요", tile)
	elseif helper and stage == 3 and not PartyService.CanHarvest(player, owner) then
		return toast(player, "주인이 \"파티원 수확\"을 켜야 거둘 수 있어요", tile)
	end

	if not state.Tilled then
		state.Tilled = true
		feedback(who, "Till", tile)
	elseif not crop then
		local seed = type(seedId) == "string" and Crops[seedId]
		if not seed then
			return toast(player, "아래 핫바에서 심을 씨앗을 골라 주세요", tile)
		elseif not Inventory.Add(player, "Seed_" .. seedId, -1) then
			return toast(player, seed.Name .. " 씨앗이 없어요. 정원사 모모에게 살 수 있어요", tile)
		end
		state.Crop, state.PlantedAt, state.WateredAt = seedId, now, nil
		feedback(who, "Plant", tile, { Item = seedId })
	elseif stage < 3 and not state.WateredAt then
		state.WateredAt = now
		feedback(who, "Water", tile)
		if helper then
			toast(owner, player.DisplayName .. "님이 " .. crop.Name .. "에 물을 줬어요")
		end
	elseif stage < 3 then
		local left = math.ceil(secondsLeft(state, crop, p, now, rate) / 60)
		return toast(player, string.format("%s 잘 자라는 중이에요. 약 %d분 남았어요", Lines.Josa(crop.Name, "이", "가"), left), tile)
	else
		local island = IslandService.Get(owner)
		local special = island and island.Gen.Loot.SpecialCrop == state.Crop
		local amount = if special and math.random() < Loot.SPECIAL_CROP_CHANCE then 2 else 1
		Inventory.Add(owner, state.Crop, amount)
		feedback(who, "Harvest", tile, { Item = state.Crop, Count = amount, Gift = helper, -- Gift: 핫바로 날아가지 않는다
			Text = string.format("+%d %s%s", amount, crop.Name, if helper then " → " .. owner.DisplayName
				elseif amount > 1 then " · 섬 명물!" else "") })
		DexService.Record(owner, "Crops", state.Crop)
		if helper then
			toast(owner, string.format("%s님이 %s %d개를 거둬 줬어요", player.DisplayName, crop.Name, amount))
		end
		if crop.Regrow then
			state.PlantedAt, state.WateredAt = now - (crop.Grow - crop.Regrow), nil -- 덤불은 남고 열매만 다시
		else
			state.Crop, state.PlantedAt, state.WateredAt = nil, nil, nil
		end
	end
	profile.Tiles[key] = state
	refresh(tile, state, now, rate)
end

-- 도우미 동물: 주인 농지 중 jobs(집합)에 맞는 일이 있는 칸에서 from에 가장 가까운 것 → 농지, 일
function FarmService.FindJob(owner, jobs, from)
	local tiles, profile = farms[owner], DataService.Get(owner)
	if not tiles or not profile then
		return nil
	end
	local now, rate = os.time(), rateOf(owner)
	local best, bestJob, bestDistance
	for i, tile in tiles do
		local job = jobOf(profile.Tiles[tostring(i)] or {}, now, rate)
		local distance = job and jobs[job] and (tile.Position - from).Magnitude
		if distance and (not bestDistance or distance < bestDistance) then
			best, bestJob, bestDistance = tile, job, distance
		end
	end
	return best, bestJob
end

-- 도우미 동물이 주인 대신 한 번 누른다. 그사이 상태가 바뀌어 그 일이 아니면 false
function FarmService.Help(owner, tile, job, seedId)
	local tiles, profile = farms[owner], DataService.Get(owner)
	local index = tile:GetAttribute("Index")
	if not tiles or not profile or tiles[index] ~= tile
		or jobOf(profile.Tiles[tostring(index)] or {}, os.time(), rateOf(owner)) ~= job then
		return false
	end
	onTile(owner, owner, tile, seedId, true)
	return true
end

function FarmService.FieldPrice(profile)
	return FIELD_PRICE * profile.Fields
end

-- 더 열 수 있는 밭 자리 수(농장 땅을 사면 자리가 4개씩 는다)
function FarmService.FieldsLeft(player)
	local island = IslandService.Get(player)
	local profile = DataService.Get(player)
	return if island and profile then #island.Gen.Fields - profile.Fields else 0
end

-- 닫힌 밭 자리: 반투명 판, 다음에 열 자리에는 값 팻말
local function lockedPlate(folder, island, field, label)
	local plate = Instance.new("Part")
	plate.Name = "LockedField"
	plate.Anchored, plate.CanCollide, plate.CanQuery, plate.CanTouch, plate.CastShadow = true, false, false, false, false
	plate.Size = Vector3.new(IslandGen.CELL * 3 - 0.4, 0.2, IslandGen.CELL * 3 - 0.4)
	plate.Position = IslandService.YardPoint(island, field.X + 1.5, field.Y + 1.5) + Vector3.new(0, 0.1, 0)
	plate.Color = Color3.fromRGB(255, 245, 220)
	plate.Material = Enum.Material.SmoothPlastic
	plate.Transparency = 0.6
	if label then
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(200, 50)
		tag.StudsOffset = Vector3.new(0, 4, 0)
		tag.MaxDistance = 90
		tag.LightInfluence = 0
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 250, 235)
		text.TextStrokeTransparency = 0.3
		text.TextStrokeColor3 = Color3.fromRGB(110, 80, 50)
		text.Text = label
		text.Parent = tag
		tag.Parent = plate
	end
	plate.Parent = folder
end

-- 섬 Model 아래 Farm 폴더를 (다시) 짓는다. 상태는 profile.Tiles에 있으니 몇 번 다시 지어도 같다
function FarmService.Load(player, island)
	local profile = DataService.Get(player)
	if folders[player] then
		folders[player]:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Farm"
	local tiles = {}
	local now = os.time()
	local rate = rateOf(player)
	local open = math.min(profile.Fields, #island.Gen.Fields)
	for f, field in island.Gen.Fields do
		if f > open then
			lockedPlate(folder, island, field, if f == open + 1
				then string.format("밭 자리 · %d코인\n안내인 루미에게서 열어요", FarmService.FieldPrice(profile)) else nil)
			continue
		end
		for k = 0, 8 do
			local i = (f - 1) * 9 + k + 1
			local center = IslandService.YardPoint(island, field.X + k % 3 + 0.5, field.Y + k // 3 + 0.5)
			local tile = Instance.new("Part")
			tile.Name = "Tile"
			tile.Anchored = true
			tile.Size = Vector3.new(TILE, 0.4, TILE)
			tile.CFrame = CFrame.new(center + Vector3.new(0, 0.05, 0))
			tile:SetAttribute("Owner", player.UserId)
			tile:SetAttribute("Index", i)
			CollectionService:AddTag(tile, "FarmTile")
			refresh(tile, profile.Tiles[tostring(i)] or {}, now, rate)
			tile.Parent = folder
			tiles[i] = tile
		end
	end
	folder.Parent = island.Model
	farms[player] = tiles
	folders[player] = folder
end

-- 밭 하나 더 열기(안내인 대화). 성공하면 nil, 아니면 이유
function FarmService.BuyField(player)
	local profile = DataService.Get(player)
	local island = IslandService.Get(player)
	if not profile or not island then
		return "섬을 찾지 못했어요"
	elseif FarmService.FieldsLeft(player) <= 0 then
		return "밭 자리가 다 찼어요. 농장 땅을 넓혀 보세요"
	elseif not Inventory.AddCoins(player, -FarmService.FieldPrice(profile)) then
		return "코인이 모자라요"
	end
	profile.Fields += 1
	FarmService.Load(player, island)
	local field = island.Gen.Fields[profile.Fields]
	Remotes.Feedback:FireAllClients("Expand", { Player = player, Small = true, Text = "밭이 늘었어요!",
		Sub = string.format("밭 %d / %d", profile.Fields, #island.Gen.Fields),
		Position = IslandService.YardPoint(island, field.X + 1.5, field.Y + 1.5) })
	return nil
end

function FarmService.Unload(player)
	farms[player] = nil
	folders[player] = nil
end

function FarmService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target, arg)
		if kind ~= "Tile" or typeof(target) ~= "Instance" then
			return
		end
		local owner = Players:GetPlayerByUserId(target:GetAttribute("Owner") or 0)
		local tiles = owner and farms[owner]
		if not tiles or tiles[target:GetAttribute("Index")] ~= target or not DataService.Get(player) then
			return -- 지금 있는 농지만
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - target.Position).Magnitude <= REACH then
			onTile(player, owner, target, arg)
		end
	end)

	IslandService.Rebuilt.Event:Connect(FarmService.Load) -- 농장 땅을 사면 밭 자리가 늘어난다

	-- 자라는 단계를 1초마다 맞춘다(연 밭의 칸만)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for player, tiles in farms do
				local profile = DataService.Get(player)
				local rate = rateOf(player)
				for i, tile in tiles do
					local state = profile and profile.Tiles[tostring(i)]
					if state and state.Crop then
						refresh(tile, state, now, rate)
					end
				end
			end
		end
	end)
end

return FarmService
