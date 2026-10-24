-- NPC 대화창과 상점 창. 서버가 보낸 문장·선택지를 보여 주고 고른 번호만 돌려보낸다.
-- 상점은 상품을 누를 때마다 서버에 사기를 요청하고 결과 문구를 보여 준다. NPC에게서 멀어지면 닫힌다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local Juice = require(script.Parent:WaitForChild("Juice"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local player = Players.LocalPlayer
local CREAM = Ui.CREAM
local INK = Ui.INK
local LEAF = Ui.LEAF_DEEP
local VOICE = { ["정원사 모모"] = 1.7, ["목수 버니"] = 1.35, ["안내인 루미"] = 1.55 } -- 말소리(clickfast) 음높이
local PAUSE = { ["!"] = 0.16, ["?"] = 0.16, ["."] = 0.16, ["…"] = 0.26, [","] = 0.08 }
local CLOSE_RANGE = 16
local TYPE_SPEED = 40 -- 초당 글자 수
local PANEL_POSITION = UDim2.new(0.5, 0, 1, -110)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

local function make(className, parent, props)
	local object = Instance.new(className)
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function textProps(text, size)
	return { BackgroundTransparency = 1, Text = text, TextSize = math.max(size, 14), TextColor3 = INK, FontFace = Ui.FONT, TextWrapped = true }
end

local gui = make("ScreenGui", nil, { Name = "Dialogue", ResetOnSpawn = false, DisplayOrder = 5 })


-- 대화창: Cream 패널 + Cocoa 테두리, 이름표는 Leaf Deep. 열릴 때 아래에서 24px 떠오르며 나타난다(Ui.open)
local panel = make("Frame", gui, {
	Name = "Panel", AnchorPoint = Vector2.new(0.5, 1), Position = PANEL_POSITION,
	Size = UDim2.new(0.92, 0, 0, 136), BackgroundColor3 = CREAM, Visible = false,
})
corner(panel, 22)
make("UISizeConstraint", panel, { MaxSize = Vector2.new(640, 136) })
Ui.stroke(panel, 3)
local speaker = make("TextLabel", panel, textProps("", 17))
speaker.Position = UDim2.fromOffset(16, -16)
speaker.Size = UDim2.fromOffset(160, 32)
speaker.BackgroundTransparency = 0
speaker.BackgroundColor3 = LEAF
speaker.TextColor3 = Color3.new(1, 1, 1)
corner(speaker, 16)
Ui.stroke(speaker, 2.5, Ui.LEAF_INK)
make("UIStroke", speaker, { Thickness = 2, Color = Ui.LEAF_INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
local body = make("TextLabel", panel, textProps("", 18))
body.Name = "Body"
body.Position = UDim2.fromOffset(18, 26)
body.Size = UDim2.new(1, -36, 1, -36)
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
local closeButton = Ui.button(panel, "×", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(40, 40), TextSize = 22 })

local choices = make("Frame", panel, {
	Name = "Choices", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, -12),
	Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
})
local choiceGrid = make("UIGridLayout", choices, { CellPadding = UDim2.fromOffset(6, 6), CellSize = UDim2.fromOffset(250, 42),
	SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right })
local HUD_TOP = 130 -- 위쪽 HUD 알약 아래 끝(px). 선택지가 여기까지 올라가면 두 줄로 놓는다

-- 상점 창: 상품마다 3D 아이콘 칸 + 이름·설명 + 값 버튼(주 버튼)
local shop = make("Frame", gui, {
	Name = "Shop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(380, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CREAM, Visible = false,
})
corner(shop, 22)
Ui.stroke(shop, 3)
make("UIPadding", shop, { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
make("UIListLayout", shop, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
local shopTitle = make("TextLabel", shop, textProps("", 20))
shopTitle.FontFace = Ui.FONT_HEAVY
shopTitle.Size = UDim2.new(1, 0, 0, 28)
shopTitle.LayoutOrder = 0
local shopStatus = make("TextLabel", shop, textProps("", 15))
shopStatus.Size = UDim2.new(1, 0, 0, 22)
shopStatus.LayoutOrder = 1000
local shopClose = Ui.button(shop, "닫기", { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1001 })

local talkingTo, shopNpc -- 멀어지면 닫으려고 기억한다

local function closeShop()
	if shop.Visible then
		Ui.close(shop)
	end
	shopNpc = nil
	Juice.SetPanel("Shop", false)
end

-- 구매 실패: 코인 알약 테두리 Coral + 좌우 흔들림
local function refuseCoins()
	Juice.Sound("collide.wav", 0.8, 0.35)
	local coins = Juice.Targets.Coins
	local stroke = coins and coins:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Ui.CORAL
		task.delay(0.3, function()
			stroke.Color = Ui.COCOA
		end)
	end
	if coins and not Juice.Reduced() then
		task.spawn(function()
			for k = 1, 4 do
				coins.Rotation = if k % 2 == 0 then -4 else 4
				task.wait(0.07)
			end
			coins.Rotation = 0
		end)
	end
end

local function openShop(message)
	for _, child in shop:GetChildren() do
		if child:GetAttribute("Item") then
			child:Destroy()
		end
	end
	shopTitle.Text = message.Title .. "의 상점"
	shopStatus.Text = "코인 " .. (player:GetAttribute("Coins") or 0)
	for i, item in message.Items do
		local row = make("Frame", shop, { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Ui.PARCHMENT, LayoutOrder = i })
		corner(row, 14)
		Ui.stroke(row, 2)
		row:SetAttribute("Item", item.Id)
		local kind, id = Icons.ForItem(item.Id)
		local icon = Icons.View(kind, id, { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(4, 4) })
		icon.Parent = row
		local name = make("TextLabel", row, textProps(item.Name, 17))
		name.Position = UDim2.fromOffset(64, 6)
		name.Size = UDim2.new(1, -164, 0, 24)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local desc = make("TextLabel", row, textProps(item.Desc or "", 14))
		desc.Position = UDim2.fromOffset(64, 30)
		desc.Size = UDim2.new(1, -164, 0, 28)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextColor3 = Ui.MUTED
		local buy = Ui.button(row, item.Price .. "코인", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(88, 44), TextSize = 17 }, true)
		buy.Activated:Connect(function()
			local ok, text = Remotes.Shop:InvokeServer(message.Shop, item.Id)
			shopStatus.Text = text .. " · 코인 " .. (player:GetAttribute("Coins") or 0)
			if not ok then
				return refuseCoins()
			end
			-- 구매: 상품 아이콘 펀치, 산 것이 핫바(씨앗)나 꾸미기 버튼(가구)으로 날아간다
			Juice.Punch(icon, 1.3, 0.2)
			Juice.Sound("switch.wav", 1.2, 0.3)
			Juice.Sound("electronicpingshort.wav", 1.3, 0.25)
			Juice.Combo()
			if item.Id:find("^Pet_") then
				return -- 도우미 동물은 날아가지 않고 섬에 나타난다(PetService)
			end
			local target = Juice.Targets.Item and Juice.Targets.Item(item.Id) or Juice.Targets.Decor
			local center = icon.AbsolutePosition + icon.AbsoluteSize / 2 + Vector2.new(0, 36)
			local ray = workspace.CurrentCamera:ViewportPointToRay(center.X, center.Y)
			Juice.Fly(ray.Origin + ray.Direction * 8, kind, id, target, function()
				Juice.Sound("Kerplunk.wav", 1.5, 0.2)
			end)
		end)
	end
	shopNpc = message.Npc
	Ui.open(shop)
	Juice.SetPanel("Shop", true)
end

-- 대사를 한 글자씩 보인다(문장 부호 뒤에서 잠깐 멈추고, 세 글자마다 NPC 목소리). 새 대사가 오거나 대화창을 누르면 끝낸다
local typing = 0
local function typeOut(text, voice)
	typing += 1
	local token = typing
	body.MaxVisibleGraphemes = 0
	task.spawn(function()
		local shown = 0
		for _, code in utf8.codes(text) do
			shown += 1
			local char = utf8.char(code)
			task.wait(1 / TYPE_SPEED + (PAUSE[char] or 0))
			if typing ~= token then
				return
			end
			body.MaxVisibleGraphemes = shown
			if voice and shown % 3 == 1 and char ~= " " then
				Juice.Sound("clickfast.wav", voice, 0.12)
			end
		end
		body.MaxVisibleGraphemes = -1
	end)
end

panel.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		typing += 1
		body.MaxVisibleGraphemes = -1
	end
end)

local function showLine(message)
	for _, child in choices:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	speaker.Text = message.Speaker
	body.Text = message.Text
	typeOut(message.Text, VOICE[message.Speaker] or 1.5)
	if not Ui.IsOpen(panel) then -- 아래에서 떠오른다(닫히는 중이면 되돌린다)
		panel.Position = PANEL_POSITION + UDim2.fromOffset(0, 24)
		TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quint), { Position = PANEL_POSITION }):Play()
		Ui.open(panel)
	elseif message.Text:find("!") and not Juice.Reduced() then -- 느낌표 대사에서 창이 움찔
		panel.Position = PANEL_POSITION + UDim2.fromOffset(0, -6)
		TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Position = PANEL_POSITION }):Play()
	end
	Juice.Punch(speaker, 1.15, 0.12)
	local room = gui.AbsoluteSize.Y - 110 - 136 - 12 - HUD_TOP -- 대화창 위 ~ HUD 알약 아래
	local wide = #message.Choices * 48 > room
	choices.Size = UDim2.fromOffset(if wide then 412 else 250, 0)
	choiceGrid.CellSize = UDim2.fromOffset(if wide then 203 else 250, 42)
	for i, text in message.Choices do
		local button = Ui.button(choices, text, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 42), TextSize = 16, BackgroundColor3 = CREAM })
		button:FindFirstChildOfClass("UIStroke").Color = Ui.LEAF
		local scale = Ui.scale(button)
		scale.Scale = 0.8
		task.delay(0.05 * i, function()
			TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
		button.Activated:Connect(function()
			Remotes.Dialogue:FireServer(i)
		end)
	end
	talkingTo = message.Npc
	Juice.SetPanel("Dialogue", true)
end

local function hidePanel()
	Ui.close(panel)
	talkingTo = nil
	Juice.SetPanel("Dialogue", false)
end

Remotes.Dialogue.OnClientEvent:Connect(function(message)
	if message.Close then
		hidePanel()
	elseif message.Shop then
		openShop(message)
	else
		showLine(message)
	end
end)

closeButton.Activated:Connect(function()
	hidePanel() -- 서버 답을 기다리지 않고 바로 닫는다
	Remotes.Dialogue:FireServer(0)
end)
shopClose.Activated:Connect(closeShop)

-- NPC에게서 멀어지면 닫는다
local function far(model)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return not root or not model or not model.Parent or (root.Position - model:GetPivot().Position).Magnitude > CLOSE_RANGE
end
RunService.Heartbeat:Connect(function()
	if Ui.IsOpen(panel) and far(talkingTo) then
		Remotes.Dialogue:FireServer(0)
		hidePanel()
	end
	if Ui.IsOpen(shop) and far(shopNpc) then
		closeShop()
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
