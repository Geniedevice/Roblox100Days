-- HUD(명세: design/ux/hud.md): 위 가운데 보상 알약(아늑함·코인·도감), 아래 가운데 핫바(구역 도구 칸 + 구역 아이템 칸),
-- 오른쪽 기둥(설정·친구·도감·꾸미기, 친구 버튼은 SocialClient가 붙인다, 휴대폰은 점프 버튼 위), 토스트·배너·구역 칩·콤보, 입질 때 "당기기!" 버튼, 설정 창.
-- 숫자는 휙 바뀌지 않는다: 코인은 지연 카운터(+N 칩 → 날아온 코인이 닿으면 굴러감), 아늑함·도감은 고스트 막대.
-- 농지 누르기도 여기서 보낸다(핫바에서 고른 씨앗과 함께). 무엇을 할지는 서버가 정한다.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared:WaitForChild("Crops"))
local Fish = require(Shared:WaitForChild("Fish"))
local Ores = require(Shared:WaitForChild("Ores"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local Juice = require(script.Parent:WaitForChild("Juice"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local WorldPointer = require(script.Parent:WaitForChild("WorldPointer"))

local player = Players.LocalPlayer
local CELL, CHUNK = 3, 16
local ZONE_NAMES = { Plaza = "상점 거리", Farm = "농장", Fishing = "낚시터", House = "집터", Wild = "숲" }
-- 구역에 들어설 때 칩에 붙는 "여기서 할 수 있는 일"(design/ux/hud.md)
local ZONE_HINTS = { Plaza = "모모·버니·루미와 이야기해요", Farm = "밭을 갈고 씨앗을 뿌려요", Fishing = "물가에서 낚시해요",
	House = "꾸미기 버튼으로 가구를 놓아요", Wild = "광석 바위를 캐고 생물을 쓰다듬어요" }
local ZONE_CHIP_TIME = 3
local GRADES = { { 0, 15, "D", Color3.fromRGB(170, 160, 150) }, { 15, 45, "C", Ui.MINT }, { 45, 75, "B", Ui.SKY },
	{ 75, 110, "A", Ui.SUN }, { 110, 110, "S", Ui.BERRY } }
local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local gui = Ui.make("ScreenGui", nil, { Name = "Hud", ResetOnSpawn = false, DisplayOrder = 3 })

-- 위 가운데 알약 줄 -------------------------------------------------------------------------------
local top = Ui.make("Frame", gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, if touch then 6 else 12),
	Size = UDim2.fromOffset(0, 52), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 })
Ui.make("UIListLayout", top, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })

local function ghostBar(parent)
	local back = Ui.make("Frame", parent, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 6, 1, -6), Size = UDim2.new(1, -60, 0, 6),
		BackgroundColor3 = Ui.PARCHMENT_DEEP, BorderSizePixel = 0 })
	Ui.corner(back, "pill")
	local ghost = Ui.make("Frame", back, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Ui.GHOST_GAIN, BorderSizePixel = 0 })
	Ui.corner(ghost, "pill")
	local fill = Ui.make("Frame", back, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Ui.LEAF, BorderSizePixel = 0 })
	Ui.corner(fill, "pill")
	local value = 0
	return function(ratio, color, delay, follow)
		ratio = math.clamp(ratio, 0, 1)
		fill.BackgroundColor3 = color or fill.BackgroundColor3
		if ratio >= value then
			ghost.BackgroundColor3 = Ui.GHOST_GAIN
			ghost.Size = UDim2.fromScale(ratio, 1)
			task.delay(delay or 0.35, function()
				Juice.Tween(fill, follow or 0.5, { Size = UDim2.fromScale(ratio, 1) })
			end)
		else
			ghost.BackgroundColor3 = Ui.GHOST_LOSS
			fill.Size = UDim2.fromScale(ratio, 1)
			task.delay(0.4, function()
				Juice.Tween(ghost, 0.5, { Size = UDim2.fromScale(ratio, 1) })
			end)
		end
		value = ratio
	end
end

local function pill(order, width, iconKind)
	local frame = Ui.pill(top, { LayoutOrder = order, Size = UDim2.fromOffset(width, if order == 2 then 48 else 42) })
	local icon = Icons.View(iconKind, nil, { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(2, 2) })
	icon.Parent = frame
	return frame, icon
end

local cozyPill = pill(1, 132, "House")
local cozyText = Ui.text(cozyPill, "0", 18, { FontFace = Ui.NUM, Position = UDim2.fromOffset(42, 2), Size = UDim2.new(1, -78, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Left })
local gradeBadge = Ui.make("Frame", cozyPill, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = GRADES[1][4] })
Ui.corner(gradeBadge, "pill")
Ui.stroke(gradeBadge, 2)
local gradeText = Ui.text(gradeBadge, "D", 16, { FontFace = Ui.NUM, TextColor3 = Ui.INK })
local cozyBar = ghostBar(cozyPill)

local coinPill = pill(2, 156, "Coin")
local coinText = Ui.text(coinPill, "0", 24, { FontFace = Ui.NUM, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -52, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left })
local coinChip = Ui.text(coinPill, "", 17, { FontFace = Ui.NUM, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4),
	Size = UDim2.fromOffset(120, 22), TextColor3 = Ui.SUN, TextTransparency = 1 })
local chipStroke = Ui.stroke(coinChip, 2.5, Ui.GOLD_DEEP, true)
Juice.Targets.Coins = coinPill

