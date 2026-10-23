-- 블록 모형 만들기(서버·클라이언트 공용): 생물·물고기·광석·작물·도구. 월드(생물, 농지 작물, 손에 쥔 도구,
-- 낚은 물고기가 날아오는 모형)와 3D 아이콘(ViewportFrame)이 같은 함수를 쓴다.
-- 모두 앵커 없는 Model을 돌려준다(PrimaryPart = Root, 나머지는 Root에 용접).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Crops = require(ReplicatedStorage.Shared.Crops)
local Fish = require(ReplicatedStorage.Shared.Fish)
local Ores = require(ReplicatedStorage.Shared.Ores)

local M = Enum.Material
local Models = {}

local function part(model, size, cframe, color, material, shape, transparency)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Transparency = transparency or 0
	p.CanCollide, p.CanTouch, p.Massless = false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- 기준 Part(PrimaryPart)에 나머지를 붙인다. 기준만 앵커하면 기준의 CFrame을 옮길 때 전체가 따라온다
local function weldAll(model, root)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = root, p
			weld.Parent = p
		end
	end
	model.PrimaryPart = root
	return model
end

-- 생물: Root = 발밑 가운데(나는 생물은 몸 가운데). 앞 = −Z
function Models.Creature(id)
	local def = Creatures[id]
	local model = Instance.new("Model")
	model.Name = id
	local root = part(model, Vector3.new(1, 0.2, 1), CFrame.new(), Color3.new(1, 1, 1), nil, nil, 1)
	root.Name = "Root"
	for _, spec in def.Parts do
		local p = part(model, spec[1], CFrame.new(spec[2]), spec[3], spec[4], spec[5], spec[6])
		if def.Light and spec[4] == M.Glass then
			p.Material = M.Neon
			p.Transparency = math.max(p.Transparency, 0.2)
		end
	end
	if def.Light then
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = def.Light, 10, 1
		light.Parent = root
	end
	return weldAll(model, root)
end

-- 물고기: 가운데 기준, 머리 = −Z. 장화는 장화 모양
function Models.Fish(id)
	local def = Fish[id]
	local s = def.Size
	local model = Instance.new("Model")
	model.Name = id
	local root
	if id == "Boot" then
		root = part(model, Vector3.new(0.6, 1.1, 0.7) * s, CFrame.new(0, 0.2 * s, 0.15 * s), def.Color, M.Fabric)
		part(model, Vector3.new(0.6, 0.45, 1.2) * s, CFrame.new(0, -0.35 * s, -0.1 * s), def.Color, M.Fabric)
		part(model, Vector3.new(0.65, 0.12, 1.25) * s, CFrame.new(0, -0.6 * s, -0.1 * s), Color3.fromRGB(60, 45, 35))
	else
		root = part(model, Vector3.new(0.55, 0.8, 1.6) * s, CFrame.new(), def.Color, M.SmoothPlastic, Enum.PartType.Ball)
		part(model, Vector3.new(0.12, 0.7, 0.55) * s, CFrame.new(0, 0, 0.95 * s), def.Color:Lerp(Color3.new(0, 0, 0), 0.15))
		part(model, Vector3.new(0.08, 0.35, 0.5) * s, CFrame.new(0, 0.45 * s, 0.1 * s), def.Color:Lerp(Color3.new(1, 1, 1), 0.25))
		for _, x in { -0.25, 0.25 } do
			part(model, Vector3.one * 0.14 * s, CFrame.new(x * s, 0.12 * s, -0.55 * s), Color3.fromRGB(25, 25, 30), M.SmoothPlastic, Enum.PartType.Ball)
		end
		if id == "GoldenKoi" or id == "Catfish" then
			local glow = Instance.new("PointLight")
			glow.Color, glow.Range, glow.Brightness = def.Color, 6, 1
			glow.Parent = root
		end
	end
	return weldAll(model, root)
end

