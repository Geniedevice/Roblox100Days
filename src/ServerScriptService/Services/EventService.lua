-- 섬 이벤트와 작은 놀거리(명세: design/gdd/island-events.md). 접속한 섬마다 가끔(처음 1~2분, 그 뒤 3~6분마다) 하나씩 생긴다.
-- 누구나(방문객도) 먼저 다가가 누르는 사람이 받는다. 멀리서도 찾을 수 있게 "▼ 이름" 표지가 늘 위에 보인다.
--  Gift      선물 구름: 하늘에서 구름에 실린 선물 상자가 마당에 내려앉는다(2분). 열면 코인이나 씨앗
--  Butterfly 황금 나비: 숲·집터·농장 위를 팔랑이며 맴돈다(90초). 가까이 가서 잡으면 코인
--  Glint     반짝이는 땅: 숲·광산 땅이 반짝인다(2분 30초). 파 보면 광석이나 코인
-- 함께 받기: 연 사람과 같은 파티(연합)이고 40스터드 안에 있던 사람도 같은 표에서 따로 받는다(party-play.md).
-- 나무 흔들기: 섬 나무·버섯·선인장(Plants 블록)을 누르면 잎이 떨어지고 가끔 코인·씨앗이 떨어진다(같은 나무는 60초에 한 번).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Lines = require(ReplicatedStorage.Shared.Lines)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Inventory = require(script.Parent.Inventory)
local IslandGen = require(script.Parent.IslandGen)
local IslandService = require(script.Parent.IslandService)
local PartyPlayService = require(script.Parent.PartyPlayService)
local PartyService = require(script.Parent.PartyService)

local FIRST = { 60, 120 } -- 들어온 뒤 첫 이벤트까지(초)
local EVERY = { 180, 360 } -- 그 뒤 이벤트 사이(초)
local REACH = 14 -- 이벤트·나무까지(스터드)
local SHARE_REACH = 40 -- 함께 받기: 이벤트에서 이 안에 있던 파티원(스터드)
local SHAKE_GAP, TREE_REST = 1.2, 60 -- 흔들기 연타 막기, 같은 나무(9스터드 칸) 쉬는 초

-- Rewards: { 무게, Coins = { 최소, 최대 } } 또는 { 무게, Item, Count }
local EVENTS = {
	Gift = { Label = "선물 구름", Action = "열기", Life = 120, Zones = { Plaza = true, House = true, Farm = true },
		Rewards = { { 60, Coins = { 25, 60 } }, { 25, Item = "Seed_Carrot", Count = 3 }, { 15, Item = "Seed_Strawberry", Count = 1 } } },
	Butterfly = { Label = "황금 나비", Action = "잡기", Life = 90, Zones = { Wild = true, House = true, Farm = true },
		Rewards = { { 100, Coins = { 30, 80 } } } },
	Glint = { Label = "반짝이는 땅", Action = "파 보기", Life = 150, Zones = { Wild = true, Fishing = true },
		Rewards = { { 40, Item = "Ore_Iron", Count = 2 }, { 15, Item = "Ore_Gold", Count = 1 }, { 45, Coins = { 15, 40 } } } },
}
local KINDS = { "Gift", "Butterfly", "Glint" }
local SHAKE_REWARDS = { { 25, Coins = { 1, 4 } }, { 7, Item = "Seed_Turnip", Count = 1 }, { 68 } } -- 마지막 = 잎만 떨어진다

local EventService = {}
local active = {} -- [섬 주인] = { Kind, Model, Thread }
local nextAt = {} -- [섬 주인] = os.clock()
local lastShake = {} -- [player] = os.clock()
local treeRest = {} -- ["주인Id:x:z"] = os.clock()
local rng = Random.new()

local function pick(list)
	local total = 0
	for _, entry in list do
		total += entry[1]
	end
	local roll = rng:NextNumber(0, total)
	for _, entry in list do
		roll -= entry[1]
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

-- 보상을 주고 알림 글·아이템 정보를 돌려준다
local function give(player, reward)
	if reward.Coins then
		local coins = rng:NextInteger(reward.Coins[1], reward.Coins[2])
		Inventory.AddCoins(player, coins)
		return { Text = "+" .. coins .. " 코인", Coins = coins }
	elseif reward.Item then
		Inventory.Add(player, reward.Item, reward.Count)
		return { Item = reward.Item, Count = reward.Count }
	end
	return {}
end