local dexPill = pill(3, 120, "Book")
local dexText = Ui.text(dexPill, "0/0", 18, { FontFace = Ui.NUM, Position = UDim2.fromOffset(42, 2), Size = UDim2.new(1, -48, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Left })
local dexBar = ghostBar(dexPill)
Juice.Targets.Dex = dexPill

local function shortNumber(n)
	return if n >= 10000 then string.format("%.1fK", n / 1000) else tostring(math.floor(n + 0.5))
end

-- 지연 카운터: 값이 바뀌면 칩이 바로, 숫자는 날아온 코인이 닿을 때(없으면 100ms 뒤) 굴러간다
local shownCoins, targetCoins, changedAt, rolling = nil, 0, 0, nil
local function roll()
	if rolling or shownCoins == targetCoins then
		return
	end
	local from, to = shownCoins, targetCoins
	local value = Instance.new("NumberValue")
	value.Value = from
	rolling = value
	value.Changed:Connect(function(v)
		coinText.Text = shortNumber(v)
	end)
	Ui.scale(coinText).Scale = 1.08
	local t = Juice.Tween(value, math.clamp(0.25 + 0.003 * math.abs(to - from), 0.25, 1.2), { Value = to })
	t.Completed:Once(function()
		shownCoins = to
		coinText.Text = shortNumber(to)
		Juice.Tween(Ui.scale(coinText), 0.12, { Scale = 1 })
		Juice.Tween(coinChip, 0.2, { TextTransparency = 1 })
		Juice.Tween(chipStroke, 0.2, { Transparency = 1 })
		value:Destroy()
		rolling = nil
		roll() -- 그사이 또 바뀌었으면 이어서
	end)
end
local function onCoins()
	local coins = player:GetAttribute("Coins") or 0
	if shownCoins == nil then
		shownCoins, targetCoins = coins, coins
		coinText.Text = shortNumber(coins)
		return
	end
	local delta = coins - targetCoins
	targetCoins, changedAt = coins, os.clock()
	if delta == 0 then
		return
	end
	coinChip.Text = (if delta > 0 then "+" else "−") .. shortNumber(math.abs(delta))
	coinChip.TextColor3 = if delta > 0 then Ui.SUN else Ui.INK
	chipStroke.Color = if delta > 0 then Ui.GOLD_DEEP else Ui.CORAL
	coinChip.TextTransparency, chipStroke.Transparency = 0, 0
	Juice.Punch(coinChip, 1.3, 0.18)
end
Juice.Bus.CoinArrive.Event:Connect(roll)
RunService.Heartbeat:Connect(function()
	if shownCoins ~= targetCoins and not rolling and os.clock() >= math.max(changedAt + 0.1, Juice.State.CoinHoldUntil) then
		roll()
	end
end)

local function onCozy()
	local score = player:GetAttribute("Cozy") or 0
	local grade = GRADES[1]
	for _, g in GRADES do
		if score >= g[1] then
			grade = g
		end
	end
	cozyText.Text = tostring(score)
	if gradeText.Text ~= grade[3] then
		gradeText.Text = grade[3]
		gradeBadge.BackgroundColor3 = grade[4]
		Juice.Punch(gradeBadge, 1.4, 0.2)
	end
	cozyBar(if grade[2] > grade[1] then (score - grade[1]) / (grade[2] - grade[1]) else 1, Ui.LEAF)
end

local dexFound, dexTotal = 0, 0
local function onDex()
	local ok, data = pcall(Remotes.Dex.InvokeServer, Remotes.Dex)
	if not ok or type(data) ~= "table" then
		return
	end
	local found, total = 0, 0
	for _, category in data do
		found += category.Found
		total += category.Total
	end
	if found ~= dexFound then
		Juice.Punch(dexPill, 1.3, 0.2)
	end
	dexFound, dexTotal = found, total
	dexText.Text = found .. "/" .. total
	dexBar(if total > 0 then found / total else 0, Ui.BERRY, 0.6, 0.6)
end

-- 토스트 · 구역 칩 · 배너 --------------------------------------------------------------------------
local toast = Ui.pill(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(0, 38),
	AutomaticSize = Enum.AutomaticSize.X, Visible = false })
Ui.make("UIPadding", toast, { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) })
local toastText = Ui.text(toast, "", 17, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextWrapped = false })
local toastShown, lastToast, lastToastAt, toastRepeat = 0, nil, 0, 1
local function showToast(text)
	if text == lastToast and os.clock() - lastToastAt < 0.5 then
		toastRepeat += 1
		text = text .. " ×" .. toastRepeat
	else
		toastRepeat = 1
	end
	lastToast, lastToastAt = text:gsub(" ×%d+$", ""), os.clock()
	toastShown += 1
	local mine = toastShown
	toastText.Text = text
	toast.Position = UDim2.new(0.5, 0, 0, 70)
	toast.Visible = true
	Juice.Tween(toast, 0.18, { Position = UDim2.new(0.5, 0, 0, 82) }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		if toastShown == mine then
			toast.Visible = false
		end
	end)
end

local zoneChip = Ui.pill(gui, { Name = "ZoneChip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124),
	Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Ui.PARCHMENT, Visible = false })
Ui.make("UIPadding", zoneChip, { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) })
local zoneText = Ui.text(zoneChip, "", 15, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextWrapped = false })
local zoneShown = 0

