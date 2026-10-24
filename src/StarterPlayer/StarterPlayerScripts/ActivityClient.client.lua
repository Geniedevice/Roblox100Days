-- 낚시·광산·쓰다듬기 입력과 그 월드 표시(명세: design/gdd/fishing.md, mining.md, creatures.md, design/ux/hud.md §4).
-- 누르기: 내 섬 물 → 던지기(찌가 떠 있으면 당기기), 광석 블록 → 두드리기, 생물 → 쓰다듬기. 판정은 전부 서버.
-- 표시: 찌가 포물선으로 날아가 물에 뜨고 낚싯줄(Beam)이 손에서 이어진다. 입질 때 찌 위 "!"(PC는 "클릭!"),
-- 낚으면 물고기 모형이 플레이어 쪽으로 튀어 오른다. 광석 위에는 남은 타격 칸 막대(고스트가 따라간다).
-- 안내: 앞 물가에 "낚시하기", 입질 때 "당기기!", 내 섬 광석에 "캐기 · 광석 이름", 생물·도우미 동물에 "쓰다듬기", 내 섬 집안일에
-- "치우기", 섬 이벤트에 "열기·잡기·파 보기", 나무에 "흔들기", 다른 플레이어에 "인사하기"(E · 게임패드 X · 모바일 버튼, 밭 안내와 같은
-- 프롬프트). 누르기(클릭·탭)도 같은 요청을 보낸다.
-- 내 섬의 캘 수 있는 광석은 광석 색으로 반짝인다(캐면 꺼지고, 다시 솟으면 켜진다).
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared:WaitForChild("Creatures"))
local Pets = require(Shared:WaitForChild("Pets"))
local Models = require(Shared:WaitForChild("Models"))
local Ores = require(Shared:WaitForChild("Ores"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Juice = require(script.Parent:WaitForChild("Juice"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local WorldPointer = require(script.Parent:WaitForChild("WorldPointer"))

local player = Players.LocalPlayer
local HEAR = 80
local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local function islandOf(instance)
	local islands = workspace:FindFirstChild("Islands")
	local island = instance
	while island and island.Parent ~= islands do
		island = island.Parent
	end
	return island
end

local function mine(instance)
	local island = islandOf(instance)
	return island ~= nil and island:GetAttribute("Owner") == player.UserId
end

local function near(position)
	return (workspace.CurrentCamera.CFrame.Position - position).Magnitude <= HEAR
end

-- 낚시 표시: 플레이어마다 찌 하나 ------------------------------------------------------------------
local bobbers = {} -- [player] = { Part, Beam, Bang, Token }
local myCast = false
local myBite = false -- 내 찌에 입질이 왔다(당기기 안내)

local function clearBobber(who, sink)
	local entry = who and bobbers[who]
	if not entry then
		return
	end
	bobbers[who] = nil
	if sink and entry.Part.Parent then
		Juice.Tween(entry.Part, 0.4, { CFrame = entry.Part.CFrame + Vector3.new(0, 0.3, 0), Transparency = 1 }, Enum.EasingStyle.Sine)
		Debris:AddItem(entry.Part, 0.45)
	else
		entry.Part:Destroy()
	end
	if entry.Rod then
		entry.Rod:Destroy()
	end
end

local function rodTip(character)
	local hand = character and character:FindFirstChild("RightHand")
	if not hand then
		return nil
	end
	local rod = Models.Tool("Rod")
	for _, p in rod:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		end
	end
	rod:PivotTo(hand.CFrame * CFrame.new(0, -0.3, -0.2))
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = hand, rod.PrimaryPart
	weld.Parent = rod.PrimaryPart
	rod.Name = "FishingRod"
	rod.Parent = character
	return rod, rod.PrimaryPart:FindFirstChild("Tip")
end

local function showCast(who, position)
	clearBobber(who)
	local character = who.Character
	local rod, tip = rodTip(character)
	local bobber = Ui.make("Part", workspace, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Anchored = true, CanCollide = false,
		CanQuery = false, CanTouch = false, Color = Color3.fromRGB(235, 70, 60), Material = Enum.Material.SmoothPlastic })
	Ui.make("Part", bobber, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55, Anchored = true, CanCollide = false, CanQuery = false,
		CanTouch = false, Color = Color3.new(1, 1, 1), CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) })
	local start =(tip and tip.WorldPosition) or (character and character:GetPivot().Position) or position
	bobber.CFrame = CFrame.new(start)
	local entry = { Part = bobber, Rod = rod, Token = os.clock() }
	bobbers[who] = entry
	if tip then
		local a1 = Instance.new("Attachment")
		a1.Parent = bobber
		Ui.make("Beam", bobber, { Attachment0 = tip, Attachment1 = a1, Width0 = 0.05, Width1 = 0.05, FaceCamera = true,
			Color = ColorSequence.new(Color3.fromRGB(245, 245, 240)), Transparency = NumberSequence.new(0.2), CurveSize0 = 1.5 })
	end
	-- 감기 250ms + 던지기 150ms 뒤 찌가 포물선으로 날아가 900ms에 물에 닿는다
	local flight = Instance.new("NumberValue")
	local top = (start + position) / 2 + Vector3.new(0, 6, 0)
	flight.Changed:Connect(function(t)
		if bobber.Parent then
			local a, b = start:Lerp(top, t), top:Lerp(position, t)
			local p = a:Lerp(b, t)
			bobber.CFrame = CFrame.new(p)
			bobber:FindFirstChildOfClass("Part").CFrame = CFrame.new(p + Vector3.new(0, 0.3, 0))
		end
	end)
	task.delay(0.4, function()
		local t = Juice.Tween(flight, 0.5, { Value = 1 }, Enum.EasingStyle.Sine)
		t.Completed:Once(function()
			flight:Destroy()
			-- 착수: 0.6 → 1.2 → 1 통통, 그 뒤 물결에 살랑
			if bobber.Parent and not Juice.Reduced() then
				bobber.Size = Vector3.one * 0.5
				Juice.Tween(bobber, 0.2, { Size = Vector3.one * 0.8 }, Enum.EasingStyle.Back)
			end
		end)
	end)
end

local function showBite(who, info)
	local entry = bobbers[who]
	if not entry then
		return
	end
	local bobber = entry.Part
	local base = CFrame.new(info.Position)
	-- 찌가 0.6스터드 쑥 들어갔다가 두 번 튄다
	Juice.Tween(bobber, 0.06, { CFrame = base - Vector3.new(0, 0.6, 0) }).Completed:Once(function()
		Juice.Tween(bobber, 0.3, { CFrame = base }, Enum.EasingStyle.Bounce)
	end)
	Juice.Flash(bobber, Ui.SUN, 0, 0.15)
	task.delay(0.3, Juice.Flash, bobber, Ui.SUN, 0, 0.15)
	if who ~= player then
		return
	end
	local bang = Ui.make("BillboardGui", bobber, { Size = UDim2.fromOffset(140, 140), StudsOffset = Vector3.new(0, 3, 0), AlwaysOnTop = true,
		LightInfluence = 0 })
	local label = Ui.make("TextLabel", bang, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 100), FontFace = Ui.NUM, TextSize = 96,
		Text = "!", TextColor3 = Ui.SUN })
	Ui.stroke(label, 4, Ui.COCOA, true)
	if not touch then
		local hint = Ui.make("TextLabel", bang, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 36),
			FontFace = Ui.FONT_HEAVY, TextSize = 24, Text = "클릭!", TextColor3 = Ui.CREAM })
		Ui.stroke(hint, 2.5, Ui.COCOA, true)
	end
	local scale = Ui.make("UIScale", label, { Scale = 0 })
	Juice.Tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	if not Juice.Reduced() then
		task.spawn(function()
			for i = 1, 3 do
				label.Rotation = if i % 2 == 0 then -8 else 8
				task.wait(0.06)
			end
			label.Rotation = 0
		end)
	end
	entry.Bang = bang
