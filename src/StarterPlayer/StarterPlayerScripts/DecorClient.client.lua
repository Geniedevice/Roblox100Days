-- 꾸미기(하우스키핑): HUD 기둥의 "꾸미기"(또는 H)로 모드를 켜면 핫바 자리에 보관함 트레이(3D 아이콘)가 뜨고, 고른 가구의 반투명 미리보기가 포인터를
-- 따라 1스터드 격자에 붙는다. R(또는 회전 버튼)로 90° 돌리고 누르면 놓는다. 아무것도 안 고르고 놓인 가구를 누르면
-- 거둔다. 모드가 꺼져 있을 때는 잡초·낙엽·돌멩이를 누르면 치운다. 가구는 집터 구역에만 놓인다. 아늑함은 HUD 알약.
-- 놓을 수 있는지는 서버가 정한다(안 되면 토스트로 이유가 온다). 명세: design/gdd/housekeeping.md
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Furniture = require(Shared:WaitForChild("Furniture"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local WorldPointer = require(script.Parent:WaitForChild("WorldPointer"))

local player = Players.LocalPlayer
local selected, rotation, ghost = nil, 0, nil

local Icons = require(script.Parent:WaitForChild("Icons"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local gui = Ui.make("ScreenGui", nil, { Name = "Decor", ResetOnSpawn = false, DisplayOrder = 4 })

-- 트레이: 핫바 자리(아래 가운데), 가로 스크롤 칸 72×80
local panel = Ui.panel(gui, {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(0.62, 0, 0, 132), Visible = false,
})
Ui.make("UISizeConstraint", panel, { MaxSize = Vector2.new(680, 132) })
Ui.text(panel, "가구를 고르고 집터에 놓을 곳을 누르세요 · R 회전 · 놓인 가구를 누르면 보관함으로", 14, {
	Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 20), TextColor3 = Ui.MUTED, TextXAlignment = Enum.TextXAlignment.Left,
})
local list = Ui.make("ScrollingFrame", panel, {
	Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -158, 0, 92), BackgroundTransparency = 1, ScrollBarThickness = 4,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X,
})
Ui.make("UIListLayout", list, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center })
Ui.make("UIPadding", list, { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })
local empty = Ui.text(list, "보관함이 비었어요. 목수 버니에게 가구를 사 보세요.", 15, { Size = UDim2.fromOffset(380, 80), Visible = false })
local rotateButton = Ui.button(panel, "회전", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -80, 0, 36), Size = UDim2.fromOffset(64, 80) })
local doneButton = Ui.button(panel, "끝내기", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 36), Size = UDim2.fromOffset(64, 80),
	TextSize = 18 }, true)

local function snap(position)
	return Vector3.new(math.round(position.X), position.Y, math.round(position.Z))
end

local function choose(id)
	selected = id
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if id then
		ghost = Furniture.Build(id)
		for _, part in ghost:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency, part.CanCollide, part.CanQuery, part.CastShadow = 0.5, false, false, false
			end
		end
		ghost.Parent = workspace
	end
	for _, button in list:GetChildren() do
		if button:IsA("TextButton") then
			button.BackgroundColor3 = if button.Name == id then Color3.fromRGB(215, 240, 200) else Ui.PARCHMENT
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color, stroke.Thickness = if button.Name == id then Ui.LEAF else Ui.COCOA, if button.Name == id then 4 else 3
			end
		end
	end
end

local function refreshList()
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local any = false
	for id, data in Furniture.Items do
		local count = player:GetAttribute("Item_" .. id) or 0
		if count > 0 then
			any = true
			local button = Ui.button(list, "", { Name = id, LayoutOrder = data.Order, Size = UDim2.fromOffset(76, 84) })
			local icon = Icons.View("Furniture", id, { Size = UDim2.fromOffset(54, 54), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2) })
			icon.Parent = button
			Ui.text(button, data.Name, 14, { Position = UDim2.fromOffset(2, 54), Size = UDim2.new(1, -4, 0, 16), TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd })
			local n = Ui.text(button, "×" .. count, 14, { FontFace = Ui.NUM, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2),
				Size = UDim2.fromOffset(30, 16), TextXAlignment = Enum.TextXAlignment.Right })
			Ui.stroke(n, 2, Ui.CREAM, true)
			button.Activated:Connect(function()
				choose(if selected == id then nil else id)
			end)
		end
	end
	empty.Visible = not any
	if selected and (player:GetAttribute("Item_" .. selected) or 0) == 0 then
		choose(nil)
	else
		choose(selected)
	end
end

local function setMode(on)
	player:SetAttribute("DecorMode", if on then true else nil)
	if on then
		Ui.open(panel)
		refreshList()
	else
		Ui.close(panel)
		choose(nil)
	end
end

local function rotate()
	rotation = (rotation + 90) % 360
	if ghost then
		Juice.Sound("switch.wav", 1.2, 0.25)
	end
end

Juice.Bus.ToggleDecor.Event:Connect(function()
	setMode(not Ui.IsOpen(panel))
end)
doneButton.Activated:Connect(function()
	setMode(false)
end)
rotateButton.Activated:Connect(rotate)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.R and panel.Visible then
		rotate()
	end
end)

player.AttributeChanged:Connect(function(name)
	if panel.Visible and name:sub(1, 5) == "Item_" then
		refreshList()
	end
end)

-- NPC와 대화를 시작하면 꾸미기를 끈다
Remotes.Dialogue.OnClientEvent:Connect(function(message)
	if not message.Close and panel.Visible then
		setMode(false)
	end
end)

-- 미리보기가 포인터를 따라간다(터치 기기는 누른 자리에 바로 놓는다)
RunService.RenderStepped:Connect(function()
	if ghost and UserInputService.MouseEnabled then
		local result = WorldPointer.CastMouse()
		if result then
			ghost:PivotTo(CFrame.new(snap(result.Position)) * CFrame.Angles(0, math.rad(rotation), 0))
		end
	end
end)

local function taggedAncestor(instance, tag)
	while instance and instance ~= workspace do
		if CollectionService:HasTag(instance, tag) and instance:GetAttribute("Owner") == player.UserId then
			return instance
		end
		instance = instance.Parent
	end
	return nil
end

WorldPointer.OnTap(function(result)
	if panel.Visible then
		if selected then
			Remotes.Interact:FireServer("Place", nil, { Id = selected, Position = snap(result.Position), Rotation = rotation })
		else
			local model = taggedAncestor(result.Instance, "Placed")
			if model then
				Remotes.Interact:FireServer("Pickup", model)
			end
		end
	else
		local chore = taggedAncestor(result.Instance, "Chore")
		if chore then
			Remotes.Interact:FireServer("Chore", chore)
		end
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
