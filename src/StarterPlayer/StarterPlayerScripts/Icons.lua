-- 3D 아이콘: ViewportFrame에 게임 자체 모형을 넣어 비춘다(업로드한 이미지 없음). 핫바·상점·도감·토스트·날아가는 아이콘이 쓴다.
-- 종류(kind): Crop · Seed(씨앗 주머니) · Fish · Ore · Creature · Furniture · Island(컨셉 복셀 덩어리) · Coin · Tool(Hoe/Can/Rod/Pickaxe)
--   · Book(도감) · House(꾸미기·아늑함) · Gear(설정) · Chunk(구역 땅 덩어리) · Friends(친구 창)
-- 카메라: FOV 28, 오른쪽 35°·위에서 22° 내려다보는 3/4 시점, 모형 크기에 맞춰 거리. 못 찾은 도감은 검은 실루엣.
-- 명세: design/ux/ui-research.md §4.6
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared:WaitForChild("Crops"))
local Furniture = require(Shared:WaitForChild("Furniture"))
local IslandConcepts = require(Shared:WaitForChild("IslandConcepts"))
local Models = require(Shared:WaitForChild("Models"))
local Pets = require(Shared:WaitForChild("Pets"))

local M = Enum.Material
local rgb = Color3.fromRGB
local FOV = 28
local FACING = { Creature = true, Fish = true } -- 앞(−Z)을 보여 준다
local ZONE_COLORS = { Farm = rgb(120, 185, 80), House = rgb(200, 160, 110), Mine = rgb(140, 140, 145), Wild = rgb(70, 140, 60),
	Fishing = rgb(90, 160, 230), Plaza = rgb(210, 180, 120) }

local Icons = {}

