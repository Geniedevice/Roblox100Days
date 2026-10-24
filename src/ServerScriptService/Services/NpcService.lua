-- 섬 NPC: 마당에 세우고, 다가가 E(모바일은 버튼)를 누르면 대화한다. 대화는 Dialogues 그래프를
-- 서버가 한 노드씩 진행하고 클라이언트에는 문장과 선택지 글만 보낸다(고른 번호만 돌아온다).
-- NPC마다 상점(Shop)이 있으면 대화에서 열 수 있다. 사고팔기는 전부 서버가 검사한다.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Crops)
local Fish = require(ReplicatedStorage.Shared.Fish)
local Furniture = require(ReplicatedStorage.Shared.Furniture)
local IslandConcepts = require(ReplicatedStorage.Shared.IslandConcepts)
local Lines = require(ReplicatedStorage.Shared.Lines)
local Ores = require(ReplicatedStorage.Shared.Ores)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Dialogues = require(script.Parent.Dialogues)
local DexService = require(script.Parent.DexService)
local FarmService = require(script.Parent.FarmService)
local Inventory = require(script.Parent.Inventory)
local IslandGen = require(script.Parent.IslandGen)
local IslandService = require(script.Parent.IslandService)

local TALK_RANGE = 16 -- 이보다 멀어지면 대화·상점이 닫힌다

-- 자리는 IslandGen Npc(상점 거리 노점·안내도 옆). 색은 HumanoidDescription(기본 블록 아바타)에 칠한다
local NPCS = {
	{
		Id = "Guide", Name = "안내인 루미", Role = "밭·땅 넓히기 · 물고기·광석 팔기",
		Skin = Color3.fromRGB(255, 225, 200), Shirt = Color3.fromRGB(110, 160, 230), Pants = Color3.fromRGB(240, 240, 245),
	},
	{
		Id = "Gardener", Name = "정원사 모모", Shop = "Seeds", Role = "씨앗 · 작물 팔기 · 도우미 동물",
		Skin = Color3.fromRGB(255, 220, 190), Shirt = Color3.fromRGB(120, 180, 95), Pants = Color3.fromRGB(150, 110, 70),
	},
	{
		Id = "Carpenter", Name = "목수 버니", Shop = "Furniture", Role = "가구",
		Skin = Color3.fromRGB(240, 200, 170), Shirt = Color3.fromRGB(200, 140, 80), Pants = Color3.fromRGB(90, 110, 150),
	},
}

local SET_NAMES = { Log = "통나무 세트", Garden = "정원 세트" }