end

-- 낚은 물고기 모형이 찌에서 플레이어 쪽으로 5스터드 포물선(두 바퀴 돌며)
local function showCatch(who, info)
	local from = info.Position
	clearBobber(who)
	local character = who.Character
	local to = character and character:GetPivot().Position + Vector3.new(0, 2, 0) or from + Vector3.new(0, 5, 0)
	local fish = Models.Fish(info.Item)
	for _, p in fish:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery = true, false, false
		end
	end
	fish:PivotTo(CFrame.new(from))
	fish.Parent = workspace
	Juice.Flash(fish, Color3.new(1, 1, 1), 0.1, 0.15)
	local top = (from + to) / 2 + Vector3.new(0, 5, 0)
	local flight = Instance.new("NumberValue")
	flight.Changed:Connect(function(t)
		local a, b = from:Lerp(top, t), top:Lerp(to, t)
		fish:PivotTo(CFrame.lookAt(a:Lerp(b, t), to) * CFrame.Angles(t * 4 * math.pi, 0, 0))
	end)
	local tween = Juice.Tween(flight, 0.4, { Value = 1 }, Enum.EasingStyle.Sine)
	tween.Completed:Once(function()
		flight:Destroy()
		fish:Destroy()
	end)
end

Remotes.Feedback.OnClientEvent:Connect(function(kind, info)
	local who = info and info.Player
	if not who or not info.Position or not near(info.Position) then
		if kind == "Miss" or kind == "Catch" then
			clearBobber(who)
		end
		if who == player and (kind == "Miss" or kind == "Catch") then
			myCast, myBite = false, false
		end
		return
	end
	if who == player and (kind == "Cast" or kind == "Bite" or kind == "Catch" or kind == "Miss") then
		myBite = kind == "Bite"
	end
	if kind == "Cast" then
		showCast(who, info.Position)
		if who == player then
			myCast = true
		end
	elseif kind == "Bite" then
		showBite(who, info)
	elseif kind == "Catch" then
		task.delay(0.15, showCatch, who, info)
		if who == player then
			myCast = false
		end
	elseif kind == "Miss" then
		clearBobber(who, true)
		if who == player then
			myCast = false
		end
	end
end)