local function part(model, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Size, p.CFrame, p.Color = size, cframe, color
	p.Material = material or M.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- 블록 3단 덩어리(떠 있는 섬처럼): 위 3×3 top, 가운데 2×2 흙, 아래 1×1 돌
local function voxelChunk(model, top)
	for x = -1, 1 do
		for z = -1, 1 do
			part(model, Vector3.one, CFrame.new(x, 1, z), top:Lerp(Color3.new(1, 1, 1), ((x + z) % 2) * 0.06), M.Grass)
		end
	end
	for x = -0.5, 0.5 do
		for z = -0.5, 0.5 do
			part(model, Vector3.one, CFrame.new(x, 0, z), rgb(134, 96, 67), M.Ground)
		end
	end
	part(model, Vector3.one, CFrame.new(0, -1, 0), rgb(125, 125, 125), M.Slate)
end

local BUILDERS = {
	Crop = function(id)
		return Models.Crop(id, 3)
	end,
	Seed = function(id)
		local model = Instance.new("Model")
		part(model, Vector3.new(1.2, 1.4, 1.2), CFrame.new(0, 0, 0), rgb(205, 170, 120), M.Fabric, Enum.PartType.Ball)
		part(model, Vector3.new(0.35, 0.7, 0.7), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(185, 150, 100), M.Fabric, Enum.PartType.Cylinder)
		part(model, Vector3.new(0.25, 1.25, 1.25), CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Crops[id].Fruit,
			M.SmoothPlastic, Enum.PartType.Cylinder)
		part(model, Vector3.new(0.15, 0.5, 0.3), CFrame.new(0.1, 1.25, 0) * CFrame.Angles(0, 0, math.rad(20)), Crops[id].Leaf, M.Grass)
		return model
	end,
	Fish = function(id)
		return Models.Fish(id)
	end,
	Ore = function(id)
		return Models.Ore(id)
	end,
	Creature = function(id)
		return Models.Creature(id)
	end,
	Furniture = function(id)
		return Furniture.Build(id)
	end,
	Island = function(id)
		local model = Instance.new("Model")
		local concept = IslandConcepts[id]
		voxelChunk(model, concept and concept.Tint and concept.Tint.Grass or (concept and concept.Color) or ZONE_COLORS.Wild)
		return model
	end,
	Chunk = function(zone)
		local model = Instance.new("Model")
		voxelChunk(model, ZONE_COLORS[zone] or ZONE_COLORS.Wild)
		return model
	end,
	Coin = function()
		local model = Instance.new("Model")
		local tilt = CFrame.Angles(0, math.rad(90), math.rad(20))
		part(model, Vector3.new(0.3, 2, 2), tilt, rgb(255, 200, 60), M.SmoothPlastic, Enum.PartType.Cylinder)
		part(model, Vector3.new(0.34, 1.4, 1.4), tilt, rgb(230, 160, 40), M.SmoothPlastic, Enum.PartType.Cylinder)
		return model
	end,
	Tool = function(kind)
		return Models.Tool(kind)
	end,
	Book = function()
		local model = Instance.new("Model")
		part(model, Vector3.new(1.6, 2, 0.5), CFrame.Angles(0, math.rad(-20), 0), rgb(255, 140, 170))
		part(model, Vector3.new(1.4, 1.85, 0.52), CFrame.Angles(0, math.rad(-20), 0) * CFrame.new(0.12, 0, 0), rgb(255, 248, 235))
		part(model, Vector3.new(0.6, 0.6, 0.1), CFrame.Angles(0, math.rad(-20), 0) * CFrame.new(-0.1, 0.3, -0.28), rgb(255, 200, 60))
		return model
	end,
	House = function()
		local model = Instance.new("Model")
		part(model, Vector3.new(1.6, 1.2, 1.4), CFrame.new(0, -0.3, 0), rgb(255, 248, 235))
		for _, side in { -1, 1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Size = Vector3.new(1.8, 0.8, 0.8)
			wedge.CFrame = CFrame.new(0, 0.7, side * 0.4) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
			wedge.Color = rgb(170, 95, 70)
			wedge.Parent = model
		end
		part(model, Vector3.new(0.4, 0.6, 0.1), CFrame.new(0, -0.6, -0.72), rgb(150, 105, 70))
		return model
	end,
	Friends = function()
		local model = Instance.new("Model")
		for i, shirt in { rgb(120, 190, 255), rgb(255, 140, 170) } do
			local x = (i - 1.5) * 1.3
			part(model, Vector3.new(1, 1.1, 0.6), CFrame.new(x, -0.55, 0), shirt)
			part(model, Vector3.new(0.8, 0.8, 0.8), CFrame.new(x, 0.45, 0), rgb(255, 220, 190))
		end
		return model
	end,
	Gear = function()
		local model = Instance.new("Model")
		part(model, Vector3.new(0.5, 1.4, 1.4), CFrame.Angles(0, math.rad(90), 0), rgb(170, 175, 185), M.Metal, Enum.PartType.Cylinder)
		for i = 0, 5 do
			part(model, Vector3.new(0.45, 0.45, 0.5), CFrame.Angles(0, 0, math.rad(60 * i)) * CFrame.new(0, 0.85, 0), rgb(170, 175, 185), M.Metal)
		end
		part(model, Vector3.new(0.55, 0.5, 0.5), CFrame.Angles(0, math.rad(90), 0), rgb(110, 115, 125), M.Metal, Enum.PartType.Cylinder)
		return model
	end,
}

function Icons.Model(kind, id)
	local builder = BUILDERS[kind]
	return builder and builder(id) or nil
end

local spinning = {} -- [ViewportFrame] = { Camera, Center, Distance, Yaw, Speed }
RunService.RenderStepped:Connect(function(dt)
	for view, spin in spinning do
		if not view.Parent then
			spinning[view] = nil
		elseif view.Visible then
			spin.Yaw += spin.Speed * dt
			spin.Camera.CFrame = CFrame.new(spin.Center) * CFrame.Angles(0, math.rad(spin.Yaw), 0) * CFrame.Angles(math.rad(-22), 0, 0)
				* CFrame.new(0, 0, spin.Distance)
		end
	end
end)

-- props: Size, Position, AnchorPoint, ZIndex, Silhouette(못 찾은 도감), Spin(초당 도), LayoutOrder 등 ViewportFrame 속성
function Icons.View(kind, id, props)
	props = props or {}
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromOffset(48, 48)
	view.Ambient = rgb(205, 200, 195)
	view.LightColor = rgb(255, 244, 225)
	view.LightDirection = Vector3.new(-0.6, -1, -0.4)
	local silhouette, spin = props.Silhouette, props.Spin
	for key, value in props do
		if key ~= "Silhouette" and key ~= "Spin" then
			view[key] = value
		end
	end
	local model = Icons.Model(kind, id)
	if not model then
		return view
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif silhouette and d:IsA("BasePart") then
			d.Color, d.Material, d.Transparency = Color3.new(0, 0, 0), M.SmoothPlastic, math.min(d.Transparency, 0.2)
		elseif d:IsA("BasePart") and d.Transparency >= 1 then
			d:Destroy() -- 투명한 기준 Part는 크기 계산에서 뺀다
		end
	end
	if silhouette then
		view.Ambient, view.LightColor = Color3.new(0, 0, 0), Color3.new(0, 0, 0)
		view.ImageTransparency = 0.15
	end
	model.Parent = view
	local cframe, size = model:GetBoundingBox()
	local center = cframe.Position
	local radius = size.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	local distance = radius / math.sin(math.rad(FOV / 2)) * 1.08
	local yaw = if FACING[kind] then 215 else 35
	camera.CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(0, 0, distance)
	camera.Parent = view
	view.CurrentCamera = camera
	if spin then
		spinning[view] = { Camera = camera, Center = center, Distance = distance, Yaw = yaw, Speed = spin }
	end
	return view
end

-- 아이템 Id("Seed_Turnip", "Fish_Trout", "Ore_Iron", "Pet_Frog", 작물 Id, 가구 Id) → 아이콘 종류, Id
function Icons.ForItem(itemId)
	local prefix, rest = itemId:match("^(%a+)_(.+)$")
	if prefix == "Seed" then
		return "Seed", rest
	elseif prefix == "Fish" then
		return "Fish", rest
	elseif prefix == "Ore" then
		return "Ore", rest
	elseif prefix == "Pet" and Pets[rest] then
		return "Creature", Pets[rest].Creature
	elseif Crops[itemId] then
		return "Crop", itemId
	elseif Furniture.Items[itemId] then
		return "Furniture", itemId
	end
	return nil
end

return Icons
