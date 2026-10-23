-- 낚시·광산·쓰다듬기 입력과 그 월드 표시(명세: design/gdd/fishing.md, mining.md, creatures.md, design/ux/hud.md §4).
-- 누르기: 내 섬 물 → 던지기(찌가 떠 있으면 당기기), 광석 블록 → 두드리기, 생물 → 쓰다듬기. 판정은 전부 서버.
-- 표시: 찌가 포물선으로 날아가 물에 뜨고 낚싯줄(Beam)이 손에서 이어진다. 입질 때 찌 위 "!"(PC는 "클릭!"),
-- 낚으면 물고기 모형이 플레이어 쪽으로 튀어 오른다. 광석 위에는 남은 타격 칸 막대(고스트가 따라간다).
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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
			myCast = false
		end
		return
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
	local creature = taggedAncestor(target, "Creature")
	if creature then
		Remotes.Interact:FireServer("Pet", creature)
	elseif target:GetAttribute("Ore") and not target:GetAttribute("Depleted") and mine(target) then
		Juice.Sound("button.wav", 1.6, 0.12)
		Remotes.Interact:FireServer("Mine", target)
	elseif target.Parent and target.Parent.Name == "Water" and islandOf(target) then -- 친구 섬 물도
		Remotes.Interact:FireServer("Cast", target, result.Position)
	end
end)
