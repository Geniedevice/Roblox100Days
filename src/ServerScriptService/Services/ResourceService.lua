-- 자원 노드(나무·바위·열매 덤불·웅덩이)를 코어 주변에 흩어 놓는다.
-- ProximityPrompt를 꾹 누르면 채집되어 사라지고, Config의 Respawn초 뒤 다시 생긴다.
-- 모양: ServerStorage.ResourceModels에 같은 이름의 모델(또는 변형 여러 개가 든 Folder)이 있으면 그걸,
-- 없으면 아래 임시 파츠를 쓴다. 넣는 모델은 피벗이 바닥 중앙이고 PrimaryPart가 없어야 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseService = require(script.Parent.BaseService)
local InventoryService = require(script.Parent.InventoryService)

local ResourceService = {}
local folder
local nodes = {}

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

-- 원점(지면 y=0) 기준으로 만들고 나중에 옮긴다. 반환값이 프롬프트를 붙일 파츠.
-- 임시 모양이다. 맵 에셋이 생기면 교체한다.
local BUILDERS = {
	Tree = function(model)
		part(model, {
			Size = Vector3.new(7, 7, 7), Position = Vector3.new(0, 9, 0), Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(60, 130, 60), Material = Enum.Material.Grass, CanCollide = false,
		})
		return part(model, {
			Size = Vector3.new(8, 1.6, 1.6), CFrame = CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood,
		})
	end,
	Rock = function(model)
		return part(model, {
			Size = Vector3.new(4, 3, 4), Position = Vector3.new(0, 1.5, 0),
			Color = Color3.fromRGB(120, 120, 125), Material = Enum.Material.Slate,
		})
	end,
	Bush = function(model)
		return part(model, {
			Size = Vector3.new(4, 4, 4), Position = Vector3.new(0, 2, 0), Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(45, 100, 50), Material = Enum.Material.Grass, CanCollide = false,
		})
	end,
	Pond = function(model)
		return part(model, {
			Size = Vector3.new(0.4, 9, 9), CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(60, 140, 220), Material = Enum.Material.Glass,
			Transparency = 0.3, CanCollide = false,
		})
	end,
}

-- ponytail: 노드끼리 겹침 검사 없음. 겹침이 눈에 띄면 최소 간격 재시도를 넣는다.
local function randomGround(center)
	local angle = math.random() * math.pi * 2
	local radius = Config.Resources.MinRadius + math.random() * (Config.Resources.MaxRadius - Config.Resources.MinRadius)
	local x, z = center.X + math.cos(angle) * radius, center.Z + math.sin(angle) * radius

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, BaseService.GetCore().Parent }
	local hit = workspace:Raycast(Vector3.new(x, center.Y + 200, z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position
end

local function harvest(model, def, player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or model.Parent ~= folder then
		return
	end
	InventoryService.Add(player, def.Item, def.Amount)
	model.Parent = nil
	task.delay(def.Respawn, function()
		if folder then
			model.Parent = folder
		end
	end)
end

-- 반환: 모델, 프롬프트를 붙일 파츠
local function buildModel(typeName)
	local models = ServerStorage:FindFirstChild("ResourceModels")
	local source = models and models:FindFirstChild(typeName)
	if source then
		if source:IsA("Folder") then
			local variants = source:GetChildren()
			source = variants[math.random(#variants)]
		end
		local model = source:Clone()
		return model, model:FindFirstChildWhichIsA("BasePart", true)
	end
	local model = Instance.new("Model")
	local main = BUILDERS[typeName](model)
	model.WorldPivot = CFrame.new()
	return model, main
end

local function spawnNode(typeName, def, position)
	local model, main = buildModel(typeName)
	model.Name = typeName
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "채집"
	prompt.ObjectText = def.Label
	prompt.HoldDuration = def.HoldTime
	prompt.RequiresLineOfSight = false
	prompt.Parent = main
	prompt.Triggered:Connect(function(player)
		harvest(model, def, player)
	end)

	model.Parent = folder
	table.insert(nodes, model)
end

function ResourceService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Resources"
	folder.Parent = workspace

	local center = BaseService.GetCorePosition()
	for typeName, def in Config.Resources.Nodes do
		for _ = 1, def.Count do
			local position = randomGround(center)
			if position then
				spawnNode(typeName, def, position)
			end
		end
	end
end

-- 새 판: 채집된 노드를 전부 되돌린다.
function ResourceService.Reset()
	for _, model in nodes do
		model.Parent = folder
	end
end

return ResourceService
