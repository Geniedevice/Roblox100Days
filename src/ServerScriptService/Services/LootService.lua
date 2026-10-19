-- 도시 파밍. Workspace.LootSpots의 파츠(속성 Container = Config.Loot의 종류)마다 상자를 놓는다.
-- 파츠의 CFrame이 상자 바닥 중앙이다. ProximityPrompt를 꾹 눌러 뒤지면 Drops에서 아이템을 얻고,
-- 상자는 비었다가 Respawn초 뒤 다시 채워진다.
-- 모양: ServerStorage.LootModels/<종류>(피벗이 바닥 중앙, PrimaryPart 없음)가 있으면 그걸, 없으면 아래 파츠를 쓴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local InventoryService = require(script.Parent.InventoryService)

local LootService = {}
local containers = {} -- [model] = prompt

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = model
	return p
end

-- 원점(바닥 y=0) 기준. 반환값이 프롬프트를 붙일 파츠.
local BUILDERS = {
	Crate = function(model)
		return part(model, {
			Size = Vector3.new(3, 2.4, 3), Position = Vector3.new(0, 1.2, 0),
			Color = Color3.fromRGB(150, 110, 65), Material = Enum.Material.WoodPlanks,
		})
	end,
	Fridge = function(model)
		part(model, {
			Size = Vector3.new(0.1, 1.6, 0.2), Position = Vector3.new(-1.1, 4, -1.3),
			Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Metal,
		})
		return part(model, {
			Size = Vector3.new(3, 6, 2.4), Position = Vector3.new(0, 3, 0),
			Color = Color3.fromRGB(225, 228, 230), Material = Enum.Material.SmoothPlastic,
		})
	end,
	Medical = function(model)
		part(model, {
			Size = Vector3.new(0.6, 1.6, 0.1), Position = Vector3.new(0, 1.1, -1.05),
			Color = Color3.fromRGB(220, 40, 40), Material = Enum.Material.SmoothPlastic,
		})
		part(model, {
			Size = Vector3.new(1.6, 0.6, 0.1), Position = Vector3.new(0, 1.1, -1.05),
			Color = Color3.fromRGB(220, 40, 40), Material = Enum.Material.SmoothPlastic,
		})
		return part(model, {
			Size = Vector3.new(2.4, 2.2, 2), Position = Vector3.new(0, 1.1, 0),
			Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.SmoothPlastic,
		})
	end,
	Car = function(model)
		local body = part(model, {
			Size = Vector3.new(6, 2.2, 12), Position = Vector3.new(0, 1.9, 0),
			Color = Color3.fromRGB(120, 60, 50), Material = Enum.Material.CorrodedMetal,
		})
		part(model, {
			Size = Vector3.new(5.4, 1.8, 6), Position = Vector3.new(0, 3.9, 0.5),
			Color = Color3.fromRGB(60, 70, 80), Material = Enum.Material.Glass, Transparency = 0.3,
		})
		for _, x in { -3, 3 } do
			for _, z in { -3.8, 3.8 } do
				part(model, {
					Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 1.8, 1.8),
					Position = Vector3.new(x, 0.9, z), Color = Color3.fromRGB(30, 30, 30),
				})
			end
		end
		return body
	end,
}

local function buildModel(kind)
	local models = ServerStorage:FindFirstChild("LootModels")
	local source = models and models:FindFirstChild(kind)
	if source then
		local model = source:Clone()
		return model, model:FindFirstChildWhichIsA("BasePart", true)
	end
	local model = Instance.new("Model")
	local main = BUILDERS[kind](model)
	model.WorldPivot = CFrame.new()
	return model, main
end

-- Drops에서 굴린다. 아무것도 안 나오면 첫 번째 것을 1개 준다.
local function roll(def)
	local got, any = {}, false
	for _, drop in def.Drops do
		local count = math.random(drop.Min, drop.Max)
		if count > 0 then
			got[drop.Item] = (got[drop.Item] or 0) + count
			any = true
		end
	end
	if not any then
		got[def.Drops[1].Item] = 1
	end
	return got
end

local function setLooted(model, looted)
	model:SetAttribute("Looted", looted)
	containers[model].Enabled = not looted
end

local function search(model, def, player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or model:GetAttribute("Looted") then
		return
	end
	setLooted(model, true)

	local parts = {}
	for item, count in roll(def) do
		InventoryService.Add(player, item, count)
		table.insert(parts, Config.Items[item].Name .. " " .. count)
	end
	Remotes.GameMessage:FireClient(player, "획득: " .. table.concat(parts, ", "))

	task.delay(def.Respawn, function()
		if containers[model] then
			setLooted(model, false)
		end
	end)
end

local function spawnContainer(kind, def, cframe, folder)
	local model, main = buildModel(kind)
	model.Name = kind
	model:PivotTo(cframe)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "뒤지기"
	prompt.ObjectText = def.Label
	prompt.HoldDuration = def.HoldTime
	prompt.RequiresLineOfSight = false
	prompt.Parent = main
	containers[model] = prompt
	prompt.Triggered:Connect(function(player)
		search(model, def, player)
	end)

	model.Parent = folder
end

function LootService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Loot"
	folder.Parent = workspace

	local spots = workspace:FindFirstChild("LootSpots")
	if not spots then
		warn("[LootService] Workspace.LootSpots가 없어 파밍 상자를 놓지 않았습니다")
		return
	end
	for _, spot in spots:GetChildren() do
		local kind = spot:GetAttribute("Container")
		local def = kind and Config.Loot[kind]
		if spot:IsA("BasePart") and def then
			spawnContainer(kind, def, spot.CFrame, folder)
		end
	end
end

-- 새 판: 모든 상자를 다시 채운다.
function LootService.Reset()
	for model in containers do
		setLooted(model, false)
	end
end

return LootService