local function part(model, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Size, p.CFrame, p.Color = size, cframe, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored, p.CanCollide, p.CanTouch, p.CastShadow = false, false, false, false
	p.Parent = model
	return p
end

-- 이벤트 모형: 기준 Part(앵커, 투명) + 용접된 장식, 멀리서도 보이는 "▼ 이름" 표지
local function build(kind, at)
	local def = EVENTS[kind]
	local model = Instance.new("Model")
	model.Name = kind
	local root = part(model, Vector3.new(2, 2, 2), at, Color3.new(1, 1, 1))
	root.Name = "Root"
	root.Anchored, root.Transparency = true, 1
	model.PrimaryPart = root
	if kind == "Gift" then
		part(model, Vector3.new(2.2, 2, 2.2), at * CFrame.new(0, 1, 0), Color3.fromRGB(255, 140, 170))
		part(model, Vector3.new(2.3, 2.05, 0.5), at * CFrame.new(0, 1, 0), Color3.fromRGB(255, 230, 120))
		part(model, Vector3.new(0.5, 2.05, 2.3), at * CFrame.new(0, 1, 0), Color3.fromRGB(255, 230, 120))
		part(model, Vector3.new(1.2, 0.6, 0.6), at * CFrame.new(0, 2.3, 0), Color3.fromRGB(255, 230, 120), nil, Enum.PartType.Ball)
		for i = 0, 4 do -- 구름 받침
			local angle = i / 5 * math.pi * 2
			part(model, Vector3.one * 2.4, at * CFrame.new(math.cos(angle) * 1.6, -0.3, math.sin(angle) * 1.6), Color3.new(1, 1, 1), nil,
				Enum.PartType.Ball).Transparency = 0.1
		end
	elseif kind == "Butterfly" then
		part(model, Vector3.new(0.25, 0.25, 0.9), at, Color3.fromRGB(90, 60, 30))
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.9, 0.06, 0.8), at * CFrame.new(side * 0.5, 0.05, -0.15) * CFrame.Angles(0, 0, math.rad(side * 20)),
				Color3.fromRGB(255, 205, 60), Enum.Material.Neon)
		end
	else -- Glint: 땅 위 반짝임
		local glow = part(model, Vector3.new(2.6, 0.2, 2.6), at * CFrame.new(0, 0.1, 0), Color3.fromRGB(255, 235, 150), Enum.Material.Neon)
		glow.Transparency = 0.55
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 235, 140))
		sparkle.Size = NumberSequence.new(0.6, 0)
		sparkle.Lifetime = NumberRange.new(0.6, 1.1)
		sparkle.Speed = NumberRange.new(1, 3)
		sparkle.SpreadAngle = Vector2.new(40, 40)
		sparkle.LightEmission = 1
		sparkle.Rate = 8
		sparkle.Parent = glow
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = root, p
			weld.Parent = p
		end
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "Marker"
	tag.Size = UDim2.fromOffset(180, 44)
	tag.StudsOffset = Vector3.new(0, 4.5, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 400
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 18
	label.Text = def.Label .. "\n▼"
	label.TextColor3 = Color3.fromRGB(255, 240, 160)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(110, 78, 52)
	label.Parent = tag
	tag.Parent = root
	model:SetAttribute("Event", kind)
	model:SetAttribute("Label", def.Label)
	model:SetAttribute("Action", def.Action)
	CollectionService:AddTag(model, "IslandEvent")
	return model
end

-- 그 구역들의 청크에서 땅 자리 하나(20번 찾아 없으면 nil)
local function spotIn(island, zones)
	local chunks = {}
	for _, c in island.Gen.Chunks do
		if zones[c.Zone] then
			table.insert(chunks, c)
		end
	end
	local size = IslandGen.CHUNK * IslandGen.CELL
	for _ = 1, 20 do
		local c = chunks[rng:NextInteger(1, math.max(1, #chunks))]
		if not c then
			return nil
		end
		local point = island.Origin + Vector3.new((c.X + rng:NextNumber(0.15, 0.85)) * size, 0, (c.Z + rng:NextNumber(0.15, 0.85)) * size)
		local ground = IslandService.Ground(island, point)
		if ground then
			return ground
		end
	end
	return nil
end

local function clear(owner)
	local event = active[owner]
	active[owner] = nil
	if event then
		if event.Thread and coroutine.status(event.Thread) == "suspended" then
			task.cancel(event.Thread)
		end
		event.Model:Destroy()
	end
end

-- 살아 있는 동안의 움직임: 선물은 하늘에서 내려앉고, 나비는 땅 위를 맴돈다
local function animate(event, island, ground)
	local root = event.Model.PrimaryPart
	if event.Kind == "Gift" then
		root.CFrame = CFrame.new(ground + Vector3.new(0, 45, 0))
		local fall = TweenService:Create(root, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = CFrame.new(ground) })
		fall:Play()
	elseif event.Kind == "Butterfly" then
		while true do
			local target = IslandService.Ground(island, ground + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)))
				or ground
			local goal = CFrame.lookAt(target + Vector3.new(0, rng:NextNumber(2, 4), 0), root.Position) * CFrame.Angles(0, math.pi, 0)
			local fly = TweenService:Create(root, TweenInfo.new(rng:NextNumber(1.2, 2), Enum.EasingStyle.Sine), { CFrame = goal })
			fly:Play()
			fly.Completed:Wait()
		end
	end
end

local function spawnEvent(owner, island)
	local kind = KINDS[rng:NextInteger(1, #KINDS)]
	local ground = spotIn(island, EVENTS[kind].Zones)
	if not ground then
		return
	end
	local model = build(kind, CFrame.new(ground + if kind == "Butterfly" then Vector3.new(0, 3, 0) else Vector3.zero))
	model:SetAttribute("Owner", owner.UserId)
	local folder = island.Model:FindFirstChild("Events") or Instance.new("Folder")
	folder.Name = "Events"
	folder.Parent = island.Model
	model.Parent = folder
	local event = { Kind = kind, Model = model, Island = island, Until = os.clock() + EVENTS[kind].Life }
	active[owner] = event
	event.Thread = task.spawn(animate, event, island, ground)
	Remotes.Feedback:FireClient(owner, "Toast", { Text = "섬에 " .. Lines.Josa(EVENTS[kind].Label, "이", "가") .. " 나타났어요! ▼ 표지를 찾아보세요" })
end

local function claim(player, model)
	for owner, event in active do
		if event.Model == model then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root or not DataService.Get(player) or (root.Position - model:GetPivot().Position).Magnitude > REACH then
				return
			end
			local position = model:GetPivot().Position
			clear(owner)
			local def = EVENTS[event.Kind]
			local info = give(player, pick(def.Rewards))
			info.Player, info.Position, info.Event, info.Label = player, position, event.Kind, def.Label
			Remotes.Feedback:FireAllClients("EventOpen", info)
			PartyPlayService.Count(player, "Event")
			for _, other in Players:GetPlayers() do
				local near = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				if near and DataService.Get(other) and PartyService.Same(player, other) and (near.Position - position).Magnitude <= SHARE_REACH then
					local share = give(other, pick(def.Rewards))
					share.Player, share.Position, share.Event, share.Label = other, position, event.Kind, def.Label
					Remotes.Feedback:FireClient(other, "EventOpen", share)
					Remotes.Feedback:FireClient(other, "Toast", { Text = player.DisplayName .. "님과 함께 받았어요! " .. (share.Text or "") })
				end
			end
			return
		end
	end
end

local function shake(player, part)
	local island, owner = IslandService.Find(part)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	if not island or part.Parent ~= island.Plants or not root or not DataService.Get(player)
		or (root.Position - part.Position).Magnitude > REACH or now - (lastShake[player] or 0) < SHAKE_GAP then
		return
	end
	lastShake[player] = now
	local key = string.format("%d:%d:%d", owner.UserId, math.floor(part.Position.X / 9), math.floor(part.Position.Z / 9))
	local resting = now - (treeRest[key] or -math.huge) < TREE_REST
	local info = if resting then {} else give(player, pick(SHAKE_REWARDS))
	if not resting and (info.Coins or info.Item) then
		treeRest[key] = now -- 무언가 떨어졌으면 이 나무는 잠깐 쉰다
	end
	info.Player, info.Position, info.Part = player, part.Position, part
	Remotes.Feedback:FireAllClients("Shake", info)
end

function EventService.Unload(player)
	clear(player)
	nextAt[player] = nil
	lastShake[player] = nil
end

function EventService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target)
		if typeof(target) ~= "Instance" then
			return
		elseif kind == "Event" and CollectionService:HasTag(target, "IslandEvent") then
			claim(player, target)
		elseif kind == "Shake" and target:IsA("BasePart") then
			shake(player, target)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for owner, event in active do
				if now >= event.Until then
					clear(owner)
				end
			end
			for _, owner in game:GetService("Players"):GetPlayers() do
				local island = IslandService.Get(owner)
				if island and not active[owner] then
					nextAt[owner] = nextAt[owner] or now + rng:NextNumber(FIRST[1], FIRST[2])
					if now >= nextAt[owner] then
						nextAt[owner] = now + rng:NextNumber(EVERY[1], EVERY[2])
						spawnEvent(owner, island)
					end
				end
			end
		end
	end)
end

return EventService
