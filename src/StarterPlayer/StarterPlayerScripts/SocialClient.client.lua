-- 친구 창: HUD 오른쪽 기둥 "친구" → 서버의 다른 플레이어 줄(얼굴·이름·섬 컨셉·청크·파티 표시, "놀러 가기"·"초대")과
-- 아래쪽 내 파티(인원/6, 나가기)·"우리 섬으로". 초대 카드(수락·거절, 시간 막대)와 남의 섬에 있을 때 위쪽 "○○의 섬 · 집으로" 알약.
-- 섬 연합: 파티원 줄 "섬 잇기"(같은 연합이면 "연합" 표시), 같은 초대 카드로 섬 잇기 요청, 아래쪽 "연합 끊기".
-- 파티 놀이: 왼쪽 위 파티 카드(의뢰 막대, 대회 타이머·점수)와 친구 창 맨 위 "파티 놀이" 줄(파티장은 대회 열기).
-- 판정은 전부 서버(PartyService·UnionService·PartyPlayService). 명세: design/gdd/party-visiting.md, island-union.md, party-play.md
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IslandConcepts = require(Shared:WaitForChild("IslandConcepts"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local Juice = require(script.Parent:WaitForChild("Juice"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local player = Players.LocalPlayer
local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local MAX = 6 -- PartyService.MAX와 같게
local WATCHED = { "PartyId", "PartyLeader", "IslandConcept", "IslandChunks", "Visiting", "UnionId", "PartyQuest", "PartyContest" }
local CONTESTS = { { "Fish", "낚시 대회" }, { "Harvest", "수확 대회" }, { "Ore", "채굴 대회" } } -- PartyPlayService.CONTESTS와 같게

local gui = Ui.make("ScreenGui", nil, { Name = "Social", ResetOnSpawn = false, DisplayOrder = 6 })

local function sameParty(other)
	local id = player:GetAttribute("PartyId")
	return id ~= nil and other:GetAttribute("PartyId") == id
end

local function sameUnion(other)
	local id = player:GetAttribute("UnionId")
	return id ~= nil and other:GetAttribute("UnionId") == id
end

local function islandLine(other)
	local concept = IslandConcepts[other:GetAttribute("IslandConcept") or ""]
	return string.format("%s · %d청크", if concept then concept.Name else "섬 준비 중", other:GetAttribute("IslandChunks") or 16)
end

local function headshot(parent, userId, size)
	local image = Ui.make("ImageLabel", parent, { Size = UDim2.fromOffset(size, size), BackgroundColor3 = Ui.PARCHMENT_DEEP,
		ZIndex = parent.ZIndex + 1 }) -- 초대 카드(ZIndex 20) 위에 보이게
	Ui.corner(image, "pill")
	Ui.stroke(image, 2.5)
	task.spawn(function()
		local ok, url = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
		if ok then
			image.Image = url
		end
	end)
	return image
end

-- 친구 창 ---------------------------------------------------------------------------------------
local dim = Ui.make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.65,
	Visible = false, BorderSizePixel = 0 })
local panel = Ui.panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.94, 0.84),
	Visible = false })
Ui.make("UISizeConstraint", panel, { MaxSize = Vector2.new(540, 520) })
Icons.View("Friends", nil, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(14, 6) }).Parent = panel
Ui.text(panel, "친구 섬", 22, { FontFace = Ui.FONT_HEAVY, Position = UDim2.fromOffset(60, 10), Size = UDim2.new(1, -130, 0, 32),
	TextXAlignment = Enum.TextXAlignment.Left })
local closeButton = Ui.button(panel, "×", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(44, 44), TextSize = 24 })

local list = Ui.make("ScrollingFrame", panel, { Position = UDim2.fromOffset(12, 58), Size = UDim2.new(1, -24, 1, -134), BackgroundTransparency = 1,
	ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y })
Ui.make("UIListLayout", list, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
Ui.make("UIPadding", list, { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8) })

local footer = Ui.make("Frame", panel, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.new(1, -24, 0, 56),
	BackgroundColor3 = Ui.PARCHMENT })
Ui.corner(footer, 14)
Ui.stroke(footer, 2.5)
local partyText = Ui.text(footer, "", 16, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -250, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
local footerButtons = Ui.make("Frame", footer, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(1, -16, 0, 42),
	BackgroundTransparency = 1 })