-- 배너: 대기열(최대 3), 하나씩. 아이콘은 실루엣이었다가 300ms에 번쩍이며 색이 드러난다
local CATEGORY_KIND = { Crops = "Crop", Fish = "Fish", Ores = "Ore", Creatures = "Creature", Furniture = "Furniture", Islands = "Island" }
local bannerQueue, bannerBusy = {}, false
local function confetti(center, count)
	if Juice.Reduced() then
		return
	end
	local colors = { Ui.BERRY, Ui.SUN, Ui.MINT, Ui.SKY }
	for i = 1, count do
		local piece = Ui.make("Frame", gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(10, 10), Rotation = 45, BackgroundColor3 = colors[i % #colors + 1], BorderSizePixel = 0, ZIndex = 20 })
		local angle = math.random() * 2 * math.pi
		local distance = 90 + math.random() * 140
		local goal = center + Vector2.new(math.cos(angle), math.sin(angle)) * distance + Vector2.new(0, 60)
		Juice.Tween(piece, 0.7 + math.random() * 0.3, { Position = UDim2.fromOffset(goal.X, goal.Y), Rotation = 45 + math.random(-360, 360),
			BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		task.delay(1.1, piece.Destroy, piece)
	end
end
local function playBanner(info)
	bannerBusy = true
	local big = info.Kind == "Expand" and not info.Small
	local width, height = if big then 380 else 330, if big then 104 else 88
	local banner = Ui.panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.24, 0), Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Ui.BANNER, ZIndex = 10 })
	banner:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(200, 150, 60)
	local iconKind, iconId = info.IconKind, info.IconId
	local icon = Icons.View(iconKind, iconId, { Size = UDim2.fromOffset(height - 16, height - 16), Position = UDim2.fromOffset(8, 8), ZIndex = 11,
		Silhouette = info.Reveal == true })
	icon.Parent = banner
	Ui.text(banner, info.Title, if big then 26 else 22, { FontFace = Ui.FONT_HEAVY, Position = UDim2.fromOffset(height, 8),
		Size = UDim2.new(1, -height - 10, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 })
	Ui.text(banner, info.Sub or "", 17, { Position = UDim2.fromOffset(height, 40), Size = UDim2.new(1, -height - 10, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Ui.MUTED, ZIndex = 11 })
	if info.Progress then
		local back = Ui.make("Frame", banner, { Position = UDim2.fromOffset(height, height - 22), Size = UDim2.new(1, -height - 16, 0, 10),
			BackgroundColor3 = Ui.PARCHMENT_DEEP, ZIndex = 11 })
		Ui.corner(back, "pill")
		local ghost = Ui.make("Frame", back, { Size = UDim2.fromScale(info.Progress, 1), BackgroundColor3 = Ui.GHOST_GAIN, ZIndex = 12 })
		Ui.corner(ghost, "pill")
		local fill = Ui.make("Frame", back, { Size = UDim2.fromScale(info.Before or 0, 1), BackgroundColor3 = Ui.LEAF_DEEP, ZIndex = 13 })
		Ui.corner(fill, "pill")
		task.delay(0.6, function()
			Juice.Tween(fill, 0.6, { Size = UDim2.fromScale(info.Progress, 1) })
		end)
	end
	-- 도장 찍기 1.6 → 0.92 → 1, −6° → 0
	local scale = Ui.scale(banner)
	if not Juice.Reduced() then
		scale.Scale, banner.Rotation = 1.6, -6
		local stamp = Juice.Tween(scale, 0.16, { Scale = 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Juice.Tween(banner, 0.3, { Rotation = 0 })
		stamp.Completed:Once(function()
			Juice.Tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
			confetti(banner.AbsolutePosition + banner.AbsoluteSize / 2, if big then 24 else 16)
		end)
	end
	if info.Reveal then
		task.delay(0.3, function()
			local colored = Icons.View(iconKind, iconId, { Size = icon.Size, Position = icon.Position, ZIndex = 11 })
			colored.Parent = banner
			icon:Destroy()
			Juice.Punch(colored, 1.3, 0.2)
		end)
	end
	task.delay(if big then 3 else 2.5, function()
		local out = Juice.Tween(scale, 0.16, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Juice.Tween(banner, 0.16, { BackgroundTransparency = 1 })
		out.Completed:Once(function()
			banner:Destroy()
			bannerBusy = false
			local nextInfo = table.remove(bannerQueue, 1)
			if nextInfo then
				playBanner(nextInfo)
			end
		end)
	end)
end
local function queueBanner(info)
	if bannerBusy then
		if #bannerQueue < 3 then
			table.insert(bannerQueue, info)
		end
	else
		playBanner(info)
	end
end

-- 콤보(오른쪽 가운데): ×c, 크기·색이 커지고 장조 5음계로 올라간다. 보상 없음
local comboLabel = Ui.text(gui, "", 30, { FontFace = Ui.NUM, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.42, 0),
	Size = UDim2.fromOffset(160, 70), TextColor3 = Ui.CREAM, Visible = false, TextXAlignment = Enum.TextXAlignment.Right })
local comboStroke = Ui.stroke(comboLabel, 3, Ui.COCOA, true)
local comboCaption = Ui.text(comboLabel, "콤보", 14, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.fromOffset(60, 18),
	TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Ui.CREAM })
Ui.stroke(comboCaption, 2, Ui.COCOA, true)
local SCALE_STEPS = { 0, 2, 4, 7, 9, 12, 14, 16 }
local MILESTONES = { [5] = "좋아요!", [10] = "멋져요!", [20] = "최고예요!" }
local comboToken = 0
Juice.Bus.Combo.Event:Connect(function(c)
	if c < 2 or player:GetAttribute("Setting_Combo") == false then
		return
	end
	comboToken += 1
	local mine = comboToken
	comboLabel.Visible = true
	comboLabel.TextTransparency, comboStroke.Transparency = 0, 0
	comboLabel.Text = "×" .. c
	comboLabel.TextSize = 30 + 4 * math.min(c - 2, 10)
	comboLabel.TextColor3 = if c >= 20 then Ui.BERRY elseif c >= 10 then Ui.BERRY elseif c >= 5 then Ui.SUN else Ui.CREAM
	comboLabel.Rotation = if Juice.Reduced() then 0 else math.random(-4, 4)
	Juice.Punch(comboLabel, 1.4, 0.16)
	local step = SCALE_STEPS[math.min(c - 1, #SCALE_STEPS)]
	Juice.Sound("electronicpingshort.wav", 0.8 * 2 ^ (step / 12), 0.18)
	if MILESTONES[c] then
		showToast(MILESTONES[c] .. "  콤보 ×" .. c)
		Juice.Sound("short spring sound.wav", 1.4, 0.3)
		Juice.Sound("electronicpingshort.wav", 0.8 * 2 ^ ((step + 7) / 12), 0.15, 0.05)
		confetti(comboLabel.AbsolutePosition + comboLabel.AbsoluteSize / 2, 12)
	end
	task.delay(2, function()
		if comboToken == mine then
			Juice.Tween(Ui.scale(comboLabel), 1, { Scale = 0.85 }, Enum.EasingStyle.Sine)
		end
	end)
	task.delay(3, function()
		if comboToken == mine then
			Juice.Tween(comboLabel, 0.3, { TextTransparency = 1 })
			Juice.Tween(comboStroke, 0.3, { Transparency = 1 })
			task.delay(0.3, function()
				if comboToken == mine then
					comboLabel.Visible = false
					Ui.scale(comboLabel).Scale = 1
				end
			end)
		end
	end)
end)

-- 핫바(아래 가운데): 도구 칸 + 구역 아이템 칸 ----------------------------------------------------
local SLOT = if touch then Vector2.new(60, 68) else Vector2.new(76, 84)
local hotbar = Ui.make("Frame", gui, { Name = "Hotbar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -10 else -16),
	Size = UDim2.fromOffset(0, SLOT.Y + 8), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 })
Ui.make("UIListLayout", hotbar, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, if touch then 6 else 8),
	VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder })

local selectedSeed -- 고른 씨앗 작물 Id
local slots = {} -- [아이템 Id] = 칸(날아오는 아이콘 도착지)
local handles = {} -- [아이템 Id] = { Count = 글자, Badge = 원, BadgeText, Icon }
local currentZone, slotKey

local function makeSlot(order, kind, id, selected)
	local slot = Ui.make("TextButton", hotbar, { LayoutOrder = order, Size = UDim2.fromOffset(SLOT.X, SLOT.Y), Text = "", AutoButtonColor = false,
		BackgroundColor3 = if order == 0 then Ui.PARCHMENT_DEEP else Ui.PARCHMENT })
	Ui.corner(slot, 14)
	Ui.stroke(slot, if selected then 4 else 3, if selected then Ui.LEAF else Ui.COCOA)
	local icon = Icons.View(kind, id, { Size = UDim2.fromOffset(SLOT.X - 10, SLOT.X - 10), Position = UDim2.fromOffset(5, 3),
		Spin = if selected then 30 else nil })
	icon.Parent = slot
	local handle = { Icon = icon, Slot = slot }
	if order > 0 then
		handle.Count = Ui.text(slot, "", 16, { FontFace = Ui.NUM, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -5, 1, -2),
			Size = UDim2.fromOffset(SLOT.X - 8, 20), TextXAlignment = Enum.TextXAlignment.Right })
		Ui.stroke(handle.Count, 2, Ui.CREAM, true)
		-- 수확한 작물 수(오른쪽 위 금색 원)
		handle.Badge = Ui.make("Frame", slot, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Ui.SUN, Visible = false })
		Ui.corner(handle.Badge, "pill")
		Ui.stroke(handle.Badge, 2, Ui.GOLD_DEEP)
		handle.BadgeText = Ui.text(handle.Badge, "", 14, { FontFace = Ui.NUM })
	end
	if selected then
		Ui.scale(slot).Scale = 1.06
	end
	return slot, handle
end

-- 개수만 바뀌면 칸을 다시 만들지 않고 글자만 바꾼다(날아오는 아이콘의 도착 칸이 사라지지 않게)
local function setCounts(handle, count, badge)
	if not handle.Count then
		return
	end
	local old = handle.Count.Text
	handle.Count.Text = "×" .. count
	handle.Icon.ImageTransparency = if count == 0 then 0.5 else 0
	handle.Slot.BackgroundTransparency = if count == 0 then 0.4 else 0
	if old ~= "" and old ~= handle.Count.Text then
		Juice.Punch(handle.Slot, 1.15, 0.18)
	end
	handle.Badge.Visible = (badge or 0) > 0
	if handle.BadgeText.Text ~= tostring(badge or 0) and (badge or 0) > 0 then
		handle.BadgeText.Text = tostring(badge)
		Juice.Punch(handle.Badge, 1.35, 0.18)
	end
end

local function zoneTool(zone)
	return if zone == "Fishing" then "Rod" elseif zone == "Wild" then "Pickaxe" else "Hoe" -- 숲에 광석 바위가 솟는다
end

-- 지금 서 있는 섬·구역(섬 Model의 Chunks 속성으로 계산)
local chunkCache = {} -- [섬 Model] = { Json, Map }
local function zoneAtPosition(position)
	for _, island in (workspace:FindFirstChild("Islands") or workspace):GetChildren() do
		local origin = island:GetAttribute("Origin")
		local json = island:GetAttribute("Chunks")
		if origin and json then
			local cache = chunkCache[island]
			if not cache or cache.Json ~= json then
				local map = {}
				for _, c in HttpService:JSONDecode(json) do
					map[c.X .. "," .. c.Z] = c.Zone
				end
				cache = { Json = json, Map = map }
				chunkCache[island] = cache
			end
			local relative = position - origin
			local zone = cache.Map[(math.floor(relative.X / CELL) // CHUNK) .. "," .. (math.floor(relative.Z / CELL) // CHUNK)]
			if zone then
				return zone, island
			end
		end
	end
	return nil
end

local function rebuildHotbar(force)
	local key = tostring(currentZone) .. "|" .. tostring(selectedSeed)
	local entries = {}
	if currentZone == "Fishing" then
		for id, fish in Fish do
			local n = player:GetAttribute("Item_Fish_" .. id) or 0
			if n > 0 then
				table.insert(entries, { Order = fish.Order, Kind = "Fish", Id = id, Item = "Fish_" .. id, Count = n })
			end
		end
	elseif currentZone == "Wild" then
		for id, ore in Ores do
			local n = player:GetAttribute("Item_Ore_" .. id) or 0
			if n > 0 then
				table.insert(entries, { Order = ore.Order, Kind = "Ore", Id = id, Item = "Ore_" .. id, Count = n })
			end
		end
	else
		for id, crop in Crops do
			table.insert(entries, { Order = crop.Order, Kind = "Seed", Id = id, Item = "Seed_" .. id, Seed = id,
				Count = player:GetAttribute("Item_Seed_" .. id) or 0, Badge = player:GetAttribute("Item_" .. id) or 0 })
		end
	end
	table.sort(entries, function(a, b)
		return a.Order < b.Order
	end)
	while #entries > 6 do
		table.remove(entries)
	end
	for _, e in entries do
		key ..= "|" .. e.Id
	end
	if key == slotKey and not force then
		for _, e in entries do
			setCounts(handles[e.Item], e.Count, e.Badge)
		end
		return
	end
	local zoneChanged = slotKey == nil or slotKey:match("^[^|]*") ~= tostring(currentZone)
	slotKey = key
	for _, child in hotbar:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(slots)
	table.clear(handles)
	makeSlot(0, "Tool", zoneTool(currentZone))
	for i, e in entries do
		local slot, handle = makeSlot(i, e.Kind, e.Id, e.Seed ~= nil and e.Seed == selectedSeed)
		handles[e.Item] = handle
		setCounts(handle, e.Count, e.Badge)
		slots[e.Item] = slot
		if e.Seed then
			slots[e.Seed] = slot -- 수확한 작물도 같은 작물 씨앗 칸으로 날아간다
			slot.Activated:Connect(function()
				selectedSeed = e.Seed
				rebuildHotbar(true)
			end)
		end
		if zoneChanged and not Juice.Reduced() then -- 구역이 바뀌면 칸이 하나씩 올라온다
			local scale = Ui.scale(slot)
			scale.Scale = 0.5
			task.delay(0.03 * i, function()
				Juice.Tween(scale, 0.16, { Scale = if e.Seed == selectedSeed then 1.06 else 1 }, Enum.EasingStyle.Back)
			end)
		end
	end
end
Juice.Targets.Item = function(itemId)
	return slots[itemId]
end

-- 고른 씨앗이 없거나 다 썼으면 가진 씨앗 중 첫 번째로
local function pickSeed()
	if selectedSeed and (player:GetAttribute("Item_Seed_" .. selectedSeed) or 0) > 0 then
		return
	end
	local best
	for id, crop in Crops do
		if (player:GetAttribute("Item_Seed_" .. id) or 0) > 0 and (not best or crop.Order < Crops[best].Order) then
			best = id
		end
	end
	selectedSeed = best or selectedSeed
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local index = ({ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 })[input.KeyCode]
	if index and currentZone ~= "Fishing" and currentZone ~= "Wild" then
		for id, crop in Crops do
			if crop.Order == index then
				selectedSeed = id
				rebuildHotbar(true)
			end
		end
	elseif input.KeyCode == Enum.KeyCode.B then
		Juice.Bus.ToggleDex:Fire()
	elseif input.KeyCode == Enum.KeyCode.H then
		Juice.Bus.ToggleDecor:Fire()
	end
end)

-- 오른쪽 기둥: 꾸미기 · 도감 · 설정 ----------------------------------------------------------------
local column = Ui.make("Frame", gui, { Name = "Column", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(76, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
Ui.make("UIListLayout", column, { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder })
local function columnButton(order, kind, label, size)
	local button = Ui.button(column, "", { LayoutOrder = order, Size = UDim2.fromOffset(size, size + (if label then 6 else 0)) })
	local icon = Icons.View(kind, nil, { Size = UDim2.fromOffset(size - 18, size - 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3) })
	icon.Parent = button
	if label then
		Ui.text(button, label, 14, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0, 18) })
	end
	return button
end
local gearButton = columnButton(1, "Gear", nil, 44)
local dexButton = columnButton(3, "Book", "도감", if touch then 64 else 76) -- 2번은 SocialClient의 "친구"
local decorButton = columnButton(4, "House", "꾸미기", if touch then 64 else 76)
Juice.Targets.Decor = decorButton
Juice.Targets.Column = column
dexButton.Activated:Connect(function()
	Juice.Bus.ToggleDex:Fire()
end)
decorButton.Activated:Connect(function()
	Juice.Bus.ToggleDecor:Fire()
end)

-- 휴대폰: 점프 버튼 바로 위에 붙인다(런타임에 위치를 읽는다)
local function placeColumn()
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if jump and jump.AbsoluteSize.X > 0 then
		local center = jump.AbsolutePosition.X + jump.AbsoluteSize.X / 2
		column.AnchorPoint = Vector2.new(0.5, 1)
		column.Position = UDim2.fromOffset(center, jump.AbsolutePosition.Y - 16)
		comboLabel.Position = UDim2.new(0, center - 50, 0.42, 0)
		return
	end
	column.AnchorPoint = Vector2.new(1, 1)
	column.Position = UDim2.new(1, -16, 1, -16)
end

-- 당기기! 버튼(휴대폰, 입질 때만 기둥 자리) + 입질 창 막대
local pull = Ui.button(gui, "당기기!", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(120, 120), TextSize = 24, Visible = false,
	ZIndex = 15 }, true)
local pullBarBack = Ui.make("Frame", pull, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8), Size = UDim2.new(1, 0, 0, 8),
	BackgroundColor3 = Ui.PARCHMENT_DEEP, ZIndex = 15 })
Ui.corner(pullBarBack, "pill")
local pullBar = Ui.make("Frame", pullBarBack, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.SUN, ZIndex = 16 })
Ui.corner(pullBar, "pill")
local pullToken = 0
local function hidePull()
	pullToken += 1
	pull.Visible = false
	column.Visible = Juice.State.Panels == 0
