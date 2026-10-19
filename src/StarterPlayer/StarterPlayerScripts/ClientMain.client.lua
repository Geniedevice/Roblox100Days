-- HUD(일차·시간·체력/배고픔/갈증·코어)와 증강 선택 UI를 코드로 만든다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AugmentData = require(Shared:WaitForChild("AugmentData"))

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(20, 20, 26)
local RARITY = {
	Silver = { Label = "실버", Color = Color3.fromRGB(200, 205, 215) },
	Gold = { Label = "골드", Color = Color3.fromRGB(240, 190, 60) },
	Prism = { Label = "프리즘", Color = Color3.fromRGB(190, 120, 255) },
}

local function make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(instance, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, instance)
end

local gui = make("ScreenGui", { Name = "HUD", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

-- 상단: 일차 / 시간
local dayLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0, 340, 0, 40),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.3, TextColor3 = WHITE,
	Font = Enum.Font.GothamBold, TextSize = 20, Text = "대기 중...",
}, gui)
round(dayLabel)

-- 바 공통
local function makeBar(parent, name, color, size, position)
	local back = make("Frame", { Size = size, Position = position or UDim2.new(), BackgroundColor3 = Color3.fromRGB(35, 35, 42) }, parent)
	round(back, 6)
	local fill = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0 }, back)
	round(fill, 6)
	local label = make("TextLabel", {
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1,
		TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, Text = name, ZIndex = 2,
	}, back)
	return function(value, max)
		local ratio = max > 0 and math.clamp(value / max, 0, 1) or 0
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		label.Text = string.format("%s  %d / %d", name, math.floor(value), math.floor(max))
	end
end

local setCore = makeBar(gui, "기지 코어", Color3.fromRGB(80, 170, 255),
	UDim2.new(0, 340, 0, 18), UDim2.new(0.5, -170, 0, 56))

local statFrame = make("Frame", {
	Position = UDim2.new(0, 12, 1, -112), Size = UDim2.new(0, 230, 0, 100), BackgroundTransparency = 1,
}, gui)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, statFrame)
local setHealth = makeBar(statFrame, "체력", Color3.fromRGB(220, 70, 70), UDim2.new(1, 0, 0, 26))
local setHunger = makeBar(statFrame, "배고픔", Color3.fromRGB(230, 150, 60), UDim2.new(1, 0, 0, 26))
local setThirst = makeBar(statFrame, "갈증", Color3.fromRGB(70, 160, 230), UDim2.new(1, 0, 0, 26))

-- 인벤토리: 재료 개수와 먹기/마시기 버튼
local inventoryFrame = make("Frame", {
	Position = UDim2.new(0, 12, 0, 70), Size = UDim2.new(0, 190, 0, 112), BackgroundTransparency = 1,
}, gui)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, inventoryFrame)
local materialsLabel = make("TextLabel", {
	LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = DARK, BackgroundTransparency = 0.3,
	TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 14, Text = "",
}, inventoryFrame)
round(materialsLabel)

local function makeUseButton(order, item, verb, color)
	local button = make("TextButton", {
		LayoutOrder = order, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = color,
		TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 16, Text = verb,
	}, inventoryFrame)
	round(button)
	button.Activated:Connect(function()
		Remotes.UseItem:InvokeServer(item)
	end)
	return function()
		local count = player:GetAttribute(item) or 0
		button.Text = string.format("%s (%s %d)", verb, Config.Items[item].Name, count)
		button.BackgroundTransparency = count > 0 and 0 or 0.6
	end
end
local refreshEat = makeUseButton(2, "Food", "먹기", Color3.fromRGB(200, 120, 50))
local refreshDrink = makeUseButton(3, "Water", "마시기", Color3.fromRGB(50, 130, 200))

-- 중앙 메시지
local messageLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.2, 0), Size = UDim2.new(0.8, 0, 0, 50),
	BackgroundTransparency = 1, TextColor3 = WHITE, TextStrokeTransparency = 0.4,
	Font = Enum.Font.GothamBlack, TextScaled = true, Text = "", Visible = false,
}, gui)
local messageToken = 0
local function showMessage(text)
	messageToken += 1
	local token = messageToken
	messageLabel.Text = text
	messageLabel.Visible = true
	task.delay(4, function()
		if token == messageToken then
			messageLabel.Visible = false
		end
	end)
end

-- 증강 선택 창
local picker = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.55, 0), Size = UDim2.new(0.9, 0, 0.55, 0),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.1, Visible = false,
}, gui)
round(picker, 12)
make("UISizeConstraint", { MaxSize = Vector2.new(780, 380) }, picker)

