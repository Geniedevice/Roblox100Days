-- 세상의 움직임(클라이언트에서만, 복제 안 됨): 작물이 자라면 튀어 오르고 다 자란 작물은 살랑 흔들린다.
-- NPC는 숨 쉬듯 오르내리고 말 거는 플레이어를 바라보며, 같은 섬 NPC끼리 20초마다 말풍선으로 잡담한다.
-- 명세: design/gdd/action-animation.md
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lines = require(Shared:WaitForChild("Lines"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local RANGE = 120 -- 이보다 먼 것은 움직이지 않는다
local SWAY = math.rad(4)
local SWAY_PERIOD = 2.5
local BREATH, BREATH_PERIOD = 0.15, 3
local CHAT_EVERY = 20

local crops = {} -- [모델] = { Base, Phase, Popping }
local npcs = {} -- [모델] = { Base, Phase }
local focus -- 나와 대화 중인 NPC

local function near(position)
	return (workspace.CurrentCamera.CFrame.Position - position).Magnitude <= RANGE
end

local function phaseOf(position)
	return (position.X * 0.7 + position.Z * 1.3) % (2 * math.pi)
end

-- 0.2배 → 1.15배 → 1배
local function pop(model, entry)
	entry.Popping = true
	local value = Instance.new("NumberValue")
	value.Value = 0.2
	model:ScaleTo(0.2)
	value.Changed:Connect(function(scale)
		if model.Parent then
			model:ScaleTo(scale)
		end
	end)
	local up = TweenService:Create(value, TweenInfo.new(0.21, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1.15 })
	local down = TweenService:Create(value, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Value = 1 })
	up.Completed:Once(function()
		down:Play()
	end)
	down.Completed:Once(function()
		value:Destroy()
		entry.Popping = false
	end)
	up:Play()
end

local function addCrop(model, animate)
	local tile = model.Parent
	if not (tile and tile:IsA("BasePart")) then
		return
	end
	local base = tile.CFrame * CFrame.new(0, tile.Size.Y / 2, 0)
	model.WorldPivot = base -- 땅을 축으로 커지고 흔들린다
	local entry = { Base = base, Phase = phaseOf(base.Position), Popping = false }
	crops[model] = entry
	if animate and near(base.Position) then
		pop(model, entry)
	end
end

CollectionService:GetInstanceAddedSignal("Crop"):Connect(function(model)
	addCrop(model, true)
end)
CollectionService:GetInstanceRemovedSignal("Crop"):Connect(function(model)
	crops[model] = nil
end)
for _, model in CollectionService:GetTagged("Crop") do
	addCrop(model, false)
end

local function addNpc(model)
	npcs[model] = { Base = model:GetPivot(), Phase = phaseOf(model:GetPivot().Position) }
end
CollectionService:GetInstanceAddedSignal("Npc"):Connect(addNpc)
CollectionService:GetInstanceRemovedSignal("Npc"):Connect(function(model)
	npcs[model] = nil
end)
for _, model in CollectionService:GetTagged("Npc") do
	addNpc(model)
end

Remotes.Dialogue.OnClientEvent:Connect(function(message)
	if message.Close then
		focus = nil
	elseif message.Npc then
		focus = message.Npc
	end
end)

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for model, entry in crops do
		if not entry.Popping and model:GetAttribute("Stage") == 3 and near(entry.Base.Position) then
			model:PivotTo(entry.Base * CFrame.Angles(0, 0, SWAY * math.sin(t * 2 * math.pi / SWAY_PERIOD + entry.Phase)))
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for model, entry in npcs do
		if model.Parent and near(entry.Base.Position) then
			local position = entry.Base.Position + Vector3.new(0, BREATH * math.sin(t * 2 * math.pi / BREATH_PERIOD + entry.Phase), 0)
			local cframe = entry.Base.Rotation + position
			if model == focus and root then
				cframe = CFrame.lookAt(position, Vector3.new(root.Position.X, position.Y, root.Position.Z))
			end
			model:PivotTo(cframe)
		end
	end
end)

-- NPC끼리 잡담: 섬마다 Lines.Chatter 순서대로, 말하는 NPC가 섬에 있을 때만
local chatIndex = {} -- [섬 모델] = 다음 순번
task.spawn(function()
	while true do
		task.wait(CHAT_EVERY)
		local byIsland = {}
		for model, entry in npcs do
			if model.Parent and near(entry.Base.Position) then
				byIsland[model.Parent] = byIsland[model.Parent] or {}
				byIsland[model.Parent][model:GetAttribute("NpcId")] = model
			end
		end
		for island, present in byIsland do
			local count = 0
			for _ in present do
				count += 1
			end
			if count >= 2 then
				local i = chatIndex[island] or 1
				local line = Lines.Chatter[i]
				chatIndex[island] = i % #Lines.Chatter + 1
				local speaker = present[line[1]]
				local head = speaker and speaker:FindFirstChild("Head")
				if head then
					pcall(TextChatService.DisplayBubble, TextChatService, head, Lines.Get(line[2]))
				end
			end
		end
	end
end)
