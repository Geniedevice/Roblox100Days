-- HUD(일차·시간·체력/배고픔/갈증·인벤토리·제작·보유 증강)와 증강 선택 UI를 코드로 만든다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0, 420, 0, 40),
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

local statFrame = make("Frame", {
	Position = UDim2.new(0, 12, 1, -112), Size = UDim2.new(0, 230, 0, 100), BackgroundTransparency = 1,
}, gui)
-- 터치 기기에서는 왼쪽 아래 조이스틱과 겹치지 않게 오른쪽 위로 옮긴다
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	statFrame.AnchorPoint = Vector2.new(1, 0)
	statFrame.Position = UDim2.new(1, -12, 0, 70)
end
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, statFrame)
local setHealth = makeBar(statFrame, "체력", Color3.fromRGB(220, 70, 70), UDim2.new(1, 0, 0, 26))
local setHunger = makeBar(statFrame, "배고픔", Color3.fromRGB(230, 150, 60), UDim2.new(1, 0, 0, 26))
local setThirst = makeBar(statFrame, "갈증", Color3.fromRGB(70, 160, 230), UDim2.new(1, 0, 0, 26))

-- 인벤토리: 재료 개수와 먹기/마시기/치료 버튼
local inventoryFrame = make("Frame", {
	Position = UDim2.new(0, 12, 0, 70), Size = UDim2.new(0, 190, 0, 192), BackgroundTransparency = 1,
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
local refreshHeal = makeUseButton(4, "Medkit", "치료", Color3.fromRGB(190, 60, 70))

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

-- 제작 창: 버튼이나 C 키로 연다
local craftPanel = make("Frame", {
	Position = UDim2.new(0, 210, 0, 70), Size = UDim2.new(0, 240, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = DARK, BackgroundTransparency = 0.2, Visible = false,
}, gui)
round(craftPanel)
make("UIPadding", {
	PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
}, craftPanel)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, craftPanel)

local function describe(recipe)
	local costs = {}
	for item, amount in recipe.Cost do
		table.insert(costs, Config.Items[item].Name .. " " .. amount)
	end
	table.sort(costs)
	local effect = recipe.Place and ("체력 " .. recipe.Place.Health) or "원거리 무기"
	return string.format("%s  ·  %s\n%s", recipe.Name, effect, table.concat(costs, ", "))
end

local craftButtons = {}
for i, recipe in Config.Crafting do
	local button = make("TextButton", {
		LayoutOrder = i, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(60, 60, 72),
		TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 14, Text = describe(recipe),
	}, craftPanel)
	round(button)
	button.Activated:Connect(function()
		local _, message = Remotes.RequestCraft:InvokeServer(recipe.Id)
		showMessage(message)
	end)
	craftButtons[button] = recipe
end

local function refreshCraft()
	if not craftPanel.Visible then
		return
	end
	for button, recipe in craftButtons do
		local affordable = true
		for item, amount in recipe.Cost do
			if (player:GetAttribute(item) or 0) < amount then
				affordable = false
			end
		end
		button.BackgroundTransparency = affordable and 0 or 0.6
	end
end

local craftToggle = make("TextButton", {
	LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(90, 90, 105),
	TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 16, Text = "제작 (C)",
}, inventoryFrame)
round(craftToggle)
local function toggleCraft()
	craftPanel.Visible = not craftPanel.Visible
end
craftToggle.Activated:Connect(toggleCraft)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.C then
		toggleCraft()
	end
end)

-- 원거리 무기(Ranged 표시가 있는 Tool): 클릭/터치한 지점을 서버로 보낸다
local mouse = player:GetMouse()
local hookedTools = setmetatable({}, { __mode = "k" })
local function hookTool(tool)
	if tool:IsA("Tool") and tool:GetAttribute("Ranged") and not hookedTools[tool] then
		hookedTools[tool] = true
		tool.Activated:Connect(function()
			Remotes.Shoot:FireServer(mouse.Hit.Position)
		end)
	end
end
local function watchTools(container)
	container.ChildAdded:Connect(hookTool)
	for _, child in container:GetChildren() do
		hookTool(child)
	end
end
player.CharacterAdded:Connect(function(character)
	watchTools(character)
	watchTools(player:WaitForChild("Backpack"))
end)
if player.Character then
	watchTools(player.Character)
end
watchTools(player:WaitForChild("Backpack"))

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
	local level = player:GetAttribute("Aug_" .. id) or 0
	make("TextLabel", {
		Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(1, -20, 0, 20), BackgroundTransparency = 1,
		TextColor3 = rarity.Color, Font = Enum.Font.GothamBold, TextSize = 14,
		Text = string.format("%s · %s · %s", rarity.Label, data.Category,
			level == 0 and "새 증강" or string.format("Lv.%d → %d", level, level + 1)),
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
	showMessage(string.format("%s Lv.%d!", AugmentData[id].Name, player:GetAttribute("Aug_" .. id) or 1))
end)

-- 보유 증강 목록(오른쪽): 레벨이 바뀔 때마다 다시 그린다
local ownedFrame = make("Frame", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 190), Size = UDim2.new(0, 170, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
}, gui)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, ownedFrame)

local function refreshOwned()
	for _, child in ownedFrame:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for id, data in AugmentData do
		local level = player:GetAttribute("Aug_" .. id)
		if level then
			local label = make("TextLabel", {
				Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = DARK, BackgroundTransparency = 0.35,
				TextColor3 = RARITY[data.Rarity].Color, Font = Enum.Font.GothamBold, TextSize = 13,
				Text = string.format("%s  %s", data.Name, level >= data.MaxStack and "MAX" or ("Lv." .. level)),
			}, ownedFrame)
			round(label, 6)
		end
	end
end
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 4) == "Aug_" then
		refreshOwned()
	end
end)
refreshOwned()

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
		local best = player:GetAttribute("BestDay") or 0
		dayLabel.Text = string.format("%d / %d일차  ·  %s %d:%02d%s",
			currentDay, Config.TOTAL_DAYS, isNight and "밤" or "낮", remaining // 60, remaining % 60,
			best > 0 and string.format("  ·  최고 %d일", best) or "")
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
	refreshHeal()
	refreshCraft()

	if picker.Visible then
		timerLabel.Text = string.format("%d초", math.max(0, math.ceil(pickDeadline - os.clock())))
	end
end)