Ui.make("UIListLayout", footerButtons, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
local homeButton = Ui.button(footerButtons, "우리 섬으로", { LayoutOrder = 1, Size = UDim2.fromOffset(104, 42), TextSize = 15 }, true)
local unionButton = Ui.button(footerButtons, "연합 끊기", { LayoutOrder = 2, Size = UDim2.fromOffset(96, 42), TextSize = 15 })
local leaveButton = Ui.button(footerButtons, "파티 나가기", { LayoutOrder = 3, Size = UDim2.fromOffset(104, 42), TextSize = 15 })

local function clearList()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function row(order, other)
	local frame = Ui.make("Frame", list, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 76), BackgroundColor3 = Ui.PARCHMENT })
	Ui.corner(frame, 14)
	Ui.stroke(frame, 2.5)
	headshot(frame, other.UserId, 56).Position = UDim2.fromOffset(10, 10)
	local name = other.DisplayName .. (if other:GetAttribute("PartyLeader") and other:GetAttribute("PartyId") then "  · 파티장" else "")
	Ui.text(frame, name, 17, { FontFace = Ui.FONT_HEAVY, Position = UDim2.fromOffset(76, 10), Size = UDim2.new(1, -300, 0, 26), TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left })
	local islandIcon = Icons.View("Island", other:GetAttribute("IslandConcept"), { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(74, 40) })
	islandIcon.Parent = frame
	Ui.text(frame, islandLine(other), 14, { Position = UDim2.fromOffset(100, 40), Size = UDim2.new(1, -324, 0, 24), TextColor3 = Ui.MUTED,
		TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left })

	local visit = Ui.button(frame, "놀러 가기", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(104, 46),
		TextSize = 15 }, true)
	visit.Activated:Connect(function()
		Remotes.Interact:FireServer("Visit", other)
		Juice.Sound("button.wav", 1.2, 0.3)
	end)
	if sameUnion(other) then
		local chip = Ui.pill(frame, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -124, 0.5, 0), Size = UDim2.fromOffset(84, 34),
			BackgroundColor3 = Ui.SKY })
		Ui.text(chip, "연합", 15)
	elseif sameParty(other) then
		local unite = Ui.button(frame, "섬 잇기", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -124, 0.5, 0), Size = UDim2.fromOffset(84, 46),
			TextSize = 15, BackgroundColor3 = Ui.MINT })
		unite.Activated:Connect(function()
			Remotes.Interact:FireServer("Unite", other)
			Juice.Sound("button.wav", 1.4, 0.3)
		end)
	else
		local invite = Ui.button(frame, "초대", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -124, 0.5, 0), Size = UDim2.fromOffset(84, 46),
			TextSize = 15 })
		invite.Activated:Connect(function()
			Remotes.Interact:FireServer("Invite", other)
			Juice.Sound("button.wav", 1.4, 0.3)
		end)
	end
end

-- 서버가 단 JSON 속성(PartyQuest·PartyContest)
local function decode(key)
	local raw = player:GetAttribute(key)
	local ok, value = pcall(HttpService.JSONDecode, HttpService, raw or "")
	return if raw and ok then value else nil
end