end
pull.Activated:Connect(function()
	Remotes.Interact:FireServer("Reel")
	hidePull()
end)

-- 설정 창: 움직임 줄이기 · 떠오르는 글자 · 콤보 표시 · 섬 방문 파티원만 · 파티원 수확 · 효과음 크기 ------------------
local settingsPanel = Ui.panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(340, 384),
	Visible = false, ZIndex = 12 })
Ui.text(settingsPanel, "설정", 22, { FontFace = Ui.FONT_HEAVY, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -80, 0, 30),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 })
local settingsClose = Ui.button(settingsPanel, "×", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(44, 44),
	TextSize = 24, ZIndex = 13 })
local function sendSettings(changes)
	Remotes.Interact:FireServer("Settings", nil, changes)
end
local function toggleRow(y, label, key, default)
	Ui.text(settingsPanel, label, 17, { Position = UDim2.fromOffset(18, y), Size = UDim2.new(1, -110, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 })
	local toggle = Ui.button(settingsPanel, "", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, y), Size = UDim2.fromOffset(72, 34), ZIndex = 13 })
	local function draw()
		local value = player:GetAttribute("Setting_" .. key)
		if value == nil then
			value = default
		end
		toggle.Text = if value then "켬" else "끔"
		toggle.BackgroundColor3 = if value then Ui.LEAF_DEEP else Ui.PARCHMENT_DEEP
		toggle.TextColor3 = if value then Color3.new(1, 1, 1) else Ui.INK
	end
	toggle.Activated:Connect(function()
		local value = player:GetAttribute("Setting_" .. key)
		if value == nil then
			value = default
		end
		sendSettings({ [key] = not value })
		Juice.Sound("switch.wav", if value then 0.9 else 1.2, 0.3)
	end)
	player:GetAttributeChangedSignal("Setting_" .. key):Connect(draw)
	draw()
