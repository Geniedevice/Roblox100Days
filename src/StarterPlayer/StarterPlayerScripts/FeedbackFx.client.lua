-- 상호작용 피드백(명세: design/ux/interaction-patterns.md 표 A·B): 서버 Feedback 신호마다 '7 HIT COMBO' 일곱 요소를
-- 접촉 프레임(괭이가 땅에 닿는 순간 등, ActionAnimator와 같은 시각)에 한꺼번에 터뜨린다:
-- 번쩍임 → (히트 스톱은 ActionAnimator의 멈춤 단계) → 찌그러짐 → 카메라 흔들림(내 행동만) → 입자·링·파편 → 겹 사운드,
-- 얻은 것은 아이콘이 HUD 칸으로 날아가 닿을 때 숫자가 오른다(지연 막대). 남의 행동은 소리 50%, 흔들림 없음.
-- 마우스가 가리키는 누를 수 있는 대상에는 흰 테두리, 다 자란 작물은 계속 반짝인다. UI 버튼에는 클릭음.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Fish"))
local Ores = require(Shared:WaitForChild("Ores"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Juice = require(script.Parent:WaitForChild("Juice"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local WorldPointer = require(script.Parent:WaitForChild("WorldPointer"))
local Models = require(Shared:WaitForChild("Models"))

local player = Players.LocalPlayer
local HEAR = 60
local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local SMOKE, SPARKLE = Juice.SMOKE, Juice.SPARKLE

-- 행동의 접촉 프레임(초, 신호 기준). ActionAnimator 단계 길이와 맞춘다
local CONTACT = { Till = 0.32, Plant = 0.2, Water = 0.2, Harvest = 0.33, Clean = 0.33, Place = 0.18, Pickup = 0.18,
	Catch = 0.15, MineHit = 0.28, MineBreak = 0.28, Pet = 0.2, PetLove = 0.2, Shake = 0.33, EventOpen = 0.33 }
local COUNTED = { Till = true, Plant = true, Water = true, Harvest = true, Clean = true, Place = true, MineBreak = true, Catch = true, Pet = true,
	PetLove = true, Shake = true, EventOpen = true }
local NO_FLOAT = { Miss = true, Pet = true, PetLove = true, Greet = true, HighFive = true, Toast = true, DexNew = true, Expand = true } -- 글을 따로 보인다

local function characterPosition()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or workspace.CurrentCamera.CFrame.Position
end

-- 코인 n개가 position에서 코인 알약으로 날아간다(첫 코인이 닿으면 숫자가 구르기 시작)
local function coinsFly(position, count, firstDelay)
	local target = Juice.Targets.Coins
	Juice.State.CoinHoldUntil = os.clock() + (firstDelay or 0) + 0.7
	local arrived = false
	for i = 1, count do
		Juice.Fly(position, "Coin", nil, target, function()
			Juice.Sound("electronicpingshort.wav", math.min(1 + 0.05 * i, 1.6), 0.25)
			if not arrived then
				arrived = true
				Juice.Bus.CoinArrive:Fire()
			end
		end, (firstDelay or 0) + 0.045 * (i - 1))
	end
end

local function itemFly(position, itemId, kind, id, delay)
	local target = Juice.Targets.Item and Juice.Targets.Item(itemId)
	Juice.Fly(position, kind, id, target, function()
		Juice.Sound("clickfast.wav", 1.8, 0.2)
	end, delay)
end

-- 말풍선(2.5초): Cream 알약 + Cocoa 테두리, part 위 lift스터드
local function bubble(part, text, lift)
	if not part or not text then
		return
	end
	local gui = Ui.make("BillboardGui", player.PlayerGui, { Adornee = part, Size = UDim2.fromOffset(260, 40),
		StudsOffset = Vector3.new(0, lift or 3, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 70 })
	local pill = Ui.pill(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X, Visible = false })
	Ui.make("UIPadding", pill, { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
	Ui.text(pill, text, 15, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextWrapped = false })
	Ui.open(pill)
	task.delay(2.5, function()
		Ui.close(pill)
		task.delay(0.15, gui.Destroy, gui)
	end)
end

-- 행동별 연출. info = 서버 신호 정보, mine = 내 행동인가, v = 소리 크기 배율(남의 행동 0.5)
local KINDS = {
	Till = function(info, mine, v)
		Juice.Flash(info.Part, Ui.WARM, 0.35, 0.12)
		Juice.Squash(info.Part, Vector3.new(1.08, 0.6, 1.08), 0.05, 0.2)
		Juice.Burst(info.Position, { Color = { rgb(130, 90, 60), rgb(95, 65, 45) }, Count = 18, Size = 0.6, Speed = 13, Life = 0.6, Gravity = 40, Texture = SMOKE })
		Juice.Chunks(info.Position, { rgb(120, 85, 58), rgb(95, 65, 45) }, 4, 10, 0.45)
		Juice.Ring(info.Position - Vector3.new(0, 1.3, 0), rgb(215, 190, 150), 1, 6, 0.25)
		Juice.Sound("action_jump_land.mp3", 0.85, 0.6 * v, 0, info.Position)
		Juice.Sound("hit.wav", 1.3, 0.25 * v, 0, info.Position)
		if mine then
			Juice.Shake(0.4, 22, 0.18)
		end
	end,
	Plant = function(info, mine, v)
		Juice.Flash(info.Part, rgb(200, 255, 190), 0.5, 0.1)
		Juice.Squash(info.Part, Vector3.new(1, 0.9, 1), 0.04, 0.12)
		Juice.Burst(info.Position, { Color = rgb(140, 220, 110), Count = 10, Size = 0.4, Speed = 5, Life = 0.6, Gravity = 4, Glow = 0.5 })
		Juice.Ring(info.Position - Vector3.new(0, 1.3, 0), rgb(160, 230, 130), 0.5, 3, 0.2)
		Juice.Sound("Kerplunk.wav", 1.25, 0.45 * v, 0, info.Position)
		Juice.Sound("clickfast.wav", 1.5, 0.15 * v, 0, info.Position)
		if mine then
			Juice.Shake(0.15, 18, 0.1)
		end
	end,
	Water = function(info, mine, v)
		Juice.Flash(info.Part, rgb(170, 220, 255), 0.4, 0.16)
		local crop = info.Part and info.Part:FindFirstChild("Crop")
		Juice.ScaleModel(crop, { { 1.12, 0.08 }, { 1, 0.2, Enum.EasingStyle.Back }, { 1.08, 0.12 }, { 1, 0.13 } })
		Juice.Burst(info.Position, { Color = Ui.SKY, Count = 22, Size = 0.3, Speed = 8, Life = 0.7, Gravity = 40, Glow = 0.3 })
		Juice.Burst(info.Position, { Color = WHITE, Count = 6, Size = 0.4, Speed = 4, Life = 0.5, Gravity = 2, Glow = 1 })
		Juice.Ring(info.Position - Vector3.new(0, 1.3, 0), rgb(180, 225, 255), 0.5, 4, 0.3)
		task.delay(0.08, Juice.Ring, info.Position - Vector3.new(0, 1.3, 0), rgb(180, 225, 255), 0.5, 4, 0.3)
		Juice.Sound("impact_water.mp3", 1.15, 0.5 * v, 0, info.Position)
		Juice.Sound("Kerplunk.wav", 1.6, 0.15 * v, 0.12, info.Position)
		if mine then
			Juice.Shake(0.15, 12, 0.12)
		end
	end,
	Harvest = function(info, mine, v)
		Juice.Flash(info.Part, Ui.WARM, 0.1, 0.15)
		Juice.Squash(info.Part, Vector3.new(1, 0.85, 1), 0.05, 0.15)
		Juice.Burst(info.Position, { Color = Ui.SUN, Count = 20, Size = 0.5, Speed = 9, Life = 0.8, Gravity = 6, Glow = 1 })
		Juice.Burst(info.Position, { Color = rgb(120, 190, 90), Count = 6, Size = 0.4, Speed = 7, Life = 0.6, Gravity = 20, Texture = SMOKE })
		Juice.Ring(info.Position - Vector3.new(0, 1.3, 0), Ui.SUN, 0.5, 5, 0.26)
		Juice.Sound("snap.mp3", 1.1, 0.55 * v, 0, info.Position)
		Juice.Sound("electronicpingshort.wav", 1.5, 0.3 * v, 0.06, info.Position)
		if not info.Item then
			return
		end
		-- 열매 복제본이 4스터드 위로 돌며 솟았다가 씨앗 칸으로 날아간다
		local fruit = Models.Crop(info.Item, 3)
		for _, p in fruit:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored, p.CanCollide, p.CanQuery = true, false, false
			end
		end
		local base = CFrame.new(info.Position - Vector3.new(0, 1.3, 0))
		fruit:PivotTo(base)
		fruit.Parent = workspace
		local rise = Instance.new("NumberValue")
		rise.Changed:Connect(function(t)
			fruit:PivotTo(base * CFrame.new(0, 4 * t, 0) * CFrame.Angles(0, t * 2 * math.pi, 0))
		end)
		local up = Juice.Tween(rise, 0.28, { Value = 1 })
		up.Completed:Once(function()
			local top = fruit:GetPivot().Position
			fruit:Destroy()
			rise:Destroy()
			if mine and not info.Gift then -- Gift: 친구 밭에서 거둔 것(주인 보관함으로 간다)
				for i = 1, info.Count or 1 do
					itemFly(top, info.Item, "Crop", info.Item, 0.1 * (i - 1))
				end
			end
		end)
		if mine then
			Juice.Shake(0.35, 20, 0.16)
			Juice.Fov(2, 0.2)
		end
	end,
	Sell = function(info, mine, v)
		Juice.Burst(info.Position, { Color = Ui.SUN, Count = 28, Size = 0.5, Speed = 10, Life = 0.9, Gravity = 20, Glow = 1 })
		Juice.Ring(info.Position - Vector3.new(0, 2, 0), Ui.SUN, 1, 7, 0.3)
		Juice.Sound("short spring sound.wav", 1.2, 0.3 * v, 0.5, info.Position)
		if mine then
			local amount = tonumber((info.Text or ""):match("%d+")) or 12
			coinsFly(info.Position, math.clamp(math.ceil(amount / 12), 4, 14), 0.23)
			Juice.Punch(Juice.Targets.Coins, 1.25, 0.24)
			if amount >= 100 then
				Juice.Screen(Ui.SUN, 0.8, 0.2)
			end
		end
	end,
	Gift = function(info, mine, v)
		Juice.Burst(info.Position, { Color = Ui.BERRY, Count = 14, Size = 0.5, Speed = 6, Life = 0.9, Gravity = 2, Glow = 1 })
		Juice.Sound("short spring sound.wav", 1, 0.4 * v, 0, info.Position)
		if mine then
			for i = 1, 3 do
				itemFly(info.Position, "Seed_Turnip", "Seed", "Turnip", 0.1 * i)
			end
		end
	end,
	Clean = function(info, mine, v)
		local colors = if info.Kind == "Pebble" then { rgb(150, 150, 150), rgb(120, 120, 125) }
			elseif info.Kind == "Leaves" then { rgb(230, 150, 70), rgb(200, 110, 60) } else { rgb(110, 180, 80), rgb(80, 140, 60) }
		Juice.Burst(info.Position, { Color = colors, Count = 16, Size = 0.45, Speed = 8, Life = 0.7,
			Gravity = if info.Kind == "Leaves" then 6 else 40, Texture = if info.Kind == "Pebble" then SPARKLE else SMOKE })
		Juice.Chunks(info.Position, colors, 5, 12, 0.35)
		Juice.Ring(info.Position - Vector3.new(0, 1, 0), WHITE, 0.5, 4, 0.22)
		if info.Kind == "Pebble" then
			Juice.Sound("hit.wav", 1.1, 0.35 * v, 0, info.Position)
			Juice.Sound("collide.wav", 1.4, 0.2 * v, 0, info.Position)
		else
			Juice.Sound("splat.wav", if info.Kind == "Leaves" then 1.6 else 1.3, 0.4 * v, 0, info.Position)
			Juice.Sound("snap.mp3", 1.4, 0.2 * v, 0, info.Position)
		end
		if mine then
			coinsFly(info.Position, 1, 0.1)
			Juice.Shake(0.3, 20, 0.12)
			if info.Last then
				Juice.Burst(info.Position, { Color = Ui.SUN, Count = 24, Size = 0.5, Speed = 9, Life = 0.9, Gravity = 4, Glow = 1 })
				Juice.Ring(info.Position - Vector3.new(0, 1, 0), Ui.SUN, 1, 8, 0.4)
			end
		end
	end,
	Place = function(info, mine, v)
		Juice.Flash(info.Model, WHITE, 0.3, 0.14)
		Juice.ScaleModel(info.Model, { { 0.85, 0.06 }, { 1.08, 0.1, Enum.EasingStyle.Back }, { 1, 0.12 } })
		Juice.Burst(info.Position, { Color = rgb(215, 205, 190), Count = 14, Size = 1, Speed = 5, Life = 0.6, Gravity = -2, Texture = SMOKE, Spread = 90 })
		Juice.Ring(info.Position - Vector3.new(0, 1, 0), rgb(235, 225, 210), 1, 6, 0.26)
		Juice.Sound("action_jump_land.mp3", 1.15, 0.45 * v, 0, info.Position)
		Juice.Sound("short spring sound.wav", 1.1, 0.3 * v, 0.06, info.Position)
		if mine then
			Juice.Shake(0.3, 18, 0.14)
		end
	end,
	Pickup = function(info, _, v)
		Juice.Burst(info.Position, { Color = rgb(215, 205, 190), Count = 8, Size = 0.8, Speed = 4, Life = 0.5, Gravity = -2, Texture = SMOKE })
		Juice.Ring(info.Position - Vector3.new(0, 1, 0), rgb(235, 225, 210), 0.5, 3, 0.2)
		Juice.Sound("short spring sound.wav", 1.35, 0.3 * v, 0, info.Position)
		Juice.Sound("switch.wav", 1.4, 0.15 * v, 0, info.Position)
	end,
	-- 낚시(찌·"!"·물고기 모형은 ActivityClient)
	Cast = function(info, mine, v)
		Juice.Sound("switch.wav", 0.8, 0.3 * v, 0, characterPosition())
		task.delay(0.9, function() -- 찌가 물에 닿는 순간
			Juice.Burst(info.Position, { Color = Ui.SKY, Count = 10, Size = 0.3, Speed = 6, Life = 0.5, Gravity = 30 })
			Juice.Ring(info.Position, rgb(200, 235, 255), 0.3, 2.5, 0.25)
			Juice.Sound("Kerplunk.wav", 0.9, 0.45 * v, 0, info.Position)
			if mine then
				Juice.Shake(0.15, 12, 0.12)
			end
		end)
	end,
	Bite = function(info, mine, v)
		for i = 0, 2 do
			task.delay(0.1 * i, Juice.Ring, info.Position, rgb(220, 240, 255), 0.3, 2, 0.2)
		end
		Juice.Burst(info.Position, { Color = Ui.SKY, Count = 8, Size = 0.3, Speed = 6, Life = 0.4, Gravity = 30 })
		Juice.Sound("hit.wav", 1.6, 0.5 * v, 0, info.Position)
		Juice.Sound("electronicpingshort.wav", 2, 0.35 * v, 0, info.Position)
		if mine then
			Juice.Shake(0.3, 26, 0.12)
		end
	end,
	Catch = function(info, mine, v)
		local fish = Fish[info.Item]
		Juice.Burst(info.Position, { Color = { Ui.SKY, WHITE }, Count = 30, Size = 0.5, Speed = 12, Life = 0.8, Gravity = 35 })
		Juice.Burst(info.Position, { Color = Ui.SUN, Count = 12, Size = 0.5, Speed = 6, Life = 0.8, Gravity = 2, Glow = 1 })
		Juice.Ring(info.Position, rgb(200, 235, 255), 0.5, 6, 0.3)
		task.delay(0.1, Juice.Ring, info.Position, rgb(200, 235, 255), 0.5, 6, 0.3)
		Juice.Sound("impact_water.mp3", 1.3, 0.5 * v, 0, info.Position)
		Juice.Sound("electronicpingshort.wav", 1.6, 0.35 * v, 0.15, info.Position)
		if info.Rare or info.Special then
			Juice.Sound("short spring sound.wav", 1, 0.3 * v, 0.2, info.Position)
		end
		if mine and fish then
			Juice.Shake(0.45, 18, 0.2)
			Juice.Fov(2, 0.25)
			if info.Rare then
				Juice.Screen(Ui.WARM, 0.8, 0.15)
			end
			itemFly(info.Position, "Fish_" .. info.Item, "Fish", info.Item, 0.4)
		end
	end,
	Miss = function(info, mine, v)
		Juice.Burst(info.Position, { Color = Ui.SKY, Count = 6, Size = 0.3, Speed = 4, Life = 0.4, Gravity = 30 })
		Juice.Ring(info.Position, rgb(220, 235, 245), 0.3, 2, 0.4)
		Juice.Sound("impact_water.mp3", 0.7, 0.3 * v, 0, info.Position)
		Juice.Sound("collide.wav", 0.8, 0.2 * v, 0, info.Position)
		if mine then
			Juice.Float(info.Position + Vector3.new(0, 2, 0), info.Text or "놓쳤어요… 다시!", Ui.CREAM)
		end
	end,
	-- 광산(진행 막대는 ActivityClient)
	MineHit = function(info, mine, v)
		local ore = Ores[info.Ore]
		Juice.Flash(info.Part, WHITE, 0.3, 0.08)
		Juice.Squash(info.Part, Vector3.new(0.88, 0.88, 0.88), 0.04, 0.14)
		Juice.Chunks(info.Position, { rgb(150, 150, 150), ore and ore.Color or WHITE }, 8, 8, 0.35)
		if info.Ore == "Iron" or info.Ore == "Gold" or info.Ore == "Copper" then
			Juice.Burst(info.Position, { Color = WHITE, Count = 4, Size = 0.25, Speed = 14, Life = 0.25, Gravity = 30, Glow = 1 })
		end
		local pitch = 0.9 + 0.08 * ((info.Hit or 1) - 1) + (if info.Ore == "Coal" then -0.1 elseif info.Ore == "Diamond" then 0.2 else 0)
		Juice.Sound("hit.wav", pitch, 0.45 * v, 0, info.Position)
		Juice.Sound("collide.wav", 1.2, 0.2 * v, 0, info.Position)
		if mine then
			Juice.Shake(0.25, 24, 0.09)
		end
	end,
	MineBreak = function(info, mine, v)
		local ore = Ores[info.Ore]
		local color = ore and ore.Color or WHITE
		Juice.Flash(info.Part, color, 0, 0.15)
		Juice.Squash(info.Part, Vector3.new(1.15, 1.15, 1.15), 0.06, 0.12)
		Juice.Chunks(info.Position, { color, rgb(140, 140, 140) }, 8, 16, 0.6)
		Juice.Burst(info.Position, { Color = rgb(170, 165, 160), Count = 20, Size = 0.8, Speed = 7, Life = 0.7, Gravity = 6, Texture = SMOKE })
		Juice.Burst(info.Position, { Color = color, Count = 16, Size = 0.5, Speed = 9, Life = 0.8, Gravity = 4,
			Glow = if info.Rare then 1 else 0.4 })
		Juice.Ring(info.Position, color, 0.5, 5, 0.3)
		Juice.Sound("collide.wav", 0.7, 0.5 * v, 0, info.Position)
		Juice.Sound("hit.wav", 0.6, 0.4 * v, 0, info.Position)
		Juice.Sound("electronicpingshort.wav", 1.4, 0.3 * v, 0.08, info.Position)
		if info.Rare then
			Juice.Sound("short spring sound.wav", 1.5, 0.3 * v, 0.1, info.Position)
		end
		if mine then
			Juice.Shake(0.55, 22, 0.22)
			Juice.Fov(3, 0.3)
			if info.Rare then
				Juice.Screen(Ui.WARM, 0.85, 0.12)
			end
			itemFly(info.Position + Vector3.new(0, 1.5, 0), "Ore_" .. info.Ore, "Ore", info.Ore, 0.25)
		end
	end,
	-- 다시 솟는 광석: 작게 나타나 제 크기로 튀어 오른다(MineService가 블록을 다시 보이게 한 순간)
	OreRespawn = function(info, _, v)
		local ore = info.Part and Ores[info.Part:GetAttribute("Ore")]
		Juice.Squash(info.Part, Vector3.new(0.2, 0.2, 0.2), 0.01, 0.35)
		Juice.Burst(info.Position, { Color = ore and ore.Color or WHITE, Count = 10, Size = 0.4, Speed = 3, Life = 0.8, Gravity = -2, Glow = 1 })
		Juice.Sound("electronicpingshort.wav", 1.8, 0.12 * v, 0, info.Position)
	end,
	Pet = function(info, mine, v)
		Juice.Flash(info.Model, Ui.BERRY, 0.4, 0.2)
		Juice.Burst(info.Position, { Color = { Ui.BERRY, rgb(255, 200, 220) }, Count = 14, Size = 0.6, Speed = 4, Life = 1, Gravity = -3, Glow = 0.6 })
		Juice.Sound("short spring sound.wav", if info.Monster then 0.8 else 1.3, 0.35 * v, 0, info.Position)
		Juice.Sound("clickfast.wav", 1.7, 0.15 * v, 0.05, info.Position)
		if mine then
			Juice.Float(info.Position, info.Text or "♥", Ui.BERRY)
			Juice.Shake(0.15, 14, 0.12)
		end
	end,
	-- 도우미 동물 쓰다듬기: 폴짝 커졌다 돌아오고 하트, 말풍선(내 동물이면 한 일)
	PetLove = function(info, mine, v)
		local model = info.Model
		Juice.ScaleModel(model, { { 1.2, 0.08 }, { 0.92, 0.1 }, { 1, 0.18, Enum.EasingStyle.Back } })
		Juice.Burst(info.Position, { Color = { Ui.BERRY, rgb(255, 200, 220) }, Count = 14, Size = 0.6, Speed = 4, Life = 1, Gravity = -3, Glow = 0.6 })
		Juice.Sound("short spring sound.wav", 1.5, 0.35 * v, 0, info.Position)
		if model and model.PrimaryPart then
			bubble(model.PrimaryPart, info.Text, model:GetExtentsSize().Y + 1.5)
		end
		if mine then
			Juice.Shake(0.15, 14, 0.12)
		end
	end,
	-- 인사하기: 하트·별과 "안녕!" 말풍선(손 흔들기는 ActionAnimator)
	Greet = function(info, _, v)
		local head = info.Player and info.Player.Character and info.Player.Character:FindFirstChild("Head")
		Juice.Burst(info.Position, { Color = { Ui.BERRY, Ui.SUN }, Count = 10, Size = 0.5, Speed = 4, Life = 0.9, Gravity = -2, Glow = 0.8 })
		Juice.Sound("electronicpingshort.wav", 1.6, 0.3 * v, 0, info.Position)
		bubble(head, info.Text, 2.5)
	end,
	-- 하이파이브(둘이 서로 인사): 별 터짐·링·짝! 소리, 두 사람 머리 위 말풍선. 코인이 붙으면 코인 알약으로
	HighFive = function(info, mine, v)
		Juice.Burst(info.Position, { Color = { Ui.SUN, Ui.BERRY, Ui.SKY }, Count = 26, Size = 0.6, Speed = 10, Life = 0.8, Gravity = 4, Glow = 1,
			Spread = 180 })
		Juice.Ring(info.Position, Ui.SUN, 1, 6, 0.3)
		Juice.Sound("snap.mp3", 1.1, 0.7 * v, 0, info.Position)
		Juice.Sound("victory.wav", 1.5, 0.25 * v, 0.06, info.Position)
		for _, who in { info.Player, info.Target } do
			bubble(who and who.Character and who.Character:FindFirstChild("Head"), info.Text, 2.5)
		end
		if mine then
			Juice.Shake(0.25, 18, 0.15)
			if info.Coins then
				coinsFly(info.Position, info.Coins)
			end
		end
	end,
	-- 나무 흔들기: 블록이 흔들리고 잎이 떨어진다. 코인이 떨어지면 코인 알약으로
	Shake = function(info, mine, v)
		local color = info.Part and info.Part.Color or rgb(90, 150, 60)
		Juice.Squash(info.Part, Vector3.new(1.1, 0.94, 1.1), 0.05, 0.3)
		Juice.Burst(info.Position, { Color = { color, rgb(120, 180, 80) }, Count = 16, Size = 0.5, Speed = 4, Life = 1.4, Gravity = 6 })
		Juice.Sound("action_jump_land.mp3", 1.5, 0.35 * v, 0, info.Position)
		Juice.Sound("clickfast.wav", 0.8, 0.2 * v, 0.05, info.Position)
		if mine and info.Coins then
			coinsFly(info.Position, math.min(info.Coins, 5))
		end
	end,
	-- 섬 이벤트를 열었다(선물·나비·반짝이는 땅): 색종이·링·팡파르
	EventOpen = function(info, mine, v)
		Juice.Burst(info.Position + Vector3.new(0, 2, 0), { Color = { Ui.BERRY, Ui.SUN, Ui.SKY, Ui.MINT }, Count = 40, Size = 0.5, Speed = 14,
			Life = 1.2, Gravity = 20, Glow = 0.6, Spread = 180 })
		Juice.Ring(info.Position, Ui.SUN, 1, 8, 0.4)
		Juice.Sound("victory.wav", 1.2, 0.4 * v, 0, info.Position)
		if mine then
			Juice.Shake(0.3, 16, 0.2)
			if info.Coins then
				coinsFly(info.Position, math.clamp(math.ceil(info.Coins / 10), 3, 8))
			end
		end
	end,
	-- 섬 확장(땅·밭): 새 땅 위 구름 연기, 모서리 빛기둥, 가장자리 링, 화면 Warm, 큰 흔들림
	Expand = function(info, mine, v)
		local scale = if info.Small then 0.6 else 1
		local size = (info.Size or 9) * scale
		Juice.Burst(info.Position + Vector3.new(0, 2, 0), { Color = WHITE, Count = math.floor(40 * scale), Size = 4 * scale, Speed = 8,
			Life = 1.4, Gravity = -1, Texture = SMOKE, Spread = 180 })
		Juice.Burst(info.Position + Vector3.new(0, 2, 0), { Color = Ui.SUN, Count = math.floor(30 * scale), Size = 0.7, Speed = 12, Life = 1.2, Gravity = 4, Glow = 1, Spread = 180 })
		Juice.Ring(info.Position + Vector3.new(0, 0.3, 0), Ui.BANNER, size * 0.9, size * 1.05, 0.6)
		for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
			local pillar = Ui.make("Part", workspace, { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
				Material = Enum.Material.Neon, Color = Ui.BANNER, Shape = Enum.PartType.Cylinder, Transparency = 0.2,
				Size = Vector3.new(20 * scale, 0.6, 0.6),
				CFrame = CFrame.new(info.Position + corner * size / 2 + Vector3.new(0, 10 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
			Juice.Tween(pillar, 1.5, { Transparency = 1, Size = Vector3.new(26 * scale, 0.2, 0.2) })
			task.delay(1.6, pillar.Destroy, pillar)
		end
		Juice.Sound("victory.wav", 0.9, 0.6 * v)
		Juice.Sound("action_get_up.mp3", 0.8, 0.4 * v)
		for i = 0, 3 do
			Juice.Sound("electronicpingshort.wav", 1.2 + 0.2 * i, 0.25 * v, 0.12 * i)
		end
		if mine then
			Juice.Screen(Ui.WARM, 0.65, 0.3)
			Juice.Shake(0.6 * scale, 12, 0.45)
			Juice.Fov(4 * scale, 0.5)
		end
	end,
	-- 새 도감(배너는 Hud): 플레이어 위 금 반짝임, +10 코인 3개
	DexNew = function(info)
		local position = characterPosition() + Vector3.new(0, 4, 0)
		Juice.Burst(position, { Color = Ui.SUN, Count = 20, Size = 0.6, Speed = 8, Life = 1, Gravity = 2, Glow = 1, Spread = 180 })
		Juice.Sound("victory.wav", 1, 0.5)
		Juice.Sound("electronicpingshort.wav", 2, 0.25, 0.3)
		Juice.Screen(Ui.WARM, 0.65, 0.25)
		Juice.Shake(0.5, 14, 0.3)
		Juice.Fov(3, 0.3)
		coinsFly(position, if info.Complete then 8 else 3, 0.7)
	end,
	-- 거절(서버 토스트에 대상이 있을 때): 테두리만 Coral, ±5° 흔들림 대신 찌그러짐, 둔한 소리
	Toast = function(info)
		if info.Part then
			Juice.Flash(info.Part, Ui.CORAL, 0.5, 0.2, true)
			Juice.Squash(info.Part, Vector3.new(1.05, 0.95, 1.05), 0.06, 0.18)
			Juice.Sound("collide.wav", 0.9, 0.25)
		end
	end,
}

Remotes.Feedback.OnClientEvent:Connect(function(kind, info)
	info = info or {}
	local run = KINDS[kind]
	if not run then
		return
	end
	local mine = info.Player == player or kind == "DexNew" or kind == "Toast" or (kind == "HighFive" and info.Target == player)
	local position = info.Position
	if not mine and (not position or (workspace.CurrentCamera.CFrame.Position - position).Magnitude > HEAR) then
		return
	end
	if mine and COUNTED[kind] then
		Juice.Combo()
	end
	local function go()
		run(info, mine, if mine then 1 else 0.5)
		if info.Text and mine and not NO_FLOAT[kind] and position then
			Juice.Float(position + Vector3.new(0, 1, 0), info.Text)
		end
	end
	local contact = CONTACT[kind]
	if contact then
		task.delay(contact, go)
	else
		go()
	end
end)

-- 다 자란 작물은 계속 반짝인다(할 일이 멀리서도 보이게)
local function onCrop(model)
	local part = model:FindFirstChildWhichIsA("BasePart")
	if model:GetAttribute("Stage") ~= 3 or not part then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 235, 140))
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.2)
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Rate = 2
	emitter.Parent = part
end
CollectionService:GetInstanceAddedSignal("Crop"):Connect(onCrop)
for _, model in CollectionService:GetTagged("Crop") do
	onCrop(model)
end

-- 마우스가 가리키는 누를 수 있는 대상에 흰 테두리(터치 기기는 가리키기가 없다)
local hover = Instance.new("Highlight")
hover.FillTransparency = 1
hover.OutlineColor = WHITE
hover.DepthMode = Enum.HighlightDepthMode.Occluded
hover.Parent = workspace

local function myIsland(instance)
	local island = instance
	while island and island.Parent ~= workspace:FindFirstChild("Islands") do
		island = island.Parent
	end
	return island and island:GetAttribute("Owner") == player.UserId
end

local function pointable(instance)
	if instance:GetAttribute("Ore") and not instance:GetAttribute("Depleted") and myIsland(instance) then
		return instance
	end
	while instance and instance ~= workspace do
		if CollectionService:HasTag(instance, "Creature") or CollectionService:HasTag(instance, "Pet")
			or CollectionService:HasTag(instance, "IslandEvent") then
			return instance
		end
		local owner = instance:GetAttribute("Owner")
		local mine = owner == player.UserId
		local friend = Players:GetPlayerByUserId(owner or 0)
		local party = friend ~= nil and friend:GetAttribute("PartyId") ~= nil and friend:GetAttribute("PartyId") == player:GetAttribute("PartyId")
		if (mine or party) and CollectionService:HasTag(instance, "FarmTile") then
			return instance -- 파티원 밭도 비춘다(물주기)
		end
		if mine and (CollectionService:HasTag(instance, "Chore")
			or (CollectionService:HasTag(instance, "Placed") and player:GetAttribute("DecorMode"))) then
			return instance
		end
		instance = instance.Parent
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	local target
	if UserInputService.MouseEnabled and not UserInputService:GetFocusedTextBox() then
		local result = WorldPointer.CastMouse()
		target = result and pointable(result.Instance)
	end
	if hover.Adornee ~= target then
		hover.Adornee = target
	end
end)

-- UI 버튼 클릭음
local function onButton(object)
	if object:IsA("GuiButton") then
		object.Activated:Connect(function()
			Juice.Sound("button.wav", 1, 0.35)
		end)
	end
end
player.PlayerGui.DescendantAdded:Connect(onButton)
for _, object in player.PlayerGui:GetDescendants() do
	onButton(object)
end
