-- 컴퍼니 창: 다음 목적지 선택, 출발, 장비·증강 구매. 컴퍼니로 돌아오면 저절로 열리고, 단말기(OpenShop)나 B 키로 다시 연다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AugmentData = require(Shared:WaitForChild("AugmentData"))

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(20, 20, 26)
local BUTTON = Color3.fromRGB(55, 58, 70)
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

local function round(instance)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, instance)
end

local gui = make("ScreenGui", { Name = "Company", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
local panel = make("ScrollingFrame", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 360, 0.75, 0),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.1, Visible = false, ScrollBarThickness = 6,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, gui)
round(panel)
make("UIPadding", {
	PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 14),
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, panel)

local order = 0
local function label(text, size, color)
	order += 1
	return make("TextLabel", {
		LayoutOrder = order, Size = UDim2.new(1, 0, 0, size or 22), BackgroundTransparency = 1,
		TextColor3 = color or WHITE, Font = Enum.Font.GothamBold, TextSize = 15, Text = text,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	}, panel)
end

local function button(text, color, height)
	order += 1
	local b = make("TextButton", {
		LayoutOrder = order, Size = UDim2.new(1, 0, 0, height or 34), BackgroundColor3 = color or BUTTON,
		TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 14, Text = text, TextWrapped = true,
	}, panel)
	round(b)
	return b
end

local closeButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0.125, -36), Size = UDim2.new(0, 90, 0, 30),
	BackgroundColor3 = BUTTON, TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 14, Text = "닫기 (B)", Visible = false,
}, gui)
round(closeButton)

local title = label("컴퍼니", 30)
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
local info = label("", 40)
local status = label("", 22, Color3.fromRGB(255, 210, 120))

local busy = false
local function run(callback)
	if busy then
		return
	end
	busy = true
	local ok, message = callback()
	if message then
		status.Text = message
	end
	busy = false
	return ok
end

-- 목적지
label("다음 목적지", 22, Color3.fromRGB(150, 200, 255))
local worldButtons = {}
for _, world in Config.Worlds do
	local b = button(string.format("%s  ·  이동비 %d  ·  좀비 x%.1f  ·  고물 x%.1f",
		world.Name, world.TravelCost, world.ZombieMultiplier, world.ScrapMultiplier), BUTTON, 38)
	worldButtons[world.Id] = b
	b.Activated:Connect(function()
		Remotes.SelectWorld:FireServer(world.Id)
	end)
end
local launchButton = button("지금 출발!", Color3.fromRGB(70, 140, 80), 40)
launchButton.Activated:Connect(function()
	Remotes.Launch:FireServer()
end)

-- 장비
label("장비", 22, Color3.fromRGB(150, 200, 255))
local equipmentButtons = {}
for _, item in Config.Shop.Equipment do
	local b = button("", BUTTON)
	equipmentButtons[item] = b
	b.Activated:Connect(function()
		run(function()
			return Remotes.Buy:InvokeServer("Equipment", item.Id)
		end)
	end)
end

-- 증강(플레이어마다 따로 추첨)
label("증강", 22, Color3.fromRGB(150, 200, 255))
order += 1
local augmentFrame = make("Frame", {
	LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, augmentFrame)
local rerollButton = button(string.format("증강 새로고침  ·  %d", Config.Shop.RerollPrice), Color3.fromRGB(90, 80, 120))
rerollButton.Activated:Connect(function()
	run(function()
		return Remotes.RerollShop:InvokeServer(), nil
	end)
end)

local function showOffers(ids)
	for _, child in augmentFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i, id in ids do
		local data = AugmentData[id]
		local level = player:GetAttribute("Aug_" .. id) or 0
		local b = make("TextButton", {
			LayoutOrder = i, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Color3.fromRGB(38, 38, 48),
			TextColor3 = RARITY[data.Rarity].Color, Font = Enum.Font.GothamBold, TextSize = 14, TextWrapped = true,
			Text = string.format("[%s] %s  Lv.%d→%d  ·  %d\n%s", RARITY[data.Rarity].Label, data.Name, level, level + 1,
				Config.Shop.AugmentPrice[data.Rarity], data.Description),
		}, augmentFrame)
		round(b)
		b.Activated:Connect(function()
			run(function()
				return Remotes.Buy:InvokeServer("Augment", id)
			end)
		end)
	end
	if #ids == 0 then
		status.Text = "살 수 있는 증강이 없습니다"
	end
end
Remotes.ShopOffers.OnClientEvent:Connect(showOffers)

local function refresh()
	local credits = workspace:GetAttribute("Credits") or 0
	local period = workspace:GetAttribute("Period") or 0
	info.Text = string.format("크레딧 %d\n%d번째 탐사(%d~%d일)를 마치면 생존비 %d", credits, period,
		(period - 1) * Config.Company.PeriodDays + 1, period * Config.Company.PeriodDays, workspace:GetAttribute("Quota") or 0)
	local nextWorld = workspace:GetAttribute("NextWorld")
	for id, b in worldButtons do
		b.BackgroundColor3 = id == nextWorld and Color3.fromRGB(60, 100, 160) or BUTTON
	end
	for item, b in equipmentButtons do
		local owned = item.Weapon and player:GetAttribute("Has" .. item.Weapon)
		b.Text = owned and (item.Name .. "  ·  보유 중") or string.format("%s  ·  %d", item.Name, item.Price)
		b.BackgroundColor3 = (owned or credits < item.Price) and Color3.fromRGB(40, 40, 46) or BUTTON
	end
end

local function setOpen(open)
	open = open and workspace:GetAttribute("Phase") == "Lobby"
	panel.Visible = open
	closeButton.Visible = open
	if open then
		refresh()
	end
end

closeButton.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.B then
		setOpen(not panel.Visible)
	end
end)
Remotes.OpenShop.OnClientEvent:Connect(function()
	setOpen(true)
end)
workspace:GetAttributeChangedSignal("Phase"):Connect(function()
	status.Text = ""
	setOpen(workspace:GetAttribute("Phase") == "Lobby")
end)
for _, name in { "Credits", "NextWorld", "Period", "Quota" } do
	workspace:GetAttributeChangedSignal(name):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
end
player.AttributeChanged:Connect(function(name)
	if panel.Visible and name:sub(1, 3) == "Has" then
		refresh()
	end
end)
setOpen(true)