-- 상점 Id → (보는 사람) → 상품 목록 { Id(아이템), Name, Price, Desc, Once(하나만 가질 수 있다) }
local SHOPS = {
	Seeds = function()
		local items = {}
		for id, crop in Crops do
			table.insert(items, { Id = "Seed_" .. id, Name = crop.Name .. " 씨앗", Price = crop.SeedPrice, Order = crop.Order,
				Desc = string.format("%d분 만에 자라요 · %d코인에 팔려요", crop.Grow // 60, crop.SellPrice) })
		end
		table.sort(items, function(a, b)
			return a.Order < b.Order
		end)
		return items
	end,
	Furniture = function()
		local items = {}
		for id, data in Furniture.Items do
			local set = data.Set and (" · " .. SET_NAMES[data.Set]) or ""
			table.insert(items, { Id = id, Name = data.Name, Price = data.Price, Order = data.Order, Desc = "아늑함 +" .. data.Cozy .. set })
		end
		table.sort(items, function(a, b)
			return a.Order < b.Order
		end)
		return items
	end,
	Pets = function(player)
		local items = {}
		for id, pet in Pets do
			local owned = Inventory.Count(player, "Pet_" .. id) > 0
			table.insert(items, { Id = "Pet_" .. id, Name = pet.Name, Price = pet.Price, Order = pet.Order, Once = true,
				Desc = pet.Desc .. (if owned then " · 함께 지내는 중" else "") })
		end
		table.sort(items, function(a, b)
			return a.Order < b.Order
		end)
		return items
	end,
}
local STALL = { Pets = "Seeds" } -- 도우미 동물은 모모 노점(씨앗 상점)에서 판다

local NpcService = {}
local sessions = {} -- [player] = { Npc = 정의, Model, Node = 노드 Id, Shown = 보여 준 선택지, Sold }

local function feedback(player, kind, model, info)
	info = info or {}
	info.Player = player
	info.Position = model:GetPivot().Position + Vector3.new(0, 2, 0)
	Remotes.Feedback:FireAllClients(kind, info)
end

local ACTIONS = {
	OpenShop = function(player, session)
		Remotes.Dialogue:FireClient(player, { Shop = session.Npc.Shop, Title = session.Npc.Name, Items = SHOPS[session.Npc.Shop](player), Npc = session.Model })
	end,
	OpenPets = function(player, session)
		Remotes.Dialogue:FireClient(player, { Shop = "Pets", Title = session.Npc.Name, Items = SHOPS.Pets(player), Npc = session.Model })
	end,
	SellCrops = function(player, session)
		local total = 0
		for id, crop in Crops do
			local count = Inventory.Count(player, id)
			if count > 0 and Inventory.Add(player, id, -count) then
				total += count * crop.SellPrice
			end
		end
		Inventory.AddCoins(player, total)
		session.Sold = total
		feedback(player, "Sell", session.Model, { Text = "+" .. total .. " 코인" })
	end,
	GiftSeeds = function(player, session)
		Inventory.Add(player, "Seed_Turnip", 5)
		feedback(player, "Gift", session.Model, { Text = "순무 씨앗 ×5" })
	end,
	-- 안내인: 물고기·광석 매입, 밭 열기, 땅 넓히기
	SellGoods = function(player, session)
		local total = 0
		for _, source in { { Fish, "Fish_" }, { Ores, "Ore_" } } do
			for id, data in source[1] do
				local count = Inventory.Count(player, source[2] .. id)
				if count > 0 and Inventory.Add(player, source[2] .. id, -count) then
					total += count * data.Price
				end
			end
		end
		Inventory.AddCoins(player, total)
		session.Sold = total
		feedback(player, "Sell", session.Model, { Text = "+" .. total .. " 코인" })
	end,
	BuyField = function(player, session)
		local reason = FarmService.BuyField(player)
		session.Result = reason or Lines.Get("GUIDE_FIELD_DONE")
		session.Close = reason == nil -- 성공하면 대화를 닫아 밭이 늘어나는 연출이 가리지 않게
	end,
}
-- 땅 사기: 구역마다 행동 하나(BuyChunk_Farm …). 섬에 붙은 빈 자리(구름 판)에 무작위 바이옴 청크 하나를 붙여 그것만 짓는다
for _, zone in IslandGen.BuyZones do
	ACTIONS["BuyChunk_" .. zone] = function(player, session)
		local profile = DataService.Get(player)
		if not IslandService.CanExpand(player) then
			session.Result = Lines.Get("GUIDE_NO_LAND")
			return
		elseif not Inventory.AddCoins(player, -IslandService.ChunkPrice(profile)) then
			session.Result = Lines.Get("GUIDE_NO_COINS")
			return
		end
		local record, spot = IslandService.AddChunk(player, profile, zone)
		local chunk = IslandGen.CHUNK
		local biome = IslandConcepts[spot.Biome or record.Concept]
		Remotes.Feedback:FireAllClients("Expand", {
			Player = player, Text = "섬이 넓어졌어요!", Zone = zone,
			Sub = string.format("%s · %s · %d청크", IslandGen.Zones[zone].Name, biome.Name, #record.Gen.Chunks),
			Position = IslandService.YardPoint(record, (spot.X + 0.5) * chunk, (spot.Z + 0.5) * chunk),
			Size = chunk * IslandGen.CELL,
		})
		session.Result = Lines.Get("GUIDE_LAND_DONE")
		session.Close = true
	end
end

local function npcState(player, npcId)
	local profile = DataService.Get(player)
	profile.Npc[npcId] = profile.Npc[npcId] or {}
	return profile.Npc[npcId]
end

local function vars(player, session)
	local v = table.clone(npcState(player, session.Npc.Id))
	local profile = DataService.Get(player)
	local island = IslandService.Find(session.Model) -- 친구 섬 NPC면 그 섬(명물 안내)
	v.Home = island ~= nil and island == IslandService.Get(player) -- 밭 열기·섬 넓히기는 내 섬 루미에게서만
	v.CropCount = 0
	for id in Crops do
		v.CropCount += Inventory.Count(player, id)
	end
	v.GoodsCount = 0
	for _, source in { { Fish, "Fish_" }, { Ores, "Ore_" } } do
		for id in source[1] do
			v.GoodsCount += Inventory.Count(player, source[2] .. id)
		end
	end
	v.Sold = session.Sold
	v.Result = session.Result
	v.FieldPrice = FarmService.FieldPrice(profile)
	v.FieldsLeft = FarmService.FieldsLeft(player)
	v.ChunkPrice = IslandService.ChunkPrice(profile)
	v.ChunksLeft = if IslandService.CanExpand(player) then 1 else 0
	if island then
		local loot = island.Gen.Loot
		v.Island = IslandConcepts[island.Concept].Name
		v.SpecialFish, v.SpecialOre, v.SpecialCrop = Fish[loot.SpecialFish].Name, Ores[loot.SpecialOre].Name, Crops[loot.SpecialCrop].Name
	end
	return v
end

local function close(player)
	sessions[player] = nil
	Remotes.Dialogue:FireClient(player, { Close = true })
end

local function present(player)
	local session = sessions[player]
	local node = Dialogues[session.Npc.Id].Nodes[session.Node]
	for key, value in node.Set or {} do
		npcState(player, session.Npc.Id)[key] = value
	end
	if node.Action then
		ACTIONS[node.Action](player, session)
	end
	if node.End then
		return close(player)
	end
	local v = vars(player, session)
	local shown = {}
	for _, choice in node.Choices or { { Text = "OPT_NEXT", To = node.Next } } do
		if not choice.If or choice.If(v) then
			table.insert(shown, choice)
		end
	end
	session.Shown = shown
	local texts = {}
	for i, choice in shown do
		texts[i] = Lines.Get(choice.Text, v)
	end
	Remotes.Dialogue:FireClient(player, { Speaker = session.Npc.Name, Text = Lines.Get(node.Line, v), Choices = texts, Npc = session.Model })
end

local function inRange(player, model)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and model.Parent ~= nil and (root.Position - model:GetPivot().Position).Magnitude <= TALK_RANGE
end

local function talk(player, def, model)
	if not DataService.Get(player) then
		return
	end
	sessions[player] = { Npc = def, Model = model }
	sessions[player].Node = Dialogues[def.Id].Start(vars(player, sessions[player]))
	present(player)
end

local function buildNpc(def, island)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = def.Skin, def.Skin, def.Skin
	desc.TorsoColor = def.Shirt
	desc.LeftLegColor, desc.RightLegColor = def.Pants, def.Pants
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = def.Id
	model:SetAttribute("NpcId", def.Id)
	model:SetAttribute("Shop", def.Shop)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = def.Name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- 이름은 아래 이름표가 하는 일과 함께 보인다
	local tag = Instance.new("BillboardGui") -- 멀리서도 누가 무엇을 하는지(40스터드까지)
	tag.Name = "RoleTag"
	tag.Size = UDim2.fromOffset(240, 46)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 40
	tag.LightInfluence = 0
	for i, line in { { def.Name, 18, Enum.Font.GothamBlack }, { def.Role or "", 14, Enum.Font.GothamBold } } do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0, 0, (i - 1) * 0.52, 0)
		label.Size = UDim2.fromScale(1, if i == 1 then 0.52 else 0.48)
		label.Text, label.TextSize, label.Font = line[1], line[2], line[3]
		label.TextColor3 = if i == 1 then Color3.fromRGB(255, 250, 235) else Color3.fromRGB(255, 236, 190)
		label.TextStrokeTransparency = 0.25
		label.TextStrokeColor3 = Color3.fromRGB(110, 78, 52)
		label.Parent = tag
	end
	tag.Parent = model:FindFirstChild("Head") or model.PrimaryPart
	local root = model.PrimaryPart
	root.Anchored = true

	-- 노점 계산대 뒤(안내인은 안내도 옆)에서 Face 쪽을 보고 선다
	local spot = island.Gen.Npc[def.Id]
	local ground = IslandService.YardPoint(island, spot.Position.X, spot.Position.Y)
	local position = ground + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local face = IslandService.YardPoint(island, spot.Face.X, spot.Face.Y)
	model:PivotTo(CFrame.lookAt(position, Vector3.new(face.X, position.Y, face.Z)))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "대화하기"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		talk(player, def, model)
	end)
	prompt.Parent = root
	CollectionService:AddTag(model, "Npc")
	if island.Model.Parent then -- 모델을 만드는 사이 주인이 나가 섬이 지워졌을 수 있다
		model.Parent = island.Model
	else
		model:Destroy()
	end
end

-- 대화 그래프 검사: 없는 노드로 가는 길, 끝나지 않는 노드, 없는 대사·행동을 Output에 알린다.
local function validate()
	for npcId, graph in Dialogues do
		local function check(where, ok, what)
			if not ok then
				warn(string.format("[NpcService] %s.%s: %s", npcId, where, what))
			end
		end
		for id, node in graph.Nodes do
			check(id, node.End or node.Next or node.Choices, "끝나지 않는 노드")
			check(id, node.End or Lines.ko[node.Line], "없는 대사 " .. tostring(node.Line))
			check(id, not node.Next or graph.Nodes[node.Next], "없는 노드 " .. tostring(node.Next))
			check(id, not node.Action or ACTIONS[node.Action], "없는 행동 " .. tostring(node.Action))
			for _, choice in node.Choices or {} do
				check(id, graph.Nodes[choice.To], "없는 노드 " .. tostring(choice.To))
				check(id, Lines.ko[choice.Text], "없는 대사 " .. tostring(choice.Text))
				check(id, not choice.Action or ACTIONS[choice.Action], "없는 행동 " .. tostring(choice.Action))
			end
		end
	end
end

function NpcService.Spawn(island)
	for _, def in NPCS do
		buildNpc(def, island)
	end
end

function NpcService.Forget(player)
	sessions[player] = nil
end

function NpcService.Start()
	validate()

	Remotes.Dialogue.OnServerEvent:Connect(function(player, index)
		local session = sessions[player]
		if not session then
			return
		end
		local choice = type(index) == "number" and session.Shown[index]
		if not choice or not inRange(player, session.Model) then
			return close(player) -- 0(닫기), 이상한 값, 너무 멀어짐
		end
		if choice.Action then
			ACTIONS[choice.Action](player, session)
			if session.Close then
				return close(player) -- 땅·밭을 샀다: 대화를 닫고 섬이 넓어지는 연출을 보여 준다
			end
		end
		session.Node = choice.To
		present(player)
	end)

	Remotes.Shop.OnServerInvoke = function(player, shopId, itemId)
		local list = type(shopId) == "string" and SHOPS[shopId] and SHOPS[shopId](player)
		local item
		for _, entry in list or {} do
			if entry.Id == itemId then
				item = entry
			end
		end
		if not item then
			return false, "없는 상품이에요"
		end
		local near = false
		for _, model in CollectionService:GetTagged("Npc") do
			near = near or (model:GetAttribute("Shop") == (STALL[shopId] or shopId) and inRange(player, model))
		end
		if not near then
			return false, "상점 주인에게 가까이 가 주세요"
		elseif item.Once and Inventory.Count(player, item.Id) > 0 then
			return false, "이미 함께 지내고 있어요"
		elseif not Inventory.AddCoins(player, -item.Price) then
			return false, "코인이 모자라요"
		end
		Inventory.Add(player, item.Id, 1)
		if Furniture.Items[item.Id] then
			DexService.Record(player, "Furniture", item.Id)
		end
		return true, Lines.Josa(item.Name, "을", "를") .. " 샀어요"
	end
end

return NpcService
