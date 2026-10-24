-- 친구 창: HUD 오른쪽 기둥 "친구" → 서버의 다른 플레이어 줄(얼굴·이름·섬 컨셉·청크·파티 표시, "놀러 가기"·"초대")과
-- 아래쪽 내 파티(인원/6, 나가기)·"우리 섬으로". 초대 카드(수락·거절, 시간 막대)와 남의 섬에 있을 때 위쪽 "○○의 섬 · 집으로" 알약.
-- 섬 연합: 파티원 줄 "섬 잇기"(같은 연합이면 "연합" 표시), 같은 초대 카드로 섬 잇기 요청, 아래쪽 "연합 끊기".
-- 판정은 전부 서버(PartyService·UnionService). 명세: design/gdd/party-visiting.md, island-union.md
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
local WATCHED = { "PartyId", "PartyLeader", "IslandConcept", "IslandChunks", "Visiting", "UnionId" }

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

gui.Parent = player:WaitForChild("PlayerGui")