end
toggleRow(58, "움직임 줄이기", "ReduceMotion", false)
toggleRow(100, "떠오르는 글자", "FloatText", true)
toggleRow(142, "콤보 표시", "Combo", true)
toggleRow(184, "섬 방문: 파티원만", "VisitParty", false)
toggleRow(226, "파티원 수확 허락", "HarvestParty", false)
Ui.text(settingsPanel, "효과음", 17, { Position = UDim2.fromOffset(18, 274), Size = UDim2.fromOffset(100, 34), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 })
local volumeButtons = {}
for i, level in { 0, 0.25, 0.5, 0.75, 1 } do
	local button = Ui.button(settingsPanel, tostring(level * 100), { Position = UDim2.fromOffset(18 + (i - 1) * 62, 314), Size = UDim2.fromOffset(56, 44),
		FontFace = Ui.NUM, TextSize = 16, ZIndex = 13 })
	volumeButtons[level] = button
	button.Activated:Connect(function()
		sendSettings({ Volume = level })
	end)
end
local function drawVolume()
	local volume = player:GetAttribute("Setting_Volume") or 1
	for level, button in volumeButtons do
		button.BackgroundColor3 = if math.abs(level - volume) < 0.01 then Ui.LEAF else Ui.PARCHMENT
	end
end
player:GetAttributeChangedSignal("Setting_Volume"):Connect(drawVolume)
drawVolume()
local function setSettings(open)
	if open then
		Ui.open(settingsPanel)
	else
		Ui.close(settingsPanel)
	end
	Juice.SetPanel("Settings", open)