-- "파티 놀이" 줄: 지금 의뢰, 파티장은 대회 버튼 셋
local function playRow()
	local frame = Ui.make("Frame", list, { Name = "PartyPlay", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = Ui.BANNER })
	Ui.corner(frame, 14)
	Ui.stroke(frame, 2.5)
	local quest, contest = decode("PartyQuest"), decode("PartyContest")
	Ui.text(frame, "파티 놀이", 17, { FontFace = Ui.FONT_HEAVY, Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(90, 26),
		TextXAlignment = Enum.TextXAlignment.Left })
	Ui.text(frame, if quest then string.format("의뢰: %s %d / %d", quest.Label, math.min(quest.Have, quest.Need), quest.Need) else "의뢰 준비 중", 15,
		{ Position = UDim2.fromOffset(108, 8), Size = UDim2.new(1, -120, 0, 26), TextColor3 = Ui.MUTED, TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left })
	local buttons = Ui.make("Frame", frame, { Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 46), BackgroundTransparency = 1 })
	Ui.make("UIListLayout", buttons, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	if contest then
		Ui.text(buttons, contest.Label .. " 중 · 왼쪽 카드에서 점수를 봐요", 15, { TextColor3 = Ui.MUTED })
	elseif player:GetAttribute("PartyLeader") then
		for i, entry in CONTESTS do
			local button = Ui.button(buttons, entry[2], { Name = "Contest" .. entry[1], LayoutOrder = i, Size = UDim2.new(1 / 3, -6, 1, 0), TextSize = 15 },
				i == 1)
			button.Activated:Connect(function()
				Remotes.Interact:FireServer("Contest", nil, entry[1])
				Juice.Sound("button.wav", 1.2, 0.3)
			end)
		end
	else
		Ui.text(buttons, "파티장이 대회(낚시·수확·채굴)를 열 수 있어요", 15, { TextColor3 = Ui.MUTED })
	end
end

local function render()
	clearList()
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(others, other)
		end
	end
	-- 파티원 먼저, 그다음 이름 순
	table.sort(others, function(a, b)
		if sameParty(a) ~= sameParty(b) then
			return sameParty(a)
		end
		return a.DisplayName < b.DisplayName
	end)
	for i, other in others do
		row(i, other)
	end
	if #others == 0 then
		Ui.text(list, "아직 이 서버에 다른 섬 주인이 없어요.\n친구가 들어오면 여기에서 놀러 갈 수 있어요.", 16, { Size = UDim2.new(1, 0, 0, 80),
			TextColor3 = Ui.MUTED })
	end

	local members = 0
	for _, other in Players:GetPlayers() do
		if sameParty(other) then
			members += 1
		end
	end
	local islands = 0
	for _, other in Players:GetPlayers() do
		if sameUnion(other) then
			islands += 1
		end
	end
	if members > 0 then
		playRow()
	end
	partyText.Text = (if members > 0 then string.format("파티 %d / %d명", members, MAX) else "파티 없음 · 친구를 초대해 보세요")
		.. (if islands > 0 then string.format("\n연합 %d섬", islands) else "")
	leaveButton.Visible = members > 0
	homeButton.Visible = player:GetAttribute("Visiting") ~= nil
	unionButton.Visible = islands > 0
	local shown = (if homeButton.Visible then 112 else 0) + (if unionButton.Visible then 104 else 0) + (if leaveButton.Visible then 112 else 0)
	partyText.Size = UDim2.new(1, -(shown + 24), 1, 0)
end

local function setOpen(open)
	if open then
		Ui.open(dim, true)
		Ui.open(panel)
		render()
	else
		Ui.close(dim, true)
		Ui.close(panel)
	end
	Juice.SetPanel("Friends", open)
end

closeButton.Activated:Connect(function()
	setOpen(false)
end)
leaveButton.Activated:Connect(function()
	Remotes.Interact:FireServer("LeaveParty")
end)
unionButton.Activated:Connect(function()
	Remotes.Interact:FireServer("LeaveUnion")
end)
homeButton.Activated:Connect(function()
	Remotes.Interact:FireServer("Home")
	setOpen(false)
end)

local function watch(other)
	for _, key in WATCHED do
		other:GetAttributeChangedSignal(key):Connect(function()
			if panel.Visible then
				render()
			end
		end)
	end
end
for _, other in Players:GetPlayers() do
	watch(other)
end
Players.PlayerAdded:Connect(function(other)
	watch(other)
	if panel.Visible then
		render()
	end
end)
Players.PlayerRemoving:Connect(function()
	if panel.Visible then
		task.defer(render)
	end
end)

-- 기둥 버튼(Hud가 Juice.Targets.Column을 내놓으면 2번 자리에)
task.spawn(function()
	while not Juice.Targets.Column do
		task.wait(0.1)
	end
	local size = if touch then 64 else 76
	local button = Ui.button(Juice.Targets.Column, "", { Name = "Friends", LayoutOrder = 2, Size = UDim2.fromOffset(size, size + 6) })
	local icon = Icons.View("Friends", nil, { Size = UDim2.fromOffset(size - 18, size - 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3) })
	icon.Parent = button
	Ui.text(button, "친구", 14, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0, 18) })
	button.Activated:Connect(function()
		setOpen(not Ui.IsOpen(panel))
	end)