-- 광석 진행 막대: 칸 N개, 칠 때마다 한 칸이 튀어 사라지고 고스트가 따라간다. 2.5초 안 치면 사라진다
local progress = {} -- [광석 Part] = { Gui, Cells, Token }
local function oreBar(part, hit, need)
	local entry = progress[part]
	if not entry or entry.Need ~= need then
		if entry then
			entry.Gui:Destroy()
		end
		local gui = Ui.make("BillboardGui", part, { Size = UDim2.fromOffset(120, 18), StudsOffset = Vector3.new(0, 2.8, 0), AlwaysOnTop = true,
			LightInfluence = 0 })
		local back = Ui.make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.CREAM })
		Ui.corner(back, "pill")
		Ui.stroke(back, 2)
		Ui.make("UIPadding", back, { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) })
		Ui.make("UIListLayout", back, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
		local ore = Ores[part:GetAttribute("Ore")]
		local cells = {}
		for i = 1, need do
			local cell = Ui.make("Frame", back, { LayoutOrder = i, Size = UDim2.new(1 / need, -3, 1, 0), BackgroundColor3 = ore and ore.Color or Ui.SUN })
			Ui.corner(cell, 4)
			cells[i] = cell
		end
		entry = { Gui = gui, Cells = cells, Need = need, Token = 0 }
		progress[part] = entry
		local scale = Ui.make("UIScale", back, { Scale = 0.8 })
		Juice.Tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	entry.Token += 1
	local token = entry.Token
	for i = 1, hit do
		local cell = entry.Cells[need - i + 1] -- 오른쪽부터 사라진다
		if cell and cell.BackgroundTransparency == 0 then
			cell.BackgroundColor3 = Ui.GHOST_LOSS
			Juice.Punch(cell, 1.3, 0.12)
			task.delay(0.25, function()
				Juice.Tween(cell, 0.3, { BackgroundTransparency = 1 })
			end)
		end
	end
	task.delay(2.5, function()
		if progress[part] == entry and entry.Token == token then
			entry.Gui:Destroy()
			progress[part] = nil
		end
	end)
end

Remotes.Feedback.OnClientEvent:Connect(function(kind, info)
	if (kind ~= "MineHit" and kind ~= "MineBreak") or not info or info.Player ~= player or not info.Part then
		return
	end
	task.delay(0.28, function() -- 곡괭이가 닿는 순간
		if kind == "MineHit" then
			oreBar(info.Part, info.Hit, info.Need)
		else
			local entry = progress[info.Part]
			if entry then
				for _, cell in entry.Cells do
					cell.BackgroundColor3 = Ui.GHOST_LOSS
				end
				local scale = entry.Gui:FindFirstChildWhichIsA("Frame"):FindFirstChildOfClass("UIScale")
				if scale then
					Juice.Tween(scale, 0.15, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
				Debris:AddItem(entry.Gui, 0.2)
				progress[info.Part] = nil
			end
		end
	end)
end)

-- 누르기 ------------------------------------------------------------------------------------------
local function taggedAncestor(instance, tag)
	while instance and instance ~= workspace do
		if CollectionService:HasTag(instance, tag) then
			return instance
		end
		instance = instance.Parent
	end
	return nil
end

WorldPointer.OnTap(function(result)
	if player:GetAttribute("DecorMode") then
		return
	end
	local target = result.Instance
	if myCast and (target.Parent and target.Parent.Name == "Water" or not taggedAncestor(target, "FarmTile")) then
		Remotes.Interact:FireServer("Reel") -- 찌가 떠 있으면 어디를 눌러도 당긴다
		myCast = false
		return
	end
	local event = taggedAncestor(target, "IslandEvent")
	local animal = taggedAncestor(target, "Pet") or taggedAncestor(target, "Creature") -- 도우미 동물·섬 생물 쓰다듬기
	local other = Players:GetPlayerFromCharacter(target:FindFirstAncestorOfClass("Model"))
	if event then
		Remotes.Interact:FireServer("Event", event)
	elseif animal then
		Remotes.Interact:FireServer("Pet", animal)
	elseif other and other ~= player then
		Remotes.Interact:FireServer("Greet", other)
	elseif target:GetAttribute("Ore") and not target:GetAttribute("Depleted") and mine(target) then
		Juice.Sound("button.wav", 1.6, 0.12)
		Remotes.Interact:FireServer("Mine", target)
	elseif target.Parent and target.Parent.Name == "Water" and islandOf(target) then -- 친구 섬 물도
		Remotes.Interact:FireServer("Cast", target, result.Position)
	elseif target.Parent and target.Parent.Name == "Plants" and islandOf(target) then
		Remotes.Interact:FireServer("Shake", target)
	end
end)

-- 광석 반짝임: 무엇을 캘 수 있는지 멀리서도 보이게(블록 겉면에서 바깥으로)
local function onOre(part)
	if not mine(part) or part:FindFirstChild("OreSparkle") then
		return
	end
	local ore = Ores[part:GetAttribute("Ore")]
	local emitter = Ui.make("ParticleEmitter", part, { Name = "OreSparkle", Texture = Juice.SPARKLE,
		Color = ColorSequence.new(ore and ore.Color or Color3.new(1, 1, 1)), Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(0.4, 1.2), SpreadAngle = Vector2.new(30, 30), LightEmission = 1,
		Rate = 2, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Enabled = not part:GetAttribute("Depleted") })
	part:GetAttributeChangedSignal("Depleted"):Connect(function()
		emitter.Enabled = not part:GetAttribute("Depleted")
	end)
end
CollectionService:GetInstanceAddedSignal("Ore"):Connect(onOre)
for _, part in CollectionService:GetTagged("Ore") do
	onOre(part)
end

-- 낚시·광산·생물·집안일 안내 프롬프트(누르면 화면을 누른 것과 같은 요청, 판정은 서버). 터치 기기의 당기기는 HUD 버튼이 맡는다
local ORE_REACH = 11 -- 캐릭터에서 광석까지(서버 REACH 22 안)
local NEAR_REACH = 9 -- 생물·집안일까지(서버 쓰다듬기 14, 치우기 20 안)
local CHORE_NAMES = { Weed = "잡초", Leaves = "낙엽", Pebble = "돌멩이" }
local WATER_AHEAD = { 4, 7, 10 } -- 앞 이 거리들에서 물을 찾는다
local greetedBy = {} -- [나에게 인사한 사람] = os.clock()(5초 안에 마주 인사하면 하이파이브)
Remotes.Feedback.OnClientEvent:Connect(function(kind, info)
	if kind == "Greet" and info and info.Target == player and info.Player then
		greetedBy[info.Player] = os.clock()
	elseif kind == "HighFive" and info then
		greetedBy[info.Player] = nil
		greetedBy[info.Target] = nil
	end
end)
local promptTarget -- { Kind = "Cast" | "Reel" | "Mine" | "Pet" | "Chore" | "Event" | "Shake" | "Greet", Part, Position }
local showPrompt = WorldPointer.Prompt("ActivityPrompt", function()
	local t = promptTarget
	if not t then
		return
	elseif t.Kind == "Reel" then
		Remotes.Interact:FireServer("Reel")
		myCast, myBite = false, false
	elseif t.Kind == "Cast" then
		Remotes.Interact:FireServer("Cast", t.Part, t.Position)
	elseif t.Kind == "Pet" or t.Kind == "Chore" or t.Kind == "Event" or t.Kind == "Shake" or t.Kind == "Greet" then
		if t.Part.Parent then -- Greet이면 Part = 상대 Player
			Remotes.Interact:FireServer(t.Kind, t.Part)
		end
	elseif t.Part.Parent and not t.Part:GetAttribute("Depleted") then
		Juice.Sound("button.wav", 1.6, 0.12)
		Remotes.Interact:FireServer("Mine", t.Part)
	end
end)

local waterParams = RaycastParams.new()
waterParams.FilterType = Enum.RaycastFilterType.Exclude
local function waterAhead(root)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		return nil
	end
	waterParams.FilterDescendantsInstances = { player.Character }
	for _, d in WATER_AHEAD do
		local hit = workspace:Raycast(root.Position + look.Unit * d + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), waterParams)
		if hit and hit.Instance.Parent and hit.Instance.Parent.Name == "Water" and islandOf(hit.Instance) then
			return hit
		end
	end
	return nil
end

-- 섬 나무(Plants 폴더) 찾기: 2초마다 섬 목록을 다시 모은다
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
local plantsAt = 0
local function plantsNear(point)
	if os.clock() - plantsAt > 2 then
		plantsAt = os.clock()
		local folders = {}
		for _, island in workspace:FindFirstChild("Islands") and workspace.Islands:GetChildren() or {} do
			local terrain = island:FindFirstChild("Terrain")
			table.insert(folders, terrain and terrain:FindFirstChild("Plants"))
		end
		overlap.FilterDescendantsInstances = folders
	end
	return workspace:GetPartBoundsInRadius(point, 3, overlap)
end

-- 앞에 가장 가까운 대상(이벤트·광석·생물·도우미 동물·집안일·나무·플레이어) → { Kind, Part, Position }, 행동 글, 대상 글.
-- bias = 점수에 더한다(이벤트는 먼저, 나무는 나중)
local function thingAhead(root)
	local front = root.Position + root.CFrame.LookVector * 3
	local best, bestScore, action, object
	local function consider(kind, part, position, reach, act, obj, bias)
		if (position - root.Position).Magnitude > reach then
			return
		end
		local score = (position - front).Magnitude + (bias or 0)
		if not bestScore or score < bestScore then
			best, bestScore, action, object = { Kind = kind, Part = part, Position = position + Vector3.new(0, 2, 0) }, score, act, obj
		end
	end
	for _, part in CollectionService:GetTagged("Ore") do
		if not part:GetAttribute("Depleted") and (part.Position - root.Position).Magnitude <= ORE_REACH and mine(part) then
			local def = Ores[part:GetAttribute("Ore")]
			consider("Mine", part, part.Position, ORE_REACH, "캐기", def and string.format("%s · %d번 두드리기", def.Name, def.Hits))
		end
	end
	for _, model in CollectionService:GetTagged("Creature") do
		local def = Creatures[model:GetAttribute("Creature") or ""]
		consider("Pet", model, model:GetPivot().Position, NEAR_REACH, "쓰다듬기", def and def.Name)
	end
	for _, model in CollectionService:GetTagged("Chore") do
		if model:GetAttribute("Owner") == player.UserId then
			consider("Chore", model, model:GetPivot().Position, NEAR_REACH, "치우기",
				(CHORE_NAMES[model:GetAttribute("Kind")] or "집안일") .. " · +3코인")
		end
	end
	for _, model in CollectionService:GetTagged("Pet") do
		local def = Pets[model:GetAttribute("Pet") or ""]
		consider("Pet", model, model:GetPivot().Position, NEAR_REACH, "쓰다듬기", def and def.Name)
	end
	for _, model in CollectionService:GetTagged("IslandEvent") do
		consider("Event", model, model:GetPivot().Position, 12, model:GetAttribute("Action") or "열기", model:GetAttribute("Label"), -3)
	end
	for _, part in plantsNear(front) do
		consider("Shake", part, part.Position, NEAR_REACH, "흔들기", "나무", 2)
	end
	for _, other in Players:GetPlayers() do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if otherRoot then
			local back = greetedBy[other] and os.clock() - greetedBy[other] < 5 -- 나에게 막 인사했다 → 마주 인사하면 하이파이브
			consider("Greet", other, otherRoot.Position, 8, if back then "하이파이브!" else "인사하기", other.DisplayName)
		end
	end
	return best, action, object
end

local lastPromptCheck = 0
RunService.Heartbeat:Connect(function()
	if os.clock() - lastPromptCheck < 0.1 then
		return
	end
	lastPromptCheck = os.clock()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local target, action, object
	if root and Juice.State.Panels == 0 and not player:GetAttribute("DecorMode") then
		local bobber = bobbers[player]
		if myCast then
			if myBite and not touch and bobber then
				target, action = { Kind = "Reel", Position = bobber.Part.Position }, "당기기!"
			end
		else
			target, action, object = thingAhead(root)
			local water = not target and waterAhead(root)
			if water then
				target, action, object = { Kind = "Cast", Part = water.Instance, Position = water.Position }, "낚시하기", "찌 던지기"
			end
		end
	end
	promptTarget = target
	showPrompt(target and target.Position + Vector3.new(0, 1, 0), action, object)
end)