end
gearButton.Activated:Connect(function()
	setSettings(not Ui.IsOpen(settingsPanel))
end)
settingsClose.Activated:Connect(function()
	setSettings(false)
end)

-- 상황별 보이기: 패널이 열리면 핫바·기둥을 숨긴다, 꾸미기 모드면 핫바 대신 트레이(DecorClient)
local function applyVisibility()
	local panels = Juice.State.Panels
	hotbar.Visible = panels == 0 and not player:GetAttribute("DecorMode")
	column.Visible = (panels == 0 or settingsPanel.Visible) and not pull.Visible
end
Juice.Bus.Panels.Event:Connect(applyVisibility)
player:GetAttributeChangedSignal("DecorMode"):Connect(applyVisibility)

-- 신호 -------------------------------------------------------------------------------------------
Remotes.Feedback.OnClientEvent:Connect(function(kind, info)
	info = info or {}
	if kind == "Toast" then
		showToast(info.Text)
		Juice.Sound("clickfast.wav", 1.3, 0.3)
	elseif kind == "DexNew" then
		queueBanner({ Kind = "DexNew", Title = if info.Complete then "도감 완성!" else "새 도감!", Sub = info.Text,
			IconKind = CATEGORY_KIND[info.Category] or "Book", IconId = info.Item, Reveal = info.Item ~= nil })
	elseif kind == "Expand" and info.Player == player then
		local chunks = player:GetAttribute("IslandChunks") or 16
		queueBanner({ Kind = "Expand", Small = info.Small, Title = info.Text, Sub = info.Sub,
			IconKind = "Chunk", IconId = info.Zone or "Farm",
			Progress = if info.Small then nil else math.clamp((chunks - 16) / 20, 0, 1), Before = math.clamp((chunks - 17) / 20, 0, 1) })
	elseif kind == "Banner" then -- 파티 의뢰 완료·대회 시작·끝(PartyPlayService)
		queueBanner({ Kind = "Banner", Title = info.Title, Sub = info.Sub, IconKind = info.IconKind or "Friends" })
		Juice.Sound("victory.wav", 1.3, 0.3)
	elseif kind == "Bite" and info.Player == player and touch then
		pullToken += 1
		local mine = pullToken
		local jumpCenter = column.AbsolutePosition + Vector2.new(column.AbsoluteSize.X / 2, column.AbsoluteSize.Y)
		pull.Position = UDim2.fromOffset(jumpCenter.X, jumpCenter.Y)
		pull.Visible = true
		column.Visible = false
		Juice.Punch(pull, 0.6, 0.18)
		pullBar.Size = UDim2.fromScale(1, 1)
		Juice.Tween(pullBar, info.Window or 1.2, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
		task.delay((info.Window or 1.2) + 0.4, function()
			if pullToken == mine then
				hidePull()
			end
		end)
	elseif (kind == "Catch" or kind == "Miss") and info.Player == player then
		hidePull()
	end
end)

-- 얻은 것 알림(핫바 위): 아이콘 + "철 +1" + 가진 수. 캔 광석·낚은 물고기·거둔 작물(도우미 동물·친구가 내 밭에서 거둔 것도).
-- 같은 것을 2.6초 안에 또 얻으면 한 줄에서 숫자만 오른다. 최대 3줄, 새 줄이 핫바에 가장 가깝다
local FEED_MAX, FEED_TIME = 3, 2.6
local feed = Ui.make("Frame", gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(SLOT.Y + (if touch then 26 else 36))),
	Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
Ui.make("UIListLayout", feed, { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder })
local feedRows, feedOrder = {}, 0 -- [아이템 Id] = { Frame, Label, Total, Count, Token }

local function dropRow(itemId)
	local row = feedRows[itemId]
	feedRows[itemId] = nil
	Ui.close(row.Frame)
	task.delay(0.15, row.Frame.Destroy, row.Frame)
end

local function gained(itemId, name, amount)
	feedOrder += 1
	local row = feedRows[itemId]
	if not row then
		local oldest, count = nil, 0
		for id, other in feedRows do
			count += 1
			if not oldest or other.Frame.LayoutOrder < feedRows[oldest].Frame.LayoutOrder then
				oldest = id
			end
		end
		if count >= FEED_MAX then
			dropRow(oldest)
		end
		local frame = Ui.pill(feed, { Size = UDim2.fromOffset(0, 42), AutomaticSize = Enum.AutomaticSize.X, Visible = false })
		Ui.make("UIListLayout", frame, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		Ui.make("UIPadding", frame, { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 16) })
		local kind, id = Icons.ForItem(itemId)
		Icons.View(kind, id, { Size = UDim2.fromOffset(36, 36), LayoutOrder = 1 }).Parent = frame
		row = { Frame = frame, Count = 0, Token = 0,
			Label = Ui.text(frame, "", 17, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36),
				TextWrapped = false, FontFace = Ui.FONT_HEAVY }),
			Total = Ui.text(frame, "", 14, { LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36),
				TextWrapped = false, TextColor3 = Ui.MUTED }) }
		feedRows[itemId] = row
		Ui.open(frame)
	end
	row.Frame.LayoutOrder = feedOrder
	row.Count += amount
	row.Label.Text = string.format("%s +%d", name, row.Count)
	task.delay(0.1, function() -- 보관함 속성이 신호보다 늦게 올 수 있다
		row.Total.Text = "가진 수 " .. (player:GetAttribute("Item_" .. itemId) or row.Count)
	end)
	Juice.Punch(row.Frame, 1.08, 0.15)
	row.Token += 1
	local token = row.Token
	task.delay(FEED_TIME, function()
		if feedRows[itemId] == row and row.Token == token then
			dropRow(itemId)
		end
	end)