end)

-- 초대 카드 -------------------------------------------------------------------------------------
local card = Ui.panel(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 170), Size = UDim2.fromOffset(380, 118),
	Visible = false, ZIndex = 20 })
local cardFace = Ui.make("Frame", card, { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(52, 52), ZIndex = 21 })
local cardText = Ui.text(card, "", 17, { Position = UDim2.fromOffset(74, 10), Size = UDim2.new(1, -86, 0, 56), TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 21 })
local accept = Ui.button(card, "수락", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -14), Size = UDim2.fromOffset(110, 40),
	ZIndex = 21 }, true)
local decline = Ui.button(card, "거절", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -132, 1, -14), Size = UDim2.fromOffset(90, 40),
	ZIndex = 21 })
local timerBack = Ui.make("Frame", card, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -6), Size = UDim2.new(1, -32, 0, 4),
	BackgroundColor3 = Ui.PARCHMENT_DEEP, BorderSizePixel = 0, ZIndex = 21 })
local timerBar = Ui.make("Frame", timerBack, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.LEAF, BorderSizePixel = 0, ZIndex = 22 })
local inviter, inviteKind, cardToken = nil, nil, 0

local function hideCard()
	cardToken += 1
	inviter = nil
	Ui.close(card)
end

local function answer(yes)
	if inviter then
		Remotes.Interact:FireServer(if inviteKind == "Unite" then "UniteAnswer" else "Answer", inviter, yes)
	end
	hideCard()
end
accept.Activated:Connect(function()
	answer(true)
end)
decline.Activated:Connect(function()
	answer(false)
end)

Remotes.Feedback.OnClientEvent:Connect(function(kind, info)
	if (kind ~= "Invite" and kind ~= "Unite") or not info or not info.From then
		return
	end
	cardToken += 1
	local mine = cardToken
	inviter, inviteKind = info.From, kind
	for _, child in cardFace:GetChildren() do
		child:Destroy()
	end
	headshot(cardFace, inviter.UserId, 52)
	cardText.Text = if kind == "Unite" then inviter.DisplayName .. "님이 섬을 잇자고 해요!\n내 섬이 옆으로 날아가 다리가 놓여요"
		else inviter.DisplayName .. "님이 파티에 초대했어요!\n같이 섬을 가꿔요"
	Ui.open(card)
	Juice.Punch(card, 1.08, 0.2)
	Juice.Sound("electronicpingshort.wav", 1.2, 0.4)
	timerBar.Size = UDim2.fromScale(1, 1)
	Juice.Tween(timerBar, info.Ttl or 30, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
	task.delay(info.Ttl or 30, function()
		if cardToken == mine then
			hideCard()
		end
	end)
end)

-- 방문 알약: 남의 섬에 있을 때 "○○의 섬 · 집으로" -------------------------------------------------------
local visitPill = Ui.pill(gui, { Position = UDim2.fromOffset(16, if touch then 64 else 72), Size = UDim2.fromOffset(0, 48),
	AutomaticSize = Enum.AutomaticSize.X, Visible = false })
Ui.make("UIListLayout", visitPill, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
Ui.make("UIPadding", visitPill, { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6) })
local visitIconHolder = Ui.make("Frame", visitPill, { LayoutOrder = 1, Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1 })
local visitText = Ui.text(visitPill, "", 16, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), TextWrapped = false })
local visitHome = Ui.button(visitPill, "집으로", { LayoutOrder = 3, Size = UDim2.fromOffset(84, 38), TextSize = 15 }, true)
visitHome.Activated:Connect(function()
	Remotes.Interact:FireServer("Home")
end)

local function onVisiting()
	local owner = Players:GetPlayerByUserId(player:GetAttribute("Visiting") or 0)
	visitPill.Visible = owner ~= nil
	if owner then
		for _, child in visitIconHolder:GetChildren() do
			child:Destroy()
		end
		Icons.View("Island", owner:GetAttribute("IslandConcept"), { Size = UDim2.fromScale(1, 1), Spin = 30 }).Parent = visitIconHolder
		visitText.Text = owner.DisplayName .. "의 섬"
		Juice.Punch(visitPill, 1.1, 0.18)
	end
	if panel.Visible then
		render()
	end