make("TextLabel", {
	Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(0.5, 0, 0, 30), BackgroundTransparency = 1,
	TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "증강 선택",
}, picker)
local timerLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 10), Size = UDim2.new(0.4, 0, 0, 30),
	BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(200, 200, 200), Font = Enum.Font.GothamBold,
	TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, Text = "",
}, picker)

local cardRow = make("Frame", {
	Position = UDim2.new(0, 16, 0, 50), Size = UDim2.new(1, -32, 1, -110), BackgroundTransparency = 1,
}, picker)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, cardRow)

local rerollButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(0, 180, 0, 40),
	BackgroundColor3 = Color3.fromRGB(60, 60, 72), TextColor3 = WHITE, Font = Enum.Font.GothamBold,
	TextSize = 16, Text = "새로고침",
}, picker)
round(rerollButton)

local pickDeadline = 0
local busy = false

local function clearCards()
	for _, child in cardRow:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function makeCard(id)
	local data = AugmentData[id]
	local rarity = RARITY[data.Rarity]
	local card = make("TextButton", {
		Size = UDim2.new(0.31, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(38, 38, 48), Text = "", AutoButtonColor = true,
	}, cardRow)
	round(card, 10)
	make("UIStroke", { Color = rarity.Color, Thickness = 2 }, card)
	make("TextLabel", {
		Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(1, -20, 0, 20), BackgroundTransparency = 1,
		TextColor3 = rarity.Color, Font = Enum.Font.GothamBold, TextSize = 14,
		Text = rarity.Label .. " · " .. data.Category,
	}, card)
	make("TextLabel", {
		Position = UDim2.new(0, 10, 0, 34), Size = UDim2.new(1, -20, 0, 34), BackgroundTransparency = 1,
		TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextScaled = true, Text = data.Name,
	}, card)
	make("TextLabel", {
		Position = UDim2.new(0, 10, 0, 76), Size = UDim2.new(1, -20, 1, -86), BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(210, 210, 210), Font = Enum.Font.Gotham, TextSize = 15,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = data.Description,
	}, card)

	card.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		Remotes.ChooseAugment:InvokeServer(id)
		busy = false
	end)
end

Remotes.AugmentOffer.OnClientEvent:Connect(function(ids, pickTime, rerollsLeft)
	clearCards()
	for _, id in ids do
		makeCard(id)
	end
	rerollsLeft = rerollsLeft or 0
	rerollButton.Visible = rerollsLeft > 0
	rerollButton.Text = string.format("새로고침 (%d)", rerollsLeft)
	pickDeadline = os.clock() + pickTime
	picker.Visible = true
end)

Remotes.AugmentClosed.OnClientEvent:Connect(function(id)
	picker.Visible = false
	clearCards()
	showMessage(AugmentData[id].Name .. " 획득!")
end)

rerollButton.Activated:Connect(function()
	if busy then
		return
	end
	busy = true
	Remotes.RerollAugment:InvokeServer()
	busy = false
end)

-- 낮/밤 상태
local currentDay, isNight, phaseEndsAt = 0, false, 0
Remotes.DayChanged.OnClientEvent:Connect(function(day, night, endsAt)
	local changed = day ~= currentDay or night ~= isNight
	currentDay, isNight, phaseEndsAt = day, night, endsAt
	if changed then
		showMessage(night and (day .. "일차 밤 — 좀비가 몰려온다!") or (day .. "일차 아침"))
	end
end)

Remotes.GameMessage.OnClientEvent:Connect(showMessage)

RunService.Heartbeat:Connect(function()
	if currentDay > 0 then
		local remaining = math.max(0, math.floor(phaseEndsAt - workspace:GetServerTimeNow()))
		dayLabel.Text = string.format("%d / %d일차  ·  %s %d:%02d",
			currentDay, Config.TOTAL_DAYS, isNight and "밤" or "낮", remaining // 60, remaining % 60)
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		setHealth(humanoid.Health, humanoid.MaxHealth)
	else
		setHealth(0, 100)
	end
	setHunger(player:GetAttribute("Hunger") or Config.Survival.Max, Config.Survival.Max)
	setThirst(player:GetAttribute("Thirst") or Config.Survival.Max, Config.Survival.Max)
	materialsLabel.Text = string.format("%s %d  ·  %s %d", Config.Items.Wood.Name, player:GetAttribute("Wood") or 0,
		Config.Items.Stone.Name, player:GetAttribute("Stone") or 0)
	refreshEat()
	refreshDrink()

	local base = workspace:FindFirstChild("Base")
	local core = base and base:FindFirstChild("Core")
	if core then
		setCore(core:GetAttribute("Health") or 0, core:GetAttribute("MaxHealth") or Config.Core.MaxHealth)
	end

	if picker.Visible then
		timerLabel.Text = string.format("%d초", math.max(0, math.ceil(pickDeadline - os.clock())))
	end
end)