end

Remotes.Feedback.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then
		return
	elseif kind == "MineBreak" and info.Player == player and Ores[info.Ore] then
		task.delay(0.3, gained, "Ore_" .. info.Ore, Ores[info.Ore].Name, 1) -- 곡괭이가 닿은 뒤
	elseif kind == "Catch" and info.Player == player and Fish[info.Item] then
		task.delay(0.3, gained, "Fish_" .. info.Item, Fish[info.Item].Name, 1)
	elseif kind == "Harvest" and info.Owner == player and Crops[info.Item] then
		task.delay(0.3, gained, info.Item, Crops[info.Item].Name, info.Count or 1)
	elseif (kind == "EventOpen" or kind == "Shake") and info.Player == player and type(info.Item) == "string" then
		local prefix, id = info.Item:match("^(%a+)_(.+)$")
		local name = if prefix == "Seed" and Crops[id] then Crops[id].Name .. " 씨앗" elseif prefix == "Ore" and Ores[id] then Ores[id].Name else info.Item
		task.delay(0.35, gained, info.Item, name, info.Count or 1)
	end
end)

-- 농지 누르기: 서버에 "눌렀다"와 고른 씨앗만 보낸다(Tap Acknowledge로 지연을 가린다)
local function useTile(tile)
	Juice.Squash(tile, Vector3.new(1, 0.92, 1), 0.05, 0.09)
	Juice.Sound("button.wav", 1.6, 0.12)
	Remotes.Interact:FireServer("Tile", tile, selectedSeed)