-- 작물 단계 모형(0 씨앗 ~ 3 수확). Root = 땅 가운데. 농지(FarmService)와 아이콘이 같이 쓴다
function Models.Crop(id, stage)
	local crop = Crops[id]
	local model = Instance.new("Model")
	model.Name = "Crop"
	local root = part(model, Vector3.new(1, 0.1, 1), CFrame.new(), Color3.new(1, 1, 1), nil, nil, 1)
	root.Name = "Root"
	local leaf = crop.Leaf
	if stage == 0 then
		part(model, Vector3.new(1.6, 0.5, 1.6), CFrame.new(), Color3.fromRGB(115, 80, 55), M.Ground, Enum.PartType.Ball)
	else
		local size = if stage == 1 then Vector3.new(0.25, 0.7, 0.45) else Vector3.new(0.3, 1.3, 0.7)
		local count = if stage == 1 then 2 else 4
		for i = 1, count do
			local yaw = math.rad(360 / count * i + 20)
			part(model, size, CFrame.Angles(0, yaw, math.rad(25)) * CFrame.new(0, size.Y / 2, 0), leaf, M.Grass)
		end
	end
	if stage == 3 then
		if crop.Shape == "Root" then
			part(model, Vector3.one * 1.5, CFrame.new(0, 0.25, 0), crop.Fruit, M.SmoothPlastic, Enum.PartType.Ball)
		elseif crop.Shape == "Carrot" then
			part(model, Vector3.new(1, 1.1, 1.1), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), crop.Fruit,
				M.SmoothPlastic, Enum.PartType.Cylinder)
		else
			part(model, Vector3.one * 2, CFrame.new(0, 0.7, 0), leaf, M.Grass, Enum.PartType.Ball)
			for i = 1, 5 do
				local yaw = math.rad(72 * i)
				part(model, Vector3.one * 0.5, CFrame.Angles(0, yaw, 0) * CFrame.new(0.95, 0.6 + (i % 2) * 0.4, 0), crop.Fruit,
					M.SmoothPlastic, Enum.PartType.Ball)
			end
		end
	end
	return weldAll(model, root)
end

-- 손에 쥐는 도구(Hoe 괭이 · Can 물뿌리개 · Rod 낚싯대 · Pickaxe 곡괭이). Root = 손잡이, 도구 끝 = −Z.
-- 낚싯대 끝에는 Attachment "Tip"(낚싯줄 Beam이 붙는다)
function Models.Tool(kind)
	local model = Instance.new("Model")
	model.Name = kind
	local wood, metal = Color3.fromRGB(140, 100, 60), Color3.fromRGB(175, 180, 185)
	local root
	if kind == "Hoe" then
		root = part(model, Vector3.new(0.25, 0.25, 4), CFrame.new(0, 0, -1.3), wood, M.Wood)
		part(model, Vector3.new(0.3, 1.1, 0.5), CFrame.new(0, -0.45, -3.2), metal, M.Metal)
	elseif kind == "Can" then
		root = part(model, Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, -0.3, -0.3), Color3.fromRGB(110, 170, 230))
		part(model, Vector3.new(0.25, 0.25, 1.2), CFrame.new(0, -0.1, -1.2) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(110, 170, 230))
	elseif kind == "Rod" then
		root = part(model, Vector3.new(0.22, 0.22, 5), CFrame.new(0, 0, -2.2) * CFrame.Angles(math.rad(12), 0, 0), wood, M.Wood)
		part(model, Vector3.new(0.4, 0.4, 0.3), CFrame.new(0.25, -0.05, -0.2), metal, M.Metal, Enum.PartType.Cylinder)
		local tip = Instance.new("Attachment")
		tip.Name = "Tip"
		tip.Position = Vector3.new(0, 0, -2.5)
		tip.Parent = root
	elseif kind == "Pickaxe" then
		root = part(model, Vector3.new(0.25, 0.25, 3.4), CFrame.new(0, 0, -1.1), wood, M.Wood)
		part(model, Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 0, -2.85), metal, M.Metal)
		part(model, Vector3.new(0.3, 2.4, 0.3), CFrame.new(0, 0, -2.85), metal, M.Metal)
		part(model, Vector3.new(0.3, 0.3, 0.7), CFrame.new(0, 1.05, -2.6), metal, M.Metal)
		part(model, Vector3.new(0.3, 0.3, 0.7), CFrame.new(0, -1.05, -2.6), metal, M.Metal)
	end
	return weldAll(model, root)
end

-- 광석: 돌 블록 + 광석 색 알갱이(가운데 기준, 한 변 2스터드)
function Models.Ore(id)
	local def = Ores[id]
	local model = Instance.new("Model")
	model.Name = id
	local root = part(model, Vector3.one * 2, CFrame.new(), Color3.fromRGB(125, 125, 125), M.Slate)
	local spots = { { 1, 0.4, 0.3 }, { 1, -0.5, -0.4 }, { -1, 0.2, -0.5 }, { -1, -0.4, 0.5 }, { 0.3, 1, -0.4 }, { -0.4, 1, 0.4 },
		{ 0.5, -0.3, -1 }, { -0.4, 0.4, -1 }, { 0.2, 0.5, 1 }, { -0.5, -0.5, 1 } }
	for _, s in spots do
		part(model, Vector3.one * 0.55, CFrame.new(s[1], s[2], s[3]), def.Color,
			if id == "Amethyst" or id == "Diamond" then M.Glass else M.SmoothPlastic)
	end
	return weldAll(model, root)
end

return Models