end
player:GetAttributeChangedSignal("Visiting"):Connect(onVisiting)
onVisiting()

-- 파티 카드(왼쪽 위, 파티일 때만): 의뢰 막대, 대회 중이면 남은 시간과 위 3명(나는 굵게, 4등 아래면 내 줄을 덧붙인다) -------
local partyCard = Ui.panel(gui, { Name = "PartyCard", Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false })
Ui.corner(partyCard, 16)
Ui.make("UIListLayout", partyCard, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
Ui.make("UIPadding", partyCard, { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
local questTitle = Ui.text(partyCard, "", 14, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), TextColor3 = Ui.MUTED, TextXAlignment = Enum.TextXAlignment.Left })
local questText = Ui.text(partyCard, "", 17, { FontFace = Ui.FONT_HEAVY, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 22), TextWrapped = false,
	TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left })
local questBack = Ui.make("Frame", partyCard, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = Ui.PARCHMENT_DEEP })
Ui.corner(questBack, "pill")
local questFill = Ui.make("Frame", questBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Ui.LEAF_DEEP })
Ui.corner(questFill, "pill")
local contestText = Ui.text(partyCard, "", 17, { FontFace = Ui.FONT_HEAVY, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 26), TextColor3 = Ui.GOLD_DEEP,
	TextXAlignment = Enum.TextXAlignment.Left, Visible = false })
local scoreText = Ui.text(partyCard, "", 15, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left, Visible = false })
local lastHave, lastKind

local function scoreLines(contest)
	local rows = {}
	for key, score in contest.Scores do
		local other = Players:GetPlayerByUserId(tonumber(key) or 0)
		if other then
			table.insert(rows, { Name = if other == player then "나" else other.DisplayName, Score = score, Me = other == player })
		end
	end
	table.sort(rows, function(a, b)
		return a.Score > b.Score
	end)
	local lines = {}
	for i, row in rows do
		if i <= 3 or row.Me then
			local line = string.format("%d. %s  %d%s", i, row.Name, row.Score, contest.Unit)
			table.insert(lines, if row.Me then "<b>" .. line .. "</b>" else line)
		end
	end
	return if #lines > 0 then table.concat(lines, "\n") else "아직 기록이 없어요"
end

local function renderCard()
	local quest, contest = decode("PartyQuest"), decode("PartyContest")
	partyCard.Visible = quest ~= nil or contest ~= nil
	partyCard.Position = UDim2.fromOffset(16, (if touch then 64 else 72) + (if visitPill.Visible then 56 else 0))
	local t = workspace:GetServerTimeNow()
	if quest then
		local resting = quest.RestUntil ~= nil
		questTitle.Text = if resting then "파티 의뢰 완료!" else string.format("파티 의뢰 · %d / %d", math.min(quest.Have, quest.Need), quest.Need)
		questText.Text = if resting then string.format("다음 의뢰 %d초", math.max(0, math.ceil(quest.RestUntil - t))) else quest.Label
		questFill.Size = UDim2.fromScale(if resting then 1 else math.clamp(quest.Have / math.max(quest.Need, 1), 0, 1), 1)
		if quest.Kind == lastKind and lastHave and quest.Have > lastHave then
			Juice.Punch(partyCard, 1.05, 0.15)
		end
		lastHave, lastKind = quest.Have, quest.Kind
	end
	contestText.Visible, scoreText.Visible = contest ~= nil, contest ~= nil
	if contest then
		local left = math.max(0, math.floor(contest.Ends - t))
		contestText.Text = if t < contest.Starts then string.format("%s · 곧 시작 %d", contest.Label, math.ceil(contest.Starts - t))
			else string.format("%s %d:%02d", contest.Label, left // 60, left % 60)
		scoreText.Text = scoreLines(contest)
	end
end
for _, key in { "PartyQuest", "PartyContest", "Visiting" } do
	player:GetAttributeChangedSignal(key):Connect(renderCard)
end
task.spawn(function()
	while true do
		task.wait(0.5)
		if partyCard.Visible then
			renderCard() -- 남은 시간
		end
	end
end)
renderCard()

gui.Parent = player:WaitForChild("PlayerGui")