end
WorldPointer.OnTap(function(result)
	if player:GetAttribute("DecorMode") then
		return
	end
	local target = result.Instance
	if CollectionService:HasTag(target, "FarmTile") then -- 친구 밭도 보낸다(파티원 물주기, 안 되면 서버가 이유를 토스트)
		useTile(target)
	end
end)

-- 밭 안내: 캐릭터 앞 농지 하나에 지금 할 일을 띄운다(E · 게임패드 X · 모바일은 버튼). 내 밭은 밭 갈기 → 씨앗 뿌리기 → 물주기 →
-- 수확하기, 물 준 뒤 자라는 중이면 살펴보기(남은 시간 토스트). 친구 밭은 파티·연합이면 물주기, 주인이 허락하면 수확하기만.
-- 프롬프트는 클라이언트에만 있고(내 화면용), 누르면 농지를 누른 것과 같은 요청을 보낸다. 판정은 서버.
local PROMPT_RANGE = 9 -- 캐릭터에서 농지까지(수평, 스터드)
local promptTile
local showTilePrompt = WorldPointer.Prompt("TilePrompt", function()
	if promptTile and promptTile.Parent then
		useTile(promptTile)
	end
end)

local function sameGroup(owner) -- 파티원·연합 멤버(서버 PartyService.Same과 같은 판정)
	for _, key in { "PartyId", "UnionId" } do
		local id = player:GetAttribute(key)
		if id ~= nil and owner:GetAttribute(key) == id then
			return true
		end
	end
	return false
end

-- 그 농지에서 지금 할 일 → 글, 작물·씨앗 글. 할 일이 없으면 nil
local function tileAction(tile)
	local owner = Players:GetPlayerByUserId(tile:GetAttribute("Owner") or 0)
	local crop = Crops[tile:GetAttribute("Crop") or ""]
	local ripe = tile:GetAttribute("Stage") == 3
	if owner ~= player then
		if not owner or not crop or not sameGroup(owner) then
			return nil
		elseif ripe then
			return if owner:GetAttribute("Setting_HarvestParty") then "수확하기" else nil, crop.Name
		end
		return if tile:GetAttribute("Watered") then nil else "물주기", crop.Name
	elseif not tile:GetAttribute("Tilled") then
		return "밭 갈기", ""
	elseif not crop then
		local seed = selectedSeed and Crops[selectedSeed]
		local count = seed and player:GetAttribute("Item_Seed_" .. selectedSeed) or 0
		return "씨앗 뿌리기", if count > 0 then string.format("%s 씨앗 ×%d", seed.Name, count) else "씨앗 없음 · 모모에게서 사요"
	elseif ripe then
		return "수확하기", crop.Name
	elseif not tile:GetAttribute("Watered") then
		return "물주기", crop.Name
	end
	return "살펴보기", crop.Name .. " · 자라는 중"
end

local lastPromptCheck = 0
RunService.Heartbeat:Connect(function()
	if os.clock() - lastPromptCheck < 0.1 then
		return
	end
	lastPromptCheck = os.clock()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local best, bestScore, bestAction, bestObject
	if root and Juice.State.Panels == 0 and not player:GetAttribute("DecorMode") then
		local flat = Vector3.new(1, 0, 1)
		local front = root.Position + root.CFrame.LookVector * 3 -- 바라보는 쪽 칸이 먼저
		for _, tile in CollectionService:GetTagged("FarmTile") do
			if ((tile.Position - root.Position) * flat).Magnitude <= PROMPT_RANGE then
				local action, object = tileAction(tile)
				-- 살펴보기는 다른 할 일이 없을 때만
				local score = action and ((tile.Position - front) * flat).Magnitude + (if action == "살펴보기" then 100 else 0)
				if score and (not bestScore or score < bestScore) then
					best, bestScore, bestAction, bestObject = tile, score, action, object
				end
			end
		end
	end
	promptTile = best
	showTilePrompt(best and best.Position + Vector3.new(0, 1, 0), bestAction, bestObject)
end)

-- 구역이 바뀌면 칩과 핫바
local lastZoneCheck = 0
RunService.Heartbeat:Connect(function()
	if os.clock() - lastZoneCheck < 0.3 then
		return
	end
	lastZoneCheck = os.clock()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local zone = root and zoneAtPosition(root.Position)
	if zone ~= currentZone then
		currentZone = zone
		rebuildHotbar(true)
		if zone then
			zoneShown += 1
			local mine = zoneShown
			zoneText.Text = (ZONE_NAMES[zone] or zone) .. (if ZONE_HINTS[zone] then "  ·  " .. ZONE_HINTS[zone] else "")
			Ui.open(zoneChip)
			Juice.Punch(zoneChip, 0.8, 0.16)
			task.delay(ZONE_CHIP_TIME, function()
				if zoneShown == mine then
					Ui.close(zoneChip)
				end
			end)
		end
	end
	placeColumn()
end)

player.AttributeChanged:Connect(function(name)
	if name == "Coins" then
		onCoins()
	elseif name == "Cozy" or name == "CozyGrade" then
		onCozy()
	elseif name == "DexVersion" then
		onDex()
	elseif name:sub(1, 5) == "Item_" then
		pickSeed()
		rebuildHotbar()
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
onCoins()
onCozy()
pickSeed()
rebuildHotbar(true)
task.spawn(onDex)
applyVisibility()
